#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A deliberate attack on a position, the way a trained squad does it rather than a
 * rush down the direct line:
 *   plan         analyse the ground (lambs_main_fnc_findApproach), split the squad into a
 *                support element (leader, machine guns, launchers) and an assault element
 *   approach     support moves to a support by fire position with eyes on the objective,
 *                the assault element follows a covered route to an assault position on the
 *                flank, in a free-form wedge, both at the same time
 *   assault      support suppresses and fires rockets and grenade launchers into the
 *                objective, the assault element closes with fire and movement in pairs
 *                (lambs_main_fnc_doGroupBound); support shifts and lifts as they get close
 *   clear        the assault element sweeps the buildings, support moves up
 *   consolidate  everyone takes a sector on a perimeter around the objective facing out
 * A squad too small to split assaults with fire and movement straight from the approach.
 * Reacts on the way: fired on before the assault position it goes straight into the
 * assault from where it is; losses or broken morale end it. Runs on its own per frame
 * handler every 4 s and owns the group's tactic state until it ends.
 *
 * Arguments:
 * 0: group executing tactics <GROUP> or group leader <UNIT>
 * 1: objective position or unit <ARRAY> or <OBJECT>
 * 2: maximum duration in seconds <NUMBER>
 *
 * Return Value:
 * success
 *
 * Example:
 * [group bob, getPos angryJoe] call lambs_danger_fnc_tacticsManeuver;
 *
 * Public: No
*/
#define CYCLE 4
#define MIN_SPLIT_SIZE 5
#define MIN_ASSAULT 3
#define ASSAULT_SPACING 4
#define SUPPORT_SPACING 5
#define SHIFT_FIRE_DISTANCE 60
#define PERIMETER_RADIUS 20
#define CLEAR_QUIET 30
#define REACT_STRESS 0.5
#define REACT_RANGE 150
#define FAIL_MORALE 0.35
#define FAIL_LOSSES 3
#define SUPPRESS_POSITIONS 10

params ["_group", "_objective", ["_maxDuration", 420]];

// group is missing
if (isNull _group) exitWith {false};
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;
if (_group call EFUNC(main,isDirected)) exitWith {false};
_objective = _objective call CBA_fnc_getPos;
if (_objective isEqualTo [0, 0, 0]) exitWith {false};

// units on foot ~ vehicles stay back as a fire base through the bound code
private _units = [_unit, 300] call EFUNC(main,findReadyUnits);
if (_units isEqualTo []) exitWith {false};

// stop whatever else was running
private _oldPFH = _group getVariable [QGVAR(maneuverPFH), -1];
if (_oldPFH isNotEqualTo -1) then {[_oldPFH] call CBA_fnc_removePerFrameHandler;};
private _monitor = _group getVariable [QGVAR(tacticPFH), -1];
if (_monitor isNotEqualTo -1) then {[_monitor] call CBA_fnc_removePerFrameHandler; _group setVariable [QGVAR(tacticPFH), nil];};

// plan
([getPosATL _unit, _objective] call EFUNC(main,findApproach)) params ["_route", "_assaultPos", "_supportPos", "_side"];
private _support = [];
private _assault = _units;
if (count _units >= MIN_SPLIT_SIZE) then {
    _support = [_unit] + ((_units - [_unit]) select {_x call EFUNC(main,isSupportGunner) || {(secondaryWeapon _x) isNotEqualTo ""}});
    _assault = _units - _support;
    while {count _assault < MIN_ASSAULT && {count _support > 2}} do {
        private _mover = (_support - [_unit]) select -1;
        _assault pushBack _mover;
        _support = _support - [_mover];
    };
    while {count _support > count _assault && {count _support > 2}} do {
        private _mover = (_support - [_unit]) select -1;
        _assault pushBack _mover;
        _support = _support - [_mover];
    };
};

// what the support element shoots at
private _posList = ([_group, 90] call FUNC(pictureContacts)) apply {_x select 1};
_posList append ([_objective, 30, true, false] call EFUNC(main,findBuildings));
_posList pushBack _objective;
if (count _posList > SUPPRESS_POSITIONS) then {_posList resize SUPPRESS_POSITIONS;};

