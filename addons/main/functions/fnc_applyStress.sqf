#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Applies the effect of combat stress to a unit's aiming: a stressed soldier shoots
 * more and aims less. The original skill is remembered and restored once the unit
 * has calmed down. Meant to be called from the danger cycle (every 1-2 s), not per frame.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * current stress <NUMBER>
 *
 * Example:
 * bob call lambs_main_fnc_applyStress;
 *
 * Public: No
*/
#define STRESS_THRESHOLD 0.3
#define ACCURACY_LOSS 0.6

params [["_unit", objNull, [objNull]]];

if ((missionNamespace getVariable [QEGVAR(danger,aggression), 0]) isEqualTo 0 || {isPlayer _unit}) exitWith {0};

private _stress = _unit call FUNC(getStress);
private _baseAccuracy = _unit getVariable [QGVAR(baseAccuracy), -1];

if (_stress > STRESS_THRESHOLD) then {
    if (_baseAccuracy < 0) then {
        _baseAccuracy = _unit skill "aimingAccuracy";
        _unit setVariable [QGVAR(baseAccuracy), _baseAccuracy];
    };
    _unit setSkill ["aimingAccuracy", _baseAccuracy * (1 - (ACCURACY_LOSS * _stress))];
} else {
    if (_baseAccuracy >= 0) then {
        _unit setSkill ["aimingAccuracy", _baseAccuracy];
        _unit setVariable [QGVAR(baseAccuracy), nil];
    };
};

_stress
