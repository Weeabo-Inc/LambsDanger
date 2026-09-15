#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * May the Director spend on the player element nearest a position right now? Only while
 * that element's pacing is building up (RESEARCH.md C-16), and never with the throttle
 * at zero. With no player element known, spending is allowed.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Position <ARRAY>
 *
 * Return Value:
 * allowed <BOOL>
 *
 * Example:
 * [east, getPos player] call hostis_director_fnc_spendAllowed;
 *
 * Public: No
*/
#define NEAREST_RANGE 1500

params [["_side", sideUnknown, [sideUnknown]], ["_pos", [], [[]]]];

if (GVAR(throttle) <= 0) exitWith {false};
private _state = [_side] call FUNC(sideState);
// a Zeus drew an area of operations: nothing is spent outside it
private _ao = _state get "ao";
if (_ao isNotEqualTo [] && {(_ao select 0) distance2D _pos > (_ao select 1)}) exitWith {false};
private _nearest = [];
private _nearestDistance = NEAREST_RANGE;
{
    private _distance = (_y select 5) distance2D _pos;
    if (_distance < _nearestDistance) then {_nearestDistance = _distance; _nearest = _y;};
} forEach (_state get "pacing");

_nearest isEqualTo [] || {(_nearest select 1) isEqualTo "buildUp"}
