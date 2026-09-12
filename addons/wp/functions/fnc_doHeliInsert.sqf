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
#define MAX_DOWN_FINAL 1
#define MAX_UP 4
#define LOW_HEIGHT 12
#define FINAL_HEIGHT 4
#define TRANSIT_HEIGHT 18
#define SMOOTHING 0.15
#define HOLD_HEIGHT 0.3
#define LANDED_HEIGHT 1.2
#define LANDED_SPEED 1.5
#define UNLOAD_TIME 20
#define HOLD_AFTER_UNLOAD 10
#define EGRESS_INTERVAL 0.7
#define EGRESS_ANIMATION_TIME 3
#define SECURITY_RING 20
#define SECURITY_RUN_TIMEOUT 12
#define TIMEOUT 90
#define LEAN 0.02

params [["_heli", objNull, [objNull]], ["_lz", [], [[]]], ["_troops", [], [[]]], ["_exit", [], [[]]], ["_onDone", {}, [{}]]];

if (isNull _heli || {!alive _heli} || {_lz isEqualTo []} || {!local _heli}) exitWith {false};
// one set of hands on the controls at a time
if (!isNil {_heli getVariable QGVAR(heliInsert)}) exitWith {false};
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

    // controller ~ where we are, where we want to be: over the spot at skid height
    private _pos = getPosATL _heli;
    private _height = _pos select 2;
    private _touching = isTouchingGround _heli;
    private _error = [(_lz select 0) - (_pos select 0), (_lz select 1) - (_pos select 1), HOLD_HEIGHT - _height];
    private _horizontal = [_error select 0, _error select 1, 0];
    private _distance = vectorMagnitude _horizontal;
    private _desired = if (_distance > 0.1) then {(vectorNormalized _horizontal) vectorMultiply ((_distance * GAIN) min MAX_HORIZONTAL)} else {[0, 0, 0]};
    // descent: fast high up, gentle under 12 m, a crawl for the last metres, nothing once the skids touch
    private _maxDown = switch (true) do {
        case (_touching): {0};
        case (_height < FINAL_HEIGHT): {MAX_DOWN_FINAL};
        case (_height < LOW_HEIGHT): {MAX_DOWN_LOW};
        default {MAX_DOWN};
    };
    // come down only once nearly over the spot, otherwise hold the transit height
    private _verticalError = if (_distance > 25 && {_height < TRANSIT_HEIGHT}) then {TRANSIT_HEIGHT - _height} else {_error select 2};
    _desired set [2, (((_verticalError * GAIN_VERTICAL) max -_maxDown) min MAX_UP)];
    if (_touching) then {_desired set [2, 0];};
    private _velocity = _state param [3, velocity _heli];
    private _new = (_velocity vectorMultiply (1 - SMOOTHING)) vectorAdd (_desired vectorMultiply SMOOTHING);
    _state set [3, _new];

    // attitude ~ level, a slight lean into the motion, heading kept
    private _dir = vectorDir _heli;
    _dir set [2, 0];
    if (vectorMagnitude _dir < 0.1) then {_dir = [0, 1, 0];};
    _dir = vectorNormalized _dir;
    private _up = vectorNormalized ([0, 0, 1] vectorAdd ([_new select 0, _new select 1, 0] vectorMultiply LEAN));

    // fly it kinematically ~ the helicopter's own hover logic cancels plain velocity changes
    private _posASL = getPosASL _heli;
    private _step = _new vectorMultiply diag_deltaTime;
    _heli setVelocityTransformation [_posASL, _posASL vectorAdd _step, _new, _new, _dir, _dir, _up, _up, 1];

    // a line every couple of seconds so the RPT shows what the controller is doing
    if (EGVAR(main,debug_functions) && {time > (_state param [4, 0])}) then {
        _state set [4, time + 2];
        ["heli insert: %1 %2 ~ %3m out, %4m up, %5 m/s", typeOf _heli, _phase, round _distance, round (_pos select 2), round (vectorMagnitude _new)] call EFUNC(main,debugLog);
    };

    switch (_phase) do {
        case "descend": {
            // gear down for the last part
            if (_height < LOW_HEIGHT * 2 && {!(_state param [5, false])}) then {
                _state set [5, true];
                _heli action ["LandGear", _heli];
            };
            if (_distance < 4 && {_touching || {_height < LANDED_HEIGHT}} && {vectorMagnitude _new < LANDED_SPEED + 1}) then {
                _state set [0, "unload"];
                _state set [2, time];
                if (EGVAR(main,debug_functions)) then {["heli insert: %1 down on the LZ after %2s, unloading", typeOf _heli, round (time - _startTime)] call EFUNC(main,debugLog);};
                [selectRandom _troops, "combat", "Dismount"] call EFUNC(main,doCallout);
                // out one after another through the doors, each man runs 20 m to his slot on the ring around the
                // aircraft, drops prone and watches outward ~ 360 security while the rest get off
                private _count = count _troops;
                private _heading = getDir _heli;
                {
                    private _unit = _x;
                    private _bearing = _heading + 90 + (_forEachIndex * (360 / (_count max 1)));
                    private _slot = _lz getPos [SECURITY_RING, _bearing];
                    [
                        {
                            params ["_unit", "_heli", "_slot", "_bearing"];
                            if (!alive _unit) exitWith {};
                            // off the seat list first, or the aircraft will land to collect him again later
                            unassignVehicle _unit;
                            [_unit] allowGetIn false;
                            if ((vehicle _unit) isEqualTo _heli) then {_unit action ["GetOut", _heli];};
                            _unit setVariable [QEGVAR(main,currentTask), "Getting off", EGVAR(main,debug_functions)];
                            // the moment he is out he runs for his slot; if the animation did not get him out, he is put out
                            [
                                {params ["_unit", "_heli"]; !alive _unit || {(vehicle _unit) isNotEqualTo _heli}},
                                {
                                    params ["_unit", "_heli", "_slot", "_bearing"];
                                    if (!alive _unit) exitWith {};
                                    if ((vehicle _unit) isEqualTo _heli) then {unassignVehicle _unit; moveOut _unit;};
                                    [_unit] allowGetIn false;
                                    _unit setVariable [QEGVAR(danger,forceMove), true];
                                    _unit setUnitPos "UP";
                                    _unit forceSpeed -1;
                                    _unit doMove _slot;
                                    _unit setVariable [QEGVAR(main,currentTask), "Running to the ring", EGVAR(main,debug_functions)];
                                    [
                                        {params ["_unit", "_slot"]; !alive _unit || {_unit distance2D _slot < 3} || {unitReady _unit}},
                                        {
                                            params ["_unit", "_slot", "_bearing"];
                                            if (!alive _unit) exitWith {};
                                            _unit setUnitPos "DOWN";
                                            _unit doWatch (_slot getPos [60, _bearing]);
                                            _unit setVariable [QEGVAR(main,currentTask), "Security", EGVAR(main,debug_functions)];
                                        },
                                        [_unit, _slot, _bearing],
                                        SECURITY_RUN_TIMEOUT
                                    ] call CBA_fnc_waitUntilAndExecute;
                                },
                                [_unit, _heli, _slot, _bearing],
                                EGRESS_ANIMATION_TIME
                            ] call CBA_fnc_waitUntilAndExecute;
                        },
                        [_unit, _heli, _slot, _bearing],
                        _forEachIndex * EGRESS_INTERVAL
                    ] call CBA_fnc_waitAndExecute;
                } forEach _troops;
            };
        };
        case "unload": {
            private _allOut = (_troops findIf {alive _x && {(vehicle _x) isEqualTo _heli}}) isEqualTo -1;
            private _unloadTime = UNLOAD_TIME + ((count _troops) * EGRESS_INTERVAL);
            // everybody out: the aircraft sits a while longer with the ring around it before it lifts
            if (_allOut && {(_state param [6, -1]) < 0}) then {
                _state set [6, time];
                if (EGVAR(main,debug_functions)) then {["heli insert: %1 all %2 troops out after %3s, holding %4s", typeOf _heli, count _troops, round (time - _unloadSince), HOLD_AFTER_UNLOAD] call EFUNC(main,debugLog);};
            };
            private _heldLongEnough = (_state param [6, -1]) >= 0 && {time - (_state param [6, -1]) > HOLD_AFTER_UNLOAD};
            if (_heldLongEnough || {time - _unloadSince > _unloadTime}) then {
                {if (alive _x && {(vehicle _x) isEqualTo _heli}) then {unassignVehicle _x; moveOut _x; [_x] allowGetIn false;};} forEach _troops;
                [_heli, _exit, false, _troops, _onDone, _handle, "troops out"] call _fnc_release;
            };
        };
    };
}, 0, [_heli, _lz, _troops, _exit, _onDone, ["descend", time, -1, velocity _heli, 0, false, -1]]] call CBA_fnc_addPerFrameHandler;

true
