#include "script_component.hpp"

private _targets = [];
GET_GROUPS_CONTEXT(_targets);

{
    [QGVAR(taskReset), [_x, true, true], leader _x] call CBA_fnc_targetEvent;
} forEach _targets;
