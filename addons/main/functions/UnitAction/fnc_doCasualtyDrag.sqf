#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Casualty drill with ACE: the buddy throws smoke towards the enemy, runs to the man
 * down, drags him into the nearest cover that is out of the enemy's sight, drops him
 * there, goes prone beside him and calls for the medic. Marked for the duration so
 * the group's manoeuvres leave him alone. Does nothing without ACE dragging.
 *
 * Arguments:
 * 0: Rescuer <OBJECT>
 * 1: Casualty (alive, incapacitated) <OBJECT>
 * 2: Threat position AGL, [] for unknown <ARRAY>
 *
 * Return Value:
 * started <BOOL>
 *
 * Example:
 * [bob, joe, getPos angryJoe] call lambs_main_fnc_doCasualtyDrag;
 *
 * Public: No
*/
#define REACH_TIME 15
#define DRAG_TIME 25
#define MARK_TIME 45
#define COVER_RADIUS 25
#define MIN_DRAG 6
#define SMOKE_RANGE 200

params [["_rescuer", objNull, [objNull]], ["_casualty", objNull, [objNull]], ["_threatPos", [], [[]]]];

if (
    isNil "ace_dragging_fnc_startDrag"
    || {isNull _rescuer} || {isNull _casualty} || {!local _rescuer} || {isPlayer _rescuer}
    || {!(_rescuer call FUNC(isAlive))} || {!isNull objectParent _rescuer}
    || {!alive _casualty} || {(lifeState _casualty) isNotEqualTo "INCAPACITATED"} || {!isNull objectParent _casualty}
) exitWith {false};

// one rescuer per man down
_casualty setVariable [QGVAR(rescuer), [_rescuer, time + MARK_TIME]];
_rescuer setVariable [QGVAR(survival), time + MARK_TIME];
_rescuer setVariable [QEGVAR(danger,forceMove), true];
_rescuer setVariable [QGVAR(currentTask), "Casualty! moving to him", GVAR(debug_functions)];
_rescuer setVariable [QGVAR(currentTarget), _casualty, GVAR(debug_functions)];

// where he goes: out of the enemy's sight, at least a few metres from where he fell
if (_threatPos isEqualTo []) then {_threatPos = (getPosATL _casualty) getPos [50, getDir _casualty];};
private _spots = [getPosATL _casualty, _threatPos, 1, false, COVER_RADIUS] call FUNC(findDismountCover);
private _cover = if (_spots isNotEqualTo []) then {(_spots select 0) select 0} else {(getPosATL _casualty) getPos [10, _threatPos getDir _casualty]};
if (_cover distance2D _casualty < MIN_DRAG) then {_cover = (getPosATL _casualty) getPos [MIN_DRAG + 2, _threatPos getDir _casualty];};

// smoke between him and the guns, then go
if (_rescuer distance2D _threatPos < SMOKE_RANGE) then {[_rescuer, _threatPos] call FUNC(doSmoke);};
[_rescuer, "combat", "mandown", 80] call FUNC(doCallout);
_rescuer disableAI "AUTOTARGET";
_rescuer disableAI "TARGET";
_rescuer setUnitPos "UP";
_rescuer forceSpeed -1;
_rescuer doMove (getPosATL _casualty);

[
    {
        params ["_rescuer", "_casualty"];
        !(_rescuer call FUNC(isAlive)) || {!alive _casualty} || {(lifeState _casualty) isNotEqualTo "INCAPACITATED"} || {_rescuer distance2D _casualty < 2.5}
    },
    {
        params ["_rescuer", "_casualty", "_cover", "_threatPos"];
        private _fnc_done = {
            params ["_rescuer", "_casualty", "_threatPos"];
            if (!(_rescuer call FUNC(isAlive))) exitWith {};
            _rescuer enableAI "AUTOTARGET";
            _rescuer enableAI "TARGET";
            _rescuer setUnitPos "DOWN";
            _rescuer doWatch _threatPos;
            _rescuer setVariable [QGVAR(currentTask), "With the casualty", GVAR(debug_functions)];
            _rescuer setVariable [QGVAR(survival), time + 10];
            if (alive _casualty && {!isNil "ace_medical_ai_fnc_requestMedic"}) then {_casualty call ace_medical_ai_fnc_requestMedic;};
        };
        if (!(_rescuer call FUNC(isAlive)) || {!alive _casualty} || {(lifeState _casualty) isNotEqualTo "INCAPACITATED"}) exitWith {[_rescuer, _casualty, _threatPos] call _fnc_done;};

        // pick him up and drag
        [_casualty, true] call ace_dragging_fnc_setDraggable;
        if ([_rescuer, _casualty] call ace_dragging_fnc_canDrag) then {
            [_rescuer, _casualty] call ace_dragging_fnc_startDrag;
            _rescuer setVariable [QGVAR(currentTask), "Dragging him to cover", GVAR(debug_functions)];
            [
                {
                    params ["_rescuer", "_casualty", "_cover"];
                    !(_rescuer call FUNC(isAlive)) || {!alive _casualty} || {_rescuer distance2D _cover < 2.5} || {isNull (_rescuer getVariable ["ace_dragging_draggedObject", objNull])}
                },
                {
                    params ["_rescuer", "_casualty", "", "_threatPos"];
                    if (_rescuer call FUNC(isAlive) && {!isNull (_rescuer getVariable ["ace_dragging_draggedObject", objNull])}) then {
                        [_rescuer, _casualty] call ace_dragging_fnc_dropObject;
                    };
                    [_rescuer, _casualty, _threatPos] call _fnc_done;
                },
                [_rescuer, _casualty, _cover, _threatPos],
                DRAG_TIME,
                {
                    params ["_rescuer", "_casualty", "", "_threatPos"];
                    if (_rescuer call FUNC(isAlive) && {!isNull (_rescuer getVariable ["ace_dragging_draggedObject", objNull])}) then {
                        [_rescuer, _casualty] call ace_dragging_fnc_dropObject;
                    };
                    [_rescuer, _casualty, _threatPos] call _fnc_done;
                }
            ] call CBA_fnc_waitUntilAndExecute;
            // the dragger walks; the drag animation follows his movement
            [{params ["_rescuer", "_cover"]; if (_rescuer call FUNC(isAlive)) then {_rescuer doMove _cover;};}, [_rescuer, _cover], 1.5] call CBA_fnc_waitAndExecute;
        } else {
            [_rescuer, _casualty, _threatPos] call _fnc_done;
        };
    },
    [_rescuer, _casualty, _cover, _threatPos],
    REACH_TIME,
    {
        params ["_rescuer", "_casualty", "", "_threatPos"];
        if (_rescuer call FUNC(isAlive)) then {
            _rescuer enableAI "AUTOTARGET";
            _rescuer enableAI "TARGET";
            _rescuer setUnitPos "DOWN";
            _rescuer doWatch _threatPos;
            _rescuer setVariable [QGVAR(survival), time + 5];
        };
    }
] call CBA_fnc_waitUntilAndExecute;

if (GVAR(debug_functions)) then {["%1 %2 goes for %3 (casualty), cover %4m away", side _rescuer, name _rescuer, name _casualty, round (_cover distance2D _casualty)] call FUNC(debugLog);};

true
