#include "script_component.hpp"
/*
 * Author: diwako, bluefield-creator
 * Returns position and stance of cover near a unit. Kept for compatibility: the work
 * is done by the tactical position system (lambs_main_fnc_findPositions).
 *
 * Arguments:
 * 0: Unit seeking cover <OBJECT>
 * 1: Enemy <OBJECT> or Enemy Position (AGL) <ARRAY>
 * 2: Range to find cover, default 15 <NUMBER>
 * 3: Sort mode <STRING>, default "ASCEND": ASCEND nearest first, DESCEND best first, RANDOM shuffled
 * 4: Max Results <Number>, default 1, -1 for all
 *
 * Return Value:
 * Array of format [_posAGL, _stance], when no cover found then an empty array is returned
 * Stance can be "UP", "MIDDLE" or "DOWN"
 *
 * Example:
 * [bob, angryJoe, 50] call lambs_main_fnc_findCover
 *
 * Public: Yes
*/
params [
    ["_unit", objNull, [objNull]],
    ["_enemy", objNull, [objNull, []]],
    ["_range", 15, [0]],
    ["_sortMode", "ASCEND", [""]],
    ["_maxResults", 1, [0]]
];

_maxResults = floor _maxResults;
if (_maxResults isEqualTo 0 || {isNull _unit}) exitWith {[]};

private _threat = _enemy call CBA_fnc_getPos;
private _threats = [[_threat], []] select (_threat isEqualTo [0, 0, 0]);
private _options = createHashMapFromArray [["purpose", "fight"], ["unit", _unit], ["count", [_maxResults, 12] select (_maxResults < 0)]];
private _positions = [getPosATL _unit, _range, _threats, _options] call FUNC(findPositions);

// no real cover is no cover
_positions = _positions select {(_x select 1) > 0};
switch (_sortMode) do {
    case "ASCEND": {_positions = [_positions, [], {_unit distance2D (_x select 0)}, "ASCEND"] call BIS_fnc_sortBy;};
    case "RANDOM": {_positions = _positions call BIS_fnc_arrayShuffle;};
};

_positions apply {[_x select 0, _x select 3]}
