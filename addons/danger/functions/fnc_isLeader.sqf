#include "script_component.hpp"
/*
 * Author: nkenny
 * Checks if the unit is a ready leader at FSM level
 *
 * Arguments:
 * 0: unit being tested <OBJECT>
 *
 * Return Value:
 * bool
 *
 * Example:
 * [bob] call lambs_danger_fnc_isLeader;
 *
 * Public: No
*/
params ["_unit"];
// assertive leaders keep planning while under fire
getSuppression _unit < ([0.2, 0.6] select (GVAR(aggression) > 0))
&& ((leader _unit) isEqualTo _unit || {!((leader _unit) call EFUNC(main,isAlive))})
&& {!(group _unit getVariable [QGVAR(isExecutingTactic), false])}
