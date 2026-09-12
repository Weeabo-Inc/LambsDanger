#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One step of moving a team along a route in a free-form shape, independent of the
 * engine formation: the first unit leads on the route point, the others take slots
 * relative to it (wedge, line or file). Called every few seconds by whoever owns
 * the team (see tacticsManeuver); keeps no state of its own beyond the route index.
 * With no contact for a while and no objective the team walks its slots in a tight
 * shape; otherwise every man's slot is an order to the per-soldier machine, which gets
 * him there from cover to cover and, in a settlement, from house to house.
 *
 * Arguments:
 * 0: Units <ARRAY>
 * 1: Route positions <ARRAY>
 * 2: Index of the current route point <NUMBER>
 * 3: Shape "wedge", "line" or "file" <STRING>
 * 4: Spacing in metres <NUMBER>
 * 5: Facing at the end of the route, position or [] <ARRAY>
 * 6: Threat positions AGL, [] for the group's picture <ARRAY>
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
#define QUIET_TIME 90
#define SETTLEMENT_RANGE 40

params [["_units", [], [[]]], ["_route", [], [[]]], ["_index", 0, [0]], ["_shape", "wedge", [""]], ["_spacing", 4, [0]], ["_facing", [], [[]]], ["_threats", [], [[]]]];

_units = _units select {_x call FUNC(isAlive) && {isNull objectParent _x} && {(_x getVariable [QGVAR(survival), 0]) < time}};
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

// how the men move: a tight shape while nothing has happened, cover to cover once something has
private _picture = (group _lead) getVariable QEGVAR(danger,picture);
private _contact = !isNil "_picture" && {time - (_picture get "lastContact") < QUIET_TIME};
if (_threats isEqualTo [] && {_contact}) then {
    private _threatPos = _picture get "threatPos";
    if (_threatPos isNotEqualTo []) then {_threats = [_threatPos];};
};
private _settlement = ([_point, SETTLEMENT_RANGE, false, false] call FUNC(findBuildings)) isNotEqualTo [];
private _careful = _contact || _settlement || {_facing isNotEqualTo []};
private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
private _options = createHashMapFromArray [["onArrive", "hold"], ["indoorBias", _settlement], ["task", "Moving with the team"]];

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
    if (_careful && {!isNil "_order"}) then {
        // the machine walks him there between cover and settles him behind something at the end
        private _slotThreats = if (_threats isEqualTo [] && {_facing isNotEqualTo []}) then {[_facing]} else {_threats};
        [_x, "move", _slot, _slotThreats, _options] call _order;
    } else {
        // a plain walk: the machine lets go of anyone it still holds from a careful leg
        if (([_x, "state", "Idle"] call EFUNC(danger,unitState)) isNotEqualTo "Idle") then {[_x, false] call EFUNC(danger,unitRelease);};
        if (_x distance2D _slot > SLOT_TOLERANCE) then {
            _x doMove _slot;
        } else {
            if (_last && {_facing isNotEqualTo []}) then {_x doWatch _facing;};
        };
    };
} forEach _units;

// arrived when the whole team is on the last point
private _arrived = _last && {(_units findIf {_x distance2D _point > (_spacing * ceil ((count _units) / 2)) + POINT_REACHED}) isEqualTo -1};

[_arrived, _index]
