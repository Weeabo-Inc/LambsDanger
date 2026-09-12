#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One think of the fire mission queue (RESEARCH.md C-52): a queued mission fires one
 * adjusting round at the reported position with its error; after the time of flight the
 * observer must still be alive and still hold the contact with a small enough error,
 * then the corrected position gets fire for effect; otherwise the mission is cancelled
 * and the log says why. Missions without an observer fire for effect on the given
 * position after their delay.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east] call hostis_director_fnc_fireMissions;
 *
 * Public: No
*/
#define ADJUST_TIME 35
#define EFFECT_TIME 60
#define KEEP_TIME 180
#define OBSERVER_AGE 60
#define OBSERVER_RANGE 200
#define EFFECT_ROUNDS 4
#define SPREAD 40

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _missions = _state get "missions";

{
    private _mission = _x;
    private _mstate = _mission get "state";
    private _since = _mission get "since";
    private _observer = _mission get "observer";
    private _pos = _mission get "pos";
    private _id = _mission get "id";
    private _caller = if (isNull _observer) then {objNull} else {leader _observer};

    switch (_mstate) do {
        case "requested": {
            if (time >= (_mission get "notBefore")) then {
                if (isNull _observer) then {
                    // no observer to adjust: straight to effect on the given area
                    private _aim = _pos getPos [random ((_mission get "error") * 0.5), random 360];
                    [_side, _aim, objNull, EFFECT_ROUNDS, SPREAD, true] call LFUNC(wp,taskArtillery);
                    _mission set ["state", "effect"];
                    _mission set ["since", time];
                    [_side, format ["fire mission %1: fire for effect on %2", _id, mapGridPosition _aim]] call FUNC(log);
                } else {
                    private _aim = _pos getPos [random (_mission get "error"), random 360];
                    [_side, _aim, _caller, 1, SPREAD, true] call LFUNC(wp,taskArtillery);
                    _mission set ["state", "adjusting"];
                    _mission set ["since", time];
                    _mission set ["aim", _aim];
                    [_side, format ["fire mission %1: adjusting round, %2 observing", _id, groupId _observer]] call FUNC(log);
                };
            };
        };
        case "adjusting": {
            if (time - _since > ADJUST_TIME) then {
                private _alive = !isNull _observer && {!isNull leader _observer} && {(leader _observer) call LFUNC(main,isAlive)};
                private _contact = [];
                if (_alive) then {
                    _contact = ([_observer, OBSERVER_AGE, 0.3, [], _pos, OBSERVER_RANGE] call EFUNC(core,contactsGet)) select {(_x select CONTACT_ERROR) <= GVAR(observerError)};
                };
                if (_contact isEqualTo []) then {
                    _mission set ["state", "cancelled"];
                    _mission set ["since", time];
                    [_side, format ["fire mission %1 cancelled: %2", _id, ["observer lost", "observer no longer holds the target"] select _alive]] call FUNC(log);
                } else {
                    private _corrected = (_contact select 0) select CONTACT_POS;
                    private _shift = round (_corrected distance2D (_mission get "aim"));
                    private _aim = _corrected getPos [random ((_contact select 0) select CONTACT_ERROR) * 0.5, random 360];
                    [_side, _aim, _caller, EFFECT_ROUNDS, SPREAD, true] call LFUNC(wp,taskArtillery);
                    _mission set ["state", "effect"];
                    _mission set ["since", time];
                    _mission set ["pos", _corrected];
                    [_side, format ["fire mission %1: correction %2 m, fire for effect", _id, _shift]] call FUNC(log);
                    [leader _observer, "combat", "SupportRequestRGArty", 75] call LFUNC(main,doCallout);
                };
            };
        };
        case "effect": {
            if (time - _since > EFFECT_TIME) then {
                _mission set ["state", "done"];
                _mission set ["since", time];
            };
        };
    };
} forEach _missions;

_state set ["missions", _missions select {!((_x get "state") in ["done", "cancelled"]) || {time - (_x get "since") < KEEP_TIME}}];
