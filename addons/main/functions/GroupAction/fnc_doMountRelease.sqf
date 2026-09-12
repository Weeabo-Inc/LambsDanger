#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Undoes doMountUp: vehicles may unload in combat again and the boarding units get
 * their danger reactions back. Does not dismount anyone.
 *
 * Arguments:
 * 0: Group <GROUP>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob] call lambs_main_fnc_doMountRelease;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {};

{
    private _vehicle = vehicle _x;
    if (_vehicle isNotEqualTo _x && {(_vehicle getVariable [QGVAR(groupVehicle), grpNull]) isEqualTo _group}) then {
        _vehicle setUnloadInCombat [true, true];
        _vehicle setVariable [QGVAR(keepMounted), nil];
    };
    if ((_x getVariable [QGVAR(currentTask), ""]) isEqualTo "Mounting up") then {
        _x setVariable [QEGVAR(danger,forceMove), nil];
        _x setVariable [QGVAR(currentTask), nil, GVAR(debug_functions)];
    };
} forEach (units _group);
