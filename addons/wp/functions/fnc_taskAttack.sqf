#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Attack Position
 *        Group moves on an objective with weapons hot. Far from it the group simply
 *        travels; once close or in contact it fights forward with fire and movement
 *        (see lambs_danger_fnc_tacticsBound), sweeps the buildings on arrival and
 *        stands down when the objective is held and no enemy is known nearby.
 *
 * Arguments:
 * 0: Group performing action, either unit <OBJECT> or group <GROUP>
 * 1: Objective position <ARRAY>
 * 2: Radius of the objective, default 50 <NUMBER>
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
#define CONTACT_AGE 30
#define HOLD_TIME 30

if (canSuspend) exitWith { [FUNC(taskAttack), _this] call CBA_fnc_directCall; };

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_pos", [], [[]]],
    ["_radius", TASK_ATTACK_SIZE, [0]]
];

// sort group
if (!local _group) exitWith {false};
if (_group isEqualType objNull) then {_group = group _group;};
if (_pos isEqualTo []) exitWith {false};
_pos = _pos call CBA_fnc_getPos;

// task lifecycle
private _token = [_group, "taskAttack"] call FUNC(taskBegin);

// orders ~ autonomous LAMBS tactics are off, the task decides when to fight forward
_group setVariable [QEGVAR(danger,disableGroupAI), true, true];
_group setBehaviour "AWARE";
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_group setFormation "WEDGE";
_group enableAttack false;
_group setVariable [QEGVAR(main,groupMemory), []];
{
    _x setVariable [QEGVAR(danger,forceMove), nil];
    _x setUnitPos "AUTO";
    _x forceSpeed -1;
} forEach (units _group);

// go
[_group] call CBA_fnc_clearWaypoints;
_group move _pos;
[leader _group, "combat", "Advance", 125] call EFUNC(main,doCallout);

private _handle = [{
    params ["_args", "_handle"];
    _args params ["_group", "_pos", "_radius", "_token", "_state"];
    _state params ["_phase", "_heldSince"];

    private _fnc_end = {
        params ["_group", "_handle", "_token", "_reason"];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (isNull _group) exitWith {};
        _group setVariable [QGVAR(attackPFH), nil];
        if (EGVAR(main,debug_functions)) then {
            ["%1 taskAttack: %2 %3", side _group, groupId _group, _reason] call EFUNC(main,debugLog);
        };
        if (!([_group, _token] call FUNC(taskIsCancelled))) then {[_group] call FUNC(taskCleanup);};
    };

    // cancelled, taken over by a Zeus, or nobody left
    if ([_group, _token] call FUNC(taskIsCancelled) || {_group call EFUNC(main,isDirected)}) exitWith {[_group, _handle, _token, "cancelled"] call _fnc_end;};
    private _units = (units _group) select {_x call EFUNC(main,isAlive) && {!isPlayer _x}};
    if (_units isEqualTo []) exitWith {[_group, _handle, _token, "no units left"] call _fnc_end;};

    private _leader = leader _group;
    if (!(_leader call EFUNC(main,isAlive))) then {
        _leader = _units select 0;
        _group selectLeader _leader;
    };
    private _distance = _leader distance2D _pos;

    // what do we know
    private _contacts = [_group, CONTACT_AGE] call EFUNC(danger,pictureContacts);
    _contacts = _contacts select {(_x select 1) distance2D _pos < _radius + ENGAGE_DISTANCE};
    private _nearestContact = [];
    if (_contacts isNotEqualTo []) then {
        _contacts = _contacts apply {[_leader distance2D (_x select 1), _x select 1]};
        _contacts sort true;
        _nearestContact = (_contacts select 0) select 1;
    };

    // objective held ~ on it, and nothing known around it for a while
    private _held = false;
    if (_distance < _radius && {_nearestContact isEqualTo []}) then {
        if (_heldSince < 0) then {_state set [1, time];} else {_held = time - _heldSince > HOLD_TIME;};
    } else {
        _state set [1, -1];
    };
    if (_held) exitWith {[_group, _handle, _token, "objective held"] call _fnc_end;};

    // a tactic is running (fire and movement or the building sweep) ~ let it work
    if (_group getVariable [QEGVAR(danger,isExecutingTactic), false]) exitWith {};

    // fight forward when in contact or close
    if (_nearestContact isNotEqualTo [] || {_distance < ENGAGE_DISTANCE}) exitWith {
        private _objective = [_pos, _nearestContact] select (_nearestContact isNotEqualTo [] && {_distance > _radius});
        _state set [0, "engage"];
        [_group, _objective] call EFUNC(danger,tacticsBound);
        [_group, "bound", _objective, 150] call EFUNC(danger,tacticsMonitor);
    };

    // travel ~ keep the leader moving
    _state set [0, "approach"];
    if (unitReady _leader || {((expectedDestination _leader) select 1) isEqualTo "DoNotPlan"}) then {
        _group move _pos;
    };
}, CYCLE_TIME, [_group, _pos, _radius, _token, ["approach", -1]]] call CBA_fnc_addPerFrameHandler;

_group setVariable [QGVAR(attackPFH), _handle];

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 taskAttack: %2 attacks %3m away", side _group, groupId _group, round ((leader _group) distance2D _pos)] call EFUNC(main,debugLog);
};

// end
true
