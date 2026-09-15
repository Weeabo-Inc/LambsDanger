#include "..\script_component.hpp"
/*
 * Author: bluefield-creator
 * Waypoint script: the group defends the waypoint (docs/systems/zeus.md).
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Waypoint position <ARRAY>
 *
 * Return Value:
 * true
*/
params ["_group", "_pos"];

[_group, "defend", _pos] call FUNC(intent);
true
