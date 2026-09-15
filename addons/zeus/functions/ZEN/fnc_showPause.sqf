#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context condition: show "Pause" while running, "Resume" while paused.
 *
 * Arguments:
 * 0: 1 for the pause entry, 0 for the resume entry <NUMBER>
 *
 * Return Value:
 * show <BOOL>
 *
 * Example:
 * [1] call hostis_zeus_fnc_showPause;
 *
 * Public: No
*/
params [["_wantsPause", 1, [0]]];

private _paused = missionNamespace getVariable [QEGVAR(squad,paused), false];
(_wantsPause > 0) isNotEqualTo _paused
