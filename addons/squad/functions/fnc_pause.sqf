#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The Zeus brake: pauses or resumes the squad layer everywhere. Pausing resets every
 * local group's tactic within the frame and stops the planner; resuming lets the
 * commander plan again on its next think. Broadcast with the second argument.
 *
 * Arguments:
 * 0: Paused <BOOL>
 * 1: Broadcast to every machine, default true <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call hostis_squad_fnc_pause;
 *
 * Public: Yes
*/
params [["_paused", true, [false]], ["_broadcast", true, [false]]];

if (_broadcast) exitWith {[QGVAR(pause), [_paused]] call CBA_fnc_globalEvent;};

GVAR(paused) = _paused;
if (_paused) then {
    {
        if (local _x && {!isNil {_x getVariable QGVAR(tactic)}}) then {
            [_x, "paused", "now"] call FUNC(tacticReset);
        };
    } forEach allGroups;
};
if (SQUAD_DEBUG) then {["SQUAD %1", ["resumed", "PAUSED"] select _paused] call LFUNC(main,debugLog);};
