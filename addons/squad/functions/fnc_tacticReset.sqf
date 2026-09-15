#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Ends whatever tactic a group is running and hands the men back, cleanly, from any
 * layer: the tactic's own reset, then the group flags, the monitor, the men and the
 * group settings from before the tactic. Safe on a group with nothing running, on a
 * dead group and on a foreign group. The public equivalent of upstream taskReset for
 * tactics (ADR-0011).
 *
 * Interrupt classes (C-15): "now" resets this frame; "blend" lets a bound finish its
 * current leg (at most 10 s) and then resets; "finish" only marks the reason and lets the
 * monitor end the tactic on its own terms.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Reason or result, for the log <STRING>
 * 2: Interrupt class: "now", "blend" or "finish", default "now" <STRING>
 *
 * Return Value:
 * true when a tactic was ended now <BOOL>
 *
 * Example:
 * [group bob, "zeus pause"] call hostis_squad_fnc_tacticReset;
 *
 * Public: Yes
*/
#define BLEND_MAX 10

params [["_group", grpNull, [grpNull, objNull]], ["_reason", "aborted", [""]], ["_class", "now", [""]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group}) exitWith {false};
private _state = _group getVariable QGVAR(tactic);

// a softer stop: the monitor finishes the job
if (!isNil "_state" && {_class isNotEqualTo "now"}) exitWith {
    if (_class isEqualTo "blend") then {
        private _rushing = (units _group) findIf {([_x, "state", "Idle"] call LFUNC(danger,unitState)) isEqualTo "Rushing"};
        if (_rushing isEqualTo -1) exitWith {[_group, _reason, "now"] call FUNC(tacticReset)};
        _state set ["abortAt", time + BLEND_MAX];
        _state set ["abortReason", _reason];
    } else {
        _state set ["abortReason", _reason];
    };
    false
};

private _releaseMen = true;
private _name = "";
if (!isNil "_state") then {
    _name = _state get "name";
    private _handle = _state getOrDefault ["handle", -1];
    if (_handle isNotEqualTo -1) then {[_handle] call CBA_fnc_removePerFrameHandler;};
    private _descriptor = GVAR(tactics) get _name;
    if (!isNil "_descriptor" && {!isNil {_descriptor get "reset"}}) then {
        private _keep = [_group, _state, _reason] call (_descriptor get "reset");
        if (_keep isEqualTo true) then {_releaseMen = false;};
    };
    // what it was before the tactic
    (_state get "snapshot") params ["_speedMode", "_formation", "_combatMode", "_behaviour", "_attack"];
    if (_releaseMen) then {
        _group setSpeedMode _speedMode;
        _group setFormation _formation;
        _group setCombatMode _combatMode;
        _group setBehaviourStrong _behaviour;
        _group enableAttack (_attack || {!(_group call LFUNC(main,isDirected))});
    };
    private _picture = [_group] call EFUNC(core,pictureGet);
    // the reason may carry a detail after the verdict: "failed (leader lost)"
    private _result = switch (true) do {
        case ((_reason find "completed") isEqualTo 0): {"completed"};
        case ((_reason find "failed") isEqualTo 0): {"failed"};
        case ((_reason find "timeout") isEqualTo 0): {"timeout"};
        default {"aborted"};
    };
    _picture set ["lastTactic", _name];
    _picture set ["lastResult", _result];
    _picture set ["lastTacticTime", time];
    private _log = _picture getOrDefault ["tacticLog", []];
    _log pushBack format ["%1 end %2: %3", round time, _name, _reason];
    if (count _log > 10) then {_log deleteAt 0;};
    _picture set ["tacticLog", _log];
    if (SQUAD_DEBUG) then {["%1 TACTIC %2: %3 %4 after %5 s", side _group, groupId _group, _name, _reason, round (time - (_state get "since"))] call LFUNC(main,debugLog);};
};
_group setVariable [QGVAR(tactic), nil];

// the flags every upstream tactic and the commander read
_group setVariable [QLGVAR(danger,tacticToken), nil];
_group setVariable [QLGVAR(danger,isExecutingTactic), nil];
_group setVariable [QLGVAR(danger,boundToken), nil];
_group setVariable [QLGVAR(main,currentTactic), nil, LGVAR(main,debug_functions)];
private _oldMonitor = _group getVariable [QLGVAR(danger,tacticPFH), -1];
if (_oldMonitor isNotEqualTo -1) then {
    [_oldMonitor] call CBA_fnc_removePerFrameHandler;
    _group setVariable [QLGVAR(danger,tacticPFH), nil];
};

// the men
if (_releaseMen) then {
    {
        if (!isPlayer _x) then {
            [_x, true] call LFUNC(danger,unitRelease);
            _x setVariable [QLGVAR(danger,forceMove), nil];
            private _taskDisabled = _x getVariable [QLGVAR(wp,disabledAI), []];
            if (!("AUTOCOMBAT" in _taskDisabled) && {!(_group call LFUNC(main,isDirected))}) then {_x enableAI "AUTOCOMBAT";};
        };
    } forEach (units _group);
};

!isNil "_state"
