#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The AI groups a Zeus may direct, nearest to a position first: led by a live AI, no
 * player in them, on a playing side (ADR-0006).
 *
 * Arguments:
 * 0: Position, [] for no sorting <ARRAY>
 *
 * Return Value:
 * groups <ARRAY of GROUP>
 *
 * Example:
 * [getPos player] call hostis_zeus_fnc_groupsNear;
 *
 * Public: No
*/
params [["_pos", [], [[]]]];

private _groups = allGroups select {
    private _leader = leader _x;
    !isNull _leader
    && {alive _leader}
    && {!isPlayer _leader}
    && {(units _x) findIf {isPlayer _x} isEqualTo -1}
    && {(side _x) in [west, east, independent]}
};
if (_pos isNotEqualTo []) then {
    _groups = [_groups, [], {(leader _x) distance2D _pos}, "ASCEND"] call BIS_fnc_sortBy;
};

_groups
