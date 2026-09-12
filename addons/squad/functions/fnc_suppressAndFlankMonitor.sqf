#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Monitor of suppress and flank: turns the manoeuvre element in on the enemy once it
 * holds the flank point, notices the hand-over to the building assault, and ends the
 * tactic when the element is gone, stalled, or on the objective.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Context <HASHMAP>
 * 2: Tactic state <HASHMAP>
 *
 * Return Value:
 * "running", "done" or "failed" <STRING>
 *
 * Example:
 * called by hostis_squad_fnc_tacticMonitor
 *
 * Public: No
*/
#define FLANK_REACHED 30
#define STALL_TIME 60
#define PROGRESS_STEP 8

params [["_group", grpNull, [grpNull]], ["_ctx", createHashMap, [createHashMap]], ["_state", createHashMap, [createHashMap]]];

private _data = _state get "data";
private _maneuver = (_data get "maneuver") select {_x call LFUNC(main,isAlive) && {isNull objectParent _x}};
private _base = (_data get "base") select {_x call LFUNC(main,isAlive)};
if (_maneuver isEqualTo []) exitWith {"failed"};
_data set ["maneuver", _maneuver];
_data set ["base", _base];

private _threatPos = _ctx get "threatPos";
if (_threatPos isEqualTo []) then {_threatPos = _state get "objective";};
private _phase = _data get "phase";
private _target = [_data get "flankPoint", _threatPos] select (_phase isEqualTo "assault");

// where the element is
private _centre = [0, 0, 0];
{_centre = _centre vectorAdd (getPosATL _x);} forEach _maneuver;
_centre = _centre vectorMultiply (1 / (count _maneuver));
private _distance = _centre distance2D _target;
private _nearest = 1e9;
{_nearest = _nearest min (_x distance2D _threatPos);} forEach _maneuver;

// the bound handed the men to the building assault: it keeps them, we are done
if (_nearest < (_ctx get "cqbRange")) exitWith {
    _data set ["handedOver", true];
    "done"
};

// on the flank point: turn in
if (_phase isEqualTo "approach" && {_distance < FLANK_REACHED}) exitWith {
    _data set ["phase", "assault"];
    _data set ["lastDistance", 1e9];
    _data set ["lastProgress", time];
    private _token = time + random 1;
    _data set ["token", _token];
    _group setVariable [QLGVAR(danger,boundToken), _token];
    private _posList = _data get "posList";
    [{_this call LFUNC(main,doGroupBound)}, [_group, _base, _maneuver, _posList, _threatPos, 0, 0, [], _data get "vehicles", _token, true], 0.5] call CBA_fnc_waitAndExecute;
    [_maneuver select 0, "attack", true] call EFUNC(agent,bark);
    if (SQUAD_DEBUG) then {["%1 TACTIC %2: on the flank, turning in (%3 m)", side _group, groupId _group, round (_centre distance2D _threatPos)] call LFUNC(main,debugLog);};
    "running"
};

// progress toward the current target
if (_distance < (_data get "lastDistance") - PROGRESS_STEP) then {
    _data set ["lastDistance", _distance];
    _data set ["lastProgress", time];
} else {
    if (time - (_data get "lastProgress") > STALL_TIME) exitWith {
        if (SQUAD_DEBUG) then {["%1 TACTIC %2: manoeuvre element stalled %3 m from %4", side _group, groupId _group, round _distance, _phase] call LFUNC(main,debugLog);};
        "failed"
    };
};

"running"
