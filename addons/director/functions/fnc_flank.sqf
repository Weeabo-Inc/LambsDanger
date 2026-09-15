#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Adaptation (RESEARCH.md C-14, brief 3.8): a collapsing flank. Two defended positions
 * lost close together and close in time mean the enemy is rolling up one side of the
 * line. Instead of retaking either, the Director puts a reserve on a blocking position
 * between the breach and the nearest position still held, and it holds there. Reads the
 * fallen list and the side's own intents; no player position.
 *
 * One sentence: "They lost two posts on that side, so the next squad dug in across your path."
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * the group sent, grpNull when none <GROUP>
 *
 * Example:
 * [east] call hostis_director_fnc_flank;
 *
 * Public: No
*/
#define CLUSTER 400
#define WINDOW 600
#define BLOCK_BACK 150
#define BLOCK_RADIUS 80
#define TASK_TIMEOUT 300

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _blocked = (_state get "blocked") select {time - (_x select 1) < 2 * WINDOW};
_state set ["blocked", _blocked];

private _recent = (values (_state get "fallen")) select {time - (_x select 2) < WINDOW};
if (count _recent < 2) exitWith {grpNull};

// two posts lost near each other
private _pair = [];
{
    private _a = _x;
    private _b = _recent findIf {_x isNotEqualTo _a && {(_a select 0) distance2D (_x select 0) < CLUSTER}};
    if (_b isNotEqualTo -1) exitWith {_pair = [_a, _recent select _b];};
} forEach _recent;
if (_pair isEqualTo []) exitWith {grpNull};
private _centre = (((_pair select 0) select 0) vectorAdd ((_pair select 1) select 0)) vectorMultiply 0.5;
if ((_blocked findIf {(_x select 0) distance2D _centre < CLUSTER}) isNotEqualTo -1) exitWith {grpNull};

// the nearest post still held: the block goes between it and the breach
private _holders = (_state get "groups") select {
    private _intent = [_x] call LFUNC(danger,intentGet);
    (_intent select 0) in ["hold", "defend"]
    && {(_intent select 1) isNotEqualTo []}
    && {(_intent select 1) distance2D _centre > 50}
    && {((units _x) findIf {_x call LFUNC(main,isAlive)}) isNotEqualTo -1}
};
if (_holders isEqualTo []) exitWith {grpNull};
_holders = [_holders, [], {(([_x] call LFUNC(danger,intentGet)) select 1) distance2D _centre}, "ASCEND"] call BIS_fnc_sortBy;
private _anchor = ([_holders select 0] call LFUNC(danger,intentGet)) select 1;
private _block = _anchor getPos [BLOCK_BACK min ((_anchor distance2D _centre) / 2), _anchor getDir _centre];

_blocked pushBack [_centre, time];
if (!([_side, _block] call FUNC(spendAllowed))) exitWith {
    [_side, format ["collapsing flank at %1, nothing to spend on a block", mapGridPosition _centre]] call FUNC(log);
    grpNull
};
private _group = [_side, _block, BLOCK_RADIUS, format ["collapsing flank: block between %1 and %2", mapGridPosition _centre, mapGridPosition _anchor], -1, false] call FUNC(release);
if (!isNull _group) then {
    // once the attack task has put it there it holds, and does not drift home
    [
        {params ["_group"]; isNull _group || {isNil {_group getVariable QLGVAR(wp,taskSnapshot)}}},
        {params ["_group", "_block"]; if (!isNull _group) then {[_group, "hold", _block, BLOCK_RADIUS] call LFUNC(danger,intentSet);};},
        [_group, _block],
        TASK_TIMEOUT,
        {params ["_group", "_block"]; if (!isNull _group) then {[_group, "hold", _block, BLOCK_RADIUS] call LFUNC(danger,intentSet);};}
    ] call CBA_fnc_waitUntilAndExecute;
    [_side, format ["adaptation: %1 blocks the collapsing flank at %2", groupId _group, mapGridPosition _block]] call FUNC(log);
};

_group
