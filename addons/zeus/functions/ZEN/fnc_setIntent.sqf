#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Opens the intent dialog for the selected groups; the clicked
 * position is the objective.
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
 * [[group bob], [], getPos bob] call hostis_zeus_fnc_setIntent;
 *
 * Public: No
*/
params [["_groups", [], [[]]], ["_objects", [], [[]]], ["_position", [], [[]]]];

private _targets = +_groups;
{_targets pushBackUnique (group _x);} forEach _objects;
_targets = _targets select {!isNull (leader _x) && {!isPlayer (leader _x)}};
if (_targets isEqualTo []) exitWith {};

[_targets, _position, clientOwner, false] call FUNC(dialogIntent);
