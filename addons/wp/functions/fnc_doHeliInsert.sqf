#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Puts a helicopter down at a spot and unloads its troops without helipads or the
 * engine's landing logic: once close, the pilot's flight AI is switched off and the
 * aircraft is flown by a velocity controller every frame, levelled, straight down onto
 * the spot, held at skid height while the troops get out, then handed back to the
 * pilot with a climb-out order. Aborts and hands back if the aircraft is hit badly,
 * if the task that owns it ends, or after a timeout.
 *
 * Arguments:
 * 0: Helicopter <OBJECT>
 * 1: Landing spot AGL <ARRAY>
 * 2: Troops to unload <ARRAY>
 * 3: Position to climb out towards <ARRAY>
 * 4: Code run when the troops are out (or the insert was aborted), with [heli, troopsOut, aborted] <CODE>
 *
 * Return Value:
 * started <BOOL>
 *
 * Example:
 * [heli, getPos lz, units group bob, getPos heli, {}] call lambs_wp_fnc_doHeliInsert;
 *
 * Public: No
*/
#define GAIN 0.6
#define GAIN_VERTICAL 0.8
#define MAX_HORIZONTAL 14
#define MAX_DOWN 7
#define MAX_DOWN_LOW 2.5
#define MAX_UP 4
#define LOW_HEIGHT 12
#define SMOOTHING 0.15
#define HOLD_HEIGHT 0.8
#define APPROACH_HEIGHT 6
#define LANDED_HEIGHT 1.4
#define LANDED_SPEED 1.5
#define UNLOAD_TIME 8
#define TIMEOUT 75
#define LEAN 0.02

params [["_heli", objNull, [objNull]], ["_lz", [], [[]]], ["_troops", [], [[]]], ["_exit", [], [[]]], ["_onDone", {}, [{}]]];

if (isNull _heli || {!alive _heli} || {_lz isEqualTo []} || {!local _heli}) exitWith {false};
private _pilot = driver _heli;
if (isNull _pilot || {!alive _pilot}) exitWith {false};

// take the controls
_pilot disableAI "MOVE";
_pilot disableAI "FSM";
_heli setVariable [QGVAR(heliInsert), true];
_heli engineOn true;
_heli land "NONE";
{_x setVariable [QEGVAR(main,currentTask), "Inserting", EGVAR(main,debug_functions)];} forEach (crew _heli);
if (EGVAR(main,debug_functions)) then {
    ["%1 heli insert: %2 taking the controls %3m from the LZ, %4m up, %5 troops aboard", side _pilot, typeOf _heli, round (_heli distance2D _lz), round ((getPosATL _heli) select 2), count _troops] call EFUNC(main,debugLog);
};

