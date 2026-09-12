#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Gives up a man's claim on his fighting position (see lambs_main_fnc_positionReserve).
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob] call lambs_main_fnc_positionRelease;
 *
 * Public: No
*/
params [["_unit", objNull, [objNull]]];

if (isNull _unit) exitWith {};
private _reserved = (group _unit) getVariable QGVAR(reserved);
if (isNil "_reserved") exitWith {};
_reserved deleteAt (hashValue _unit);
