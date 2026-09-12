#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One line of the Director's reasoning, in plain language, kept for the overlay and
 * the report and written to the RPT when debugging (RESEARCH.md C-19).
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Line <STRING>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east, "released Bravo toward the compound"] call hostis_director_fnc_log;
 *
 * Public: No
*/
params [["_side", sideUnknown, [sideUnknown]], ["_line", "", [""]]];

private _state = [_side] call FUNC(sideState);
private _log = _state get "log";
_log pushBack format ["%1 %2", round time, _line];
if (count _log > 12) then {_log deleteAt 0;};
if (DIRECTOR_DEBUG) then {["%1 DIRECTOR: %2", _side, _line] call LFUNC(main,debugLog);};
