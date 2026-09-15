#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The intent dialog, shared by the module and the ZEN action: intent, radius, posture,
 * escalation cap, and a group picker when the caller could not tell which group.
 *
 * Arguments:
 * 0: Groups <ARRAY of GROUP>
 * 1: Objective position, [] for the leader's position <ARRAY>
 * 2: Curator client that gets feedback <NUMBER>
 * 3: Show a group picker and apply to the chosen one only <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [[group bob], getPos bob, clientOwner, false] call hostis_zeus_fnc_dialogIntent;
 *
 * Public: No
*/
params [["_groups", [], [[]]], ["_position", [], [[]]], ["_curatorOwner", -1, [0]], ["_choose", false, [false]]];

_groups = _groups select {!isNull (leader _x)};
if (_groups isEqualTo []) exitWith {};

private _current = [_groups select 0] call LFUNC(danger,intentGet);
private _fields = [
    [LSTRING(Dialog_Mode), "DROPDOWN", LSTRING(Dialog_Mode_ToolTip), [LSTRING(Intent_Free), LSTRING(Intent_Hold), LSTRING(Intent_Defend), LSTRING(Intent_Attack), LSTRING(Intent_Reserve)], (INTENT_MODES find (_current select 0)) max 0],
    [LSTRING(Dialog_Radius), "SLIDER", LSTRING(Dialog_Radius_ToolTip), [10, 500], [10, 50], _current select 2, 0],
    [LSTRING(Dialog_Posture), "DROPDOWN", LSTRING(Dialog_Posture_ToolTip), [LSTRING(Posture_Cautious), LSTRING(Posture_Balanced), LSTRING(Posture_Aggressive)], _current select 3],
    [LSTRING(Dialog_Cap), "DROPDOWN", LSTRING(Dialog_Cap_ToolTip), [LSTRING(Escalation_Routine), LSTRING(Escalation_Alert), LSTRING(Escalation_Engaged), LSTRING(Escalation_Decisive)], _current select 4]
];
if (_choose) then {
    private _names = _groups apply {format ["%1 - %2 (%3 m)", side _x, groupId _x, round ((leader _x) distance2D _position)]};
    _fields = [[LSTRING(Dialog_Group), "DROPDOWN", LSTRING(Dialog_Group_ToolTip), _names, 0]] + _fields;
};

[LSTRING(Module_Intent_DisplayName), _fields, {
    params ["_data", "_args"];
    _args params ["_groups", "_position", "_curatorOwner", "_choose"];
    if (_choose) then {_groups = [_groups select (_data deleteAt 0)];};
    _data params ["_modeIndex", "_radius", "_posture", "_cap"];
    private _mode = INTENT_MODES select _modeIndex;
    {[_x, _mode, _position, _radius, _posture, _cap, _curatorOwner] call FUNC(intent);} forEach _groups;
}, {}, {}, [_groups, _position, _curatorOwner, _choose]] call LFUNC(main,showDialog);
