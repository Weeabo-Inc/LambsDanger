#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Starts a registered tactic on a group under the squad lifecycle (ADR-0011): whatever
 * was running is reset first, the group is marked busy for the upstream commander and
 * tactics, the tactic's start runs, and a monitor handler takes over until it ends.
 * The same tactic that just ended on the same ground is refused for the cooldown.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Tactic name <STRING>
 * 2: Context from tacticContext, built here when empty <HASHMAP>
 * 3: Reason, for the log <STRING>
 *
 * Return Value:
 * started <BOOL>
 *
 * Example:
 * [group bob, "suppressAndFlank"] call hostis_squad_fnc_tacticStart;
 *
 * Public: Yes
*/
#define MONITOR_INTERVAL 3

params [["_group", grpNull, [grpNull, objNull]], ["_name", "", [""]], ["_ctx", createHashMap, [createHashMap]], ["_reason", "", [""]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group} || {GVAR(paused)}) exitWith {false};
private _descriptor = GVAR(tactics) get _name;
if (isNil "_descriptor") exitWith {false};
if (count _ctx isEqualTo 0) then {_ctx = [_group] call FUNC(tacticContext);};
private _picture = _ctx get "picture";

// cooldown on a repeat of what just ended
if (
    (_picture get "lastTactic") isEqualTo _name
    && {time - (_picture getOrDefault ["lastTacticTime", -1e9]) < GVAR(tacticCooldown)}
    && {(_picture get "lastResult") in ["completed", "failed", "timeout"]}
) exitWith {
    if (SQUAD_DEBUG) then {["%1 TACTIC %2: %3 refused (cooldown)", side _group, groupId _group, _name] call LFUNC(main,debugLog);};
    false
};

// whatever ran before is over now
if (!isNil {_group getVariable QGVAR(tactic)}) then {
    [_group, format ["replaced by %1", _name], "now"] call FUNC(tacticReset);
};
private _oldMonitor = _group getVariable [QLGVAR(danger,tacticPFH), -1];
if (_oldMonitor isNotEqualTo -1) then {
    [_oldMonitor] call CBA_fnc_removePerFrameHandler;
    _group setVariable [QLGVAR(danger,tacticPFH), nil];
};

private _token = time + random 1;
private _leader = leader _group;
private _state = createHashMapFromArray [
    ["name", _name],
    ["since", time],
    ["token", _token],
    ["objective", _ctx getOrDefault ["threatPos", []]],
    ["data", createHashMap],
    ["startLosses", _picture get "losses"],
    ["progress", [1e9, time, -1]],
    ["abortAt", -1],
    ["handle", -1],
    ["snapshot", [speedMode _group, formation _group, combatMode _group, behaviour _leader, attackEnabled _group]]
];
_group setVariable [QGVAR(tactic), _state];
_group setVariable [QLGVAR(danger,tacticToken), _token];
_group setVariable [QLGVAR(danger,isExecutingTactic), true];
_group setVariable [QLGVAR(main,currentTactic), _name, LGVAR(main,debug_functions)];

private _started = [_group, _ctx, _state] call (_descriptor get "start");
if (_started isNotEqualTo true) exitWith {
    _group setVariable [QGVAR(tactic), nil];
    _group setVariable [QLGVAR(danger,tacticToken), nil];
    _group setVariable [QLGVAR(danger,isExecutingTactic), nil];
    _group setVariable [QLGVAR(main,currentTactic), nil, LGVAR(main,debug_functions)];
    if (SQUAD_DEBUG) then {["%1 TACTIC %2: %3 did not start", side _group, groupId _group, _name] call LFUNC(main,debugLog);};
    false
};

private _handle = [FUNC(tacticMonitor), MONITOR_INTERVAL, [_group, _token]] call CBA_fnc_addPerFrameHandler;
_state set ["handle", _handle];

private _log = _picture getOrDefault ["tacticLog", []];
_log pushBack format ["%1 start %2 (%3)", round time, _name, [_reason, _descriptor get "explain"] select (_reason isEqualTo "")];
if (count _log > 10) then {_log deleteAt 0;};
_picture set ["tacticLog", _log];
if (SQUAD_DEBUG) then {["%1 TACTIC %2: start %3%4", side _group, groupId _group, _name, ["", format [" (%1)", _reason]] select (_reason isNotEqualTo "")] call LFUNC(main,debugLog);};

true
