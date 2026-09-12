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
#define SMOKE_RANGE 250
#define SMOKE_INTERVAL 20
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
    [_group, _target] call (missionNamespace getVariable [QEFUNC(danger,tacticsAssault), {}]);
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

    if (_moving isEqualTo TEAM_ASSAULT) then {
        // next bound from the assault team's centre towards the objective, on cover if there is any nearby
        _anchor = _assaultCentre getPos [([BOUND_LENGTH_FAR, BOUND_LENGTH_NEAR] select _near) min _distance, _direction];
        private _cover = nearestTerrainObjects [_anchor, ["BUSH", "TREE", "SMALL TREE", "HIDE", "WALL", "ROCK", "FENCE"], COVER_SEARCH, false, true];
        if (_cover isNotEqualTo []) then {
            _anchor = (_cover select 0) getPos [1.5, _target getDir (_cover select 0)];
        } else {
            // open ground ~ nothing to stop at, so run further and screen the rush with smoke
            if (!_near) then {_anchor = _assaultCentre getPos [BOUND_LENGTH_OPEN min _distance, _direction];};
            if (
                _distance < SMOKE_RANGE
                && {time > (_group getVariable [QGVAR(boundSmokeTime), 0])}
                && {!(missionNamespace getVariable [QEGVAR(danger,disableAutonomousSmokeGrenades), false])}
            ) then {
                _group setVariable [QGVAR(boundSmokeTime), time + SMOKE_INTERVAL];
                [_assaultTeam, _target] call FUNC(doSmoke);
                if (_fireTeam isNotEqualTo []) then {[_fireTeam, _target] call FUNC(doSmoke);};
            };
        };
    } else {
        // fire team moves up to a spot behind the assault team, still facing the objective
        _anchor = _assaultCentre getPos [FIRE_TEAM_BEHIND, _direction + 180];
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
        // the moving team ignores incoming fire until it is on its slot
        _x disableAI "SUPPRESSION";
        _x setUnitPos (["UP", "MIDDLE"] select (_near && {_moving isEqualTo TEAM_FIRE}));
        _x forceSpeed -1;
        _x doMove _pos;
        _x setVariable [QGVAR(currentTask), ["Assault team bounding", "Fire team moving up"] select (_moving isEqualTo TEAM_FIRE), GVAR(debug_functions)];
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
    _x setUnitPos (_x call FUNC(getLowStance));
    _x setVariable [QGVAR(currentTask), ["Fire team covering", "Assault team covering"] select (_moving isEqualTo TEAM_FIRE), GVAR(debug_functions)];
    if (_index isEqualTo -1 && {_checks > 0} && {_posList isNotEqualTo []}) then {
        _index = [_x, _posList] call FUNC(checkVisibilityList);
        _checks = _checks - 1;
    };
    if (_index isNotEqualTo -1 && {(currentCommand _x) isNotEqualTo "Suppress"}) then {
        if !([_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call FUNC(doSuppress)) then {_index = -1;};
    } else {
        _x doWatch _target;
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
