#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One tick of the morale handler: a bounded number of the commander's groups, each man's
 * state then the group's cohesion. Groups nobody has registered with the commander are
 * left to the engine's own suppression.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call hostis_agent_fnc_moraleCycle;
 *
 * Public: No
*/
#define GROUPS_PER_TICK 10

private _groups = missionNamespace getVariable [QLGVAR(danger,commanderGroups), []];
_groups = _groups select {!isNull _x && {local _x}};
if (_groups isEqualTo []) exitWith {};

private _count = count _groups;
private _cursor = GVAR(moraleCursor) mod _count;
for "_i" from 1 to (GROUPS_PER_TICK min _count) do {
    private _group = _groups select _cursor;
    _cursor = (_cursor + 1) mod _count;
    {
        if (_x call LFUNC(main,isAlive)) then {[_x] call FUNC(moraleState);};
    } forEach (units _group);
    [_group] call FUNC(cohesion);
};
GVAR(moraleCursor) = _cursor;
