#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The air assault part of the Attack Position task, one step per task tick:
 *   plan     pick a landing zone 250-400 m short of the objective, on the group's side,
 *            out of the objective's line of sight where the ground allows, flat and empty
 *   fly      the helicopter flies itself to the LZ; a contact near the LZ before the
 *            landing moves the LZ further out once
 *   land     the scripted insert (doHeliInsert) puts it down and unloads
 *   release  the aircrew leaves the group: an armed helicopter loiters 300 m off the
 *            objective as fire support, an unarmed one returns to where it took off
 * Returns true once the infantry is on the ground and the task can carry on on foot.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Objective position AGL <ARRAY>
 * 2: Helicopters carrying the group <ARRAY>
 *
 * Return Value:
 * infantry on the ground, air assault over <BOOL>
 *
 * Example:
 * [group bob, getPos angryJoe, [heli]] call lambs_wp_fnc_taskAttackAir;
 *
 * Public: No
*/
#define LZ_MIN 250
#define LZ_MAX 400
#define LZ_STEP 50
#define LZ_ANGLES [0, 25, -25, 50, -50, 80, -80]
#define LZ_CLEARANCE 12
#define LZ_GRADIENT 0.15
#define HOT_LZ 200
#define START_INSERT 200
#define HOVER_ARRIVED 400
#define APPROACH_ALTITUDE 60
#define LIFT_DELAY 4
#define LIFT_SPEED 5
#define ENGINE_LAND_TIMEOUT 60

params [["_group", grpNull, [grpNull]], ["_pos", [], [[]]], ["_helis", [], [[]]], ["_curatorOwner", -1, [0]]];

private _fnc_feedback = {
    if (_curatorOwner >= 0) then {[_curatorOwner, _this] call EFUNC(danger,directedMoveFeedback);};
};

private _air = _group getVariable QGVAR(attackAir);
_helis = _helis select {alive _x && {canMove _x} && {alive (driver _x)}};

// plan ~ once
if (isNil "_air") then {
    if (_helis isEqualTo []) exitWith {true};
    private _heli = _helis select 0;
    private _axis = _pos getDir _heli;
    private _objectiveASL = (AGLToASL _pos) vectorAdd [0, 0, 1.5];
    private _lz = [];
    private _best = -1e9;
    for "_range" from LZ_MIN to LZ_MAX step LZ_STEP do {
        {
            private _candidate = _pos getPos [_range, _axis + _x];
            if (!surfaceIsWater _candidate && {(_candidate isFlatEmpty [LZ_CLEARANCE, -1, LZ_GRADIENT, LZ_CLEARANCE, 0, false, objNull]) isNotEqualTo []}) then {
                private _score = ([0, 4] select (terrainIntersectASL [(AGLToASL _candidate) vectorAdd [0, 0, 2], _objectiveASL])) - (abs _x / 40) - ((_range - LZ_MIN) / 100);
                if (_score > _best) then {_best = _score; _lz = _candidate;};
            };
        } forEach LZ_ANGLES;
    };
    if (_lz isEqualTo []) then {_lz = _pos getPos [LZ_MAX, _axis];};
    _lz set [2, 0];
    _air = createHashMapFromArray [
        ["phase", "fly"],
        ["heli", _heli],
        ["lz", _lz],
        ["start", getPosATL _heli],
        ["moved", false],
        ["time", time]
    ];
    _group setVariable [QGVAR(attackAir), _air];
    {
        _x engineOn true;
        _x land "NONE";
        _x flyInHeight APPROACH_ALTITUDE;
        (driver _x) doMove _lz;
        {_x setVariable [QEGVAR(main,currentTask), "Air assault (flying in)", EGVAR(main,debug_functions)];} forEach (crew _x);
    } forEach _helis;
    format [localize ELSTRING(danger,Feedback_AirAssault), groupId _group, round (_lz distance2D _pos)] call _fnc_feedback;
    if (EGVAR(main,debug_functions)) then {
        ["%1 taskAttack: %2 air assault, LZ %3m from the objective", side _group, groupId _group, round (_lz distance2D _pos)] call EFUNC(main,debugLog);
        private _marker = [_lz, "LZ", (leader _group) call EFUNC(main,debugMarkerColor), "hd_pickup"] call EFUNC(main,dotMarker);
        [{deleteMarker _this}, _marker, 300] call CBA_fnc_waitAndExecute;
    };
};

