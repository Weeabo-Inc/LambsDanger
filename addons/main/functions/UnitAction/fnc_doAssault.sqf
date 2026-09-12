#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Unit closes on an enemy. A target he can see at close range he fights from where he
 * stands; otherwise the position he last knew the enemy at goes to the per-soldier
 * machine as an assault order (lambs_danger_fnc_unitOrder), which closes from cover to
 * cover and into the building that holds the enemy when there is one. Repeated calls
 * for the same target refresh the order rather than restart it.
 *
 * Arguments:
 * 0: unit assaulting <OBJECT>
 * 1: enemy <OBJECT>
 * 2: unused, kept for callers <NUMBER>
 * 3: unused, kept for callers <BOOL>
 *
 * Return Value:
 * boolean
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doAssault;
 *
 * Public: No
*/
#define VISIBLE_RANGE 20
#define HOLD_TIME 6

params ["_unit", ["_target", objNull], ["_range", 12], ["_doMove", false]];

// check if stopped
if (!(_unit checkAIFeature "PATH") || {isNull _target}) exitWith {false};

_unit setVariable [QGVAR(currentTarget), _target, GVAR(debug_functions)];

// can see the target close by: fight from here
if (_unit distanceSqr _target < (VISIBLE_RANGE * VISIBLE_RANGE) && {[_unit, "FIRE", _target] checkVisibility [getPosWorld _unit, aimPos _target] isEqualTo 1}) exitWith {
    _unit doWatch _target;
    _unit setVariable [QGVAR(currentTask), "Assault (target visible)", GVAR(debug_functions)];
    true
};

// where he thinks the enemy is ~ nothing sensible means nothing to do
private _hide = _unit getHideFrom _target;
if (_hide isEqualTo [0, 0, 0] || {_unit distance2D _hide > 500}) exitWith {false};

// staying inside when the enemy is in the open and far from any building
if (_unit call FUNC(isIndoor) && RND(GVAR(indoorMove)) && {([_hide, _range, false, false] call FUNC(findBuildings)) isEqualTo []}) exitWith {
    _unit setVariable [QGVAR(currentTask), "Stay inside", GVAR(debug_functions)];
    _unit doWatch _hide;
    true
};

private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (isNil "_order") exitWith {false};
private _ok = [_unit, "assault", _hide, [_hide], createHashMapFromArray [["holdTime", HOLD_TIME], ["task", "Assault"]]] call _order;

// debug ~ once per new order, not once per FSM tick
if (_ok && GVAR(debug_functions) && {time - (_unit getVariable [QGVAR(assaultLogged), -1e9]) > 10}) then {
    _unit setVariable [QGVAR(assaultLogged), time];
    ["%1 assaulting (%2 @ %3m)", side _unit, name _unit, round (_unit distance _hide)] call FUNC(debugLog);
};

_ok
