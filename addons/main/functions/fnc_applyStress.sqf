#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns a unit's current stress. It used to lower aimingAccuracy in proportion; that
 * skill write is gone (docs/FAIRNESS.md R3, RESEARCH.md C-35): stress now changes what a
 * man does through his morale state (hostis_agent_fnc_moraleState), never how well he
 * shoots. Kept as the call site every brain already uses.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * stress 0..1 <NUMBER>
 *
 * Example:
 * [bob] call lambs_main_fnc_applyStress;
 *
 * Public: No
*/
params [["_unit", objNull, [objNull]]];

if (isNull _unit || {isPlayer _unit}) exitWith {0};

// a base accuracy stored by an earlier version is handed back once
private _baseAccuracy = _unit getVariable [QGVAR(baseAccuracy), -1];
if (_baseAccuracy >= 0) then {
    _unit setVariable [QGVAR(baseAccuracy), nil];
};

_unit call FUNC(getStress)
