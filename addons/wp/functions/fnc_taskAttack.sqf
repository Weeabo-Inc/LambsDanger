#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Attack Position
 *        Group moves on an objective with weapons hot. Far from it the group travels
 *        fast; once close, or once the enemy is close, it fights forward with fire
 *        and movement (see lambs_danger_fnc_tacticsBound), sweeps the buildings on
 *        arrival and stands down when the objective is held and no enemy is known nearby.
 *        A Zeus gets it by placing a Seek & Destroy waypoint; the group then carries
 *        on to its next waypoint when done.
 *
 * Arguments:
 * 0: Group performing action, either unit <OBJECT> or group <GROUP>
 * 1: Objective position <ARRAY>
 * 2: Radius of the objective, 0 or less for the default 50 <NUMBER>
 * 3: Waypoint index that started the task, -1 for none <NUMBER>
 * 4: Curator client that gets feedback, -1 for none <NUMBER>
 *
 * Return Value:
 * none
 *
 * Example:
 * [bob, getPos angryJoe, 50] call lambs_wp_fnc_taskAttack;
 *
 * Public: Yes
*/
#define CYCLE_TIME 6
#define ENGAGE_DISTANCE 350
#define TRAVEL_STANDOFF 300
#define MOUNT_TIMEOUT 45
#define MAX_ATTEMPTS 2
#define CONTACT_ENGAGE_DISTANCE 200
#define CONTACT_AGE 30
#define HOLD_TIME 30
#define HOLD_TIME_FRIENDS 8

if (canSuspend) exitWith { [FUNC(taskAttack), _this] call CBA_fnc_directCall; };

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_pos", [], [[]]],
    ["_radius", TASK_ATTACK_SIZE, [0]],
    ["_wpIndex", -1, [0]],
    ["_curatorOwner", -1, [0]]
];

// sort group
if (!local _group) exitWith {false};
if (_group isEqualType objNull) then {_group = group _group;};
if (_pos isEqualTo []) exitWith {false};
_pos = _pos call CBA_fnc_getPos;
if (_radius <= 0) then {_radius = TASK_ATTACK_SIZE;};

// task lifecycle
private _token = [_group, "taskAttack"] call FUNC(taskBegin);
_group setVariable [QGVAR(attackWaypoint), _wpIndex];
[_group, "attack", _pos, _radius, nil, 3] call EFUNC(danger,intentSet);

// whatever LAMBS was doing with this group ends here ~ the task owns it now
private _tacticPFH = _group getVariable [QEGVAR(danger,tacticPFH), -1];
if (_tacticPFH isNotEqualTo -1) then {[_tacticPFH] call CBA_fnc_removePerFrameHandler;};
_group setVariable [QEGVAR(danger,tacticPFH), nil];
_group setVariable [QEGVAR(danger,isExecutingTactic), nil];
_group setVariable [QEGVAR(danger,inCQB), nil];
_group setVariable [QEGVAR(danger,disableGroupAI), true, true];
_group setVariable [QEGVAR(main,groupMemory), []];

// orders ~ AWARE and no automatic switch to COMBAT, or the engine crawls and never arrives
_group setBehaviourStrong "AWARE";
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_group setFormation "WEDGE";
_group enableAttack false;
private _leader = leader _group;
{
    _x setVariable [QEGVAR(danger,forceMove), nil];
    _x setUnitPos "AUTO";
    _x forceSpeed -1;
    [_x] allowGetIn true;
    if (!(_x checkAIFeature "PATH")) then {_x enableAI "PATH";};
    if (!(_x checkAIFeature "MOVE")) then {_x enableAI "MOVE";};
    _x disableAI "AUTOCOMBAT";
    _x setVariable [QGVAR(disabledAI), ["AUTOCOMBAT"]];
    _x doFollow _leader;
    // followers travel, the leader keeps his reactions so the group still builds its picture
    if (_x isNotEqualTo _leader) then {_x setVariable [QEGVAR(danger,forceMove), true];};
    _x setVariable [QEGVAR(main,currentTask), "Attack (approach)", EGVAR(main,debug_functions)];
} forEach ((units _group) select {!isPlayer _x});

