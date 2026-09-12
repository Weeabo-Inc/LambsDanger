#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Watches a running group tactic and ends it on outcome instead of on a timer:
 * completed (objective reached or enemy gone), failed (losses, morale, no progress)
 * or timeout. Ending clears isExecutingTactic so the leader re-plans on the next
 * danger cycle, and records the result in the combat picture so the next plan can
 * avoid repeating a failure. One per frame handler per group, every 5 seconds.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Tactic name <STRING>
 * 2: Objective position <ARRAY>
 * 3: Maximum duration in seconds <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob, "assault", getPos angryJoe, 85] call lambs_danger_fnc_tacticsMonitor;
 *
 * Public: No
*/
#define CHECK_INTERVAL 5
#define REACHED_DISTANCE 15
#define ENEMY_GONE_AGE 25
#define ENEMY_GONE_HOLD 30
#define STALL_TIME 40
#define PROGRESS_STEP 5
#define FAIL_LOSSES 2
#define FAIL_MORALE 0.35
#define MOVING_TACTICS ["assault", "flank", "garrison", "bound", "withdraw"]

params [["_group", grpNull, [grpNull]], ["_tactic", "", [""]], ["_objective", [], [[]]], ["_maxDuration", 120, [0]]];

if (isNull _group) exitWith {};

// only one monitor per group
private _oldHandle = _group getVariable [QGVAR(tacticPFH), -1];
if (_oldHandle isNotEqualTo -1) then {[_oldHandle] call CBA_fnc_removePerFrameHandler;};

private _picture = [_group] call FUNC(pictureGet);
private _leader = leader _group;
private _startDistance = if (_objective isEqualTo []) then {0} else {_leader distance2D _objective};

private _handle = [{
    params ["_args", "_handle"];
    _args params ["_group", "_tactic", "_objective", "_endTime", "_startLosses", "_progress"];
    _progress params ["_lastDistance", "_lastProgressTime", "_enemyGoneSince"];

    private _fnc_end = {
        params ["_group", "_handle", "_tactic", "_result"];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (isNull _group) exitWith {};
        _group setVariable [QGVAR(tacticPFH), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QEGVAR(main,currentTactic), nil, EGVAR(main,debug_functions)];
        private _picture = [_group] call FUNC(pictureGet);
        _picture set ["lastTactic", _tactic];
        _picture set ["lastResult", _result];
        _picture set ["lastTacticTime", time];
        if (EGVAR(main,debug_functions)) then {
            ["%1 TACTICS %2 %3 (%4)", side _group, toUpper _tactic, _result, groupId _group] call EFUNC(main,debugLog);
        };
    };

    // group gone, tactic already ended elsewhere, or handed to a Zeus
    if (isNull _group || {!local _group}) exitWith {[_group, _handle, _tactic, "aborted"] call _fnc_end;};
    if (!(_group getVariable [QGVAR(isExecutingTactic), false]) || {_group call EFUNC(main,isDirected)}) exitWith {[_group, _handle, _tactic, "aborted"] call _fnc_end;};

    private _leader = leader _group;
    private _picture = [_group] call FUNC(pictureGet);
    private _losses = (_picture get "losses") - _startLosses;
    private _result = "";

    // timeout
    if (time > _endTime) then {_result = "timeout";};

    // failure ~ bleeding or broken
    if (_result isEqualTo "" && {_losses >= FAIL_LOSSES || {([_group] call FUNC(getMorale)) < FAIL_MORALE}}) then {
        _result = "failed";
    };

    // enemy gone for a while ~ done, whatever the tactic was
    if (_result isEqualTo "") then {
        private _contacts = [_group, ENEMY_GONE_AGE] call FUNC(pictureContacts);
        if (_contacts isEqualTo []) then {
            if (_enemyGoneSince < 0) then {
                _progress set [2, time];
            } else {
                if (time - _enemyGoneSince > ENEMY_GONE_HOLD) then {_result = "completed";};
            };
        } else {
            _progress set [2, -1];
        };
    };

    // movement tactics ~ reached or stalled
    if (_result isEqualTo "" && {_tactic in MOVING_TACTICS} && {_objective isNotEqualTo []}) then {
        // the closest man counts, not the leader ~ in a bound the leader sits with the base of fire
        private _distance = _leader distance2D _objective;
        {
            if (isNull objectParent _x && {_x call EFUNC(main,isAlive)}) then {_distance = _distance min (_x distance2D _objective);};
        } forEach (units _group);
        if (_distance < REACHED_DISTANCE) then {
            _result = "completed";
        } else {
            if (_distance < _lastDistance - PROGRESS_STEP) then {
                _progress set [0, _distance];
                _progress set [1, time];
            } else {
                if (time - _lastProgressTime > STALL_TIME) then {_result = "failed";};
            };
        };
    };

    if (_result isNotEqualTo "") then {
        [_group, _handle, _tactic, _result] call _fnc_end;
    };
}, CHECK_INTERVAL, [_group, _tactic, _objective, time + _maxDuration, _picture get "losses", [_startDistance, time, -1]]] call CBA_fnc_addPerFrameHandler;

_group setVariable [QGVAR(tacticPFH), _handle];
