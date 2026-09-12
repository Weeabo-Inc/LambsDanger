#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Actualises group level hiding: every man is handed to the per-soldier machine with
 * a cover order (see lambs_main_fnc_doHide), which picks a spot with a roof or a wall
 * between him and the danger, gets him there and brings him back to the leader later.
 *
 * Arguments:
 * 0: units list <ARRAY>
 * 1: danger position <ARRAY> or <OBJECT>
 * 2: reason for hiding (used in debugging) <STRING>
 *
 * Return Value:
 * bool
 *
 * Example:
 * [units bob, angryJoe] call lambs_main_fnc_doGroupHide;
 *
 * Public: No
*/
params ["_units", "_pos", ["_action", "group"]];

// check units
_units = _units select { _x call FUNC(isAlive) && { isNull objectParent _x } && { !isPlayer _x } };
if (_units isEqualTo []) exitWith {false};

{
    if ([_x, _pos] call FUNC(doHide)) then {
        _x setVariable [QEGVAR(main,currentTask), format ["Hide (%1)", _action], EGVAR(main,debug_functions)];
    };
} forEach _units;

// end
true