private _heli = _air get "heli";
private _lz = _air get "lz";
private _phase = _air get "phase";

// aircraft gone before the troops were out ~ whoever survived fights on foot from where they are
if (_phase in ["fly", "land"] && {!alive _heli || {!canMove _heli}}) exitWith {
    _air set ["phase", "done"];
    {[_x] allowGetIn false;} forEach (units _group);
    if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 lost its helicopter", side _group, groupId _group] call EFUNC(main,debugLog);};
    true
};

switch (_phase) do {

    case "fly": {
        // hot LZ ~ known enemy near it: push it out along the same bearing, once
        if (!(_air get "moved")) then {
            private _contacts = [_group, 30] call EFUNC(danger,pictureContacts);
            if ((_contacts findIf {(_x select 1) distance2D _lz < HOT_LZ}) isNotEqualTo -1) then {
                _lz = _lz getPos [150, _pos getDir _lz];
                _lz set [2, 0];
                _air set ["lz", _lz];
                _air set ["moved", true];
                (driver _heli) doMove _lz;
                if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 hot LZ, moving it out", side _group, groupId _group] call EFUNC(main,debugLog);};
            };
        };
        // sitting on the ground: an AI helicopter will not take off on a move order alone ~ start it and lift it
        private _grounded = isTouchingGround _heli || {(getPosATL _heli) select 2 < 2 && {speed _heli < 2}};
        if (_grounded && {_heli distance2D _lz > START_INSERT}) then {
            _heli engineOn true;
            _heli land "NONE";
            if (isEngineOn _heli && {time - (_air get "time") > LIFT_DELAY}) then {
                private _velocity = velocity _heli;
                _heli setVelocity [_velocity select 0, _velocity select 1, LIFT_SPEED];
                (driver _heli) doMove _lz;
                _heli flyInHeight APPROACH_ALTITUDE;
                if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 helicopter lifted off", side _group, groupId _group] call EFUNC(main,debugLog);};
            };
        } else {
            if (unitReady (driver _heli)) then {(driver _heli) doMove _lz;};
        };
        if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 flying in, %3m to the LZ, %4m up, %5 km/h", side _group, groupId _group, round (_heli distance2D _lz), round ((getPosATL _heli) select 2), round (speed _heli)] call EFUNC(main,debugLog);};

        // close enough, or the pilot considers himself arrived and hovers ~ take over and land
        if (_heli distance2D _lz < START_INSERT || {unitReady (driver _heli) && {_heli distance2D _lz < HOVER_ARRIVED}}) then {
            _air set ["phase", "land"];
            if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 starting the landing %3m from the LZ", side _group, groupId _group, round (_heli distance2D _lz)] call EFUNC(main,debugLog);};
            // everyone aboard who is not flying or manning a weapon gets off, whatever group they belong to
            private _aircrew = [driver _heli, gunner _heli, commander _heli] + (((fullCrew [_heli, "turret"]) select {!(_x select 4)}) apply {_x select 0});
            private _troops = (crew _heli) select {!(_x in _aircrew) && {!isPlayer _x} && {alive _x}};
            _air set ["troops", _troops];
            private _exit = _lz getPos [400, _pos getDir _lz];
            _heli setVariable [QGVAR(attackGroup), _group];
            [_heli, _lz, _troops, _exit, {
                params ["_heli"];
                if (isNull _heli) exitWith {};
                private _group = _heli getVariable [QGVAR(attackGroup), grpNull];
                if (isNull _group) exitWith {};
                private _air = _group getVariable QGVAR(attackAir);
                if (!isNil "_air") then {_air set ["phase", "release"];};
            }] call FUNC(doHeliInsert);
        };
        false
    };

    case "land": {false};

    // last resort after two failed scripted landings: the engine's own landing, troops out as soon as it is low
    case "engineLand": {
        if (alive _heli) then {
            private _low = (getPosATL _heli) select 2 < 3 && {speed _heli < 5};
            if (_low || {time - (_air get "time") > ENGINE_LAND_TIMEOUT}) then {
                {if (alive _x && {(vehicle _x) isEqualTo _heli}) then {unassignVehicle _x; moveOut _x; [_x] allowGetIn false;};} forEach (_air getOrDefault ["troops", []]);
                _heli land "NONE";
                (driver _heli) doMove (_lz getPos [400, _pos getDir _lz]);
                _air set ["phase", "release"];
                if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 engine landing done (%3)", side _group, groupId _group, ["timeout", "low enough"] select _low] call EFUNC(main,debugLog);};
            } else {
                if (unitReady (driver _heli)) then {(driver _heli) doMove _lz; _heli land "GET OUT";};
            };
        } else {
            _air set ["phase", "release"];
        };
        false
    };

    case "release": {
        private _troops = _air getOrDefault ["troops", []];
        private _aboard = _troops select {alive _x && {(vehicle _x) isEqualTo _heli}};

        // the drop did not happen ~ try the scripted landing once more, then let the engine land it
        if (_aboard isNotEqualTo [] && {alive _heli} && {canMove _heli}) then {
            private _attempts = _air getOrDefault ["attempts", 0];
            _air set ["attempts", _attempts + 1];
            _air set ["time", time];
            if (_attempts < 1) then {
                _air set ["phase", "fly"];
                (driver _heli) doMove _lz;
                _heli flyInHeight APPROACH_ALTITUDE;
                format [localize ELSTRING(danger,Feedback_AirGoAround), groupId _group] call _fnc_feedback;
                if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 drop failed with %3 still aboard, going around", side _group, groupId _group, count _aboard] call EFUNC(main,debugLog);};
            } else {
                _air set ["phase", "engineLand"];
                (driver _heli) doMove _lz;
                _heli land "GET OUT";
                if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 drop failed twice, engine landing", side _group, groupId _group] call EFUNC(main,debugLog);};
            };
        };
        if ((_air get "phase") isNotEqualTo "release") exitWith {false};

        _air set ["phase", "done"];
        private _onFoot = (units _group) select {isNull objectParent _x && {_x call EFUNC(main,isAlive)} && {!isPlayer _x}};

        // passengers from other groups who made it to the ground attack on their own feet, same objective
        private _otherGroups = [];
        {if (alive _x && {isNull objectParent _x} && {(group _x) isNotEqualTo _group}) then {_otherGroups pushBackUnique (group _x);};} forEach _troops;
        {
            [QGVAR(taskAttack), [_x, _pos, 0, -1, _curatorOwner], leader _x] call CBA_fnc_targetEvent;
            format [localize ELSTRING(danger,Feedback_AirDropped), groupId _x, round ((leader _x) distance2D _pos)] call _fnc_feedback;
            if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 dropped off, attacks on foot", side _x, groupId _x] call EFUNC(main,debugLog);};
        } forEach _otherGroups;
        if (_onFoot isNotEqualTo []) then {format [localize ELSTRING(danger,Feedback_AirDropped), groupId _group, round ((_onFoot select 0) distance2D _pos)] call _fnc_feedback;};

        if (alive _heli) then {
            private _crew = (crew _heli) select {(group _x) isEqualTo _group};
            if (_onFoot isNotEqualTo []) then {
                // the infantry leads from here; this group's aircrew becomes its own element
                if (!(isNull objectParent (leader _group))) then {_group selectLeader (_onFoot select 0);};
                if (_crew isNotEqualTo []) then {
                    private _airGroup = createGroup [side _group, true];
                    _crew joinSilent _airGroup;
                    [_airGroup, _heli, _pos, _air get "start"] call FUNC(doAirLoiter);
                };
            } else {
                // nobody of ours on the ground ~ either this is the aircrew's group and the drop was the job,
                // or our own men are still aboard after everything failed: they stay with the aircraft
                _air set ["crewOnly", true];
            };
        };
        if (_onFoot isNotEqualTo []) then {[leader _group, "combat", "Advance", 125] call EFUNC(main,doCallout);};
        if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 drop complete, %3 of ours on the ground, %4 other groups", side _group, groupId _group, count _onFoot, count _otherGroups] call EFUNC(main,debugLog);};
        true
    };

    default {true};
};
