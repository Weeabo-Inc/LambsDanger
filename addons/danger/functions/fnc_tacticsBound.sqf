#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Leader orders fire and movement towards the enemy: half the group suppresses the
 * known positions while the other half bounds forward, then the halves swap. Support
 * gunners and the leader form the first base of fire. Inside CQB range the building
 * assault takes over.
 *
 * Arguments:
 * 0: group executing tactics <GROUP> or group leader <UNIT>
 * 1: group threat unit <OBJECT> or position <ARRAY>
 * 2: units in group, default all <ARRAY>
 * 3: delay until unit is ready again <NUMBER>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tacticsBound;
 *
 * Public: No
*/
#define SUPPRESS_POSITIONS 12

params ["_group", "_target", ["_units", []], ["_delay", 150]];

// group is missing
if (isNull _group) exitWith {false};

// get leader
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;
if (_group call EFUNC(main,isDirected)) exitWith {false};

// find target
_target = _target call CBA_fnc_getPos;
if ((_target select 2) > 6) then {
    _target set [2, 0.5];
};

// close already ~ the building assault handles it
if (_unit distance2D _target < GVAR(cqbRange)) exitWith {
    [_group, _target] call FUNC(tacticsAssault);
    false
};

// reset tactics
_group setVariable [QGVAR(isExecutingTactic), true];
[
    {
        params [["_group", grpNull], ["_delay", 0]];
        time > _delay || {isNull _group} || {!(_group getVariable [QGVAR(isExecutingTactic), false])}
    },
    {
        params [["_group", grpNull], "", ["_speedMode", "NORMAL"], ["_formation", "WEDGE"], ["_combatMode", "YELLOW"], ["_enableAttack", true], ["_behaviour", "AWARE"], ["_boundUnits", []]];
        if (!isNull _group) then {
            _group setVariable [QGVAR(isExecutingTactic), nil];
            _group setVariable [QGVAR(boundToken), nil];
            _group setVariable [QEGVAR(main,currentTactic), nil];
            _group setSpeedMode _speedMode;
            _group setFormation _formation;
            _group setCombatMode _combatMode;
            _group setBehaviourStrong _behaviour;
            _group enableAttack (_enableAttack || {GVAR(aggression) > 0 && {!(_group call EFUNC(main,isDirected))}});
            {
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x setVariable [QGVAR(forceMove), nil];
                _x setUnitPos "AUTO";
                _x forceSpeed -1;
                _x doFollow (leader _x);
            } forEach (units _group);
            // give the engine its combat reflexes back ~ only where this tactic took them
            {
                if (!isNull _x) then {
                    private _boundUnit = _x;
                    private _taskDisabled = _boundUnit getVariable [QEGVAR(wp,disabledAI), []];
                    {
                        if (!(_x in _taskDisabled)) then {_boundUnit enableAI _x;};
                    } forEach ["SUPPRESSION", "TARGET", "AUTOTARGET", "AUTOCOMBAT"];
                };
            } forEach _boundUnits;
        };
    },
    [_group, time + _delay, speedMode _group, formation _group, combatMode _group, attackEnabled _group, behaviour _unit, _units]
] call CBA_fnc_waitUntilAndExecute;

// find units ~ vehicles stay back as a fire base
if (_units isEqualTo []) then {
    _units = [_unit, 250] call EFUNC(main,findReadyUnits);
};
if (_units isEqualTo []) exitWith {
    _group setVariable [QGVAR(isExecutingTactic), nil];
    false
};
private _vehicles = ([_unit] call EFUNC(main,findReadyVehicles)) select {someAmmo _x};
{_x doWatch _target;} forEach _vehicles;

// teams ~ leader, support gunners and medic form the fire team, everyone else the assault team
private _base = [_unit] + ((_units - [_unit]) select {_x call EFUNC(main,isSupportGunner) || {_x call EFUNC(main,isMedic)}});
private _assault = _units - _base;
// a fire team needs no more than half the group, an assault team needs at least two
while {count _assault < 2 && {count _base > 1}} do {
    private _mover = (_base - [_unit]) select 0;
    _assault pushBack _mover;
    _base = _base - [_mover];
};
while {count _base > count _assault && {count _base > 2}} do {
    private _mover = (_base - [_unit]) select -1;
    _assault pushBack _mover;
    _base = _base - [_mover];
};

// positions worth suppressing ~ known enemies, then buildings around the objective, then the objective itself
private _posList = ([_group, 60] call FUNC(pictureContacts)) apply {_x select 1};
_posList append ([_target, 20, true, false] call EFUNC(main,findBuildings));
_posList pushBack _target;
if (count _posList > SUPPRESS_POSITIONS) then {_posList resize SUPPRESS_POSITIONS;};

// set tasks
_unit setVariable [QEGVAR(main,currentTarget), _target, EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTask), "Tactics Bound", EGVAR(main,debug_functions)];
_group setVariable [QEGVAR(main,currentTactic), "Fire and movement", EGVAR(main,debug_functions)];

// group orders ~ AWARE with no automatic COMBAT switch, or the engine crawls and the bound never completes
_group enableAttack false;
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_group setFormation "LINE";
_group setFormDir (_unit getDir _target);
_group setBehaviourStrong "AWARE";
{
    _x setVariable [QGVAR(forceMove), true];
    _x forceSpeed -1;
    _x disableAI "AUTOCOMBAT";
} forEach _units;

// gesture and callout
[_unit, "gesturePoint"] call EFUNC(main,doGesture);
[_unit, "combat", "suppress", 125] call EFUNC(main,doCallout);

// concealment
if (!GVAR(disableAutonomousSmokeGrenades)) then {[_unit, _target] call EFUNC(main,doSmoke);};

// start the cycle
private _token = time + random 1;
_group setVariable [QGVAR(boundToken), _token];
[{_this call EFUNC(main,doGroupBound)}, [_group, _base, _assault, _posList, _target, 0, 0, [], _vehicles, _token], 1] call CBA_fnc_waitAndExecute;

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 TACTICS BOUND (%2 with %3 fire team / %4 assault team / %5 vehicles @ %6m, %7 positions)", side _unit, name _unit, count _base, count _assault, count _vehicles, round (_unit distance2D _target), count _posList] call EFUNC(main,debugLog);
    private _m = [_unit, "tactics bound", _unit call EFUNC(main,debugMarkerColor), "hd_arrow"] call EFUNC(main,dotMarker);
    private _mt = [_target, "", _unit call EFUNC(main,debugMarkerColor), "hd_destroy"] call EFUNC(main,dotMarker);
    {_x setMarkerSizeLocal [0.6, 0.6];} forEach [_m, _mt];
    _m setMarkerDirLocal (_unit getDir _target);
    [{{deleteMarker _x;true} count _this;}, [_m, _mt], _delay + 30] call CBA_fnc_waitAndExecute;
};

// end
true
