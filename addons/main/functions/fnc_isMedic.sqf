#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Whether a unit is a medic, by ACE medical class if set or by the vanilla attendant flag.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * true for medics <BOOL>
 *
 * Example:
 * bob call lambs_main_fnc_isMedic;
 *
 * Public: Yes
*/
params [["_unit", objNull, [objNull]]];

(_unit getVariable ["ace_medical_medicClass", getNumber (configOf _unit >> "attendant")]) > 0
