#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The Director's reasoning as plain text, for the Zeus overlay, the Diagnose module and
 * the tests: budgets, pacing per player element, the board, the missions, the last
 * decisions.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * report lines <ARRAY of STRING>
 *
 * Example:
 * [east] call hostis_director_fnc_report;
 *
 * Public: Yes
*/
params [["_side", sideUnknown, [sideUnknown]]];

private _state = GVAR(sides) get _side;
if (isNil "_state") exitWith {[format ["Director %1: not running", _side]]};
private _budget = _state get "budget";
private _spent = _state get "spent";
private _lines = [];
_lines pushBack format ["Director %1: %2 groups, %3 reserves; reinforcements %4 left (%5 spent), fire missions %6 left (%7 spent); throttle %8",
    _side, count (_state get "groups"), count ([_side] call FUNC(reserves)),
    _budget get "reinforcements", _spent get "reinforcements", _budget get "fireMissions", _spent get "fireMissions", GVAR(throttle)];
private _ao = _state get "ao";
if (_ao isNotEqualTo []) then {_lines pushBack format ["  area of operations: %1 m around %2", round (_ao select 1), mapGridPosition (_ao select 0)];};
if (_state get "hug") then {_lines pushBack "  hugging: the enemy has indirect fire or air";};
{
    _y params ["_intensity", "_pstate", "_since"];
    _lines pushBack format ["  pacing: element %1 %2 for %3 s, intensity %4", _x, _pstate, round (time - _since), _intensity toFixed 2];
} forEach (_state get "pacing");
{
    _x params ["_pos", "_strength", "_confidence", "_age", "_reporters", "_error"];
    _lines pushBack format ["  board: %1 x%2 at %3, confidence %4, %5 s old, error %6 m, %7 reporter(s)", mapGridPosition _pos, _strength, mapGridPosition _pos, _confidence toFixed 2, round _age, round _error, count _reporters];
} forEach (_state get "board");
{
    _lines pushBack format ["  mission %1: %2 on %3 (%4)", _x get "id", _x get "state", mapGridPosition (_x get "pos"), _x get "reason"];
} forEach (_state get "missions");
{
    _y params ["_pos", "", "_since", "_group", "_done"];
    _lines pushBack format ["  fallen: %1 (%2), %3 s ago%4", mapGridPosition _pos, groupId _group, round (time - _since), ["", ", counterattacked"] select _done];
} forEach (_state get "fallen");
{_lines pushBack ("  " + _x);} forEach (_state get "log");

_lines
