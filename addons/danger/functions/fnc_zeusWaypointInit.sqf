#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Client side. Hooks the curator waypoint events of the curator logic assigned to the
 * player so that a waypoint placed, moved or deleted in Zeus reaches the group owner as
 * a directed move order. Polls because curator logics can be assigned after mission start.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call lambs_danger_fnc_zeusWaypointInit;
 *
 * Public: No
*/
#define POLL_INTERVAL 5

if (!hasInterface) exitWith {};

[{
    private _logic = getAssignedCuratorLogic player;
    if (isNull _logic || {_logic getVariable [QGVAR(waypointEH), false]}) exitWith {};
    _logic setVariable [QGVAR(waypointEH), true];

    _logic addEventHandler ["CuratorWaypointPlaced", {
        params ["", "_group", "_wpIndex"];
        if (GVAR(zeusWaypointDiscipline) isEqualTo 0 || {isNull _group} || {isNull (leader _group)}) exitWith {};
        [QGVAR(directedMove), [_group, _wpIndex, clientOwner], leader _group] call CBA_fnc_targetEvent;
    }];

    _logic addEventHandler ["CuratorWaypointEdited", {
        params ["", "_waypoint"];
        _waypoint params ["_group", "_wpIndex"];
        if (GVAR(zeusWaypointDiscipline) isEqualTo 0 || {isNull _group} || {isNull (leader _group)}) exitWith {};
        [QGVAR(directedMove), [_group, _wpIndex, clientOwner], leader _group] call CBA_fnc_targetEvent;
    }];

    _logic addEventHandler ["CuratorWaypointDeleted", {
        params ["", "_waypoint"];
        _waypoint params ["_group", "_wpIndex"];
        if (isNull _group || {isNull (leader _group)}) exitWith {};
        [QGVAR(directedDeleted), [_group, _wpIndex], leader _group] call CBA_fnc_targetEvent;
    }];
}, POLL_INTERVAL, []] call CBA_fnc_addPerFrameHandler;