// state
private _state = createHashMapFromArray [
    ["phase", "approach"],
    ["phaseTime", time],
    ["endTime", time + _maxDuration],
    ["support", _support],
    ["assault", _assault],
    ["route", _route],
    ["routeIndex", 0],
    ["assaultPos", _assaultPos],
    ["supportPos", _supportPos],
    ["objective", _objective],
    ["posList", _posList],
    ["supportIndex", 0],
    ["supportArrived", _support isEqualTo []],
    ["lifted", false],
    ["quietSince", -1],
    ["startLosses", ([_group] call FUNC(pictureGet)) get "losses"]
];
_group setVariable [QGVAR(maneuver), _state];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QEGVAR(main,currentTactic), "Deliberate attack", EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTarget), _objective, EGVAR(main,debug_functions)];

// orders ~ AWARE, no automatic COMBAT, engine formation out of the way, everyone on their own slots
_group enableAttack false;
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_group setBehaviourStrong "AWARE";
_group setFormDir (_unit getDir _objective);
{
    _x setVariable [QGVAR(forceMove), true];
    _x disableAI "AUTOCOMBAT";
    _x forceSpeed -1;
    _x setUnitPos "AUTO";
    _x setVariable [QEGVAR(main,currentTask), ["Assault element", "Support element"] select (_x in _support), EGVAR(main,debug_functions)];
} forEach _units;
[_unit, "gesturePoint"] call EFUNC(main,doGesture);
[_unit, "combat", "Advance", 125] call EFUNC(main,doCallout);

