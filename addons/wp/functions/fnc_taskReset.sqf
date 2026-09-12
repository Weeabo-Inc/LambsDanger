#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Zeus module which resets units, cancelling garrisons, waypoints an all animation phases
 *
 * Arguments:
 * 0: Group performing action, either unit <OBJECT> or group <GROUP>
 * 1: Soft reset where group variable name is not replaced <BOOL>
 * 2: Reset waypoints in soft reset mode <BOOL>
 *
 * Return Value:
 * new group
 *
 * Example:
 * [bob] call lambs_wp_fnc_taskReset;
 *
 * Public: Yes
*/

// init
params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_softReset", false, [true]],
    ["_resetWaypoints", false, [true]]
];

// sort group
if (!local _group) exitWith { _group };
if (_group isEqualType objNull) then { _group = group _group; };

// stop running tasks and undo what they changed
[_group] call FUNC(taskCleanup);

// stop a Zeus directed move
if (_group call EFUNC(main,isDirected)) then {
    [_group, "reset"] call EFUNC(danger,directedMoveRelease);
};

// units
private _units = units _group select {!isPlayer _x};

// remove all current waypoints
if (_resetWaypoints) then {[_group] call CBA_fnc_clearWaypoints;};

// remove LAMBS group variables
_group setVariable [QEGVAR(danger,disableGroupAI), nil, true];
_group setVariable [QEGVAR(danger,enableGroupReinforce), nil, true];
_group setVariable [QEGVAR(danger,enableGroupReinforceTime), nil, true];
_group setVariable [QEGVAR(danger,isExecutingTactic), nil];
_group setVariable [QEGVAR(danger,contact), nil];
_group setVariable [QEGVAR(danger,inCQB), nil];
_group setVariable [QEGVAR(main,groupMemory), []];
_group setVariable [QGVAR(taskAssaultDestination), nil, true];
_group setVariable [QGVAR(taskAssaultMembers), nil, true];

// group orders
_group enableAttack true;

// reset
private _leader = leader _group;
{
    // check move
    _x doMove (getPosASL _x);

    // AI states
    _x enableAI "MOVE";
    _x enableAI "PATH";
    _x enableAI "COVER";
    _x enableAI "SUPPRESSION";
    _x enableAI "FSM";
    _x enableAI "TARGET";
    _x enableAI "AUTOTARGET";
    _x enableAI "AUTOCOMBAT";
    _x enableAI "WEAPONAIM";
    _x enableAI "FIREWEAPON";

    // speed and stance
    _x forceSpeed -1;
    _x setUnitPos "AUTO";
    _x setUnitPosWeak "AUTO";
    _x allowGetIn true;

    // reset animations
    _x enableAI "ANIM";
    if (isNull objectParent _x && {_x call EFUNC(main,isAlive)}) then {
        [_x, "" , 2] call EFUNC(main,doAnimation);
        _x playMove (["AmovPercMstpSlowWrflDnon", "AmovPercMstpSnonWnonDnon"] select ((primaryWeapon _x) isEqualTo ""));
    };

    // LAMBS variables
    _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
    _x setVariable [QEGVAR(main,currentTarget), nil, EGVAR(main,debug_functions)];
    _x setVariable [QEGVAR(danger,disableAI), nil, true];
    _x setVariable [QEGVAR(danger,forceMove), nil, true];
    _x setVariable [QGVAR(disabledAI), nil];
    _x setVariable [QGVAR(setDisableAI), nil];
    _x setVariable [QGVAR(taskAssault), nil];

    // LAMBS eventhandlers
    [_x, _x getVariable [QGVAR(eventhandlers), []]] call EFUNC(main,removeEventhandlers);
    _x setVariable [QGVAR(eventhandlers), nil];

    // rejoin
    _x doFollow _leader;
} forEach _units;

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 taskReset: %2 reset (%3)", side _group, groupId _group, ["hard", "soft"] select _softReset] call EFUNC(main,debugLog);
};

// exit on soft reset
if (_softReset) exitWith {
    _units joinSilent _group;
    _group
};

// make new group + adopt name
private _groupNew = createGroup [side _group, true];
_groupNew setGroupIdGlobal [groupId _group];
_groupNew setFormation (formation _group);

// rejoin group
_units joinSilent _groupNew;

if (dynamicSimulationEnabled _group) then {
    [_groupNew, true] remoteExecCall ["enableDynamicSimulation", 2];
};

// reset move and behaviour
_groupNew setBehaviour "AWARE";

// mark old gorup for deletion
_group deleteGroupWhenEmpty true;

// end
_groupNew
