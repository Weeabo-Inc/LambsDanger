#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One step of moving a team along a route in a free-form shape, independent of the
 * engine formation: the first unit leads on the route point, the others take slots
 * relative to it (wedge, line or file). Called every few seconds by whoever owns
 * the team (see tacticsManeuver); keeps no state of its own beyond the route index.
 *
 * Arguments:
 * 0: Units <ARRAY>
 * 1: Route positions <ARRAY>
 * 2: Index of the current route point <NUMBER>
 * 3: Shape "wedge", "line" or "file" <STRING>
 * 4: Spacing in metres <NUMBER>
 * 5: Facing at the end of the route, position or [] <ARRAY>
 *
 * Return Value:
 * [arrived at the end of the route, new route index] <ARRAY>
 *
 * Example:
 * [[bob, joe], [getPos angryJoe], 0, "wedge", 4, getPos angryJoe] call lambs_main_fnc_doTeamMove;
 *
 * Public: No
*/
#define POINT_REACHED 10
#define SLOT_TOLERANCE 3

params [["_units", [], [[]]], ["_route", [], [[]]], ["_index", 0, [0]], ["_shape", "wedge", [""]], ["_spacing", 4, [0]], ["_facing", [], [[]]]];

_units = _units select {_x call FUNC(isAlive) && {isNull objectParent _x}};
if (_units isEqualTo [] || {_route isEqualTo []}) exitWith {[true, _index]};
_index = _index min ((count _route) - 1);

private _lead = _units select 0;
private _point = _route select _index;
private _last = _index isEqualTo ((count _route) - 1);

// advance along the route
if (_lead distance2D _point < POINT_REACHED && {!_last}) then {
    _index = _index + 1;
    _point = _route select _index;
    _last = _index isEqualTo ((count _route) - 1);
};

// direction the shape faces: onwards along the route, or the given facing at the end
private _direction = if (_last && {_facing isNotEqualTo []}) then {_point getDir _facing} else {_lead getDir _point};
if (_lead distance2D _point < 2) then {_direction = getDir _lead;};

// slots
{
    private _slot = if (_forEachIndex isEqualTo 0) then {_point} else {
        private _row = ceil (_forEachIndex / 2);
        private _side = [90, -90] select ((_forEachIndex % 2) isEqualTo 1);
        switch (_shape) do {
            case "line": {_point getPos [_spacing * _row, _direction + _side]};
            case "file": {_point getPos [_spacing * _forEachIndex, _direction + 180]};
            default {(_point getPos [_spacing * _row * 0.7, _direction + 180]) getPos [_spacing * _row, _direction + _side]};
        }
    };
    if (_x distance2D _slot > SLOT_TOLERANCE) then {
        _x doMove _slot;
    } else {
        if (_last && {_facing isNotEqualTo []}) then {_x doWatch _facing;};
    };
} forEach _units;

// arrived when the whole team is on the last point
private _arrived = _last && {(_units findIf {_x distance2D _point > (_spacing * ceil ((count _units) / 2)) + POINT_REACHED}) isEqualTo -1};

[_arrived, _index]
