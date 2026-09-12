#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Per frame handler body of a Zeus directed move. Every few seconds it checks whether the
 * group reached its waypoint (then follows the next one or releases the group), whether
 * the waypoint still exists, and whether the group is making progress. A group that stalls
 * gets its orders re-issued; after repeated stalls the curator gets a diagnosis.
 *
 * Arguments:
 * 0: PFH arguments <ARRAY>
 *   0: Group <GROUP>
 * 1: PFH handle <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [lambs_danger_fnc_directedMoveWatchdog, 10, group bob] call CBA_fnc_addPerFrameHandler;
 *
 * Public: No
*/
#define POSITION_TOLERANCE 2
#define PROGRESS_STEP 5
#define STALL_TIME 30
#define STALL_REPORT_AFTER 3
#define MIN_COMPLETION_RADIUS 15
#define HOLDING_WAYPOINTS ["HOLD", "GUARD", "SENTRY", "SAD", "LOITER", "DISMISS", "SUPPORT"]
#define SKIPPED_WAYPOINTS ["CYCLE", "SCRIPTED"]

params ["_args", "_handle"];
_args params ["_group"];

// group gone or moved to another machine ~ the new owner starts without a directed move
if (isNull _group || {!local _group}) exitWith {
    [_handle] call CBA_fnc_removePerFrameHandler;
    if (!isNull _group) then {
        _group setVariable [QGVAR(directedPFH), nil];
        _group setVariable [QGVAR(directedMove), nil, true];
    };
};

private _state = _group getVariable [QGVAR(directedMove), []];
if (_state isEqualTo []) exitWith {[_group, "cleared"] call FUNC(directedMoveRelease);};
_state params ["_wpIndex", "_wpPos", "_until", "_curatorOwner"];

// group dead or out of time
private _units = (units _group) select {!isPlayer _x && {_x call EFUNC(main,isAlive)}};
if (_units isEqualTo []) exitWith {[_group, "no units left"] call FUNC(directedMoveRelease);};
if (CBA_missionTime > _until) exitWith {[_group, "timeout"] call FUNC(directedMoveRelease);};

// waypoint still there? indices shift when the Zeus deletes an earlier one
private _waypoints = waypoints _group;
if (_wpIndex >= count _waypoints || {(waypointPosition (_waypoints select _wpIndex)) distance2D _wpPos > POSITION_TOLERANCE}) then {
    _wpIndex = _waypoints findIf {(waypointPosition _x) distance2D _wpPos < POSITION_TOLERANCE};
    if (_wpIndex isNotEqualTo -1) then {
        _state set [0, _wpIndex];
        _group setVariable [QGVAR(directedMove), _state, true];
    };
};
if (_wpIndex isEqualTo -1) exitWith {[_group, "waypoint removed"] call FUNC(directedMoveRelease);};

// arrived?
private _leader = leader _group;
private _waypoint = _waypoints select _wpIndex;
private _wpType = waypointType _waypoint;
private _radius = (waypointCompletionRadius _waypoint) max MIN_COMPLETION_RADIUS;
private _arrived = (currentWaypoint _group) > _wpIndex
    || {_wpType in HOLDING_WAYPOINTS && {_leader distance2D _wpPos < _radius}};

if (_arrived) exitWith {
    private _nextIndex = _wpIndex + 1;
    private _nextType = if (_nextIndex < count _waypoints) then {waypointType (_waypoints select _nextIndex)} else {""};

    // next on the route is an attack ~ hand the group to the attack task
    if (_nextType in ["SAD", "DESTROY"] && {EGVAR(main,Loaded_WP)} && {!(_wpType in HOLDING_WAYPOINTS)}) exitWith {
        [_group, "attack waypoint"] call FUNC(directedMoveRelease);
        [_group, _nextIndex, _curatorOwner] call FUNC(directedMoveSet);
    };

    if (_nextIndex < count _waypoints && {!(_nextType in SKIPPED_WAYPOINTS)} && {!(_wpType in HOLDING_WAYPOINTS)}) then {
        // follow the route on to the next waypoint
        private _nextPos = waypointPosition (_waypoints select _nextIndex);
        _state set [0, _nextIndex];
        _state set [1, _nextPos];
        _group setVariable [QGVAR(directedMove), _state, true];
        _group setVariable [QGVAR(directedProgress), [_leader distance2D _nextPos, CBA_missionTime, 0, false]];
        if ((currentWaypoint _group) isNotEqualTo _nextIndex) then {_group setCurrentWaypoint [_group, _nextIndex];};
        if (EGVAR(main,debug_functions)) then {
            ["%1 DIRECTED MOVE %2 -> next waypoint %3", side _group, groupId _group, _nextIndex] call EFUNC(main,debugLog);
        };
    } else {
        [_group, "completed"] call FUNC(directedMoveRelease);
    };
};

// stragglers ~ a follower that stopped to shoot or fell far behind is told to catch up
{
    if (_x isNotEqualTo _leader && {(currentCommand _x) isEqualTo "Suppress" || {_x distance2D _leader > 50}}) then {
        _x doWatch objNull;
        _x doFollow _leader;
    };
} forEach _units;

// progress
private _progress = _group getVariable [QGVAR(directedProgress), [1e9, CBA_missionTime, 0, false]];
_progress params ["_lastDistance", "_lastProgressTime", "_reissues", "_diagnosisSent"];
private _distance = _leader distance2D _wpPos;

if (_distance < _lastDistance - PROGRESS_STEP) then {
    _progress set [0, _distance];
    _progress set [1, CBA_missionTime];
} else {
    if (CBA_missionTime - _lastProgressTime > STALL_TIME) then {

        // re-issue the order
        if (!(_leader call EFUNC(main,isAlive))) then {
            _leader = _units select 0;
            _group selectLeader _leader;
        };
        {
            if (!(_x checkAIFeature "PATH")) then {_x enableAI "PATH";};
            if (!(_x checkAIFeature "MOVE")) then {_x enableAI "MOVE";};
            _x forceSpeed -1;
            _x doFollow _leader;
        } forEach _units;
        _group setCurrentWaypoint [_group, _wpIndex];
        _reissues = _reissues + 1;
        _progress set [1, CBA_missionTime];
        _progress set [2, _reissues];
        if (EGVAR(main,debug_functions)) then {
            ["%1 DIRECTED MOVE %2 stalled at %3m, orders re-issued (%4)", side _group, groupId _group, round _distance, _reissues] call EFUNC(main,debugLog);
        };

        // tell the curator why after repeated stalls
        if (_reissues >= STALL_REPORT_AFTER && {!_diagnosisSent}) then {
            _progress set [3, true];
            [_curatorOwner, format [localize LSTRING(Feedback_NoProgress), groupId _group, round _distance]] call FUNC(directedMoveFeedback);
            if (_curatorOwner >= 0) then {
                [QGVAR(diagnoseResult), [groupId _group, _group call FUNC(directedMoveDiagnose)], _curatorOwner] call CBA_fnc_ownerEvent;
            };
        };
    };
};
_group setVariable [QGVAR(directedProgress), _progress];
