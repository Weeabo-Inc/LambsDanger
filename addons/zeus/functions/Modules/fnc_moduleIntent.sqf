#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Dropped on a group it opens the intent dialog for that group; dropped on
 * the ground it offers the nearest groups and uses the drop point as the objective.
 *
 * Arguments:
 * Arma 3 Module Function Parameters
 *
 * Return Value:
 * None
 *
 * Public: No
*/
#define PICK_COUNT 12

params ["_logic", "", "_activated"];

if (!(_activated && local _logic)) exitWith {};
private _position = getPosATL _logic;
private _mouseOver = curatorMouseOver;
deleteVehicle _logic;

private _group = grpNull;
if (_mouseOver isNotEqualTo []) then {
    _group = switch (_mouseOver select 0) do {
        case "OBJECT": {group (_mouseOver select 1)};
        case "GROUP": {_mouseOver select 1};
        default {grpNull};
    };
};
if (!isNull _group && {!isNull (leader _group)} && {!isPlayer (leader _group)}) exitWith {
    [[_group], _position, clientOwner, false] call FUNC(dialogIntent);
};

private _groups = [_position] call FUNC(groupsNear);
if (_groups isEqualTo []) exitWith {[objNull, localize LAMBS_STRING(main,NoGroupSelected)] call BIS_fnc_showCuratorFeedbackMessage;};
if (count _groups > PICK_COUNT) then {_groups resize PICK_COUNT;};
[_groups, _position, clientOwner, true] call FUNC(dialogIntent);
