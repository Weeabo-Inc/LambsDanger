#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The sensor sweep: the one place in the mod that asks the engine what a group's men have
 * detected, and files it as evidence. Reads the leader's targets and, when nothing was
 * handed in, a rotating pair of other men's, through each man's own knowsAbout,
 * getHideFrom and targetKnowledge, so the position and the error are the engine's own
 * (FAIRNESS.md R1; RESEARCH.md C-02).
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Enemies already known to the caller, [] to sweep <ARRAY of OBJECT>
 * 2: Source to file them under, default "seen" <STRING>
 * 3: Observer whose knowledge to use, default the leader <OBJECT>
 *
 * Return Value:
 * combat picture <HASHMAP>
 *
 * Example:
 * [group bob] call hostis_core_fnc_contactSweep;
 * [group bob, [angryJoe], "shotAt", bob] call hostis_core_fnc_contactSweep;
 *
 * Public: Yes
*/
params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_enemies", [], [[]]],
    ["_source", "seen", [""]],
    ["_observer", objNull, [objNull]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {createHashMap};
private _picture = [_group] call FUNC(pictureGet);
if (!local _group) exitWith {_picture};

private _units = (units _group) select {_x call LFUNC(main,isAlive)};
if (_units isEqualTo []) exitWith {_picture};

// whose eyes
private _observers = [];
if (!isNull _observer) then {
    _observers pushBack _observer;
} else {
    private _leader = leader _group;
    if (_leader in _units) then {_observers pushBack _leader;};
    if (_enemies isEqualTo [] && {GVAR(sweepUnits) > 0} && {count _units > 1}) then {
        private _cursor = _picture get "sweepCursor";
        for "_i" from 1 to (GVAR(sweepUnits) min (count _units - 1)) do {
            _cursor = (_cursor + 1) mod (count _units);
            _observers pushBackUnique (_units select _cursor);
        };
        _picture set ["sweepCursor", _cursor];
    };
};

private _side = side _group;
private _range = GVAR(sweepRange);
{
    private _eyes = _x;
    private _seen = if (_enemies isEqualTo []) then {_eyes targets [true, _range]} else {_enemies};
    {
        private _enemy = _x;
        if (!isNull _enemy && {(side _enemy) isNotEqualTo _side} && {(_eyes knowsAbout _enemy) > 0}) then {
            private _pos = _eyes getHideFrom _enemy;
            if (_pos isNotEqualTo [0, 0, 0]) then {
                private _error = ((_eyes targetKnowledge _enemy) param [5, 25]) max 1;
                [_group, _enemy, _pos, _source, _error, 1, 1, "", -1, "unknown", _eyes knowsAbout _enemy] call FUNC(contactReport);
            };
        };
    } forEach _seen;
} forEach _observers;

_picture set ["swept", time];
[_group] call FUNC(pictureRefresh)