// the plan runs from here
private _handle = [{
    params ["_args", "_handle"];
    _args params ["_group", "_units"];

    private _fnc_end = {
        params ["_group", "_handle", "_units", "_result"];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (isNull _group) exitWith {};
        private _picture = [_group] call FUNC(pictureGet);
        _picture set ["lastTactic", "maneuver"];
        _picture set ["lastResult", _result];
        _picture set ["lastTacticTime", time];
        _group setVariable [QGVAR(maneuverPFH), nil];
        _group setVariable [QGVAR(maneuver), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QEGVAR(main,currentTactic), nil, EGVAR(main,debug_functions)];
        _group enableAttack (GVAR(aggression) > 0 && {!(_group call EFUNC(main,isDirected))});
        _group setSpeedMode "NORMAL";
        {
            if (!isNull _x) then {
                _x setVariable [QGVAR(forceMove), nil];
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x setUnitPos "AUTO";
                _x forceSpeed -1;
                private _taskDisabled = _x getVariable [QEGVAR(wp,disabledAI), []];
                private _maneuverUnit = _x;
                {if (!(_x in _taskDisabled)) then {_maneuverUnit enableAI _x;};} forEach ["SUPPRESSION", "TARGET", "AUTOTARGET", "AUTOCOMBAT"];
                if (_result isNotEqualTo "completed") then {_x doFollow (leader _group);};
            };
        } forEach _units;
        if (EGVAR(main,debug_functions)) then {
            ["%1 MANEUVER %2 %3", side _group, groupId _group, _result] call EFUNC(main,debugLog);
        };
    };

    // gone, taken over, or out of time
    if (isNull _group || {!local _group} || {_group call EFUNC(main,isDirected)}) exitWith {[_group, _handle, _units, "aborted"] call _fnc_end;};
    private _state = _group getVariable QGVAR(maneuver);
    if (isNil "_state") exitWith {[_group, _handle, _units, "aborted"] call _fnc_end;};
    if (time > (_state get "endTime")) exitWith {[_group, _handle, _units, "timeout"] call _fnc_end;};

    // this plan owns the group's tactic state until it is done
    _group setVariable [QGVAR(isExecutingTactic), true];

    private _picture = [_group] call FUNC(pictureGet);
    private _objective = _state get "objective";
    private _phase = _state get "phase";
    private _alive = {_x call EFUNC(main,isAlive) && {isNull objectParent _x}};
    private _support = (_state get "support") select _alive;
    private _assault = (_state get "assault") select _alive;
    if (_assault isEqualTo []) then {_assault = _support; _support = [];};
    _state set ["support", _support];
    _state set ["assault", _assault];
    if (_assault isEqualTo []) exitWith {[_group, _handle, _units, "failed"] call _fnc_end;};

    // broken or bled out ~ the withdraw tactic takes over from the commander
    private _losses = (_picture get "losses") - (_state get "startLosses");
    if (_losses >= FAIL_LOSSES || {([_group] call FUNC(getMorale)) < FAIL_MORALE}) exitWith {[_group, _handle, _units, "failed"] call _fnc_end;};

    private _leader = leader _group;
    private _assaultCentre = [0, 0, 0];
    {_assaultCentre = _assaultCentre vectorAdd (getPosATL _x);} forEach _assault;
    _assaultCentre = _assaultCentre vectorMultiply (1 / count _assault);
    private _assaultDistance = _assaultCentre distance2D _objective;
    private _posList = _state get "posList";
    private _fnc_setPhase = {
        _state set ["phase", _this];
        _state set ["phaseTime", time];
        if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2 -> %3", side _group, groupId _group, _this] call EFUNC(main,debugLog);};
    };

    // support element ~ suppress from its position once there, shift and lift when the assault is close
    private _fnc_supportFire = {
        private _lifted = _state get "lifted";
        {
            _x setUnitPos "DOWN";
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
            if (_lifted) then {
                _x doWatch _objective;
            } else {
                if (!([_x, [_objective, _posList select 0] select (_posList isNotEqualTo [])] call EFUNC(main,doLauncherFire))) then {
                    if ((currentCommand _x) isNotEqualTo "Suppress") then {
                        private _index = [_x, _posList] call EFUNC(main,checkVisibilityList);
                        if (_index isEqualTo -1 || {!([_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call EFUNC(main,doSuppress))}) then {
                            _x doWatch _objective;
                        };
                    };
                };
            };
        } forEach _support;
    };

    switch (_phase) do {

        case "approach": {
            // support to its position
            if (_support isNotEqualTo [] && {!(_state get "supportArrived")}) then {
                ([_support, [_state get "supportPos"], 0, "line", SUPPORT_SPACING, _objective] call EFUNC(main,doTeamMove)) params ["_arrived"];
                if (_arrived) then {
                    _state set ["supportArrived", true];
                    [_leader, "combat", "suppress", 100] call EFUNC(main,doCallout);
                };
                {_x setVariable [QEGVAR(main,currentTask), "Support moving to position", EGVAR(main,debug_functions)];} forEach _support;
            } else {
                call _fnc_supportFire;
            };

            // assault element along the covered route
            ([_assault, _state get "route", _state get "routeIndex", "wedge", ASSAULT_SPACING, _objective] call EFUNC(main,doTeamMove)) params ["_arrived", "_index"];
            _state set ["routeIndex", _index];
            {
                _x setUnitPos "UP";
                _x setVariable [QEGVAR(main,currentTask), "Assault element approaching", EGVAR(main,debug_functions)];
            } forEach _assault;

            // fired on before the assault position ~ go in from here
            private _stress = 0;
            {_stress = _stress + (_x call EFUNC(main,getStress));} forEach _assault;
            _stress = _stress / count _assault;
            private _contacts = [_group, 20] call FUNC(pictureContacts);
            private _closeContact = (_contacts findIf {(_x select 1) distance2D _assaultCentre < REACT_RANGE}) isNotEqualTo -1;
            if (_arrived || {_stress > REACT_STRESS && _closeContact} || {_assaultDistance < REACT_RANGE * 0.8}) then {
                "assault" call _fnc_setPhase;
                // pairs: half covers, half runs, alternating, straight out of the bound code
                private _fireHalf = [];
                private _runHalf = [];
                {[_runHalf, _fireHalf] select ((_forEachIndex % 2) isEqualTo 1) pushBack _x;} forEach _assault;
                if (_runHalf isEqualTo []) then {_runHalf = _fireHalf; _fireHalf = [];};
                [{_this call EFUNC(main,doGroupBound)}, [_group, _fireHalf, _runHalf, _posList, _objective, 0, 0, [], [_leader] call EFUNC(main,findReadyVehicles)], 0.5] call CBA_fnc_waitAndExecute;
                [_leader, "combat", "Advance", 125] call EFUNC(main,doCallout);
            };
        };

        case "assault": {
            // shift and lift ~ no suppression into the assault element's backs
            if (!(_state get "lifted") && {_assaultDistance < SHIFT_FIRE_DISTANCE}) then {
                _state set ["lifted", true];
                {_x doWatch objNull; _x setUnitPos "MIDDLE";} forEach _support;
                [_leader, "combat", "KeepFocused", 100] call EFUNC(main,doCallout);
            };
            call _fnc_supportFire;

            // support moves up once fire is lifted, to the assault position
            if (_state get "lifted" && {_support isNotEqualTo []}) then {
                [_support, [_state get "assaultPos"], 0, "line", SUPPORT_SPACING, _objective] call EFUNC(main,doTeamMove);
                {_x setUnitPos "MIDDLE"; _x setVariable [QEGVAR(main,currentTask), "Support moving up", EGVAR(main,debug_functions)];} forEach _support;
            };

            // the bound code hands over to the building assault inside CQB range ~ from there it is the clear
            if (_assaultDistance < GVAR(cqbRange)) then {
                "clear" call _fnc_setPhase;
            };
        };

        case "clear": {
            // support closes to the objective edge and watches outwards
            if (_support isNotEqualTo []) then {
                [_support, [_objective getPos [PERIMETER_RADIUS, _objective getDir _leader]], 0, "line", SUPPORT_SPACING, _objective] call EFUNC(main,doTeamMove);
            };
            // done when nothing has been seen for a while and the assault element is on the objective
            private _contacts = [_group, CLEAR_QUIET] call FUNC(pictureContacts);
            _contacts = _contacts select {(_x select 1) distance2D _objective < 100};
            if (_contacts isEqualTo [] && {_assaultDistance < PERIMETER_RADIUS * 2}) then {
                if ((_state get "quietSince") < 0) then {_state set ["quietSince", time];};
                if (time - (_state get "quietSince") > CLEAR_QUIET) then {
                    "consolidate" call _fnc_setPhase;
                    // perimeter ~ sectors all round, facing out
                    private _all = _assault + _support;
                    {
                        private _bearing = _forEachIndex * (360 / count _all);
                        private _spot = _objective getPos [PERIMETER_RADIUS, _bearing];
                        private _empty = _spot findEmptyPosition [0, 5];
                        if (_empty isNotEqualTo []) then {_spot = _empty;};
                        _x doMove _spot;
                        _x setUnitPos "MIDDLE";
                        _x setVariable [QEGVAR(main,currentTask), "Consolidating", EGVAR(main,debug_functions)];
                        [{params ["_unit", "_spot", "_bearing"]; if (_unit call EFUNC(main,isAlive)) then {_unit doWatch (_spot getPos [50, _bearing]);};}, [_x, _spot, _bearing], 8 + random 4] call CBA_fnc_waitAndExecute;
                    } forEach _all;
                    [_leader, "combat", "KeepFocused", 100] call EFUNC(main,doCallout);
                    if (_losses > 0) then {[{_this call EFUNC(main,doCallout)}, [_leader, "combat", "mandown", 100], 3] call CBA_fnc_waitAndExecute;};
                };
            } else {
                _state set ["quietSince", -1];
            };
        };

        case "consolidate": {
            if (time - (_state get "phaseTime") > 12) then {
                [_group, "defend", _objective, 60] call FUNC(intentSet);
                [_group, _handle, _units, "completed"] call _fnc_end;
            };
        };
    };
}, CYCLE, [_group, _units]] call CBA_fnc_addPerFrameHandler;
_group setVariable [QGVAR(maneuverPFH), _handle];

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 MANEUVER %2: %3 support / %4 assault, %5 flank, objective %6m", side _unit, groupId _group, count _support, count _assault, ["left", "right"] select (_side > 0), round (_unit distance2D _objective)] call EFUNC(main,debugLog);
    private _markers = [];
    _markers pushBack ([_supportPos, "SBF", _unit call EFUNC(main,debugMarkerColor), "hd_dot"] call EFUNC(main,dotMarker));
    _markers pushBack ([_assaultPos, "assault pos", _unit call EFUNC(main,debugMarkerColor), "hd_flag"] call EFUNC(main,dotMarker));
    {_markers pushBack ([_x, format ["route %1", _forEachIndex], _unit call EFUNC(main,debugMarkerColor), "hd_arrow"] call EFUNC(main,dotMarker));} forEach _route;
    _markers pushBack ([_objective, "objective", _unit call EFUNC(main,debugMarkerColor), "hd_destroy"] call EFUNC(main,dotMarker));
    [{{deleteMarker _x;true} count _this;}, _markers, _maxDuration] call CBA_fnc_waitAndExecute;
};

// end
true
