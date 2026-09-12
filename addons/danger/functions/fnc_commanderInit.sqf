#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Starts the AI commander on this machine: one per frame handler that gives each
 * registered local group a think every few seconds, a few groups per second, and
 * refreshes the side board (threat clusters, roles, reinforcements) every ten.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call lambs_danger_fnc_commanderInit;
 *
 * Public: No
*/
#define TICK 1
#define GROUPS_PER_TICK 8
#define GROUP_INTERVAL 5
#define SIDE_INTERVAL 10
#define IDLE_DROP 900

if (!isNil QGVAR(commanderPFH)) exitWith {};
GVAR(commanderGroups) = [];
GVAR(commanderCursor) = 0;
GVAR(commanderSideNext) = 0;

GVAR(commanderPFH) = [{
    if (!GVAR(commander)) exitWith {};
    private _groups = GVAR(commanderGroups);
    if (_groups isEqualTo []) exitWith {};

    // side board
    if (time > GVAR(commanderSideNext)) then {
        GVAR(commanderSideNext) = time + SIDE_INTERVAL;
        private _sides = [];
        {
            if (!isNull _x) then {_sides pushBackUnique (side _x);};
        } forEach _groups;
        {[_x] call FUNC(commanderSide);} forEach _sides;
    };

    // groups ~ round robin, a few per tick
    private _count = count _groups;
    private _done = 0;
    private _checked = 0;
    while {_done < GROUPS_PER_TICK && {_checked < _count}} do {
        private _index = GVAR(commanderCursor) % _count;
        GVAR(commanderCursor) = _index + 1;
        _checked = _checked + 1;
        private _group = _groups select _index;

        private _drop = isNull _group || {!local _group} || {(units _group) isEqualTo []}
            || {time - (([_group] call FUNC(pictureGet)) get "lastContact") > IDLE_DROP && {(([_group] call FUNC(intentGet)) select 0) isEqualTo "free"}};
        if (_drop) then {
            _groups deleteAt _index;
            _count = _count - 1;
            if (!isNull _group) then {
                _group setVariable [QGVAR(role), nil];
                _group setVariable [QGVAR(commanderNext), nil];
            };
        } else {
            if (time > (_group getVariable [QGVAR(commanderNext), 0])) then {
                _group setVariable [QGVAR(commanderNext), time + GROUP_INTERVAL + random 2];
                [_group] call FUNC(commanderGroup);
                _done = _done + 1;
            };
        };
    };
}, TICK, []] call CBA_fnc_addPerFrameHandler;
