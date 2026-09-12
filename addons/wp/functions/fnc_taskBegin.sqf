#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Marks the start of a waypoint task on a group. Bumps the group task token so any
 * older task loop of the same group exits, and snapshots the group state a task is
 * allowed to change so taskCleanup can restore it later.
 *
 * Arguments:
 * 0: Group starting the task <GROUP>
 * 1: Name of the task, used for debugging <STRING>
 *
 * Return Value:
 * task token, pass it to taskIsCancelled <NUMBER>
 *
 * Example:
 * [group bob, "taskRush"] call lambs_wp_fnc_taskBegin;
 *
 * Public: No
*/
params [["_group", grpNull, [grpNull]], ["_taskName", "", [""]]];

if (isNull _group) exitWith {-1};

// token ~ monotonic per group, any loop holding an older token must exit
private _token = (_group getVariable [QGVAR(taskToken), 0]) + 1;
_group setVariable [QGVAR(taskToken), _token];

// snapshot ~ only the first task takes it, later tasks inherit it so chained tasks restore the original
if (isNil {_group getVariable QGVAR(taskSnapshot)}) then {
    _group setVariable [QGVAR(taskSnapshot), [
        attackEnabled _group,
        speedMode _group,
        formation _group,
        behaviour (leader _group),
        combatMode _group,
        _group getVariable [QEGVAR(danger,disableGroupAI), false]
    ]];
};

// set group task
_group setVariable [QEGVAR(main,currentTactic), _taskName, EGVAR(main,debug_functions)];

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 %2: %3 started (token %4)", side _group, _taskName, groupId _group, _token] call EFUNC(main,debugLog);
};

// end
_token
