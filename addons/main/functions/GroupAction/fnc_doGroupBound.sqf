#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One cycle of fire and movement towards an objective. A base of fire team suppresses
 * the known enemy positions while an assault team bounds forward; when the bound is
 * done (everyone arrived, or the bound timed out) the teams swap roles. The leader
 * always stays with the base of fire. Hands over to the building assault once the
 * assault team is inside CQB range of the objective. Re-arms itself every few seconds
 * with CBA_fnc_waitAndExecute; no per frame work.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Base of fire team <ARRAY>
 * 2: Assault team <ARRAY>
 * 3: Positions worth suppressing <ARRAY>
 * 4: Objective position AGL <ARRAY>
 * 5: Time the current bound started <NUMBER>
 * 6: Bound destinations, one per assault unit <ARRAY>
 * 7: Group vehicles acting as a fire base <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob, [bob], [joe], [getPos angryJoe], getPos angryJoe, time, [], []] call lambs_main_fnc_doGroupBound;
 *
 * Public: No
*/
#define CYCLE_TIME 4
#define BOUND_LENGTH 25
#define BOUND_TIMEOUT 20
#define ARRIVED_DISTANCE 6
#define COVER_SEARCH 8
#define SPREAD 3
#define SUPPRESS_CHECKS 3

params [["_group", grpNull], ["_base", []], ["_assault", []], ["_posList", []], ["_target", [0, 0, 0]], ["_boundStart", 0], ["_boundPositions", []], ["_vehicles", []]];

// exit!
if (isNull _group || {!(_group getVariable [QEGVAR(danger,isExecutingTactic), false])}) exitWith {};

// update teams
private _fnc_ready = {_x call FUNC(isAlive) && {!isPlayer _x} && {isNull objectParent _x} && {!(_x getVariable [QEGVAR(danger,disableAI), false])}};
_base = _base select _fnc_ready;
_assault = _assault select _fnc_ready;
if (_base isEqualTo [] && {_assault isEqualTo []}) exitWith {};
private _leader = leader _group;

// close enough ~ the building assault takes over
private _closest = 1e9;
{_closest = _closest min (_x distance2D _target);} forEach (_assault + _base);
if (_closest < (missionNamespace getVariable [QEGVAR(danger,cqbRange), 60])) exitWith {
    [_group, _target] call (missionNamespace getVariable [QEFUNC(danger,tacticsAssault), {}]);
};

// bound finished? everyone arrived or it took too long
private _arrived = (time - _boundStart) > BOUND_TIMEOUT;
if (!_arrived && {_boundPositions isNotEqualTo []}) then {
    _arrived = true;
    {
        private _pos = _boundPositions param [_forEachIndex, []];
        if (_pos isNotEqualTo [] && {_x distance2D _pos > ARRIVED_DISTANCE}) exitWith {_arrived = false;};
    } forEach _assault;
};

if (_arrived || {_boundPositions isEqualTo []}) then {

    // swap roles ~ the leader stays with the base of fire
    if (_boundPositions isNotEqualTo []) then {
        private _newBase = _assault;
        private _newAssault = _base - [_leader];
        if (!(_leader in _newBase) && {_leader in _base}) then {_newBase pushBack _leader;};
        if (_newAssault isEqualTo [] && {count _newBase > 1}) then {
            private _mover = (_newBase - [_leader]) select 0;
            _newAssault pushBack _mover;
            _newBase = _newBase - [_mover];
        };
        _base = _newBase;
        _assault = _newAssault;
    };

    // new bound from the assault team's centre towards the objective
    if (_assault isNotEqualTo []) then {
        private _centre = [0, 0, 0];
        {_centre = _centre vectorAdd (getPosATL _x);} forEach _assault;
        _centre = _centre vectorMultiply (1 / count _assault);
        private _distance = _centre distance2D _target;
        private _direction = _centre getDir _target;
        private _boundPoint = _centre getPos [BOUND_LENGTH min _distance, _direction];

        // prefer a spot with something to hide behind
        private _cover = nearestTerrainObjects [_boundPoint, ["BUSH", "TREE", "SMALL TREE", "HIDE", "WALL", "ROCK", "FENCE"], COVER_SEARCH, false, true];
        if (_cover isNotEqualTo []) then {
            _boundPoint = (_cover select 0) getPos [1.5, _target getDir (_cover select 0)];
        };

        _boundPositions = [];
        {
            private _pos = _boundPoint getPos [SPREAD * ceil (_forEachIndex / 2), _direction + ([90, -90] select ((_forEachIndex % 2) isEqualTo 0))];
            private _emptyPos = _pos findEmptyPosition [0, 4];
            if (_emptyPos isNotEqualTo []) then {_pos = _emptyPos;};
            _boundPositions pushBack _pos;
            _x setVariable [QEGVAR(danger,forceMove), true];
            _x setUnitPosWeak "MIDDLE";
            _x forceSpeed -1;
            _x doMove _pos;
            _x setVariable [QGVAR(currentTask), "Bounding", GVAR(debug_functions)];
        } forEach _assault;
        _boundStart = time;

        // gesture and callout from whoever leads the bound
        [_assault select 0, "gestureGo"] call FUNC(doGesture);
        if (RND(0.5)) then {[_leader, "combat", "Advance", 100] call FUNC(doCallout);};
    };
};

// base of fire ~ suppress what can be seen, otherwise watch the objective
[_posList, true] call CBA_fnc_shuffle;
private _index = -1;
private _checks = SUPPRESS_CHECKS;
{
    _x setVariable [QEGVAR(danger,forceMove), true];
    _x setUnitPos (_x call FUNC(getLowStance));
    _x setVariable [QGVAR(currentTask), "Base of fire", GVAR(debug_functions)];
    if (_index isEqualTo -1 && {_checks > 0} && {_posList isNotEqualTo []}) then {
        _index = [_x, _posList] call FUNC(checkVisibilityList);
        _checks = _checks - 1;
    };
    if (_index isNotEqualTo -1 && {(currentCommand _x) isNotEqualTo "Suppress"}) then {
        if !([_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call FUNC(doSuppress)) then {_index = -1;};
    } else {
        _x doWatch _target;
    };
} forEach _base;

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
[{_this call FUNC(doGroupBound)}, [_group, _base, _assault, _posList, _target, _boundStart, _boundPositions, _vehicles], CYCLE_TIME] call CBA_fnc_waitAndExecute;
