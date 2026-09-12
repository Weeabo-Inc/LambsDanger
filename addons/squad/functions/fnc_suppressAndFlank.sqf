#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Start of suppress and flank (docs/systems/tactics.md): the leader, the gunners and the
 * medic become the base of fire and hold from cover with a list of positions to suppress;
 * everyone else is the manoeuvre element and bounds, through the covered-route bound of
 * doGroupBound, to a flank point off the enemy's side, chosen for the cover it offers.
 * The bound itself only moves while the base of fire is firing (C-42). The monitor turns
 * the element in on the enemy once it reaches the flank point.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Context <HASHMAP>
 * 2: Tactic state <HASHMAP>
 *
 * Return Value:
 * started <BOOL>
 *
 * Example:
 * called by hostis_squad_fnc_tacticStart
 *
 * Public: No
*/
#define SUPPRESS_POSITIONS 12
#define BASE_MAX_SHARE 0.5
#define FLANK_MIN 40

params [["_group", grpNull, [grpNull]], ["_ctx", createHashMap, [createHashMap]], ["_state", createHashMap, [createHashMap]]];

private _threatPos = _ctx get "threatPos";
if (_threatPos isEqualTo []) exitWith {false};
private _leader = leader _group;
private _units = (_ctx get "onFoot") select {(_x getVariable [QLGVAR(main,survival), 0]) < time};
if (count _units < 4) exitWith {false};

// task organisation ~ the base of fire is the leader, the guns and the medic, never more than half
private _base = [_leader] + ((_units - [_leader]) select {_x call LFUNC(main,isSupportGunner) || {_x call LFUNC(main,isMedic)}});
private _maneuver = _units - _base;
while {count _base > (count _units) * BASE_MAX_SHARE && {count _base > 1}} do {
    private _mover = (_base - [_leader]) select -1;
    _maneuver pushBack _mover;
    _base = _base - [_mover];
};
while {count _maneuver < 2 && {count _base > 1}} do {
    private _mover = (_base - [_leader]) select 0;
    _maneuver pushBack _mover;
    _base = _base - [_mover];
};
if (count _maneuver < 2) exitWith {false};

// which side ~ the flank point with the better cover wins; the offset never overshoots the enemy
private _distance = _leader distance2D _threatPos;
private _offset = (GVAR(flankOffset) min (_distance * 0.7)) max FLANK_MIN;
private _direction = _leader getDir _threatPos;
private _best = [];
private _bestScore = -1e9;
{
    private _candidate = _threatPos getPos [_offset, _direction + _x];
    // pull the point back toward our side so the route does not cross the enemy's front
    _candidate = _candidate getPos [_offset * 0.5, _direction + 180];
    private _positions = [_candidate, 30, [_threatPos], createHashMapFromArray [["purpose", "fight"], ["count", 1], ["group", _group]]] call LFUNC(main,findPositions);
    private _score = if (_positions isEqualTo []) then {-10} else {(_positions select 0) select 4};
    if (surfaceIsWater _candidate) then {_score = -100;};
    _score = _score + random 0.5;
    if (_score > _bestScore) then {_bestScore = _score; _best = if (_positions isEqualTo []) then {_candidate} else {(_positions select 0) select 0};};
} forEach [90, -90];
private _flankPoint = _best;

// positions worth suppressing ~ known enemies, then buildings around them, then the centre
private _posList = (_ctx get "contacts") apply {_x select CONTACT_POS};
_posList append ([_threatPos, 20, true, false] call LFUNC(main,findBuildings));
_posList pushBack _threatPos;
if (count _posList > SUPPRESS_POSITIONS) then {_posList resize SUPPRESS_POSITIONS;};

// group orders ~ as the bound: AWARE with no automatic COMBAT, or the engine crawls
_group enableAttack false;
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_group setFormation "LINE";
_group setFormDir _direction;
_group setBehaviourStrong "AWARE";
{
    _x setVariable [QLGVAR(danger,forceMove), true];
    _x forceSpeed -1;
    _x disableAI "AUTOCOMBAT";
} forEach _units;

// the base of fire fights from the nearest cover to where it stands
{
    private _options = createHashMapFromArray [
        ["onArrive", "hold"], ["radius", 8], ["suppressList", _posList], ["task", "Base of fire"], ["covered", true]
    ];
    [_x, "hold", getPosATL _x, [_threatPos], _options] call LFUNC(danger,unitOrder);
} forEach _base;
[_leader, "suppress", true] call EFUNC(agent,bark);
if (!LGVAR(danger,disableAutonomousSmokeGrenades)) then {[_leader, _threatPos] call LFUNC(main,doSmoke);};

// the manoeuvre element bounds to the flank point; the base never moves up
private _token = time + random 1;
_group setVariable [QLGVAR(danger,boundToken), _token];
private _vehicles = _ctx getOrDefault ["vehicles", []];
{_x doWatch _threatPos;} forEach _vehicles;
[{_this call LFUNC(main,doGroupBound)}, [_group, _base, _maneuver, _posList, _flankPoint, 0, 0, [], _vehicles, _token, true], 1] call CBA_fnc_waitAndExecute;
[_maneuver select 0, "flank"] call EFUNC(agent,bark);

private _data = _state get "data";
_data set ["phase", "approach"];
_data set ["base", _base];
_data set ["maneuver", _maneuver];
_data set ["flankPoint", _flankPoint];
_data set ["posList", _posList];
_data set ["vehicles", _vehicles];
_data set ["token", _token];
_data set ["lastDistance", 1e9];
_data set ["lastProgress", time];
_data set ["handedOver", false];
_state set ["objective", _threatPos];

if (SQUAD_DEBUG) then {
    ["%1 TACTIC %2: suppress and flank, base %3, manoeuvre %4, flank point %5 m %6 of the enemy", side _group, groupId _group, count _base, count _maneuver, round _offset, ["right", "left"] select (((((_threatPos getDir _flankPoint) - _direction) + 360) mod 360) > 180)] call LFUNC(main,debugLog);
    private _m = [_flankPoint, "flank point", _leader call LFUNC(main,debugMarkerColor), "hd_flag"] call LFUNC(main,dotMarker);
    [{deleteMarker _this}, _m, 300] call CBA_fnc_waitAndExecute;
};

true