[{
    params ["_args", "_handle"];
    _args params ["_heli", "_lz", "_troops", "_exit", "_onDone", "_state"];
    _state params ["_phase", "_startTime", "_unloadSince"];

    private _fnc_release = {
        params ["_heli", "_exit", "_aborted", "_troops", "_onDone", "_handle", ["_reason", ""]];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (EGVAR(main,debug_functions)) then {
            ["heli insert: %1 released (%2), %3 of %4 troops out", typeOf _heli, _reason, {alive _x && {isNull objectParent _x}} count _troops, count _troops] call EFUNC(main,debugLog);
        };
        if (alive _heli) then {
            private _pilot = driver _heli;
            if (!isNull _pilot) then {_pilot enableAI "MOVE"; _pilot enableAI "FSM";};
            _heli setVariable [QGVAR(heliInsert), nil];
            private _velocity = velocity _heli;
            _heli setVelocity [_velocity select 0, _velocity select 1, MAX_UP];
            _heli flyInHeight 80;
            if (_exit isNotEqualTo [] && {!isNull _pilot}) then {_pilot doMove _exit;};
            {_x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];} forEach (crew _heli);
        };
        [_heli, _troops select {isNull objectParent _x}, _aborted] call _onDone;
    };

    // aircraft lost, crippled, or the owner gave up on it
    private _abort = switch (true) do {
        case (!alive _heli): {"destroyed"};
        case (!canMove _heli): {"crippled"};
        case (isNull (driver _heli) || {!alive (driver _heli)}): {"pilot dead"};
        case (isNil {_heli getVariable QGVAR(heliInsert)}): {"cancelled"};
        case (time - _startTime > TIMEOUT): {"timeout"};
        default {""};
    };
    if (_abort isNotEqualTo "") exitWith {[_heli, _exit, true, _troops, _onDone, _handle, _abort] call _fnc_release;};

    // controller ~ where we are, where we want to be
    private _pos = getPosATL _heli;
    private _holdHeight = [APPROACH_HEIGHT, HOLD_HEIGHT] select (_phase isEqualTo "unload");
    private _error = [(_lz select 0) - (_pos select 0), (_lz select 1) - (_pos select 1), _holdHeight - (_pos select 2)];
    private _horizontal = [_error select 0, _error select 1, 0];
    private _distance = vectorMagnitude _horizontal;
    private _desired = if (_distance > 0.1) then {(vectorNormalized _horizontal) vectorMultiply ((_distance * GAIN) min MAX_HORIZONTAL)} else {[0, 0, 0]};
    private _maxDown = [MAX_DOWN, MAX_DOWN_LOW] select ((_pos select 2) < LOW_HEIGHT);
    // come down only once nearly over the spot, otherwise hold the approach height
    private _verticalError = if (_distance > 25 && {(_pos select 2) < APPROACH_HEIGHT * 3}) then {(APPROACH_HEIGHT * 3) - (_pos select 2)} else {_error select 2};
    _desired set [2, (((_verticalError * GAIN_VERTICAL) max -_maxDown) min MAX_UP)];
    private _velocity = velocity _heli;
    private _new = (_velocity vectorMultiply (1 - SMOOTHING)) vectorAdd (_desired vectorMultiply SMOOTHING);
    _heli setVelocity _new;

    // attitude ~ level, a slight lean into the motion, heading kept
    private _dir = vectorDir _heli;
    _dir set [2, 0];
    if (vectorMagnitude _dir < 0.1) then {_dir = [0, 1, 0];};
    private _up = vectorNormalized ([0, 0, 1] vectorAdd ([_new select 0, _new select 1, 0] vectorMultiply LEAN));
    _heli setVectorDirAndUp [vectorNormalized _dir, _up];

    switch (_phase) do {
        case "descend": {
            if (_distance < 4 && {(_pos select 2) < LANDED_HEIGHT + 1} && {vectorMagnitude _new < LANDED_SPEED + 1}) then {
                _state set [0, "unload"];
                _state set [2, time];
                if (EGVAR(main,debug_functions)) then {["heli insert: %1 down on the LZ after %2s, unloading", typeOf _heli, round (time - _startTime)] call EFUNC(main,debugLog);};
                // out ~ instantly and safely, no jumping out of a hovering aircraft
                {
                    if (alive _x && {(vehicle _x) isEqualTo _heli}) then {
                        unassignVehicle _x;
                        moveOut _x;
                        [_x] allowGetIn false;
                        _x setVariable [QEGVAR(main,currentTask), "Unloading", EGVAR(main,debug_functions)];
                    };
                } forEach _troops;
                [selectRandom _troops, "combat", "Dismount"] call EFUNC(main,doCallout);
            };
        };
        case "unload": {
            {
                if (alive _x && {(vehicle _x) isEqualTo _heli}) then {unassignVehicle _x; moveOut _x; [_x] allowGetIn false;};
            } forEach _troops;
            private _allOut = (_troops findIf {alive _x && {(vehicle _x) isEqualTo _heli}}) isEqualTo -1;
            if (_allOut || {time - _unloadSince > UNLOAD_TIME}) then {
                // troops move clear of the rotor before the aircraft lifts
                {if (alive _x && {isNull objectParent _x}) then {_x doMove (_lz getPos [20, _lz getDir _x]); _x setUnitPos "MIDDLE";};} forEach _troops;
                [_heli, _exit, false, _troops, _onDone, _handle, "troops out"] call _fnc_release;
            };
        };
    };
}, 0, [_heli, _lz, _troops, _exit, _onDone, ["descend", time, -1]]] call CBA_fnc_addPerFrameHandler;

true
