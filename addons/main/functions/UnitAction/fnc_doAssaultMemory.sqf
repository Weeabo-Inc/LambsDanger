#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Unit joins the group's assault on the positions in its "memory": the nearest one is
 * handed to the per-soldier machine as an assault order (lambs_danger_fnc_unitOrder),
 * which closes on it from cover to cover. Positions far from the leader are ignored;
 * an empty memory sends the man back into formation.
 *
 * Arguments:
 * 0: unit assaulting <OBJECT>
 * 1: group memory <ARRAY>
 *
 * Return Value:
 * boolean
 *
 * Example:
 * [bob] call lambs_main_fnc_doAssaultMemory;
 *
 * Public: No
*/
#define LEADER_RANGE 142
#define HOLD_TIME 8

params ["_unit", ["_groupMemory", []]];

// check if stopped
if (!(_unit checkAIFeature "PATH")) exitWith {false};

// check it
private _group = group _unit;
if (_groupMemory isEqualTo []) then {
    _groupMemory = _group getVariable [QGVAR(groupMemory), []];
};

// positions too far away from group leader are ignored
private _leader = leader _unit;
_groupMemory = _groupMemory select {_leader distance2D _x < LEADER_RANGE && {_unit distance2D _x > 1.5}};
if (_groupMemory isEqualTo []) exitWith {
    _unit doFollow _leader;
    _group setVariable [QGVAR(groupMemory), [], false];
    false
};

// nearest first, low floors first for the pathfinding's sake
_groupMemory = _groupMemory apply {[floor (_x select 2), _x distance2D _unit, _x]};
_groupMemory sort true;
private _pos = (_groupMemory select 0) select 2;

private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (isNil "_order") exitWith {false};
private _ok = [_unit, "assault", _pos, [], createHashMapFromArray [["holdTime", HOLD_TIME], ["task", "Assault (sympathetic)"], ["exact", true]]] call _order;

// debug
if (_ok && GVAR(debug_functions)) then {
    ["%1 assaulting (sympathetic) (%2 @ %3m - %4 spots)", side _unit, name _unit, round (_unit distance _pos), count _groupMemory] call FUNC(debugLog);
};

_ok
