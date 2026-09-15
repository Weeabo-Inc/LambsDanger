#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The Director's dials, shared by the module and the ZEN action: side, throttle, the two
 * budgets, an area of operations centred where the Zeus clicked, and the pause. Applied
 * on the server by fnc_director.
 *
 * Arguments:
 * 0: Position clicked, the area of operations centre <ARRAY>
 * 1: Curator client that gets feedback <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [getPos player, clientOwner] call hostis_zeus_fnc_dialogDirector;
 *
 * Public: No
*/
params [["_position", [], [[]]], ["_curatorOwner", -1, [0]]];

private _fields = [
    [LSTRING(Dialog_Side), "DROPDOWN", LSTRING(Dialog_Side_ToolTip), ["OPFOR", "BLUFOR", "Independent"], 0],
    [LSTRING(Dialog_Throttle), "SLIDER", LSTRING(Dialog_Throttle_ToolTip), [0, 2], [0.1, 0.5], missionNamespace getVariable [QEGVAR(director,throttle), 1], 1],
    [LSTRING(Dialog_Reinforcements), "SLIDER", LSTRING(Dialog_Reinforcements_ToolTip), [0, 20], [1, 5], missionNamespace getVariable [QEGVAR(director,reinforcements), 3], 0],
    [LSTRING(Dialog_FireMissions), "SLIDER", LSTRING(Dialog_FireMissions_ToolTip), [0, 20], [1, 5], missionNamespace getVariable [QEGVAR(director,fireMissions), 4], 0],
    [LSTRING(Dialog_AORadius), "SLIDER", LSTRING(Dialog_AORadius_ToolTip), [0, 5000], [50, 500], 0, 0],
    [LSTRING(Dialog_Paused), "BOOLEAN", LSTRING(Dialog_Paused_ToolTip), missionNamespace getVariable [QEGVAR(squad,paused), false]]
];

[LSTRING(Module_Director_DisplayName), _fields, {
    params ["_data", "_args"];
    _args params ["_position", "_curatorOwner"];
    _data params ["_sideIndex", "_throttle", "_reinforcements", "_fireMissions", "_aoRadius", "_paused"];
    private _side = [east, west, independent] select _sideIndex;
    [QGVAR(director), [_side, _throttle, _reinforcements, _fireMissions, _position, _aoRadius, _paused, _curatorOwner]] call CBA_fnc_serverEvent;
}, {}, {}, [_position, _curatorOwner]] call LFUNC(main,showDialog);
