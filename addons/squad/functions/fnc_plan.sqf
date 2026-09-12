#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The squad planner: a prioritised list of tactics (ADR-0009). The first registered,
 * planned tactic whose precondition holds and that is not on cooldown is started. Called
 * from the commander's group think for a group that is not busy.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Context from tacticContext, built here when empty <HASHMAP>
 *
 * Return Value:
 * the name of the tactic started, "" when none <STRING>
 *
 * Example:
 * [group bob] call hostis_squad_fnc_plan;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_ctx", createHashMap, [createHashMap]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group} || {!GVAR(enabled)} || {GVAR(paused)}) exitWith {""};
if (!isNil {_group getVariable QGVAR(tactic)}) exitWith {""};
if (count _ctx isEqualTo 0) then {_ctx = [_group] call FUNC(tacticContext);};

private _candidates = [];
{
    if (_y get "planned") then {_candidates pushBack [_y get "priority", _x];};
} forEach GVAR(tactics);
_candidates sort false;

private _started = "";
{
    private _name = _x select 1;
    private _descriptor = GVAR(tactics) get _name;
    if ([_group, _ctx] call (_descriptor get "precondition")) then {
        if ([_group, _name, _ctx, "planned"] call FUNC(tacticStart)) exitWith {_started = _name;};
    };
} forEach _candidates;

_started