// go ~ a Zeus route is kept, but the Seek & Destroy waypoint itself is parked as HOLD while the task runs:
// otherwise the engine keeps driving the group into the objective in competition with the plan
if (_wpIndex < 0) then {[_group] call CBA_fnc_clearWaypoints;} else {
    if (_wpIndex < count (waypoints _group)) then {
        [_group, _wpIndex] setWaypointType "HOLD";
        _group setCurrentWaypoint [_group, _wpIndex];
    };
};
// a group with vehicles mounts up and is driven to the engagement distance, never into the objective;
// the attack plan dismounts it there
private _travelPos = _pos;
private _boarding = [];
if (([_leader, 400] call EFUNC(main,findGroupVehicles)) isNotEqualTo []) then {
    _travelPos = _pos getPos [TRAVEL_STANDOFF min ((_leader distance2D _pos) * 0.8), _pos getDir _leader];
    private _empty = _travelPos findEmptyPosition [0, 30, typeOf (vehicle _leader)];
    if (_empty isNotEqualTo []) then {_travelPos = _empty;};
    _group setVariable [QGVAR(attackTravelPos), _travelPos];
    _boarding = [_group] call EFUNC(main,doMountUp);
};
if (_boarding isEqualTo []) then {
    _group move _travelPos;
} else {
    // vehicles wait for everyone, then roll
    {if (!isNull objectParent _x) then {doStop (driver (vehicle _x));};} forEach (units _group);
    [
        {
            params ["_group", "_boarding"];
            isNull _group || {(_boarding findIf {alive _x && {isNull objectParent _x}}) isEqualTo -1}
        },
        {
            params ["_group", "", "_travelPos"];
            if (isNull _group) exitWith {};
            {if (!isNull objectParent _x) then {(driver (vehicle _x)) doFollow (leader _group);};} forEach (units _group);
            _group move _travelPos;
        },
        [_group, _boarding, _travelPos],
        MOUNT_TIMEOUT
    ] call CBA_fnc_waitUntilAndExecute;
};
[_leader, "combat", "Advance", 125] call EFUNC(main,doCallout);

