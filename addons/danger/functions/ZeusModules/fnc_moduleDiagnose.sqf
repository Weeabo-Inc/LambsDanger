#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Dropped on a group it reports why the group may not be moving; the report
 * appears as a hint and is copied to the clipboard.
 *
 * Arguments:
 * Arma 3 Module Function Parameters
 *
 * Return Value:
 * None
 *
 * Public: No
*/
params ["_logic", "", "_activated"];

if (!(_activated && local _logic)) exitWith {};

//--- Get group under cursor
private _group = GET_CURATOR_GRP_UNDER_CURSOR;

if (!isNull _group) exitWith {
    [QGVAR(diagnose), [_group, clientOwner], leader _group] call CBA_fnc_targetEvent;
    deleteVehicle _logic;
};

//--- No group: choose the nearest ones
private _groups = allGroups select {(units _x) findIf {alive _x} != -1};
_groups = [_groups, [], {_logic distance (leader _x)}, "ASCEND"] call BIS_fnc_sortBy;
if (_groups isEqualTo []) exitWith {
    [objNull, LELSTRING(main,NoGroupSelected)] call BIS_fnc_showCuratorFeedbackMessage;
    deleteVehicle _logic;
};

[LSTRING(Module_Diagnose_DisplayName),
    [
        [LSTRING(Groups_DisplayName), "DROPDOWN", LSTRING(Groups_ToolTip), _groups apply {format ["%1 - %2 (%3 m)", side _x, groupId _x, round ((leader _x) distance _logic)]}, 0]
    ], {
        params ["_data", "_args"];
        _args params ["_groups", "_logic"];
        _data params ["_groupIndex"];
        private _group = _groups select _groupIndex;
        [QGVAR(diagnose), [_group, clientOwner], leader _group] call CBA_fnc_targetEvent;
        deleteVehicle _logic;
    }, {
        params ["", "_logic"];
        deleteVehicle _logic;
    }, {
        params ["", "_logic"];
        deleteVehicle _logic;
    }, [_groups, _logic]
] call EFUNC(main,showDialog);
