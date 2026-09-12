#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Hands a soldier back to the engine: his position claim is dropped, stance and speed
 * are freed, the AI features the machine switched off come back (unless a waypoint task
 * holds them), and he falls in behind his leader when asked to. The record stays so he
 * can be ordered again without a fresh registration.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Follow the leader afterwards <BOOL>, default true
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob] call lambs_danger_fnc_unitRelease;
 *
 * Public: No
*/
params [["_unit", objNull, [objNull]], ["_follow", true, [false]]];

if (isNull _unit) exitWith {};
private _record = _unit getVariable QGVAR(unit);
if (isNil "_record") exitWith {};

[_unit] call EFUNC(main,positionRelease);
_record set ["state", "Idle"];
_record set ["since", time];
_record set ["order", []];
_record set ["final", []];
_record set ["hop", []];
_record set ["hopFinal", false];
_record set ["position", []];
_record set ["alternates", []];
_record set ["suppressList", []];
_record set ["sector", []];
_record set ["holdUntil", 0];
_record set ["needThink", false];
_record set ["lastEvent", time];

if (!alive _unit) exitWith {};
_unit setVariable [QGVAR(forceMove), nil];
_unit setVariable [QEGVAR(main,survival), nil];
_unit setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
_unit setUnitPos "AUTO";
_unit forceSpeed -1;
private _taskDisabled = _unit getVariable [QEGVAR(wp,disabledAI), []];
{if (!(_x in _taskDisabled)) then {_unit enableAI _x;};} forEach ["SUPPRESSION", "TARGET", "AUTOTARGET"];
if (_follow && {isNull objectParent _unit}) then {
    _unit doWatch objNull;
    _unit doFollow (leader _unit);
};
