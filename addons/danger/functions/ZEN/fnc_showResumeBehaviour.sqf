#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context condition. Shows the resume action when any selected group is on a directed move.
 *
 * Arguments:
 * 0: Selected groups <ARRAY>
 * 1: Selected objects <ARRAY>
 *
 * Return Value:
 * show the action <BOOL>
 *
 * Example:
 * [[group bob], []] call lambs_danger_fnc_showResumeBehaviour;
 *
 * Public: No
*/
private _targets = [];
GET_GROUPS_CONTEXT(_targets);

_targets findIf {_x call EFUNC(main,isDirected)} != -1
