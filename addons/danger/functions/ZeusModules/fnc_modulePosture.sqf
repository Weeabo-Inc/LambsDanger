#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Sets posture, escalation cap and intent of the group under the cursor,
 * or of a chosen group when dropped on the ground. The module position is the spot
 * for "hold" and "defend".
 *
 * Arguments:
 * Arma 3 Module Function Parameters
 *
 * Return Value:
 * NONE
 *
 * Public: No
*/
params [["_mode", "", [""]], ["_input", [], [[]]]];

if (_mode isNotEqualTo "init") exitWith {};
if (is3DEN) exitWith {};
_input params [["_logic", objNull, [objNull]], ["_isActivated", true, [true]], ["_isCuratorPlaced", false, [true]]];
if !(_isActivated && local _logic) exitWith {};
if (!_isCuratorPlaced) exitWith {deleteVehicle _logic;};

private _group = GET_CURATOR_GRP_UNDER_CURSOR;
private _groups = [_group];
if (isNull _group) then {
    _groups = allGroups select {!isPlayer (leader _x) && {((units _x) findIf {alive _x}) != -1}};
    _groups = [_groups, [], {_logic distance (leader _x)}, "ASCEND"] call BIS_fnc_sortBy;
};
if (_groups isEqualTo []) exitWith {
    [objNull, LELSTRING(main,NoGroupSelected)] call BIS_fnc_showCuratorFeedbackMessage;
    deleteVehicle _logic;
};

private _current = [_groups select 0] call FUNC(intentGet);
private _fields = [
    [LSTRING(Module_Posture_Posture_DisplayName), "DROPDOWN", LSTRING(Module_Posture_Posture_Tooltip), [LSTRING(Posture_Cautious), LSTRING(Posture_Balanced), LSTRING(Posture_Aggressive)], _current select 3],
    [LSTRING(Module_Posture_Cap_DisplayName), "DROPDOWN", LSTRING(Module_Posture_Cap_Tooltip), [LSTRING(Escalation_Routine), LSTRING(Escalation_Alert), LSTRING(Escalation_Engaged), LSTRING(Escalation_Decisive)], _current select 4],
    [LSTRING(Module_Posture_Mode_DisplayName), "DROPDOWN", LSTRING(Module_Posture_Mode_Tooltip), [LSTRING(Intent_Free), LSTRING(Intent_Hold), LSTRING(Intent_Defend)], (["free", "hold", "defend"] find (_current select 0)) max 0],
    [LSTRING(Module_Posture_Radius_DisplayName), "SLIDER", LSTRING(Module_Posture_Radius_Tooltip), [10, 500], [2, 1], _current select 2, 2]
];
if (isNull _group) then {
    _fields = [[LSTRING(Groups_DisplayName), "DROPDOWN", LSTRING(Groups_ToolTip), _groups apply {format ["%1 - %2 (%3 m)", side _x, groupId _x, round ((leader _x) distance _logic)]}, 0]] + _fields;
};

[LSTRING(Module_Posture_DisplayName), _fields, {
    params ["_data", "_args"];
    _args params ["_groups", "_logic", "_chooseGroup"];
    private _group = _groups select 0;
    if (_chooseGroup) then {
        _group = _groups select (_data deleteAt 0);
    };
    _data params ["_posture", "_cap", "_modeIndex", "_radius"];
    private _mode = ["free", "hold", "defend"] select _modeIndex;
    private _objective = [[], getPos _logic] select (_modeIndex > 0);
    [QGVAR(intent), [_group, _mode, _objective, _radius, _posture, _cap], leader _group] call CBA_fnc_targetEvent;
    deleteVehicle _logic;
}, {
    params ["", "_logic"];
    deleteVehicle _logic;
}, {
    params ["", "_logic"];
    deleteVehicle _logic;
}, [_groups, _logic, isNull _group]] call EFUNC(main,showDialog);
