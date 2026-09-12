#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Checks whether a task loop should stop because the group got a newer task,
 * was cleaned up, or no longer exists.
 *
 * Arguments:
 * 0: Group running the task <GROUP>
 * 1: Token returned by taskBegin when the loop started <NUMBER>
 *
 * Return Value:
 * true when the loop must exit <BOOL>
 *
 * Example:
 * [group bob, 3] call lambs_wp_fnc_taskIsCancelled;
 *
 * Public: No
*/
params [["_group", grpNull, [grpNull]], ["_token", -1, [0]]];

isNull _group
|| {(_group getVariable [QGVAR(taskToken), 0]) isNotEqualTo _token}
