#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Opens the Director's dials; the clicked position is the area of
 * operations centre.
 *
 * Arguments:
 * 0: Clicked position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [getPos player] call hostis_zeus_fnc_setDirector;
 *
 * Public: No
*/
params [["_position", [], [[]]]];

[_position, clientOwner] call FUNC(dialogDirector);
