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
// with enemy guns or air overhead the side hugs (RESEARCH.md C-55): the closing tactics come first
#define HUG_TACTICS ["bound", "assault", "suppressAndFlank"]
#define HUG_BIAS 30
// at night a grenadier lights the threat before the squad moves on it, at most this often
#define ILLUM_TACTICS ["suppress", "assault", "bound", "suppressAndFlank", "search"]
#define ILLUM_INTERVAL 60

params [["_group", grpNull, [grpNull, objNull]], ["_ctx", createHashMap, [createHashMap]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group} || {!GVAR(enabled)} || {GVAR(paused)}) exitWith {""};
if (!isNil {_group getVariable QGVAR(tactic)}) exitWith {""};
if (count _ctx isEqualTo 0) then {_ctx = [_group] call FUNC(tacticContext);};

private _hug = _ctx getOrDefault ["hug", false];
private _candidates = [];
{
    if (_y get "planned") then {
        private _priority = _y get "priority";
        if (_hug && {_x in HUG_TACTICS}) then {_priority = _priority + HUG_BIAS;};
        _candidates pushBack [_priority, _x];
    };
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

if (_started in ILLUM_TACTICS && {_ctx getOrDefault ["night", false]} && {(_ctx get "threatPos") isNotEqualTo []}) then {
    private _picture = _ctx get "picture";
    if (time - (_picture getOrDefault ["illumTime", -1e9]) > ILLUM_INTERVAL) then {
        _picture set ["illumTime", time];
        [{_this call LFUNC(main,doUGL)}, [_ctx get "onFoot", _ctx get "threatPos"], 2] call CBA_fnc_waitAndExecute;
        if (SQUAD_DEBUG) then {["%1 TACTIC %2: illuminates the threat for %3", side _group, groupId _group, _started] call LFUNC(main,debugLog);};
    };
};

_started
