#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns the stance LAMBS should force on a unit that needs to get low. With the
 * assertive combat discipline units go prone only when they are actually suppressed;
 * otherwise they crouch and keep fighting.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * "DOWN" or "MIDDLE" <STRING>
 *
 * Example:
 * bob call lambs_main_fnc_getLowStance;
 *
 * Public: No
*/
#define SUPPRESSED 0.7

params ["_unit"];

if (
    (missionNamespace getVariable [QEGVAR(danger,aggression), 0]) isEqualTo 0
    || {getSuppression _unit > SUPPRESSED}
) exitWith {"DOWN"};

"MIDDLE"
