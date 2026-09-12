#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Dropped on a group it puts the group on a directed move along its waypoints,
 * or towards the module position when it has none. Dropped on empty ground it asks which
 * group should move to the module position.
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

private _fnc_direct = {
    params ["_group", "_position"];
    private _leader = leader _group;
    if (isNull _leader || {isPlayer _leader}) exitWith {
        [objNull, format [localize LSTRING(Feedback_PlayerGroup), groupId _group]] call BIS_fnc_showCuratorFeedbackMessage;
    };
    private _wpIndex = currentWaypoint _group;
    if (_wpIndex >= count (waypoints _group)) then {
        private _waypoint = _group addWaypoint [_position, 0];
        _waypoint setWaypointType "MOVE";
        _wpIndex = _waypoint select 1;
    };
    [QGVAR(directedMove), [_group, _wpIndex, clientOwner], _leader] call CBA_fnc_targetEvent;
};

//--- Get group under cursor
private _group = GET_CURATOR_GRP_UNDER_CURSOR;

if (!isNull _group) exitWith {
    [_group, getPos _logic] call _fnc_direct;
    deleteVehicle _logic;
};

//--- No group: choose one
private _groups = allGroups select {!isPlayer (leader _x) && {(units _x) findIf {alive _x} != -1}};
_groups = [_groups, [], {_logic distance (leader _x)}, "ASCEND"] call BIS_fnc_sortBy;
if (_groups isEqualTo []) exitWith {
    [objNull, LELSTRING(main,NoGroupSelected)] call BIS_fnc_showCuratorFeedbackMessage;
    deleteVehicle _logic;
};

[LSTRING(Module_DirectedMove_DisplayName),
    [
        [LSTRING(Groups_DisplayName), "DROPDOWN", LSTRING(Groups_ToolTip), _groups apply {format ["%1 - %2 (%3 m)", side _x, groupId _x, round ((leader _x) distance _logic)]}, 0]
    ], {
        params ["_data", "_args"];
        _args params ["_groups", "_logic", "_fnc_direct"];
        _data params ["_groupIndex"];
        [_groups select _groupIndex, getPos _logic] call _fnc_direct;
        deleteVehicle _logic;
    }, {
        params ["", "_logic"];
        deleteVehicle _logic;
    }, {
        params ["", "_logic"];
        deleteVehicle _logic;
    }, [_groups, _logic, _fnc_direct]
] call EFUNC(main,showDialog);
