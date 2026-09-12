#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Puts a group on a Zeus directed move towards one of its waypoints. Running LAMBS tasks
 * and tactics are cancelled, units that LAMBS stopped or slowed are released, and the
 * group follows the waypoint until it is reached (see directedMoveWatchdog). While the
 * move lasts, unit level reactions stay active but no group manoeuvre is started.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Index of the waypoint to follow <NUMBER>
 * 2: clientOwner of the curator to report back to, -1 for none <NUMBER>
 * 3: Internal, number of times the call was forwarded to the group owner <NUMBER>
 *
 * Return Value:
 * true when the directed move was started or extended <BOOL>
 *
 * Example:
 * [group bob, 0] call lambs_danger_fnc_directedMoveSet;
 *
 * Public: Yes
*/
#define WAYPOINT_WAIT 5
#define POSITION_TOLERANCE 2
#define MOUNT_TIMEOUT 45

params [["_group", grpNull, [grpNull, objNull]], ["_wpIndex", -1, [0]], ["_curatorOwner", -1, [0]], ["_hops", 0, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {_wpIndex < 0} || {GVAR(zeusWaypointDiscipline) isEqualTo 0}) exitWith {false};

// only the group owner may command it ~ forward once
if (!local _group) exitWith {
    if (_hops < 1) then {
        [QGVAR(directedMove), [_group, _wpIndex, _curatorOwner, _hops + 1], leader _group] call CBA_fnc_targetEvent;
    };
    false
};

// player led groups are not commanded by scripts
if (isPlayer (leader _group)) exitWith {
    [_curatorOwner, format [localize LSTRING(Feedback_PlayerGroup), groupId _group]] call FUNC(directedMoveFeedback);
    false
};

// the waypoint may not have arrived on the owner yet
if (_wpIndex >= count (waypoints _group)) exitWith {
    [
        {
            params ["_group", "_wpIndex"];
            isNull _group || {_wpIndex < count (waypoints _group)}
        },
        {
            _this call FUNC(directedMoveSet);
        },
        [_group, _wpIndex, _curatorOwner, _hops],
        WAYPOINT_WAIT,
        {
            params ["_group", "", "_curatorOwner"];
            [_curatorOwner, format [localize LSTRING(Feedback_NoWaypoint), groupId _group]] call FUNC(directedMoveFeedback);
        }
    ] call CBA_fnc_waitUntilAndExecute;
    true
};

// waypoint types that run their own scripts are left alone
private _waypoint = [_group, _wpIndex];
if ((waypointType _waypoint) in ["CYCLE", "SCRIPTED"]) exitWith {false};
private _wpPos = waypointPosition _waypoint;

// Seek & Destroy on a gunship with nobody to drop off ~ the engine's own search and destroy flies that well
if ((waypointType _waypoint) in ["SAD", "DESTROY"] && {(vehicle (leader _group)) isKindOf "Air"}) then {
    private _aircraft = vehicle (leader _group);
    private _passengers = (fullCrew [_aircraft, "cargo"]) select {alive (_x select 0) && {!isPlayer (_x select 0)}};
    if (_passengers isEqualTo []) exitWith {
        if (_group call EFUNC(main,isDirected)) then {[_group, "gunship attack"] call FUNC(directedMoveRelease);};
        _group setCurrentWaypoint _waypoint;
        _wpIndex = -1;
    };
};
if (_wpIndex isEqualTo -1) exitWith {true};

// a waypoint placed beyond a running attack waits its turn ~ the attack chains to it when the objective is held
private _attackIndex = _group getVariable [QEGVAR(wp,attackWaypoint), -1];
if (EGVAR(main,Loaded_WP) && {_attackIndex >= 0} && {_wpIndex > _attackIndex}) exitWith {
    [_curatorOwner, format [localize LSTRING(Feedback_Queued), groupId _group, _wpIndex]] call FUNC(directedMoveFeedback);
    true
};

// Seek & Destroy placed by a Zeus ~ attack the position with fire and movement, then carry on
if ((waypointType _waypoint) in ["SAD", "DESTROY"] && {EGVAR(main,Loaded_WP)}) exitWith {
    if (_group call EFUNC(main,isDirected)) then {[_group, "attack waypoint"] call FUNC(directedMoveRelease);};
    [QEGVAR(wp,taskAttack), [_group, _wpPos, 0, _wpIndex, _curatorOwner]] call CBA_fnc_localEvent;
    [_curatorOwner, format [localize LSTRING(Feedback_Attack), groupId _group, _wpIndex, round ((leader _group) distance2D _wpPos)]] call FUNC(directedMoveFeedback);
    true
};

// already directed ~ a later waypoint extends the route, the same one refreshes it (edited in Zeus)
private _state = _group getVariable [QGVAR(directedMove), []];
private _wasDirected = _state isNotEqualTo [] && {CBA_missionTime < (_state select 2)};
private _prevAttackEnabled = true;
if (_wasDirected) then {
    _state params ["_stateIndex", "", "", "", "", "_stateAttackEnabled"];
    _prevAttackEnabled = _stateAttackEnabled;
    if (_stateIndex < _wpIndex && {_stateIndex >= currentWaypoint _group}) then {
        // keep following the earlier waypoint, only extend the timer
        _state set [2, CBA_missionTime + GVAR(zeusWaypointTimeout)];
        _group setVariable [QGVAR(directedMove), _state, true];
        [_curatorOwner, format [localize LSTRING(Feedback_Extended), groupId _group, _wpIndex]] call FUNC(directedMoveFeedback);
        _wpIndex = -1;
    };
};
if (_wpIndex isEqualTo -1) exitWith {true};

// stop LAMBS tasks and tactics ~ the cleanup restores the attack state a task changed, so read it afterwards
if (EGVAR(main,Loaded_WP)) then {
    [_group] call EFUNC(wp,taskCleanup);
};
if (!_wasDirected) then {_prevAttackEnabled = attackEnabled _group;};
_group setVariable [QGVAR(isExecutingTactic), nil];
_group setVariable [QGVAR(inCQB), nil];
_group setVariable [QEGVAR(main,groupMemory), []];
_group setVariable [QEGVAR(main,currentTactic), "Directed move", EGVAR(main,debug_functions)];

// release the units
private _strict = GVAR(zeusWaypointDiscipline) isEqualTo 2;
private _units = (units _group) select {!isPlayer _x};
{
    _x setVariable [QGVAR(forceMove), nil];
    _x forceSpeed -1;
    _x setUnitPos "AUTO";
    [_x] allowGetIn true;
    if (!(_x checkAIFeature "PATH")) then {_x enableAI "PATH";};
    if (!(_x checkAIFeature "MOVE")) then {_x enableAI "MOVE";};
    if (_strict && {!(_x getVariable [QGVAR(disableAI), false])}) then {
        _x setVariable [QGVAR(disableAI), true, true];
        _x setVariable [QGVAR(directedStrict), true];
    };
    // no automatic COMBAT ~ in COMBAT the engine strings the formation out and bounds at a crawl
    if (_x checkAIFeature "AUTOCOMBAT") then {
        _x disableAI "AUTOCOMBAT";
        _x setVariable [QGVAR(directedAutoCombat), true];
    };
    _x setVariable [QEGVAR(main,currentTask), "Directed move", EGVAR(main,debug_functions)];
} forEach _units;

// a dead or unconscious leader never advances a waypoint
private _leader = leader _group;
if (!(_leader call EFUNC(main,isAlive))) then {
    private _candidates = _units select {_x call EFUNC(main,isAlive)};
    if (_candidates isNotEqualTo []) then {
        _leader = _candidates select 0;
        _group selectLeader _leader;
    };
};
{_x doFollow _leader;} forEach _units;

// group orders ~ attack stays off so nobody breaks formation to chase targets, AWARE so they actually travel
_group enableAttack false;
if ((behaviour _leader) isEqualTo "COMBAT") then {_group setBehaviourStrong "AWARE";};

// a group with vehicles mounts up first and stays aboard until it arrives; the vehicles roll once everyone is in
private _boarding = [_group] call EFUNC(main,doMountUp);
if (_boarding isNotEqualTo []) then {
    _group setVariable [QGVAR(directedMounting), time];
    {if (!isNull objectParent _x) then {doStop (driver (vehicle _x));};} forEach (units _group);
    [
        {
            params ["_group", "_boarding"];
            isNull _group || {(_boarding findIf {alive _x && {isNull objectParent _x}}) isEqualTo -1}
        },
        {
            params ["_group", "", "_waypoint"];
            if (isNull _group) exitWith {};
            _group setVariable [QGVAR(directedMounting), nil];
            {if (!isNull objectParent _x) then {(driver (vehicle _x)) doFollow (leader _group);};} forEach (units _group);
            _group setCurrentWaypoint _waypoint;
            _group setVariable [QGVAR(directedProgress), [(leader _group) distance2D (waypointPosition _waypoint), CBA_missionTime, 0, false]];
        },
        [_group, _boarding, _waypoint],
        MOUNT_TIMEOUT
    ] call CBA_fnc_waitUntilAndExecute;
} else {
    _group setCurrentWaypoint _waypoint;
};

// state
_group setVariable [QGVAR(directedMove), [_wpIndex, _wpPos, CBA_missionTime + GVAR(zeusWaypointTimeout), _curatorOwner, GVAR(zeusWaypointDiscipline), _prevAttackEnabled], true];
_group setVariable [QGVAR(directedProgress), [_leader distance2D _wpPos, CBA_missionTime, 0, false]];

// watchdog
if ((_group getVariable [QGVAR(directedPFH), -1]) isEqualTo -1) then {
    _group setVariable [QGVAR(directedPFH), [FUNC(directedMoveWatchdog), 10, _group] call CBA_fnc_addPerFrameHandler];
};

// feedback
[_curatorOwner, format [localize LSTRING(Feedback_Directed), groupId _group, _wpIndex, round (_leader distance2D _wpPos)]] call FUNC(directedMoveFeedback);
if (EGVAR(main,debug_functions)) then {
    ["%1 DIRECTED MOVE %2 -> waypoint %3 (%4m)", side _group, groupId _group, _wpIndex, round (_leader distance2D _wpPos)] call EFUNC(main,debugLog);
};

// end
true
