#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Ends the directed move of the selected groups and hands them back to LAMBS.
 *
 * Arguments:
 * 0: Selected groups <ARRAY>
 * 1: Selected objects <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [[group bob], []] call lambs_danger_fnc_setResumeBehaviour;
 *
 * Public: No
*/
private _targets = [];
GET_GROUPS_CONTEXT(_targets);

{
    [QGVAR(directedRelease), [_x, "zeus"], leader _x] call CBA_fnc_targetEvent;
} forEach (_targets select {_x call EFUNC(main,isDirected)});
