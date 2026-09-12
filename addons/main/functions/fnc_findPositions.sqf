#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The tactical position system: scored fighting, hiding and stepping-stone positions
 * around a point, the way a soldier reads ground. Candidates come from walls, rocks,
 * bushes and trees (the far side from the threat), building positions (cached per
 * house), dips in the ground below the threat's line of sight, and parked vehicles or
 * wrecks. Spots too close to a known enemy, in water, blacklisted for this man or
 * already claimed by a squadmate are dropped. The rest are scored cheaply, the best
 * few are then tested with two rays each (body height and head height from the
 * threat) so the stance and whether the man can shoot back are known, not guessed.
 * Bounded work: one object scan of each kind, at most 40 candidates, 24 rays.
 *
 * Arguments:
 * 0: Centre AGL <ARRAY>
 * 1: Search radius <NUMBER>
 * 2: Threat positions AGL, the first is the main one, [] for none <ARRAY>
 * 3: Options <HASHMAP>, any of:
 *      "purpose"       "fight" (cover and a field of fire), "hide" (cover and concealment
 *                      first), "move" (a stepping stone towards "objective"), default "fight"
 *      "objective"     position AGL progress is measured against <ARRAY>
 *      "unit"          the man the query is for: path cost and his blacklist <OBJECT>
 *      "group"         group whose reservations count, default the unit's <GROUP>
 *      "indoorBias"    prefer positions under a roof <BOOL>
 *      "buildingsOnly" only building positions <BOOL>
 *      "minDistance"   drop candidates closer than this to the centre <NUMBER>
 *      "count"         how many to return, default 6 <NUMBER>
 *
 * Return Value:
 * positions, best first, each [positionAGL, coverHeight, canFire, stance, score, source] <ARRAY>
 *   coverHeight 0 none, 0.6 prone, 1.2 kneeling, 2 full; source "terrain", "building",
 *   "dip", "vehicle" or "open"
 *
 * Example:
 * [getPos bob, 25, [getPos angryJoe], createHashMapFromArray [["purpose", "fight"], ["unit", bob]]] call lambs_main_fnc_findPositions;
 *
 * Public: Yes
*/
#define MAX_CANDIDATES 40
#define RAY_TESTED 12
#define MAX_OBJECT_RADIUS 40
#define THREAT_CLEARANCE 20
#define RESERVED_BLOCK 2.5
#define RESERVED_CROWD 6
#define STANDOFF 1.4
#define DIP_SAMPLES 8
#define DIP_DEPTH 0.5
#define BODY_HEIGHT 0.45
#define HEAD_HEIGHT 1.55
#define THREAT_EYE 1.5
#define WEIGHT_COVER 1.5
#define WEIGHT_PROGRESS 3
#define WEIGHT_PATH 1.2
#define WEIGHT_ROAD 1
#define WEIGHT_CROWD 1
#define WEIGHT_INDOOR 2.5
#define WEIGHT_CONCEAL 1
#define WEIGHT_FIGHT 3
#define WEIGHT_HIDE 2
#define WEIGHT_EXPOSED 3
#define WEIGHT_UPPER_FLOOR 1.5
#define DEBUG_MS 2
#define HARD_TYPES ["WALL", "ROCK", "FENCE", "HIDE"]
#define SOFT_TYPES ["BUSH", "TREE", "SMALL TREE"]

params [["_centre", [], [[]]], ["_radius", 25, [0]], ["_threats", [], [[]]], ["_options", createHashMap, [createHashMap]]];

if (_centre isEqualTo []) exitWith {[]};
private _started = diag_tickTime;

private _purpose = _options getOrDefault ["purpose", "fight"];
private _objective = _options getOrDefault ["objective", []];
private _unit = _options getOrDefault ["unit", objNull];
private _group = _options getOrDefault ["group", group _unit];
private _indoorBias = _options getOrDefault ["indoorBias", false];
private _buildingsOnly = _options getOrDefault ["buildingsOnly", false];
private _minDistance = _options getOrDefault ["minDistance", 0];
private _count = _options getOrDefault ["count", 6];
private _threat = _threats param [0, []];
private _hasThreat = _threat isNotEqualTo [];
private _threatASL = if (_hasThreat) then {(AGLToASL _threat) vectorAdd [0, 0, THREAT_EYE]} else {[]};
private _from = if (isNull _unit) then {_centre} else {getPosATL _unit};
private _objectRadius = _radius min MAX_OBJECT_RADIUS;

