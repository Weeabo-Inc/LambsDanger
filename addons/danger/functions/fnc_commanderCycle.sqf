#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One tick of the commander on this machine: the side board every ten seconds, then a
 * bounded number of registered groups get their think, round robin, each every five
 * seconds. A group that is gone, no longer local, empty, or idle and free for a long time
 * is dropped and unpinned (ADR-0007).
 *
 * Arguments:
 * None
 *
 * Return Value:
 * groups thought this tick <NUMBER>
 *
 * Example:
 * call lambs_danger_fnc_commanderCycle;
 *
 * Public: No
*/
#define GROUPS_PER_TICK 8
#define GROUP_INTERVAL 5
#define SIDE_INTERVAL 10
#define IDLE_DROP 900

private _groups = GVAR(commanderGroups);
if (_groups isEqualTo []) exitWith {0};

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
            // free for a load balancer again (ADR-0007); a group that left this machine is unpinned by its new owner
            if (local _group) then {
                _group setVariable ["hostis_pinned", nil, true];
                {_x setVariable ["ace_headless_blacklist", nil, true];} forEach (units _group);
            };
        };
    } else {
        if (time > (_group getVariable [QGVAR(commanderNext), 0])) then {
            _group setVariable [QGVAR(commanderNext), time + GROUP_INTERVAL + random 2];
            [_group] call FUNC(commanderGroup);
            _done = _done + 1;
        };
    };
};

_done
