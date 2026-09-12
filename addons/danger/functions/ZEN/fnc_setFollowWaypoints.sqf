#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action. Puts the selected groups on a directed move along their current
 * waypoint; a group without a waypoint gets a MOVE waypoint at the clicked position.
 *
 * Arguments:
 * 0: Selected groups <ARRAY>
 * 1: Selected objects <ARRAY>
 * 2: Clicked position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [[group bob], [], getPos bob] call lambs_danger_fnc_setFollowWaypoints;
 *
 * Public: No
*/
private _position = _this param [2, [], [[]]];
private _targets = [];
GET_GROUPS_CONTEXT(_targets);

{
    private _group = _x;
    private _leader = leader _group;
    if (isNull _leader || {isPlayer _leader}) then {continue};

    // no waypoint left ~ make one where the Zeus clicked
    private _wpIndex = currentWaypoint _group;
    if (_wpIndex >= count (waypoints _group)) then {
        if (_position isEqualTo []) then {continue};
        private _waypoint = _group addWaypoint [_position, 0];
        _waypoint setWaypointType "MOVE";
        _wpIndex = _waypoint select 1;
    };

    [QGVAR(directedMove), [_group, _wpIndex, clientOwner], _leader] call CBA_fnc_targetEvent;
} forEach _targets;
