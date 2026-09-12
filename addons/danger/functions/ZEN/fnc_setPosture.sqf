#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Opens the posture and intent dialog for the selected groups;
 * the clicked position is the spot for "hold" and "defend".
 *
 * Arguments:
 * 0: Selected groups <ARRAY>
 * 1: Selected objects <ARRAY>
 * 2: Clicked position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [[group bob], [], getPos bob] call lambs_danger_fnc_setPosture;
 *
 * Public: No
*/
private _position = _this param [2, [], [[]]];
private _targets = [];
GET_GROUPS_CONTEXT(_targets);
_targets = _targets select {!isNull (leader _x)};
if (_targets isEqualTo []) exitWith {};

private _current = [_targets select 0] call FUNC(intentGet);
[LSTRING(Module_Posture_DisplayName), [
    [LSTRING(Module_Posture_Posture_DisplayName), "DROPDOWN", LSTRING(Module_Posture_Posture_Tooltip), [LSTRING(Posture_Cautious), LSTRING(Posture_Balanced), LSTRING(Posture_Aggressive)], _current select 3],
    [LSTRING(Module_Posture_Cap_DisplayName), "DROPDOWN", LSTRING(Module_Posture_Cap_Tooltip), [LSTRING(Escalation_Routine), LSTRING(Escalation_Alert), LSTRING(Escalation_Engaged), LSTRING(Escalation_Decisive)], _current select 4],
    [LSTRING(Module_Posture_Mode_DisplayName), "DROPDOWN", LSTRING(Module_Posture_Mode_Tooltip), [LSTRING(Intent_Free), LSTRING(Intent_Hold), LSTRING(Intent_Defend)], (["free", "hold", "defend"] find (_current select 0)) max 0],
    [LSTRING(Module_Posture_Radius_DisplayName), "SLIDER", LSTRING(Module_Posture_Radius_Tooltip), [10, 500], [2, 1], _current select 2, 2]
], {
    params ["_data", "_args"];
    _args params ["_targets", "_position"];
    _data params ["_posture", "_cap", "_modeIndex", "_radius"];
    private _mode = ["free", "hold", "defend"] select _modeIndex;
    {
        private _objective = [[], [_position, getPosATL (leader _x)] select (_position isEqualTo [])] select (_modeIndex > 0);
        [QGVAR(intent), [_x, _mode, _objective, _radius, _posture, _cap], leader _x] call CBA_fnc_targetEvent;
    } forEach _targets;
}, {}, {}, [_targets, _position]] call EFUNC(main,showDialog);
