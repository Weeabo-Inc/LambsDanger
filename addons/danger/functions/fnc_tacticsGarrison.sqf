#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Group garrisons buildings near enemies: every man is sent, from cover to cover, to a
 * building position with a field of fire towards the threat, and fights from it with
 * the per-soldier machine's peek and duck rhythm until the tactic ends.
 *
 * Arguments:
 * 0: group executing tactics <GROUP> or group leader <UNIT>
 * 1: group target <OBJECT> or position <ARRAY>
 * 2: units in group, default all <ARRAY>
 * 3: delay until unit is ready again <NUMBER>
 *
 * Return Value:
 * Bool
 *
 * Example:
 * [bob, angryBob] call lambs_danger_fnc_tacticsGarrison;
 *
 * Public: No
*/
#define BUILDING_DISTANCE 42

params ["_group", "_target", ["_units", []], ["_delay", 180]];

// group is missing
if (isNull _group) exitWith {false};

// get leader
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;
if (_group call EFUNC(main,isDirected)) exitWith {false};
_group setVariable [QGVAR(isExecutingTactic), true];

// sort target
_target = _target call CBA_fnc_getPos;

// reset tactics
[
    {
        params ["_group", "_enableAttack", "_formation", ["_token", -1]];
        // a stale timer never touches a later tactic (ADR-0011)
        if (!isNull _group && {(_group getVariable [QGVAR(tacticToken), -1]) isEqualTo _token}) then {
            _group setVariable [QGVAR(isExecutingTactic), nil];
            _group setVariable [QEGVAR(main,currentTactic), nil];
            _group enableAttack (_enableAttack || {GVAR(aggression) > 0 && {!(_group call EFUNC(main,isDirected))}});
            _group setFormation _formation;
            {[_x, true] call FUNC(unitRelease);} forEach (units _group);
        };
    },
    [_group, attackEnabled _group, formation _group, _group getVariable [QGVAR(tacticToken), -1]],
    _delay
] call CBA_fnc_waitAndExecute;

// set speed and enableAttack
_group setFormation "FILE";
_group enableAttack false;

// find units
if (_units isEqualTo []) then {
    _units = [_unit, 150] call EFUNC(main,findReadyUnits);
};
if (_units isEqualTo []) exitWith {false};

// the buildings near the leader ~ positions with a view of the threat, one per man
private _options = createHashMapFromArray [["purpose", "fight"], ["buildingsOnly", true], ["indoorBias", true], ["count", (count _units) * 2]];
private _positions = [getPosATL _unit, BUILDING_DISTANCE, [_target], _options] call EFUNC(main,findPositions);

// failsafe
if (_positions isEqualTo []) exitWith {
    _group setVariable [QGVAR(isExecutingTactic), nil];
    {_x doFollow leader _x} forEach _units;
    false
};

// leader ~ rally animation here
[_unit, "gestureFollow"] call EFUNC(main,doGesture);

// leader callout
[_unit, "combat", "RallyUp", 125] call EFUNC(main,doCallout);

// set tasks
_unit setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTask), "Tactics Garrison", EGVAR(main,debug_functions)];

// set group task
_group setVariable [QEGVAR(main,currentTactic), "Garrison/Rally", EGVAR(main,debug_functions)];

// execute ~ the nearest man takes the nearest position, each claim keeps the next man off it
private _posList = ([_group, 60] call FUNC(pictureContacts)) apply {_x select 1};
_posList pushBack _target;
private _unassigned = +_units;
{
    if (_unassigned isEqualTo []) exitWith {};
    private _pos = _x select 0;
    private _nearest = [_unassigned, [], {_x distance2D _pos}, "ASCEND"] call BIS_fnc_sortBy;
    private _man = _nearest select 0;
    _unassigned deleteAt (_unassigned find _man);
    [_man, _pos] call EFUNC(main,positionReserve);
    private _orderOptions = createHashMapFromArray [
        ["onArrive", "hold"],
        ["radius", 4],
        ["indoorBias", true],
        ["suppressList", _posList],
        ["sector", [_pos getDir _target, 90]],
        ["delay", 0.5 + random 2],
        ["task", "Group Garrison"]
    ];
    [_man, "hold", _pos, [_target], _orderOptions] call FUNC(unitOrder);
} forEach _positions;
// more men than positions: the rest take cover where they can with a view of the threat
{
    [_x, "hold", getPosATL _x, [_target], createHashMapFromArray [["onArrive", "hold"], ["radius", 20], ["indoorBias", true], ["suppressList", _posList], ["task", "Group Garrison (outside)"]]] call FUNC(unitOrder);
} forEach _unassigned;

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 TACTICS GARRISON %2 (%3m) (%4 units, %5 positions)", side _unit, groupId _group, round (_unit distance2D _target), count _units, count _positions] call EFUNC(main,debugLog);
    private _m = [_target, "tactics garrison", _unit call EFUNC(main,debugMarkerColor), "hd_flag"] call EFUNC(main,dotMarker);
    _m setMarkerSizeLocal [0.6, 0.6];
    [{deleteMarker _this}, _m, _delay + 30] call CBA_fnc_waitAndExecute;
};

// end
true
