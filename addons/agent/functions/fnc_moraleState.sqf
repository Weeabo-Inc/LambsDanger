#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One man's morale state from what has happened to him: steady, suppressed, pinned,
 * shaken, broken, rallying. Worse states arrive at once, better ones only after the
 * minimum time, and a shaken or broken man only recovers with a living leader close by,
 * through a rallying spell. The state changes what he may do, never how well he shoots
 * (docs/systems/morale.md).
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * the state <STRING>
 *
 * Example:
 * [bob] call hostis_agent_fnc_moraleState;
 *
 * Public: Yes
*/
#define PINNED_CLOCK_LEVEL 0.75
#define PINNED_CLOCK_TIME 6
#define HIT_SUPPRESSED 20
#define HIT_RECENT 5
#define BUDDY_RANGE 15

params [["_unit", objNull, [objNull]]];

if (isNull _unit || {!local _unit} || {isPlayer _unit}) exitWith {"steady"};
private _morale = _unit getVariable [QGVAR(morale), ["steady", time, "steady", -1]];
_morale params ["_state", "_since", "_prev", "_pinnedClock"];
if (!(_unit call LFUNC(main,isAlive))) exitWith {_state};

private _now = time;
private _suppression = (getSuppression _unit) max 0;
private _stress = _unit call LFUNC(main,getStress);
private _hitAgo = _now - (_unit getVariable [QLGVAR(main,lastHit), -1e9]);
private _group = group _unit;
private _leader = leader _group;
private _leaderAlive = _leader call LFUNC(main,isAlive);
private _isolated = _unit distance2D _leader > GVAR(isolationRange)
    && {((units _group) findIf {_x isNotEqualTo _unit && {_x distance2D _unit < BUDDY_RANGE} && {_x call LFUNC(main,isAlive)}}) isEqualTo -1};
private _picture = _group getVariable QLGVAR(danger,picture);
private _cohesion = if (isNil "_picture") then {"steady"} else {_picture getOrDefault ["cohesion", "steady"]};

// how long he has been kept down
if (_suppression > GVAR(pinnedSuppression) * PINNED_CLOCK_LEVEL) then {
    if (_pinnedClock < 0) then {_pinnedClock = _now;};
} else {
    _pinnedClock = -1;
};
private _pinnedFor = if (_pinnedClock >= 0) then {_now - _pinnedClock} else {0};

private _new = switch (true) do {
    case (_cohesion isEqualTo "broken" || {_stress > GVAR(brokenStress) && {_suppression > 0.6} && {_isolated || {!_leaderAlive}}}): {"broken"};
    case (_stress > GVAR(shakenStress) || {_hitAgo < HIT_SUPPRESSED && {_suppression > 0.5}}): {"shaken"};
    case (_suppression > GVAR(pinnedSuppression) || {_pinnedFor > PINNED_CLOCK_TIME}): {"pinned"};
    case (_suppression > GVAR(suppressedLevel) || {_hitAgo < HIT_RECENT}): {"suppressed"};
    default {"steady"};
};

// a shaken or broken man does not simply feel better: he needs his leader near, and a moment
if (MORALE_RANK(_new) <= MORALE_RANK("suppressed") && {_state in ["shaken", "broken", "rallying"]}) then {
    if (_state isEqualTo "rallying") then {
        if (_now - _since < GVAR(rallyTime)) then {_new = "rallying";};
    } else {
        _new = [_state, "rallying"] select (_leaderAlive && {_unit distance2D _leader < GVAR(rallyRange)});
    };
};

// worse at once, better only after the minimum time
if (_new isNotEqualTo _state && {MORALE_RANK(_new) < MORALE_RANK(_state)} && {_now - _since < GVAR(stateMinTime)}) then {_new = _state;};

if (_new isEqualTo _state) exitWith {
    _unit setVariable [QGVAR(morale), [_state, _since, _prev, _pinnedClock]];
    _state
};

_unit setVariable [QGVAR(morale), [_new, _now, _state, _pinnedClock]];

// what the change looks and sounds like
switch (_new) do {
    case "suppressed": {
        _unit setUnitPosWeak (_unit call LFUNC(main,getLowStance));
        [_unit, "underFire"] call FUNC(bark);
    };
    case "pinned": {
        _unit setUnitPosWeak "DOWN";
        [_unit, "takeCover"] call FUNC(bark);
    };
    case "shaken": {
        _unit setUnitPosWeak "DOWN";
        [_unit, "panic"] call FUNC(bark);
    };
    case "broken": {
        [_unit, "panic", true] call FUNC(bark);
        // out of it, away from the fire, unless the machine already has him running
        if (!([_unit, "isBusy"] call LFUNC(danger,unitState)) && {!(_unit call LFUNC(main,isDirected))}) then {
            private _threats = if (isNil "_picture" || {(_picture get "threatPos") isEqualTo []}) then {[]} else {[_picture get "threatPos"]};
            [_unit, "survive", getPosATL _unit, _threats] call LFUNC(danger,unitOrder);
        };
    };
    case "rallying": {
        [_leader, "rally"] call FUNC(bark);
    };
    case "steady": {
        if (_state in ["suppressed", "pinned"]) then {_unit setUnitPosWeak "AUTO";};
    };
};

if (GVAR(debugMorale) || {LGVAR(main,debug_functions)}) then {
    ["%1 MORALE %2: %3 -> %4 (suppression %5, stress %6, hit %7 s ago%8%9)", side _unit, name _unit, _state, _new, _suppression toFixed 2, _stress toFixed 2, [round _hitAgo, "-"] select (_hitAgo > 1e8), ["", ", isolated"] select _isolated, ["", ", no leader"] select (!_leaderAlive)] call LFUNC(main,debugLog);
};

_new
