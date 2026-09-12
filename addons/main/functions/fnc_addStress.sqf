#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Adds combat stress to a unit. Stress decays on its own (see getStress) so no
 * per frame work is needed; only the value and the time it was set are stored.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Amount to add, 0..1 <NUMBER>
 *
 * Return Value:
 * new stress level 0..1 <NUMBER>
 *
 * Example:
 * [bob, 0.3] call lambs_main_fnc_addStress;
 *
 * Public: Yes
*/
params [["_unit", objNull, [objNull]], ["_amount", 0.2, [0]]];

if (isNull _unit || {isPlayer _unit}) exitWith {0};

private _stress = ((_unit call FUNC(getStress)) + _amount) min 1;
_unit setVariable [QGVAR(stress), [_stress, time]];

_stress
