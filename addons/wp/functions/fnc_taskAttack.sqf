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
#define ENGAGE_DISTANCE 250
#define CONTACT_ENGAGE_DISTANCE 200
#define CONTACT_AGE 30
#define HOLD_TIME 30

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

// go ~ a Zeus route is kept, the attack waypoint on it points at the same spot
if (_wpIndex < 0) then {[_group] call CBA_fnc_clearWaypoints;};
_group move _pos;
[_leader, "combat", "Advance", 125] call EFUNC(main,doCallout);

private _handle = [{
    params ["_args", "_handle"];
    _args params ["_group", "_pos", "_radius", "_token", "_wpIndex", "_curatorOwner", "_state"];
    _state params ["_phase", "_heldSince"];

    private _fnc_end = {
        params ["_group", "_handle", "_token", "_wpIndex", "_curatorOwner", "_reason", "_pos", "_radius"];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (isNull _group) exitWith {};
        _group setVariable [QGVAR(attackPFH), nil];
        _group setVariable [QGVAR(attackWaypoint), nil];
        if (EGVAR(main,debug_functions)) then {
            ["%1 taskAttack: %2 %3", side _group, groupId _group, _reason] call EFUNC(main,debugLog);
        };
        if ([_group, _token] call FUNC(taskIsCancelled)) exitWith {};
        [_group] call FUNC(taskCleanup);

        // the objective is now the group's ground
        [_group, ["free", "defend"] select (_reason isEqualTo "objective held"), _pos, _radius] call EFUNC(danger,intentSet);

        // carry on with the route the Zeus laid out
        if (_wpIndex >= 0 && {_wpIndex + 1 < count (waypoints _group)}) then {
            _group setCurrentWaypoint [_group, _wpIndex + 1];
        };
        if (_curatorOwner >= 0) then {
            [_curatorOwner, format [localize ELSTRING(danger,Feedback_AttackDone), groupId _group]] call EFUNC(danger,directedMoveFeedback);
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

    // objective held ~ on it, and nothing known around it for a while
    private _held = false;
    if (_distance < _radius && {_nearestContact isEqualTo []}) then {
        if (_heldSince < 0) then {_state set [1, time];} else {_held = time - _heldSince > HOLD_TIME;};
    } else {
        _state set [1, -1];
    };
    if (_held) exitWith {[_group, _handle, _token, _wpIndex, _curatorOwner, "objective held", _pos, _radius] call _fnc_end;};

    // a tactic this task started (fire and movement or the building sweep) ~ let it work
    private _executing = _group getVariable [QEGVAR(danger,isExecutingTactic), false];
    if (_executing && {_phase isEqualTo "engage"}) exitWith {};
    if (_executing) then {
        // something else grabbed the group ~ take it back
        _group setVariable [QEGVAR(danger,isExecutingTactic), nil];
    };

    // fight forward when close to the objective, or when the enemy is close to us
    if (_distance < ENGAGE_DISTANCE || {_nearestContactDistance < CONTACT_ENGAGE_DISTANCE}) exitWith {
        private _objective = [_pos, _nearestContact] select (_nearestContact isNotEqualTo [] && {_distance > _radius});
        _state set [0, "engage"];
        {_x setVariable [QEGVAR(main,currentTask), "Attack (engage)", EGVAR(main,debug_functions)];} forEach _units;
        [_group, _objective] call EFUNC(danger,tacticsBound);
        [_group, "bound", _objective, 150] call EFUNC(danger,tacticsMonitor);
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
        if (_x isNotEqualTo _leader && {(currentCommand _x) isEqualTo "Suppress" || {_x distance2D _leader > 50}}) then {
            _x doWatch objNull;
            _x doFollow _leader;
        };
    } forEach _units;
    if (unitReady _leader || {((expectedDestination _leader) select 1) isEqualTo "DoNotPlan"}) then {
        _group move _pos;
    };
}, CYCLE_TIME, [_group, _pos, _radius, _token, _wpIndex, _curatorOwner, ["approach", -1]]] call CBA_fnc_addPerFrameHandler;

_group setVariable [QGVAR(attackPFH), _handle];

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 taskAttack: %2 attacks %3m away", side _group, groupId _group, round (_leader distance2D _pos)] call EFUNC(main,debugLog);
};

// end
true
