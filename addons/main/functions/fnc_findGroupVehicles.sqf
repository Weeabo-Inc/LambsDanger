#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The land vehicles a group travels in: anything with a group member at the wheel or
 * in a seat, armed or not, that can still move. Unarmed trucks count, unlike
 * findReadyVehicles which only returns vehicles that can fight.
 *
 * Arguments:
 * 0: Unit of the group <OBJECT>
 * 1: Range from the unit <NUMBER>, default 400
 *
 * Return Value:
 * vehicles <ARRAY>
 *
 * Example:
 * [bob] call lambs_main_fnc_findGroupVehicles;
 *
 * Public: Yes
*/
params [["_unit", objNull, [objNull]], ["_range", 400, [0]]];

private _vehicles = ((units _unit) select {!isNull objectParent _x && {_unit distance2D _x < _range}}) apply {vehicle _x};
_vehicles = _vehicles arrayIntersect _vehicles;
_vehicles select {_x isKindOf "LandVehicle" && {alive _x} && {canMove _x}}
