#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Sends a short message to the curator who gave a directed move order.
 *
 * Arguments:
 * 0: clientOwner of the curator, -1 for none <NUMBER>
 * 1: Message <STRING>
 *
 * Return Value:
 * true when a message was sent <BOOL>
 *
 * Example:
 * [2, "Alpha 1-1 moving"] call lambs_danger_fnc_directedMoveFeedback;
 *
 * Public: No
*/
params [["_curatorOwner", -1, [0]], ["_text", "", [""]]];

if (_curatorOwner < 0 || {_text isEqualTo ""}) exitWith {false};

[QGVAR(curatorFeedback), [_text], _curatorOwner] call CBA_fnc_targetEvent;

true
