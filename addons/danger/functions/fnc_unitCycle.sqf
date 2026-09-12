#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One tick of the per-soldier machine. The cheap pass touches every registered man:
 * life and vehicle state, arrival at the end of a leg, legs that time out or cannot be
 * planned, the peek and duck rhythm in a fighting position, suppression while up, the
 * end of a hold. Anything that needs a position query or a move order is queued for the
 * expensive pass, which runs for a bounded number of men per tick, oldest first.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call lambs_danger_fnc_unitCycle;
 *
 * Public: No
*/
#define THINK_BUDGET 12
#define ARRIVE_DISTANCE 2.5
#define ARRIVE_GRACE 2
#define HOP_TIMEOUT 15
#define RUSH_TIMEOUT 18
#define PLAN_TIMEOUT 3
#define HOP_FAILS 3
#define BLACKLIST_TIME 120
#define BLACKLIST_SIZE 10
#define PEEK_MIN 2
#define PEEK_MAX 3
#define UP_MIN 3
#define UP_MAX 6
#define DOWN_MIN 2
#define DOWN_MAX 4
#define QUIET_UP_MIN 15
#define QUIET_UP_MAX 25
#define QUIET_DOWN_MIN 1
#define QUIET_DOWN_MAX 2
#define FIRST_LOOK 1.5
#define CONTACT_RECENT 20
#define SUPPRESSED 0.5
#define SUPPRESS_GAP 8
#define IDLE_DROP 180
#define RESERVE_TIME 60
#define WATCH_RANGE 100

private _debug = EGVAR(main,debug_functions);
private _due = [];

// the man is on his final position: settle in, claim it, head down, then the rhythm
private _fnc_arrive = {
    params ["_unit", "_record"];
    _record set ["hop", []];
    _record set ["hopFails", 0];
    _record set ["state", "InCover"];
    _record set ["since", time];
    _record set ["phase", "down"];
    _record set ["flipAt", time + FIRST_LOOK + random FIRST_LOOK];
    _record set ["nextSuppress", 0];
    private _position = _record get "position";
    private _cover = if (_position isEqualTo []) then {0} else {_position select 1};
    [_unit, getPosATL _unit, RESERVE_TIME] call EFUNC(main,positionReserve);
    _unit forceSpeed -1;
    _unit setUnitPos (["DOWN", "MIDDLE"] select (_cover >= 2));
    private _taskDisabled = _unit getVariable [QEGVAR(wp,disabledAI), []];
    {if (!(_x in _taskDisabled)) then {_unit enableAI _x;};} forEach ["SUPPRESSION", "TARGET", "AUTOTARGET"];
    private _threats = (_record get "order") param [2, []];
    private _sector = _record get "sector";
    if (_threats isNotEqualTo []) then {_unit doWatch (_threats select 0);} else {
        if (_sector isNotEqualTo []) then {_unit doWatch ((getPosATL _unit) getPos [WATCH_RANGE, _sector select 0]);};
    };
    private _holdTime = _record getOrDefault ["holdTime", 0];
    if (_holdTime > 0) then {
        _record set ["holdUntil", time + _holdTime];
        _unit setVariable [QEGVAR(main,survival), time + _holdTime];
    };
    _unit setVariable [QEGVAR(main,currentTask), ["In cover", "Fighting position"] select ((_position isNotEqualTo []) && {_position select 2}), EGVAR(main,debug_functions)];
    if (_debug) then {["%1 UNIT %2 in position (%3, cover %4)", side _unit, name _unit, [_position select 5, "open"] select (_position isEqualTo []), _cover] call EFUNC(main,debugLog);};
    switch (_record get "onArrive") do {
        case "follow": {[_unit, true] call FUNC(unitRelease);};
        case "release": {[_unit, false] call FUNC(unitRelease);};
    };
};

// peek and duck
private _fnc_flip = {
    params ["_unit", "_record"];
    private _picture = (group _unit) getVariable QGVAR(picture);
    private _contactRecent = !isNil "_picture" && {time - (_picture get "lastContact") < CONTACT_RECENT};
    private _position = _record get "position";
    private _cover = if (_position isEqualTo []) then {0} else {_position select 1};
    private _canFire = _position isEqualTo [] || {_position select 2};
    private _threats = (_record get "order") param [2, []];
    private _sector = _record get "sector";
    private _fnc_watch = {
        if (_threats isNotEqualTo []) exitWith {_unit doWatch (_threats select 0);};
        if (_sector isNotEqualTo []) exitWith {_unit doWatch ((getPosATL _unit) getPos [WATCH_RANGE, _sector select 0]);};
        _unit doWatch objNull;
    };
    if ((_record get "phase") isEqualTo "down") then {
        _record set ["phase", "up"];
        if (_canFire) then {
            _unit setUnitPos (["DOWN", "MIDDLE"] select (_cover >= 1.2));
            private _suppressList = _record get "suppressList";
            private _suppressed = false;
            if (_contactRecent && {_suppressList isNotEqualTo []} && {time > (_record getOrDefault ["nextSuppress", 0])}) then {
                _record set ["nextSuppress", time + SUPPRESS_GAP];
                private _index = [_unit, _suppressList] call EFUNC(main,checkVisibilityList);
                if (_index isNotEqualTo -1) then {
                    _suppressed = [_unit, AGLToASL ((_suppressList select _index) vectorAdd [0, 0, random 1])] call EFUNC(main,doSuppress);
                };
            };
            if (!_suppressed) then {call _fnc_watch;};
        } else {
            // full cover with no field of fire: look, do not stand up into it
            call _fnc_watch;
        };
        _record set ["flipAt", time + ([QUIET_UP_MIN + random (QUIET_UP_MAX - QUIET_UP_MIN), UP_MIN + random (UP_MAX - UP_MIN)] select _contactRecent)];
    } else {
        _record set ["phase", "down"];
        _unit setUnitPos (["DOWN", "MIDDLE"] select (_cover >= 2));
        _record set ["flipAt", time + ([QUIET_DOWN_MIN + random (QUIET_DOWN_MAX - QUIET_DOWN_MIN), DOWN_MIN + random (DOWN_MAX - DOWN_MIN)] select _contactRecent)];
    };
    [_unit, getPosATL _unit, RESERVE_TIME] call EFUNC(main,positionReserve);
};

