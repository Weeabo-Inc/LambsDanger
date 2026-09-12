#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Answers the side's reinforcement requests: a group that broke contact or is breaking
 * asks for help (lambs_danger_reinforceRequest); the Director releases one reserve toward
 * the requester's threat, from a bearing other than the requester's own, when the budget
 * and the pacing allow. One release per think per side.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * the group released, grpNull when none <GROUP>
 *
 * Example:
 * [east] call hostis_director_fnc_reinforce;
 *
 * Public: No
*/
#define REQUEST_AGE 60
#define RELEASE_INTERVAL 45

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
if (time - (_state get "lastRelease") < RELEASE_INTERVAL) exitWith {grpNull};

private _requests = (_state get "groups") select {
    private _request = _x getVariable [QLGVAR(danger,reinforceRequest), []];
    _request isNotEqualTo [] && {time - (_request select 0) < REQUEST_AGE}
};
if (_requests isEqualTo []) exitWith {grpNull};

// the oldest request first
_requests = [_requests, [], {(_x getVariable QLGVAR(danger,reinforceRequest)) select 0}, "ASCEND"] call BIS_fnc_sortBy;
private _requester = _requests select 0;
(_requester getVariable QLGVAR(danger,reinforceRequest)) params ["", "_threatPos"];
_requester setVariable [QLGVAR(danger,reinforceRequest), nil];
if (_threatPos isEqualTo []) exitWith {grpNull};

// spending waits for the pacing (docs/systems/director.md, Pacing)
if (!([_side, _threatPos] call FUNC(spendAllowed))) exitWith {
    [_side, format ["%1 asked for help; holding the reserve during the lull", groupId _requester]] call FUNC(log);
    grpNull
};

private _error = 100;
private _cluster = (_state get "board") select {(_x select 0) distance2D _threatPos < 150};
if (_cluster isNotEqualTo []) then {_error = ((_cluster select 0) select 5) max 50;};
private _avoid = _threatPos getDir (leader _requester);
[_side, _threatPos, _error, format ["reinforce %1", groupId _requester], _avoid] call FUNC(release)