private _handle = [{
    params ["_args", "_handle"];
    _args params ["_group", "_pos", "_radius", "_token", "_wpIndex", "_curatorOwner", "_state", "_startTime"];
    _state params ["_phase", "_heldSince"];

    private _fnc_end = {
        params ["_group", "_handle", "_token", "_wpIndex", "_curatorOwner", "_reason", "_pos", "_radius", ["_startTime", 0]];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (isNull _group) exitWith {};
        _group setVariable [QGVAR(attackPFH), nil];
        _group setVariable [QGVAR(attackWaypoint), nil];
        _group setVariable [QGVAR(attackTravelPos), nil];
        if (EGVAR(main,debug_functions)) then {
            ["%1 taskAttack: %2 %3", side _group, groupId _group, _reason] call EFUNC(main,debugLog);
        };
        if ([_group, _token] call FUNC(taskIsCancelled)) exitWith {
            // somebody else took the group ~ give the Zeus back the waypoint as placed
            if (_wpIndex >= 0 && {_wpIndex < count (waypoints _group)} && {(waypointType [_group, _wpIndex]) isEqualTo "HOLD"}) then {
                [_group, _wpIndex] setWaypointType "SAD";
            };
        };
        [_group] call FUNC(taskCleanup);
        [_group] call EFUNC(main,doMountRelease);

        // the objective is now the group's ground
        private _held = _reason isEqualTo "objective held";
        [_group, ["free", "defend"] select _held, _pos, _radius] call EFUNC(danger,intentSet);

        // the Seek & Destroy waypoint is done ~ take it off the route so the engine does not drive them into it
        private _nextIndex = -1;
        if (_wpIndex >= 0 && {_wpIndex < count (waypoints _group)}) then {
            deleteWaypoint [_group, _wpIndex];
            if (_wpIndex < count (waypoints _group)) then {_nextIndex = _wpIndex;};
        };

        // carry on with the route as a directed move (mounts up first), or remount when nothing was found
        if (_nextIndex >= 0) then {
            [_group, _nextIndex, _curatorOwner] call EFUNC(danger,directedMoveSet);
        } else {
            if (_held && {(([_group] call EFUNC(danger,pictureGet)) get "lastContact") < _startTime}) then {
                [_group] call EFUNC(main,doMountUp);
                [_group, "free"] call EFUNC(danger,intentSet);
            };
        };
        if (_curatorOwner >= 0) then {
            private _feedback = [ELSTRING(danger,Feedback_AttackDone), ELSTRING(danger,Feedback_AttackFailed)] select (_reason isEqualTo "attack failed");
            [_curatorOwner, format [localize _feedback, groupId _group]] call EFUNC(danger,directedMoveFeedback);
        };
    };

    // cancelled, taken over by a Zeus move, or nobody left
    if ([_group, _token] call FUNC(taskIsCancelled) || {_group call EFUNC(main,isDirected)}) exitWith {[_group, _handle, _token, _wpIndex, _curatorOwner, "cancelled", _pos, _radius] call _fnc_end;};
    private _units = (units _group) select {_x call EFUNC(main,isAlive) && {!isPlayer _x}};
    if (_units isEqualTo []) exitWith {[_group, _handle, _token, _wpIndex, _curatorOwner, "no units left", _pos, _radius] call _fnc_end;};

    private _leader = leader _group;
    if (!(_leader call EFUNC(main,isAlive))) then {
        _leader = _units select 0;
        _group selectLeader _leader;
    };
    private _distance = _leader distance2D _pos;

    // what do we know
    private _contacts = [_group, CONTACT_AGE] call EFUNC(danger,pictureContacts);
    private _nearestContact = [];
    private _nearestContactDistance = 1e9;
    {
        private _contactPos = _x select 1;
        private _contactDistance = _leader distance2D _contactPos;
        if (_contactDistance < _nearestContactDistance && {_contactPos distance2D _pos < _radius + ENGAGE_DISTANCE}) then {
            _nearestContact = _contactPos;
            _nearestContactDistance = _contactDistance;
        };
    } forEach _contacts;

    // objective held ~ on it, and nothing known around it for a while (quickly, if friends already hold it)
    private _held = false;
    if (_distance < _radius && {_nearestContact isEqualTo []}) then {
        private _friendsThere = (allGroups findIf {
            _x isNotEqualTo _group && {(side _x) isEqualTo (side _group)} && {(leader _x) call EFUNC(main,isAlive)} && {(leader _x) distance2D _pos < _radius}
        }) isNotEqualTo -1;
        if (_heldSince < 0) then {_state set [1, time];} else {_held = time - _heldSince > ([HOLD_TIME, HOLD_TIME_FRIENDS] select _friendsThere);};
    } else {
        _state set [1, -1];
    };
    if (_held) exitWith {[_group, _handle, _token, _wpIndex, _curatorOwner, "objective held", _pos, _radius, _startTime] call _fnc_end;};

    // a tactic this task started (the attack plan, fire and movement or the building sweep) ~ let it work
    private _executing = _group getVariable [QEGVAR(danger,isExecutingTactic), false];
    if (_executing && {_phase isEqualTo "engage"}) exitWith {};
    if (_executing) then {
        // something else grabbed the group ~ take it back
        _group setVariable [QEGVAR(danger,isExecutingTactic), nil];
    };

    // the attack ran its course ~ completed means hold here and only go again on a new contact; failed twice means give up
    if (_phase isEqualTo "engage") then {
        private _picture = [_group] call EFUNC(danger,pictureGet);
        if ((_picture get "lastResult") isEqualTo "completed") then {
            // done here ~ hold if this was the objective, otherwise the fight was on the way: carry on
            _state set [0, ["approach", "hold"] select (_distance < _radius + 50)];
        } else {
            _state set [0, "approach"];
            _state set [2, (_state param [2, 0]) + 1];
        };
    };
    if ((_state param [2, 0]) >= MAX_ATTEMPTS) exitWith {[_group, _handle, _token, _wpIndex, _curatorOwner, "attack failed", _pos, _radius, _startTime] call _fnc_end;};
    if (_phase isEqualTo "hold" && {_nearestContact isEqualTo []}) exitWith {};

    // fight forward when close to the objective, or when the enemy is close to us ~ a deliberate attack
    // (support by fire, flank approach, assault, clear, consolidate); a fire team bounds instead
    if (_distance < ENGAGE_DISTANCE || {_nearestContactDistance < CONTACT_ENGAGE_DISTANCE}) exitWith {
        private _objective = [_pos, _nearestContact] select (_nearestContact isNotEqualTo [] && {_distance > _radius});
        _state set [0, "engage"];
        {
            _x setVariable [QEGVAR(danger,forceMove), nil];
            _x setVariable [QEGVAR(main,currentTask), "Attack (engage)", EGVAR(main,debug_functions)];
        } forEach _units;
        private _mounted = ([_leader, 400] call EFUNC(main,findGroupVehicles)) isNotEqualTo [];
        if (_mounted || {count _units >= 4 && {_distance > 120}}) then {
            [_group, _objective, 420] call EFUNC(danger,tacticsManeuver);
        } else {
            [_group, _objective] call EFUNC(danger,tacticsBound);
            [_group, "bound", _objective, 150] call EFUNC(danger,tacticsMonitor);
        };
    };

    // travel ~ keep the leader moving, everyone else follows
    if (_phase isNotEqualTo "approach") then {
        _state set [0, "approach"];
        {
            _x forceSpeed -1;
            _x setUnitPos "AUTO";
            _x doFollow _leader;
            if (_x isNotEqualTo _leader) then {_x setVariable [QEGVAR(danger,forceMove), true];};
            _x setVariable [QEGVAR(main,currentTask), "Attack (approach)", EGVAR(main,debug_functions)];
        } forEach _units;
    };
    // stragglers ~ anyone who stopped to shoot or fell far behind is told to catch up
    {
        if (_x isNotEqualTo _leader && {isNull objectParent _x} && {(currentCommand _x) isEqualTo "Suppress" || {_x distance2D _leader > 50}}) then {
            _x doWatch objNull;
            _x doFollow _leader;
        };
    } forEach _units;
    if (unitReady _leader || {((expectedDestination _leader) select 1) isEqualTo "DoNotPlan"}) then {
        _group move (_group getVariable [QGVAR(attackTravelPos), _pos]);
    };
}, CYCLE_TIME, [_group, _pos, _radius, _token, _wpIndex, _curatorOwner, ["approach", -1, 0], time]] call CBA_fnc_addPerFrameHandler;

_group setVariable [QGVAR(attackPFH), _handle];

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 taskAttack: %2 attacks %3m away", side _group, groupId _group, round (_leader distance2D _pos)] call EFUNC(main,debugLog);
};

// end
true
