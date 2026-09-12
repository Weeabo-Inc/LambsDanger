#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Unit repositions to a better position inside a building. Kept for compatibility: a
 * man the per-soldier machine owns is told where the enemy is and moves to a window
 * with a line of sight himself; anyone else is put into the machine's hands at his
 * own position.
 *
 * Arguments:
 * 0: unit repositioning <OBJECT>
 * 1: source of danger <OBJECT> or position <ARRAY>
 *
 * Return Value:
 * unit
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doReposition;
 *
 * Public: No
*/
#define SEARCH_RADIUS 8
#define HOLD_TIME 15

params ["_unit", ["_target", objNull, [objNull, []]]];

// enemy
if (!(_target isEqualType []) && {isNull _target}) then {
    _target = _unit findNearestEnemy _unit;
};
private _threat = if (_target isEqualType []) then {_target} else {
    if (isNull _target) then {[]} else {_unit getHideFrom _target}
};
if (_threat isEqualTo [0, 0, 0]) then {_threat = [];};

private _event = missionNamespace getVariable QEFUNC(danger,unitEvent);
if (!isNil "_event" && {_threat isNotEqualTo []} && {[_unit, "threatSeen", _threat] call _event}) exitWith {
    _unit setVariable [QGVAR(currentTask), "Repositioning", GVAR(debug_functions)];
    _unit
};

private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (!isNil "_order") then {
    [_unit, "hold", [], [_threat, []] select (_threat isEqualTo []), createHashMapFromArray [["radius", SEARCH_RADIUS], ["indoorBias", true], ["holdTime", HOLD_TIME], ["task", "Repositioning"]]] call _order;
};

// end
_unit