// what is already taken, and what this man could not reach last time
private _reserved = [];
if (!isNull _group) then {
    private _table = _group getVariable QGVAR(reserved);
    if (!isNil "_table") then {
        private _own = hashValue _unit;
        {
            if (_x isNotEqualTo _own && {time < (_y select 1)}) then {_reserved pushBack (_y select 0);};
        } forEach _table;
    };
};
private _blacklist = [];
if (!isNull _unit) then {
    private _record = _unit getVariable QEGVAR(danger,unit);
    if (!isNil "_record") then {
        _blacklist = (_record getOrDefault ["unreachable", []]) select {time < (_x select 1)};
        _blacklist = _blacklist apply {_x select 0};
    };
};

// candidates ~ [posAGL, coverGuess, source, soft, indoor, floor]
private _candidates = [];
private _fnc_add = {
    params ["_pos", "_cover", "_source", ["_soft", false], ["_indoor", false], ["_floor", 0]];
    private _distance = _pos distance2D _centre;
    if (_distance > _radius || {_distance < _minDistance}) exitWith {};
    if (surfaceIsWater _pos) exitWith {};
    if ((_threats findIf {_x distance2D _pos < THREAT_CLEARANCE}) isNotEqualTo -1) exitWith {};
    if ((_reserved findIf {_x distance2D _pos < RESERVED_BLOCK}) isNotEqualTo -1) exitWith {};
    if ((_blacklist findIf {_x distance2D _pos < RESERVED_BLOCK}) isNotEqualTo -1) exitWith {};
    _candidates pushBack [_pos, _cover, _source, _soft, _indoor, _floor];
};

// the side of an object away from the threat, or facing the centre when nothing is known
private _fnc_behind = {
    params ["_object", "_standoff"];
    if (_hasThreat) then {_object getPos [_standoff, _threat getDir _object]} else {_object getPos [_standoff, _object getDir _centre]}
};

if (!_buildingsOnly) then {
    // walls, rocks and fences stop bullets; bushes and trees mostly hide the man
    {
        [[_x, STANDOFF] call _fnc_behind, 1.2, "terrain", false] call _fnc_add;
    } forEach (nearestTerrainObjects [_centre, HARD_TYPES, _objectRadius, false, true]);
    {
        [[_x, STANDOFF] call _fnc_behind, 0.6, "terrain", true] call _fnc_add;
    } forEach (nearestTerrainObjects [_centre, SOFT_TYPES, _objectRadius, false, true]);

    // dips in the ground ~ lower than the centre, or out of the threat's sight behind a crest
    private _baseHeight = getTerrainHeightASL _centre;
    private _dipRadius = (_radius * 0.6) max 4;
    for "_i" from 0 to (DIP_SAMPLES - 1) do {
        private _pos = _centre getPos [_dipRadius, _i * (360 / DIP_SAMPLES)];
        private _drop = _baseHeight - (getTerrainHeightASL _pos);
        private _hidden = _hasThreat && {terrainIntersectASL [(AGLToASL _pos) vectorAdd [0, 0, BODY_HEIGHT], _threatASL]};
        if (_drop > DIP_DEPTH || _hidden) then {[_pos, 0.6, "dip"] call _fnc_add;};
    };

    // parked vehicles and wrecks
    {
        if (speed _x < 1 && {!(_x isKindOf "StaticWeapon")}) then {
            [[_x, 3] call _fnc_behind, 1.2, "vehicle"] call _fnc_add;
        };
    } forEach (nearestObjects [_centre, ["LandVehicle"], _objectRadius min 30]);
};

// buildings ~ only where there are any, from the per-house cache
private _houses = nearestObjects [_centre, ["House"], _objectRadius];
{
    private _house = _x;
    {
        _x params ["_pos", "_indoor", "_floor"];
        [_pos, [1.2, 2] select _indoor, "building", false, _indoor, _floor] call _fnc_add;
    } forEach ([_house] call FUNC(findPositionsBuilding));
} forEach _houses;

// nothing at all ~ open ground, spread around the centre, prone
if (_candidates isEqualTo []) then {
    private _spread = (_radius * 0.5) max 3;
    for "_i" from 0 to 3 do {
        [_centre getPos [_spread, 45 + _i * 90], 0, "open"] call _fnc_add;
    };
    if (_candidates isEqualTo []) then {_candidates pushBack [_centre, 0, "open", false, false, 0];};
};