// a leg that cannot be walked
private _fnc_unreachable = {
    params ["_unit", "_record"];
    private _hop = _record get "hop";
    private _blacklist = (_record get "unreachable") select {time < (_x select 1)};
    _blacklist pushBack [_hop, time + BLACKLIST_TIME];
    if (count _blacklist > BLACKLIST_SIZE) then {_blacklist deleteAt 0;};
    _record set ["unreachable", _blacklist];
    private _fails = (_record get "hopFails") + 1;
    _record set ["hopFails", _fails];
    if (_debug) then {["%1 UNIT %2 unreachable %3m (%4)", side _unit, name _unit, round (_unit distance2D _hop), _fails] call EFUNC(main,debugLog);};
    if (_fails >= HOP_FAILS) exitWith {[_unit, true] call FUNC(unitRelease);};
    _record set ["hop", []];
    _record set ["position", []];
    _record set ["needThink", true];
    _record set ["nextThink", time];
};

{
    private _unit = _x;
    private _record = _unit getVariable QGVAR(unit);
    if (isNull _unit || {isNil "_record"} || {!local _unit}) then {
        GVAR(units) deleteAt (GVAR(units) find _unit);
        continue;
    };
    private _state = _record get "state";

    // life
    if (!(_unit call EFUNC(main,isAlive))) then {
        if (_state isNotEqualTo "Casualty") then {
            [_unit] call EFUNC(main,positionRelease);
            _record set ["hop", []];
            _record set ["state", "Casualty"];
        };
        continue;
    };
    if (_state isEqualTo "Casualty") then {_state = "Idle"; _record set ["state", "Idle"]; _record set ["lastEvent", time];};

    // aboard
    if (!isNull objectParent _unit) then {
        if (_state isNotEqualTo "Mounted") then {
            [_unit] call EFUNC(main,positionRelease);
            _record set ["hop", []];
            _record set ["state", "Mounted"];
        };
        continue;
    };
    if (_state isEqualTo "Mounted") then {_state = "Idle"; _record set ["state", "Idle"]; _record set ["lastEvent", time];};

    switch (_state) do {
        case "Idle": {
            if (time - (_record get "lastEvent") > IDLE_DROP) then {
                GVAR(units) deleteAt (GVAR(units) find _unit);
                _unit setVariable [QGVAR(unit), nil];
            };
        };

        case "Moving";
        case "Rushing";
        case "Surviving": {
            private _hop = _record get "hop";
            // between legs: the next one once the look around is over
            if (_hop isEqualTo []) exitWith {
                if (time >= (_record get "pauseUntil")) then {
                    _record set ["needThink", true];
                    _record set ["nextThink", (_record get "nextThink") min time];
                };
            };
            private _elapsed = time - (_record get "hopStart");
            private _arrived = _unit distance2D _hop < ARRIVE_DISTANCE || {_elapsed > ARRIVE_GRACE && {unitReady _unit}};
            if (_arrived) exitWith {
                if (_record get "hopFinal") exitWith {[_unit, _record] call _fnc_arrive;};
                _record set ["hop", []];
                _record set ["pauseUntil", 0];
                private _threats = (_record get "order") param [2, []];
                if (_threats isNotEqualTo [] && {!(_record get "sprint")}) then {
                    // a look from behind the stepping stone before the next leg
                    private _position = _record get "position";
                    _unit setUnitPos ([_position param [3, "MIDDLE"], "MIDDLE"] select (_position isEqualTo []));
                    _unit doWatch (_threats select 0);
                    _record set ["pauseUntil", time + PEEK_MIN + random (PEEK_MAX - PEEK_MIN)];
                };
            };
            private _timeout = [HOP_TIMEOUT, RUSH_TIMEOUT] select (_record get "sprint");
            if (_elapsed > _timeout || {_elapsed > PLAN_TIMEOUT && {((expectedDestination _unit) select 1) isEqualTo "DoNotPlan"}}) then {
                [_unit, _record] call _fnc_unreachable;
            };
        };

        case "InCover": {
            private _holdUntil = _record get "holdUntil";
            if (_holdUntil > 0 && {time > _holdUntil}) exitWith {[_unit, true] call FUNC(unitRelease);};
            if ((_record get "shiftAt") > 0 && {time >= (_record get "shiftAt")}) then {
                _record set ["needThink", true];
                _record set ["nextThink", time];
            };
            if ((_record get "phase") isEqualTo "up" && {((getSuppression _unit) max 0) > SUPPRESSED}) then {
                [_unit, "suppressed", []] call FUNC(unitEvent);
            };
            if (time >= (_record get "flipAt")) then {[_unit, _record] call _fnc_flip;};
        };
    };

    if ((_record get "needThink") && {time >= (_record get "nextThink")}) then {_due pushBack [_record get "nextThink", _unit];};
} forEach +GVAR(units);

// the expensive pass, oldest request first
if (_due isEqualTo []) exitWith {};
_due sort true;
if (count _due > THINK_BUDGET) then {_due resize THINK_BUDGET;};
{[_x select 1] call FUNC(unitThink);} forEach _due;
