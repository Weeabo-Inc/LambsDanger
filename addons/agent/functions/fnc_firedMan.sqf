#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * FiredMan handler: stamps the shooter with the time and counts his shots in a short
 * bucket, so an element's volume of fire can be read without asking anyone what he is
 * aiming at (docs/systems/morale.md, fireVolume).
 *
 * Arguments:
 * 0: Unit that fired <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob] call hostis_agent_fnc_firedMan;
 *
 * Public: No
*/
#define BUCKET 3

params [["_unit", objNull, [objNull]]];

if (isNull _unit || {!local _unit} || {isPlayer _unit}) exitWith {};
private _now = CBA_missionTime;
_unit setVariable [QGVAR(lastFired), _now];
private _shots = _unit getVariable [QGVAR(shots), [0, 0]];
if (_now - (_shots select 0) > BUCKET) then {
    _unit setVariable [QGVAR(shots), [_now, 1]];
} else {
    _shots set [1, (_shots select 1) + 1];
};
