#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One cycle of fire and movement towards an objective with two fixed teams:
 *   fire team    leader, support gunners and medic. Holds a shallow V, gunners and
 *                medic up front, leader at the apex behind them.
 *   assault team everyone else. Moves as a tight wedge, close together, in unison.
 * The assault team bounds forward while the fire team suppresses; when it is on its
 * bound point the fire team moves up behind it while the assault team suppresses,
 * and so on. A fire team that is already close enough skips its move so the assault
 * keeps rolling. Hands over to the building assault inside CQB range of the objective.
 * Re-arms itself with CBA_fnc_waitAndExecute; no per frame work.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Fire team <ARRAY>
 * 2: Assault team <ARRAY>
 * 3: Positions worth suppressing <ARRAY>
 * 4: Objective position AGL <ARRAY>
 * 5: Team currently moving: 0 none yet, 1 assault, 2 fire team <NUMBER>
 * 6: Time the current bound started <NUMBER>
 * 7: Bound destinations, one per moving unit <ARRAY>
 * 8: Group vehicles acting as a fire base <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob, [bob], [joe], [getPos angryJoe], getPos angryJoe, 0, 0, [], []] call lambs_main_fnc_doGroupBound;
 *
 * Public: No
*/
#define CYCLE_TIME 3
#define BOUND_LENGTH_NEAR 30
#define BOUND_LENGTH_FAR 50
#define BOUND_LENGTH_OPEN 70
#define NEAR_DISTANCE 150
#define BOUND_TIMEOUT 15
#define ARRIVED_DISTANCE 4
#define COVER_SEARCH 8
#define FIRE_TEAM_BEHIND 12
#define FIRE_TEAM_CLOSE_ENOUGH 30
#define SMOKE_RANGE 300
#define SMOKE_INTERVAL 20
#define LAUNCHER_RANGE 500
#define FAN_ANGLES [-60, -35, -15, 0, 15, 35, 60]
#define WEIGHT_PROGRESS 2
#define WEIGHT_COVER 3
#define WEIGHT_SOFT 1.5
#define WEIGHT_HIDDEN 2
#define WEIGHT_DETOUR 1
#define OPEN_SCORE 2.5
#define SUPPRESS_CHECKS 3
#define TEAM_NONE 0
#define TEAM_ASSAULT 1
#define TEAM_FIRE 2

params [["_group", grpNull], ["_fireTeam", []], ["_assaultTeam", []], ["_posList", []], ["_target", [0, 0, 0]], ["_moving", TEAM_NONE], ["_boundStart", 0], ["_boundPositions", []], ["_vehicles", []]];

// exit!
if (isNull _group || {!(_group getVariable [QEGVAR(danger,isExecutingTactic), false])}) exitWith {};

// update teams
private _fnc_ready = {_x call FUNC(isAlive) && {!isPlayer _x} && {isNull objectParent _x} && {!(_x getVariable [QEGVAR(danger,disableAI), false])}};
_fireTeam = _fireTeam select _fnc_ready;
_assaultTeam = _assaultTeam select _fnc_ready;
if (_fireTeam isEqualTo [] && {_assaultTeam isEqualTo []}) exitWith {};
private _leader = leader _group;

// one team left ~ it does both jobs, moving as the assault
if (_assaultTeam isEqualTo []) then {
    _assaultTeam = _fireTeam - [_leader];
    _fireTeam = [_leader] select {_leader in _fireTeam};
    if (_assaultTeam isEqualTo []) then {_assaultTeam = _fireTeam; _fireTeam = [];};
};

// close enough ~ the building assault takes over
private _closest = 1e9;
{_closest = _closest min (_x distance2D _target);} forEach _assaultTeam;
if (_closest < (missionNamespace getVariable [QEGVAR(danger,cqbRange), 60])) exitWith {
    [_group, _target, _fireTeam + _assaultTeam] call (missionNamespace getVariable [QEFUNC(danger,tacticsAssault), {}]);
};

// team centres
private _fnc_centre = {
    private _centre = [0, 0, 0];
    {_centre = _centre vectorAdd (getPosATL _x);} forEach _this;
    _centre vectorMultiply (1 / ((count _this) max 1))
};
private _assaultCentre = _assaultTeam call _fnc_centre;
private _fireCentre = if (_fireTeam isEqualTo []) then {_assaultCentre} else {_fireTeam call _fnc_centre};

// bound finished? everyone arrived or it took too long
private _movingUnits = [[], _assaultTeam, _fireTeam] select _moving;
private _arrived = (time - _boundStart) > BOUND_TIMEOUT;
if (!_arrived && {_boundPositions isNotEqualTo []}) then {
    _arrived = true;
    {
        private _pos = _boundPositions param [_forEachIndex, []];
        if (_pos isNotEqualTo [] && {_x distance2D _pos > ARRIVED_DISTANCE}) exitWith {_arrived = false;};
    } forEach _movingUnits;
};

