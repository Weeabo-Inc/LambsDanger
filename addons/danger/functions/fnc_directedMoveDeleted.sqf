#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Keeps a Zeus directed move consistent after the curator deleted one of the group's
 * waypoints. Deleting re-indexes the remaining waypoints.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Index of the waypoint that was deleted <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob, 0] call lambs_danger_fnc_directedMoveDeleted;
 *
 * Public: No
*/
params [["_group", grpNull, [grpNull]], ["_wpIndex", -1, [0]]];

if (isNull _group || {!local _group} || {_wpIndex < 0}) exitWith {};

private _state = _group getVariable [QGVAR(directedMove), []];
if (_state isEqualTo []) exitWith {};
_state params ["_stateIndex"];

// deleted the one we follow ~ take the waypoint that slid into its place, or stop
if (_wpIndex isEqualTo _stateIndex) exitWith {
    private _waypoints = waypoints _group;
    if (_stateIndex < count _waypoints && {!((waypointType (_waypoints select _stateIndex)) in ["CYCLE", "SCRIPTED"])}) then {
        private _newPos = waypointPosition (_waypoints select _stateIndex);
        _state set [1, _newPos];
        _group setVariable [QGVAR(directedMove), _state, true];
        _group setVariable [QGVAR(directedProgress), [(leader _group) distance2D _newPos, CBA_missionTime, 0, false]];
        _group setCurrentWaypoint [_group, _stateIndex];
    } else {
        [_group, "waypoint deleted"] call FUNC(directedMoveRelease);
    };
};

// deleted an earlier one ~ ours moved down by one
if (_wpIndex < _stateIndex) then {
    _state set [0, _stateIndex - 1];
    _group setVariable [QGVAR(directedMove), _state, true];
};
