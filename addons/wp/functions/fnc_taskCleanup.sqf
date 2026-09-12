#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Stops every running waypoint task of a group and undoes the state those tasks changed:
 * AI features they disabled, eventhandlers they added, forced speed and stance, and the
 * group settings snapshotted by taskBegin. Safe to call on a group without a task.
 *
 * Arguments:
 * 0: Group to clean up <GROUP>
 * 1: Restore the group snapshot taken by taskBegin, default true <BOOL>
 *
 * Return Value:
 * true when a task was active <BOOL>
 *
 * Example:
 * [group bob] call lambs_wp_fnc_taskCleanup;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull]], ["_restoreSnapshot", true, [false]]];

if (isNull _group || {!local _group}) exitWith {false};

// stop loops ~ a new token makes every taskIsCancelled check of this group true
private _wasActive = !isNil {_group getVariable QGVAR(taskSnapshot)};
_group setVariable [QGVAR(taskToken), (_group getVariable [QGVAR(taskToken), 0]) + 1];

// per frame handlers
private _pfh = _group getVariable [QGVAR(defendPFH), -1];
if (_pfh isNotEqualTo -1) then {
    [_pfh] call CBA_fnc_removePerFrameHandler;
    _group setVariable [QGVAR(defendPFH), nil];
};

// units
private _leader = leader _group;
{
    private _unit = _x;

    // AI features disabled by a task
    private _disabledAI = _unit getVariable [QGVAR(disabledAI), []];
    {
        _unit enableAI _x;
    } forEach _disabledAI;
    if ("ANIM" in _disabledAI && {isNull objectParent _unit} && {_unit call EFUNC(main,isAlive)}) then {
        [_unit, "", 2] call EFUNC(main,doAnimation);
    };
    _unit setVariable [QGVAR(disabledAI), nil];

    // eventhandlers added by a task
    [_unit, _unit getVariable [QGVAR(eventhandlers), []]] call EFUNC(main,removeEventhandlers);
    _unit setVariable [QGVAR(eventhandlers), nil];

    // movement ~ the per-soldier machine lets go first
    [_unit, false] call EFUNC(danger,unitRelease);
    _unit forceSpeed -1;
    _unit setUnitPos "AUTO";
    [_unit] allowGetIn true;
    _unit setVariable [QEGVAR(danger,forceMove), nil];
    _unit setVariable [QGVAR(taskAssault), nil];

    // danger FSM ~ only undo what a task switched off
    if (_unit getVariable [QGVAR(setDisableAI), false]) then {
        _unit setVariable [QEGVAR(danger,disableAI), nil, true];
        _unit setVariable [QGVAR(setDisableAI), nil];
    };

    // variables
    _unit setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];

    // rejoin formation
    _unit doFollow _leader;
} forEach ((units _group) select {!isPlayer _x});

// group
_group setVariable [QGVAR(taskAssaultDestination), nil];
_group setVariable [QGVAR(taskAssaultMembers), nil];
_group setVariable [QEGVAR(main,currentTactic), nil, EGVAR(main,debug_functions)];

// restore snapshot
private _snapshot = _group getVariable [QGVAR(taskSnapshot), []];
if (_restoreSnapshot && {_snapshot isNotEqualTo []}) then {
    _snapshot params ["_attackEnabled", "_speedMode", "_formation", "_behaviour", "_combatMode", "_disableGroupAI"];
    _group enableAttack _attackEnabled;
    _group setSpeedMode _speedMode;
    _group setFormation _formation;
    _group setBehaviour _behaviour;
    _group setCombatMode _combatMode;
    if (_disableGroupAI) then {
        _group setVariable [QEGVAR(danger,disableGroupAI), true, true];
    } else {
        _group setVariable [QEGVAR(danger,disableGroupAI), nil, true];
    };
};
_group setVariable [QGVAR(taskSnapshot), nil];

// debug
if (EGVAR(main,debug_functions) && {_wasActive}) then {
    ["%1 taskCleanup: %2 tasks stopped", side _group, groupId _group] call EFUNC(main,debugLog);
};

// end
_wasActive
