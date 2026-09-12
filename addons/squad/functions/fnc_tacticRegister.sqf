#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Registers a tactic with the squad layer (ADR-0011). A tactic is a descriptor:
 *
 *   priority     number, higher is tried first by the planner
 *   planned      bool, the planner may pick it; false means only started by name
 *   precondition code [group, ctx] -> bool
 *   start        code [group, ctx, state] -> bool (false: nothing was started)
 *   monitor      code [group, ctx, state] -> "running" | "done" | "failed" (nil: default monitor)
 *   abort        code [group, ctx, state] -> bool (nil: never)
 *   reset        code [group, state, result] -> bool true when the men must NOT be released
 *   commit       seconds before the planner may replace it, default 15
 *   maxDuration  seconds before it times out, default 120
 *   moving       bool, the default monitor judges progress toward the objective
 *   explain      the one sentence a player is told afterwards
 *
 * Arguments:
 * 0: Name <STRING>
 * 1: Descriptor <HASHMAP>
 *
 * Return Value:
 * None
 *
 * Example:
 * ["hold", createHashMapFromArray [["priority", 1], ["start", {true}]]] call hostis_squad_fnc_tacticRegister;
 *
 * Public: Yes
*/
params [["_name", "", [""]], ["_descriptor", createHashMap, [createHashMap]]];

if (_name isEqualTo "") exitWith {};
{
    if (isNil {_descriptor get (_x select 0)}) then {_descriptor set [_x select 0, _x select 1];};
} forEach [
    ["priority", 0], ["planned", false], ["precondition", {true}], ["start", {false}],
    ["commit", 15], ["maxDuration", 120], ["moving", false], ["explain", ""]
];
GVAR(tactics) set [_name, _descriptor];
