#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A call for fire (RESEARCH.md C-52, C-53). An observing group asks for fire on a position
 * it holds in its own picture with the error it has; the Director checks the budget, the
 * guns, the pacing, danger close and the observer's error, and queues the mission. The
 * mission then runs through the adjust-and-effect sequence in fireMissions. With no
 * observer (counter-battery, a Zeus or a script) the position is taken as given.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Target position <ARRAY>
 * 2: Error radius in metres <NUMBER>
 * 3: Reason, for the log <STRING>
 * 4: Observing group, grpNull for none <GROUP>
 * 5: Do not fire before this time, default now <NUMBER>
 *
 * Return Value:
 * queued <BOOL>
 *
 * Example:
 * [east, getPos player, 40, "leader request", group bob] call hostis_director_fnc_fireRequest;
 *
 * Public: Yes
*/
#define MAX_ACTIVE 4
#define SAME_TARGET 150

params [["_side", sideUnknown, [sideUnknown]], ["_pos", [], [[]]], ["_error", 50, [0]], ["_reason", "", [""]], ["_observer", grpNull, [grpNull]], ["_notBefore", -1, [0]]];

if (!GVAR(enabled) || {_pos isEqualTo []} || {!isServer}) exitWith {false};
private _state = [_side] call FUNC(sideState);
private _budget = _state get "budget";
private _fnc_refuse = {
    [_side, format ["fire mission refused (%1): %2", _this, _reason]] call FUNC(log);
    false
};

if ((_budget get "fireMissions") <= 0) exitWith {"no budget" call _fnc_refuse};
if (!LGVAR(main,Loaded_WP) || {!([_side, _pos] call LFUNC(wp,sideHasArtillery))}) exitWith {"no gun in range" call _fnc_refuse};
if (!isNull _observer && {_error > GVAR(observerError)}) exitWith {format ["observer error %1 m", round _error] call _fnc_refuse};
private _active = (_state get "missions") select {(_x get "state") in ["requested", "adjusting", "effect"]};
if (count _active >= MAX_ACTIVE) exitWith {"too many missions" call _fnc_refuse};
if ((_active findIf {(_x get "pos") distance2D _pos < SAME_TARGET}) isNotEqualTo -1) exitWith {"already targeted" call _fnc_refuse};
if (!([_side, _pos] call FUNC(spendAllowed))) exitWith {"lull" call _fnc_refuse};

// danger close: none of ours near it
private _close = false;
{
    if (((units _x) findIf {_x call LFUNC(main,isAlive) && {_x distance2D _pos < GVAR(dangerClose)}}) isNotEqualTo -1) exitWith {_close = true;};
} forEach (_state get "groups");
if (_close) exitWith {"danger close" call _fnc_refuse};

GVAR(missionId) = GVAR(missionId) + 1;
private _mission = createHashMapFromArray [
    ["id", GVAR(missionId)],
    ["side", _side],
    ["observer", _observer],
    ["pos", _pos],
    ["error", _error],
    ["state", "requested"],
    ["since", time],
    ["notBefore", [time, _notBefore] select (_notBefore > 0)],
    ["reason", _reason],
    ["rounds", 0]
];
(_state get "missions") pushBack _mission;
_budget set ["fireMissions", (_budget get "fireMissions") - 1];
(_state get "spent") set ["fireMissions", ((_state get "spent") get "fireMissions") + 1];
[_side, format ["fire mission %1 queued on %2 (error %3 m, observer %4): %5; %6 missions left", GVAR(missionId), mapGridPosition _pos, round _error, ["none", groupId _observer] select (!isNull _observer), _reason, _budget get "fireMissions"]] call FUNC(log);

true
