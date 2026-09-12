#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The side's reserve pool: groups with a reserve intent, plus, when the setting allows,
 * idle groups with a free intent that are not in contact, not on a task, not directed
 * by a Zeus and not already released.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Position the reserve is needed at, [] for any <ARRAY>
 *
 * Return Value:
 * reserve groups, nearest first <ARRAY of GROUP>
 *
 * Example:
 * [east, getPos player] call hostis_director_fnc_reserves;
 *
 * Public: Yes
*/
#define RELEASE_COOLDOWN 300

params [["_side", sideUnknown, [sideUnknown]], ["_pos", [], [[]]]];

private _state = [_side] call FUNC(sideState);
private _pool = (_state get "groups") select {
    private _group = _x;
    private _leader = leader _group;
    private _intent = [_group] call LFUNC(danger,intentGet);
    private _picture = [_group] call EFUNC(core,pictureGet);
    !isNull _leader
    && {_leader call LFUNC(main,isAlive)}
    && {!isPlayer _leader}
    && {!(_group call LFUNC(main,isDirected))}
    && {!(_group getVariable [QLGVAR(danger,disableGroupAI), false])}
    && {isNil {_group getVariable QLGVAR(wp,taskSnapshot)}}
    && {time - (_group getVariable [QGVAR(releasedAt), -1e9]) > RELEASE_COOLDOWN}
    && {
        (_intent select 0) isEqualTo "reserve"
        || {GVAR(reservePoolAuto) && {(_intent select 0) isEqualTo "free"} && {(_picture getOrDefault ["escalation", 0]) < 2}}
    }
};

if (_pos isNotEqualTo []) then {
    _pool = _pool select {(leader _x) distance2D _pos < GVAR(reserveRange)};
    _pool = [_pool, [], {(leader _x) distance2D _pos}, "ASCEND"] call BIS_fnc_sortBy;
};

_pool
