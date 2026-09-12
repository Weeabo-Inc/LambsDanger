#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns the current combat stress of a unit, 0 (calm) to 1 (pinned). Stress is
 * added by addStress and halves every STRESS_HALF_LIFE seconds; the decay is
 * computed on read so nothing runs in the background.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * stress 0..1 <NUMBER>
 *
 * Example:
 * bob call lambs_main_fnc_getStress;
 *
 * Public: Yes
*/
#define STRESS_HALF_LIFE 15

params [["_unit", objNull, [objNull]]];

private _stressData = _unit getVariable [QGVAR(stress), []];
if (_stressData isEqualTo []) exitWith {0};
_stressData params ["_stress", "_setTime"];

_stress * (0.5 ^ ((time - _setTime) / STRESS_HALF_LIFE))
