#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The per-group monitor handler of a running tactic: abort conditions, the tactic's own
 * monitor or the default one, the commitment and the timeout, and the end through
 * tacticReset with the result. The default monitor ends a tactic when the group is
 * bleeding or broken (failed), when the enemy has been gone a while (completed), and
 * for a moving tactic when the closest man reaches the objective (completed) or nobody
 * has gained ground for a while (failed).
 *
 * Arguments:
 * 0: PFH arguments [group, token] <ARRAY>
 * 1: PFH handle <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * called by CBA_fnc_addPerFrameHandler
 *
 * Public: No
*/
#define FAIL_LOSSES 2
#define FAIL_MORALE 0.35
#define ENEMY_GONE_AGE 25
#define ENEMY_GONE_HOLD 20
#define REACHED_DISTANCE 25
#define PROGRESS_STEP 10
#define STALL_TIME 45

params ["_args", "_handle"];
_args params ["_group", "_token"];

if (isNull _group || {!local _group}) exitWith {[_handle] call CBA_fnc_removePerFrameHandler;};
private _state = _group getVariable QGVAR(tactic);
if (isNil "_state" || {(_state get "token") isNotEqualTo _token}) exitWith {[_handle] call CBA_fnc_removePerFrameHandler;};
private _name = _state get "name";
private _descriptor = GVAR(tactics) get _name;
if (isNil "_descriptor") exitWith {[_group, "unregistered", "now"] call FUNC(tacticReset);};

// somebody else ended it: a Zeus, an upstream reset, a task
if (!(_group getVariable [QLGVAR(danger,isExecutingTactic), false]) || {_group call LFUNC(main,isDirected)} || {GVAR(paused)}) exitWith {
    [_group, ["aborted", "paused"] select GVAR(paused), "now"] call FUNC(tacticReset);
};

// a blend abort that waited for the leg to end
private _abortAt = _state get "abortAt";
if (_abortAt > 0) then {
    private _rushing = (units _group) findIf {([_x, "state", "Idle"] call LFUNC(danger,unitState)) isEqualTo "Rushing"};
    if (_rushing isEqualTo -1 || {time > _abortAt}) exitWith {[_group, _state getOrDefault ["abortReason", "aborted"], "now"] call FUNC(tacticReset);};
};

private _ctx = [_group] call FUNC(tacticContext);
private _abort = _descriptor get "abort";
if (!isNil "_abort" && {[_group, _ctx, _state] call _abort}) exitWith {[_group, "aborted", "now"] call FUNC(tacticReset);};

private _result = "running";
private _monitor = _descriptor get "monitor";
if (!isNil "_monitor") then {
    _result = [_group, _ctx, _state] call _monitor;
    if (isNil "_result") then {_result = "running";};
};

// the default judgement, also applied after a tactic's own monitor says running
if (_result isEqualTo "running") then {
    private _picture = _ctx get "picture";
    private _losses = (_picture get "losses") - (_state get "startLosses");
    private _progress = _state get "progress";
    _progress params ["_lastDistance", "_lastProgressTime", "_enemyGoneSince"];
    if (_losses >= FAIL_LOSSES || {(_ctx get "morale") < FAIL_MORALE} || {(_ctx get "cohesion") isEqualTo "broken" && {_name isNotEqualTo "withdraw"}}) then {_result = "failed";};

    if (_result isEqualTo "running") then {
        private _recent = [_group, ENEMY_GONE_AGE] call EFUNC(core,contactsGet);
        if (_recent isEqualTo []) then {
            if (_enemyGoneSince < 0) then {_progress set [2, time];} else {
                if (time - _enemyGoneSince > ENEMY_GONE_HOLD) then {_result = "completed";};
            };
        } else {
            _progress set [2, -1];
        };
    };

    if (_result isEqualTo "running" && {_descriptor get "moving"} && {(_state get "objective") isNotEqualTo []}) then {
        private _objective = _state get "objective";
        private _distance = 1e9;
        {_distance = _distance min (_x distance2D _objective);} forEach (_ctx get "onFoot");
        if (_distance < REACHED_DISTANCE) then {_result = "completed";} else {
            if (_distance < _lastDistance - PROGRESS_STEP) then {
                _progress set [0, _distance];
                _progress set [1, time];
            } else {
                if (time - _lastProgressTime > STALL_TIME) then {_result = "failed";};
            };
        };
    };
};

if (_result isEqualTo "running" && {time - (_state get "since") > (_descriptor get "maxDuration")}) then {_result = "timeout";};

if (_result isNotEqualTo "running") then {
    [_group, ["completed", _result] select (_result in ["completed", "failed", "timeout"]), "now"] call FUNC(tacticReset);
};
