#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A soldier looks after himself. Level 2: get into the nearest cover, head down, then
 * come back up and return fire. Level 3: break away from the threat to cover 20-35 m
 * off, sprinting, smoke if there is nothing else to hide behind, drop, patch up if
 * wounded; an enemy within arm's reach is fought instead of run from.
 * While it lasts the unit is marked so group manoeuvres leave it alone; it rejoins
 * when the mark expires.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Threat level 2 or 3 <NUMBER>
 * 2: Threat position AGL, [] for the group's picture <ARRAY>
 *
 * Return Value:
 * acted <BOOL>
 *
 * Example:
 * [bob, 3, getPos angryJoe] call lambs_main_fnc_doSurvive;
 *
 * Public: No
*/
#define COOLDOWN 5
#define COVER_RANGE 15
#define BREAK_RANGE 32
#define BREAK_MIN 20
#define BREAK_FALLBACK 25
#define FIGHT_RANGE 8
#define HOLD_COVER 6
#define HOLD_BREAK 12
#define HEAD_DOWN 4
#define SMOKE_CHANCE 0.5

params [["_unit", objNull, [objNull]], ["_level", 2, [0]], ["_threatPos", [], [[]]]];

if (
    isNull _unit || {!(_unit call FUNC(isAlive))} || {isPlayer _unit} || {!isNull objectParent _unit}
    || {time < (_unit getVariable [QGVAR(surviveTime), 0])}
    || {!(_unit checkAIFeature "PATH")} || {!(_unit checkAIFeature "MOVE")}
) exitWith {false};
_unit setVariable [QGVAR(surviveTime), time + COOLDOWN];

// where the danger is
if (_threatPos isEqualTo []) then {
    private _picture = (group _unit) getVariable QEGVAR(danger,picture);
    if (!isNil "_picture") then {_threatPos = _picture get "threatPos";};
};
if (_threatPos isEqualTo []) then {
    private _enemy = _unit findNearestEnemy _unit;
    _threatPos = if (isNull _enemy) then {_unit getPos [50, getDir _unit]} else {_unit getHideFrom _enemy};
};

// somebody on top of him ~ fight, running gets you shot in the back
if (_level >= 3 && {(_unit targets [true, FIGHT_RANGE]) isNotEqualTo []}) exitWith {
    private _target = (_unit targets [true, FIGHT_RANGE]) select 0;
    _unit setVariable [QGVAR(currentTask), "Fighting for his life", GVAR(debug_functions)];
    [_unit, _target] call FUNC(doAssault);
    true
};

private _awayDir = _threatPos getDir _unit;
private _destination = [];
private _stance = "MIDDLE";

if (_level >= 3) then {
    // break: cover away from the threat, not straight back (that is where the fire goes)
    private _spots = [_unit, _threatPos, BREAK_RANGE, "ASCEND", 4] call FUNC(findCover);
    private _awayVector = [sin _awayDir, cos _awayDir, 0];
    {
        _x params ["_pos", "_posStance"];
        private _offset = (_pos vectorDiff (getPosATL _unit));
        _offset set [2, 0];
        if (_destination isEqualTo [] && {(vectorNormalized _offset) vectorDotProduct _awayVector > -0.2} && {_unit distance2D _pos > 6}) then {
            _destination = _pos;
            _stance = _posStance;
        };
    } forEach _spots;
    if (_destination isEqualTo []) then {
        _destination = _unit getPos [BREAK_FALLBACK, _awayDir + (-45 + random 90)];
        _stance = "DOWN";
    };
} else {
    private _spots = [_unit, _threatPos, COVER_RANGE, "ASCEND", 1] call FUNC(findCover);
    if (_spots isNotEqualTo []) then {
        (_spots select 0) params ["_pos", "_posStance"];
        _destination = _pos;
        _stance = _posStance;
    } else {
        // nothing to hide behind: down, and a couple of metres sideways so the next burst misses
        _destination = _unit getPos [3 + random 3, _awayDir + ([90, -90] select (random 1 > 0.5))];
        _stance = "DOWN";
    };
};

// mark and go
private _hold = [HOLD_COVER, HOLD_BREAK] select (_level >= 3);
_unit setVariable [QGVAR(survival), time + _hold];
_unit setVariable [QEGVAR(danger,forceMove), true];
_unit setVariable [QGVAR(currentTask), ["Getting to cover", "Breaking away"] select (_level >= 3), GVAR(debug_functions)];
_unit setVariable [QGVAR(currentTarget), _threatPos, GVAR(debug_functions)];
if (_level >= 3) then {
    _unit disableAI "SUPPRESSION";
    _unit disableAI "AUTOTARGET";
    _unit disableAI "TARGET";
    _unit doWatch objNull;
    _unit setUnitPos "UP";
    if (random 1 < SMOKE_CHANCE && {!(_unit call FUNC(isIndoor))}) then {[_unit, _threatPos] call FUNC(doSmoke);};
    [_unit, "combat", ["contact", "panic"] select (damage _unit > 0.3), 60] call FUNC(doCallout);
} else {
    _unit setUnitPosWeak "MIDDLE";
};
_unit forceSpeed -1;
_unit doMove _destination;

// there: down, and after a moment back up to look and shoot
[
    {
        params ["_unit", "_destination"];
        !(_unit call FUNC(isAlive)) || {_unit distance2D _destination < 2.5} || {unitReady _unit}
    },
    {
        params ["_unit", "", "_stance", "_threatPos", "_level"];
        if (!(_unit call FUNC(isAlive))) exitWith {};
        _unit setUnitPos _stance;
        _unit enableAI "SUPPRESSION";
        _unit enableAI "AUTOTARGET";
        _unit enableAI "TARGET";
        _unit setVariable [QGVAR(currentTask), "Head down", GVAR(debug_functions)];
        // wounded and out of sight: patch up (ACE medics handle it themselves)
        if (_level >= 3 && {damage _unit > 0.3} && {!isClass (configFile >> "CfgPatches" >> "ace_medical")} && {"FirstAidKit" in (items _unit)}) then {
            _unit action ["HealSoldierSelf", _unit];
        };
        [
            {
                params ["_unit", "_threatPos"];
                if (!(_unit call FUNC(isAlive))) exitWith {};
                _unit doWatch _threatPos;
                _unit setVariable [QGVAR(currentTask), "Returning fire", GVAR(debug_functions)];
            },
            [_unit, _threatPos],
            HEAD_DOWN
        ] call CBA_fnc_waitAndExecute;
    },
    [_unit, _destination, _stance, _threatPos, _level],
    _hold
] call CBA_fnc_waitUntilAndExecute;

// rejoin the group once it is over
[
    {
        params ["_unit"];
        if (!(_unit call FUNC(isAlive))) exitWith {};
        if ((_unit getVariable [QGVAR(survival), 0]) > time) exitWith {};
        _unit setVariable [QEGVAR(danger,forceMove), nil];
        _unit setUnitPos "AUTO";
        _unit doFollow (leader _unit);
        _unit setVariable [QGVAR(currentTask), nil, GVAR(debug_functions)];
    },
    [_unit],
    _hold + 0.5
] call CBA_fnc_waitAndExecute;

// debug
if (GVAR(debug_functions)) then {
    ["%1 %2 survives (level %3, %4m)", side _unit, name _unit, _level, round (_unit distance2D _destination)] call FUNC(debugLog);
};

true
