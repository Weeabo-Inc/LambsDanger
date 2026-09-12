#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * What a transport helicopter does after the drop: armed, it circles the objective at a
 * distance as fire support; unarmed, it flies back to where it took off and holds there.
 *
 * Arguments:
 * 0: Aircrew group <GROUP>
 * 1: Helicopter <OBJECT>
 * 2: Objective position AGL <ARRAY>
 * 3: Position to return to <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group pilot, heli, getPos angryJoe, getPos base] call lambs_wp_fnc_doAirLoiter;
 *
 * Public: No
*/
#define LOITER_RADIUS 300
#define LOITER_ALTITUDE 120
#define HOLD_RADIUS 200

params [["_airGroup", grpNull, [grpNull]], ["_heli", objNull, [objNull]], ["_objective", [], [[]]], ["_start", [], [[]]]];

if (isNull _airGroup || {isNull _heli} || {!alive _heli}) exitWith {};

[_airGroup] call CBA_fnc_clearWaypoints;
_airGroup setBehaviour "AWARE";
_airGroup setVariable [QEGVAR(danger,disableGroupAI), true, true];
_heli flyInHeight LOITER_ALTITUDE;

private _crew = (crew _heli) select {(group _x) isEqualTo _airGroup};
private _armed = someAmmo _heli && {(_crew findIf {_x isEqualTo (gunner _heli) || {(_heli unitTurret _x) isNotEqualTo []}}) isNotEqualTo -1};

if (_armed && {_objective isNotEqualTo []}) then {
    private _wp = _airGroup addWaypoint [_objective, 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterType "CIRCLE_L";
    _wp setWaypointLoiterRadius LOITER_RADIUS;
    _airGroup setCombatMode "RED";
    {_x setVariable [QEGVAR(main,currentTask), "Air support (loiter)", EGVAR(main,debug_functions)];} forEach _crew;
} else {
    if (_start isEqualTo []) then {_start = getPosATL _heli;};
    private _wp = _airGroup addWaypoint [_start, 0];
    _wp setWaypointType "MOVE";
    private _hold = _airGroup addWaypoint [_start, 0];
    _hold setWaypointType "LOITER";
    _hold setWaypointLoiterRadius HOLD_RADIUS;
    _airGroup setCombatMode "YELLOW";
    {_x setVariable [QEGVAR(main,currentTask), "Returning to base", EGVAR(main,debug_functions)];} forEach _crew;
};
