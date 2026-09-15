#include "..\script_component.hpp"
/*
 * Author: bluefield-creator
 * Waypoint script: the group goes to the waypoint and waits there as a reserve for the
 * Director (docs/systems/zeus.md).
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Waypoint position <ARRAY>
 *
 * Return Value:
 * true
*/
params ["_group", "_pos"];

_group move _pos;
[_group, "reserve", _pos] call FUNC(intent);
true
