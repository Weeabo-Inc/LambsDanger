#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The fighting positions a building offers, worked out once and cached on the building
 * itself: every building position with whether it is under a roof and which floor it
 * is on. The threat-independent half of the tactical position system, so a query in a
 * village does not re-scan the same houses every few seconds.
 *
 * Arguments:
 * 0: Building <OBJECT>
 *
 * Return Value:
 * positions, each [positionAGL, indoor, floor] <ARRAY>
 *
 * Example:
 * [nearestBuilding bob] call lambs_main_fnc_findPositionsBuilding;
 *
 * Public: No
*/
#define CACHE_TIME 600
#define ROOF_CHECK 6
#define FLOOR_HEIGHT 3

params [["_building", objNull, [objNull]]];

if (isNull _building || {!alive _building} || {isObjectHidden _building}) exitWith {[]};

private _cache = _building getVariable [QGVAR(tps), []];
if (_cache isNotEqualTo [] && {time - (_cache select 0) < CACHE_TIME}) exitWith {_cache select 1};

private _base = (getPosASL _building) select 2;
private _positions = (_building buildingPos -1) apply {
    private _posASL = AGLToASL _x;
    [_x, lineIntersects [_posASL vectorAdd [0, 0, 0.5], _posASL vectorAdd [0, 0, ROOF_CHECK]], floor (((_posASL select 2) - _base) / FLOOR_HEIGHT) max 0]
};
_building setVariable [QGVAR(tps), [time, _positions]];

_positions
