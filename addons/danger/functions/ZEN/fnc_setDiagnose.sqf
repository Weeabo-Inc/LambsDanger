#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Asks the owner of each selected group why the group may not be
 * moving; the report comes back as a hint and on the clipboard.
 *
 * Arguments:
 * 0: Selected groups <ARRAY>
 * 1: Selected objects <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [[group bob], []] call lambs_danger_fnc_setDiagnose;
 *
 * Public: No
*/
private _targets = [];
GET_GROUPS_CONTEXT(_targets);

{
    [QGVAR(diagnose), [_x, clientOwner], leader _x] call CBA_fnc_targetEvent;
} forEach (_targets select {!isNull (leader _x)});