if (_arrived || {_moving isEqualTo TEAM_NONE}) then {

    // whose turn ~ the fire team moves up after the assault, unless it is close enough already
    private _next = TEAM_ASSAULT;
    if (_moving isEqualTo TEAM_ASSAULT && {_fireTeam isNotEqualTo []}) then {
        private _behindAssault = _assaultCentre getPos [FIRE_TEAM_BEHIND, _target getDir _assaultCentre];
        if (_fireCentre distance2D _behindAssault > FIRE_TEAM_CLOSE_ENOUGH) then {_next = TEAM_FIRE;};
    };
    _moving = _next;
    _movingUnits = [[], _assaultTeam, _fireTeam] select _moving;

    private _direction = _assaultCentre getDir _target;
    private _distance = _assaultCentre distance2D _target;
    private _near = _distance < NEAR_DISTANCE;
    private _anchor = [0, 0, 0];

    // the runners throw smoke ahead of themselves before they go
    private _fnc_smoke = {
        params ["_throwers"];
        if (_distance < SMOKE_RANGE && {time > (_group getVariable [QGVAR(boundSmokeTime), 0])}) then {
            _group setVariable [QGVAR(boundSmokeTime), time + SMOKE_INTERVAL];
            {[_x, _target] call FUNC(doSmoke);} forEach ((_throwers select {(throwables _x) isNotEqualTo []}) select [0, 2]);
        };
    };

    // where to bound to: not the straight line, but the leg that keeps to cover, soft ground and dead
    // ground while still gaining on the objective ~ a fan of candidates, the best one wins
    private _fnc_pickBound = {
        params ["_from", "_length"];
        private _best = _from getPos [_length min _distance, _direction];
        private _bestScore = -1e9;
        private _targetASL = (AGLToASL _target) vectorAdd [0, 0, 1.5];
        {
            private _candidate = _from getPos [_length min _distance, _direction + _x];
            private _cover = nearestTerrainObjects [_candidate, ["BUSH", "TREE", "SMALL TREE", "HIDE", "WALL", "ROCK", "FENCE"], COVER_SEARCH, false, true];
            private _surface = toLower (surfaceType _candidate);
            private _hard = isOnRoad _candidate || {"concrete" in _surface} || {"asphalt" in _surface} || {"tarmac" in _surface} || {"runway" in _surface};
            private _hidden = terrainIntersectASL [(AGLToASL _candidate) vectorAdd [0, 0, 1], _targetASL];
            private _score = (_distance - (_candidate distance2D _target)) / _length * WEIGHT_PROGRESS
                + ([0, WEIGHT_COVER] select (_cover isNotEqualTo []))
                + ([WEIGHT_SOFT, 0] select _hard)
                + ([0, WEIGHT_HIDDEN] select _hidden)
                - (abs _x / 60) * WEIGHT_DETOUR;
            if (_score > _bestScore) then {
                _bestScore = _score;
                _best = if (_cover isNotEqualTo []) then {(_cover select 0) getPos [1.5, _target getDir (_cover select 0)]} else {_candidate};
            };
        } forEach FAN_ANGLES;
        [_best, _bestScore]
    };

    if (_moving isEqualTo TEAM_ASSAULT) then {
        // next bound from the assault team's centre, longer when there is nothing to stop at anyway
        private _length = [BOUND_LENGTH_FAR, BOUND_LENGTH_NEAR] select _near;
        ([_assaultCentre, _length] call _fnc_pickBound) params ["_pick", "_score"];
        if (_score < OPEN_SCORE && {!_near}) then {
            _pick = ([_assaultCentre, BOUND_LENGTH_OPEN] call _fnc_pickBound) select 0;
        };
        _anchor = _pick;
        [_assaultTeam] call _fnc_smoke;
    } else {
        // fire team moves up to a spot behind the assault team, still facing the objective
        _anchor = _assaultCentre getPos [FIRE_TEAM_BEHIND, _direction + 180];
        [_fireTeam] call _fnc_smoke;
    };

    // formation slots
    _boundPositions = [];
    {
        private _pos = if (_moving isEqualTo TEAM_FIRE && {_x isEqualTo _leader}) then {
            // apex of the V, behind the gunners
            _anchor getPos [4, _direction + 180]
        } else {
            private _slot = if (_moving isEqualTo TEAM_FIRE) then {
                (_movingUnits - [_leader]) find _x
            } else {
                _forEachIndex
            };
            private _row = ceil (_slot / 2);
            private _side = [90, -90] select ((_slot % 2) isEqualTo 1);
            if (_moving isEqualTo TEAM_FIRE) then {
                // gunners and medic side by side on the front line, 2.5 m out, alternating sides
                _anchor getPos [2.5 * (floor (_slot / 2) + 1), _direction + _side]
            } else {
                // tight wedge: 1.5 m sideways, 1 m back per row
                (_anchor getPos [_row, _direction + 180]) getPos [1.5 * _row, _direction + _side]
            }
        };
        private _emptyPos = _pos findEmptyPosition [0, 3];
        if (_emptyPos isNotEqualTo []) then {_pos = _emptyPos;};
        _boundPositions pushBack _pos;

        _x setVariable [QEGVAR(danger,forceMove), true];
        // the moving team sprints: no shooting, no aiming, no stopping for incoming fire until it is on its slot
        _x disableAI "SUPPRESSION";
        _x disableAI "TARGET";
        _x disableAI "AUTOTARGET";
        _x doWatch objNull;
        _x setUnitPos "UP";
        _x forceSpeed -1;
        _x doMove _pos;
        _x setVariable [QGVAR(currentTask), ["Assault team bounding", "Fire team moving up"] select (_moving isEqualTo TEAM_FIRE), GVAR(debug_functions)];

        // the moment it arrives it drops prone and starts shooting again
        [
            {
                params ["_unit", "_pos"];
                !(_unit call FUNC(isAlive)) || {_unit distance2D _pos < ARRIVED_DISTANCE} || {unitReady _unit}
            },
            {
                params ["_unit", "", "_target", "_group", "_posList"];
                if (!(_unit call FUNC(isAlive)) || {!(_group getVariable [QEGVAR(danger,isExecutingTactic), false])}) exitWith {};
                _unit enableAI "TARGET";
                _unit enableAI "AUTOTARGET";
                _unit enableAI "SUPPRESSION";
                _unit setUnitPos "DOWN";
                private _index = [_unit, _posList] call FUNC(checkVisibilityList);
                if (_index isEqualTo -1 || {!([_unit, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call FUNC(doSuppress))}) then {
                    _unit doWatch _target;
                };
            },
            [_x, _pos, _target, _group, _posList],
            BOUND_TIMEOUT
        ] call CBA_fnc_waitUntilAndExecute;
    } forEach _movingUnits;
    _boundStart = time;

    // gesture and callout from whoever leads the move
    if (_movingUnits isNotEqualTo []) then {
        [_movingUnits select 0, "gestureGo"] call FUNC(doGesture);
        if (RND(0.5)) then {[_leader, "combat", ["Advance", "suppress"] select (_moving isEqualTo TEAM_FIRE), 100] call FUNC(doCallout);};
    };
};

// stationary team ~ suppress what can be seen, otherwise watch the objective
private _stationary = [[], _fireTeam, _assaultTeam] select _moving;
[_posList, true] call CBA_fnc_shuffle;
private _index = -1;
private _checks = SUPPRESS_CHECKS;
{
    _x setVariable [QEGVAR(danger,forceMove), true];
    _x enableAI "SUPPRESSION";
    _x enableAI "TARGET";
    _x enableAI "AUTOTARGET";
    _x setUnitPos "DOWN";
    _x setVariable [QGVAR(currentTask), ["Fire team covering", "Assault team covering"] select (_moving isEqualTo TEAM_FIRE), GVAR(debug_functions)];
    if (_index isEqualTo -1 && {_checks > 0} && {_posList isNotEqualTo []}) then {
        _index = [_x, _posList] call FUNC(checkVisibilityList);
        _checks = _checks - 1;
    };
    // rockets and grenade launchers go into the enemy position from here
    private _launched = _x distance2D _target < LAUNCHER_RANGE && {[_x, [_target, _posList select 0] select (_posList isNotEqualTo [])] call FUNC(doLauncherFire)};
    if (!_launched) then {
        if (_index isNotEqualTo -1 && {(currentCommand _x) isNotEqualTo "Suppress"}) then {
            if !([_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call FUNC(doSuppress)) then {_index = -1;};
        } else {
            _x doWatch _target;
        };
    };
} forEach _stationary;

// vehicles hold as a fire base ~ suppress what they can see, never charge the objective
_vehicles = _vehicles select {alive _x && {canFire _x} && {(effectiveCommander _x) call FUNC(isAlive)}};
{
    if ((currentCommand _x) isNotEqualTo "Suppress") then {
        private _vehicleIndex = [_x, _posList] call FUNC(checkVisibilityList);
        if (_vehicleIndex isNotEqualTo -1) then {
            [_x, (_posList select _vehicleIndex) vectorAdd [0, 0, random 1]] call FUNC(doVehicleSuppress);
        } else {
            _x doWatch _target;
        };
        (effectiveCommander _x) setVariable [QGVAR(currentTask), "Fire base (vehicle)", GVAR(debug_functions)];
    };
} forEach _vehicles;

// next cycle
[{_this call FUNC(doGroupBound)}, [_group, _fireTeam, _assaultTeam, _posList, _target, _moving, _boundStart, _boundPositions, _vehicles], CYCLE_TIME] call CBA_fnc_waitAndExecute;
