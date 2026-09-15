#include "..\script_component.hpp"
/*
 * Author: bluefield-creator
 * Waypoint script: the group attacks the waypoint position (docs/systems/zeus.md).
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Waypoint position <ARRAY>
 *
 * Return Value:
 * true
*/
params ["_group", "_pos"];

[_group, "attack", _pos] call FUNC(intent);
true
