#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * How much fire an element is putting out right now: how many of its men fired within the
 * window and roughly how many rounds a second. The number the bound waits on: the
 * manoeuvre element only moves while the base of fire is achieving volume (C-42).
 *
 * Arguments:
 * 0: Units of the element <ARRAY of OBJECT>
 * 1: Window in seconds, default 4 <NUMBER>
 *
 * Return Value:
 * [men firing, rounds per second] <ARRAY>
 *
 * Example:
 * [units group bob, 4] call hostis_agent_fnc_fireVolume;
 *
 * Public: Yes
*/
params [["_units", [], [[]]], ["_window", 4, [0]]];

private _now = CBA_missionTime;
private _firing = 0;
private _rounds = 0;
{
    if (_now - (_x getVariable [QGVAR(lastFired), -1e9]) < _window) then {
        _firing = _firing + 1;
        private _shots = _x getVariable [QGVAR(shots), [0, 0]];
        if (_now - (_shots select 0) < _window) then {_rounds = _rounds + (_shots select 1);};
    };
} forEach _units;

[_firing, _rounds / (_window max 1)]