// cheap score
private _fromObjective = if (_objective isNotEqualTo []) then {_centre distance2D _objective} else {0};
private _unitIndoor = !isNull _unit && {_unit call FUNC(isIndoor)};
_candidates = _candidates apply {
    _x params ["_pos", "_cover", "_source", "_soft", "_indoor", "_floor"];
    private _score = _cover * WEIGHT_COVER;
    if (_objective isNotEqualTo [] && {_purpose isEqualTo "move"}) then {
        _score = _score + ((_fromObjective - (_pos distance2D _objective)) / (_radius max 1)) * WEIGHT_PROGRESS;
    };
    _score = _score - ((_from distance2D _pos) / (_radius max 1)) * WEIGHT_PATH;
    if (isOnRoad _pos) then {_score = _score - WEIGHT_ROAD;};
    if ((_reserved findIf {_x distance2D _pos < RESERVED_CROWD}) isNotEqualTo -1) then {_score = _score - WEIGHT_CROWD;};
    if (_indoor) then {
        if (_indoorBias) then {_score = _score + WEIGHT_INDOOR;};
        if (_floor > 0 && {!_unitIndoor}) then {_score = _score - WEIGHT_UPPER_FLOOR * _floor;};
    };
    if (_soft && {_purpose isEqualTo "hide"}) then {_score = _score + WEIGHT_CONCEAL;};
    [_score, _pos, _cover, _source, _soft, _indoor]
};
_candidates sort false;
if (count _candidates > MAX_CANDIDATES) then {_candidates resize MAX_CANDIDATES;};

// rays for the best few ~ body height blocked means cover, head height clear means a field of fire
private _rays = 0;
private _results = [];
{
    _x params ["_score", "_pos", "_cover", "_source", "_soft", "_indoor"];
    private _canFire = true;
    private _stance = "DOWN";
    if (_hasThreat && {_forEachIndex < RAY_TESTED} && {!_soft}) then {
        private _posASL = AGLToASL _pos;
        private _bodyBlocked = terrainIntersectASL [_posASL vectorAdd [0, 0, BODY_HEIGHT], _threatASL] || {lineIntersects [_posASL vectorAdd [0, 0, BODY_HEIGHT], _threatASL]};
        private _headBlocked = terrainIntersectASL [_posASL vectorAdd [0, 0, HEAD_HEIGHT], _threatASL] || {lineIntersects [_posASL vectorAdd [0, 0, HEAD_HEIGHT], _threatASL]};
        _rays = _rays + 2;
        switch (true) do {
            case (_bodyBlocked && !_headBlocked): {_cover = 1.2; _stance = "MIDDLE"; _canFire = true; _score = _score + WEIGHT_FIGHT;};
            case (_bodyBlocked && _headBlocked): {_cover = 2; _stance = ["MIDDLE", "UP"] select _indoor; _canFire = false; _score = _score + ([0, WEIGHT_HIDE] select (_purpose isEqualTo "hide"));};
            default {_cover = 0; _stance = "DOWN"; _canFire = true; _score = _score - WEIGHT_EXPOSED;};
        };
    } else {
        // untested: assume the man has to lie down behind it
        _stance = ["DOWN", "MIDDLE"] select _indoor;
        if (_soft && _hasThreat) then {_cover = 0.6;};
    };
    _results pushBack [_score, _pos, _cover, _canFire, _stance, _source];
} forEach _candidates;
_results sort false;
_results = _results apply {_x params ["_score", "_pos", "_cover", "_canFire", "_stance", "_source"]; [_pos, _cover, _canFire, _stance, _score, _source]};
if (count _results > _count) then {_results resize _count;};

// debug ~ only when it cost something
if (GVAR(debug_functions)) then {
    private _ms = (diag_tickTime - _started) * 1000;
    if (_ms > DEBUG_MS) then {
        private _best = _results param [0, [[], 0, false, "", 0, "none"]];
        ["TPS %1: %2 cand, %3 rays, %4 ms, best %5 %6", [name _unit, "-"] select (isNull _unit), count _candidates, _rays, _ms toFixed 1, (_best select 4) toFixed 1, _best select 5] call FUNC(debugLog);
    };
};

_results
