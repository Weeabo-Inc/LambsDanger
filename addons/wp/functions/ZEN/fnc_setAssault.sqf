#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Sends the selected groups on a rushing assault to the clicked position.
 *
 * Arguments:
 * 0: Selected groups <ARRAY>
 * 1: Selected objects <ARRAY>
 * 2: Clicked position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [[group bob], [], getPos angryJoe] call lambs_wp_fnc_setAssault;
 *
 * Public: No
*/
private _position = _this param [2, [], [[]]];
if (_position isEqualTo []) exitWith {};

private _targets = [];
GET_GROUPS_CONTEXT(_targets);

{
    [QGVAR(taskAssault), [_x, _position], leader _x] call CBA_fnc_targetEvent;
} forEach _targets;
