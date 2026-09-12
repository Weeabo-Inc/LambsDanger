#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The menace gauge and the pacing machine (RESEARCH.md C-13, C-16, C-17): per player
 * element, an intensity that rises with damage, deaths and being engaged, decays when
 * left alone and not at all while engaged; and the four states build up, sustain, fade,
 * relax. Spending on an element is allowed only while building up. This is the one place
 * the Director reads player state, and only for pacing (ADR-0004, FAIRNESS.md R6).
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * pacing map, player group hash -> [intensity, state, since, damage, alive, centre] <HASHMAP>
 *
 * Example:
 * [east] call hostis_director_fnc_pacing;
 *
 * Public: No
*/
#define PEAK 1
#define SUSTAIN 5
#define FADE_BELOW 0.5
#define ENGAGED_RANGE 200
#define ENGAGED_AGE 15
#define DAMAGE_GAIN 2
#define DEATH_GAIN 0.5
#define ENGAGED_GAIN 0.15
#define DECAY_PER_SECOND 0.01
#define FORGET 600

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _pacing = _state get "pacing";
private _interval = GVAR(thinkInterval);
private _throttle = GVAR(throttle);

// the player elements this side is fighting
private _playerGroups = [];
{
    if (alive _x && {((side _x) getFriend _side) < 0.6}) then {_playerGroups pushBackUnique (group _x);};
} forEach allPlayers;

// where the side's groups are in contact right now
private _contacts = [];
{
    private _picture = [_x] call EFUNC(core,pictureGet);
    if (time - (_picture get "lastContact") < ENGAGED_AGE && {(_picture get "threatPos") isNotEqualTo []}) then {_contacts pushBack (_picture get "threatPos");};
} forEach (_state get "groups");

{
    private _group = _x;
    private _key = hashValue _group;
    private _members = (units _group) select {isPlayer _x};
    private _alive = _members select {alive _x};
    private _damage = 0;
    {_damage = _damage + (damage _x);} forEach _alive;
    private _centre = [0, 0, 0];
    {_centre = _centre vectorAdd (getPosATL _x);} forEach _alive;
    if (_alive isNotEqualTo []) then {_centre = _centre vectorMultiply (1 / (count _alive));};

    private _entry = _pacing getOrDefault [_key, [0, "buildUp", time, _damage, count _alive, _centre, time]];
    _entry params ["_intensity", "_pstate", "_since", "_lastDamage", "_lastAlive", "", ""];

    // what happened to them
    if (_damage > _lastDamage) then {_intensity = _intensity + (_damage - _lastDamage) * DAMAGE_GAIN;};
    if (count _alive < _lastAlive) then {_intensity = _intensity + (_lastAlive - (count _alive)) * DEATH_GAIN;};
    private _engaged = (_contacts findIf {_x distance2D _centre < ENGAGED_RANGE}) isNotEqualTo -1;
    if (_engaged) then {_intensity = _intensity + ENGAGED_GAIN;} else {_intensity = _intensity - DECAY_PER_SECOND * _interval;};
    _intensity = (_intensity max 0) min 2;

    // the machine
    private _relax = if (_throttle <= 0) then {1e9} else {GVAR(relaxTime) / _throttle};
    switch (_pstate) do {
        case "buildUp": {if (_intensity >= PEAK) then {_pstate = "sustain"; _since = time;};};
        case "sustain": {if (time - _since > SUSTAIN) then {_pstate = "fade"; _since = time;};};
        case "fade": {if (_intensity < FADE_BELOW && {!_engaged}) then {_pstate = "relax"; _since = time;};};
        case "relax": {if (time - _since > _relax) then {_pstate = "buildUp"; _since = time;};};
    };
    if ((_entry select 1) isNotEqualTo _pstate) then {
        [_side, format ["pacing for %1: %2 -> %3 (intensity %4)", groupId _group, _entry select 1, _pstate, _intensity toFixed 2]] call FUNC(log);
    };
    _pacing set [_key, [_intensity, _pstate, _since, _damage, count _alive, _centre, time]];
} forEach _playerGroups;

// elements not seen for a long time are forgotten
{
    if (time - (_y select 6) > FORGET) then {_pacing deleteAt _x;};
} forEach +_pacing;

_pacing
