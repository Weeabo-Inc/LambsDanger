#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The Director's state for one side, created on first use with the budgets from the
 * settings (docs/systems/director.md).
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * state <HASHMAP>
 *
 * Example:
 * [east] call hostis_director_fnc_sideState;
 *
 * Public: Yes
*/
params [["_side", sideUnknown, [sideUnknown]]];

private _state = GVAR(sides) get _side;
if (isNil "_state") then {
    _state = createHashMapFromArray [
        ["side", _side],
        ["groups", []],
        ["board", []],
        ["budget", createHashMapFromArray [["reinforcements", GVAR(reinforcements)], ["fireMissions", GVAR(fireMissions)]]],
        ["spent", createHashMapFromArray [["reinforcements", 0], ["fireMissions", 0]]],
        ["pacing", createHashMap],
        ["influence", createHashMap],
        ["missions", []],
        ["artilleryLog", []],
        ["counterBatteryDone", []],
        ["fallen", createHashMap],
        ["routes", createHashMap],
        ["lastLosses", createHashMap],
        ["log", []],
        ["lastThink", -1e9],
        ["lastRelease", -1e9]
    ];
    GVAR(sides) set [_side, _state];
};

_state
