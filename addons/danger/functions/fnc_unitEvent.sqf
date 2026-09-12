#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Tells the per-soldier machine something happened to a man it owns. A man in a
 * fighting position who is hit, suppressed or has rounds cracking past him gets his
 * head down for a few seconds and then shifts to another spot nearby; a man on the
 * move keeps moving. Returns whether the machine took it, so the caller can fall back
 * to the engine's own dodge for men it does not own.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Event: "hit", "nearMiss", "suppressed" or "threatSeen" <STRING>
 * 2: Position the danger came from AGL, [] for unknown <ARRAY>
 *
 * Return Value:
 * handled <BOOL>
 *
 * Example:
 * [bob, "hit", getPos angryJoe] call lambs_danger_fnc_unitEvent;
 *
 * Public: No
*/
#define NEAR_MISS_WINDOW 5
#define NEAR_MISS_COUNT 2
#define HEAD_DOWN_MIN 4
#define HEAD_DOWN_MAX 8
#define SHIFT_WINDOW 30
#define SHIFT_MAX 2

params [["_unit", objNull, [objNull]], ["_event", "", [""]], ["_pos", [], [[]]]];

private _record = _unit getVariable QGVAR(unit);
if (isNil "_record") exitWith {false};
private _state = _record get "state";
if (_state in ["Idle", "Casualty", "Mounted"]) exitWith {false};
_record set ["lastEvent", time];

// a new threat direction for a man in position
if (_event isEqualTo "threatSeen") exitWith {
    if (_pos isNotEqualTo []) then {
        private _order = _record get "order";
        if (_order isNotEqualTo []) then {
            private _threats = _order select 2;
            if (_threats isEqualTo [] || {(_threats select 0) distance2D _pos > 15}) then {
                _threats = [_pos] + (_threats select {_x distance2D _pos > 15});
                _order set [2, _threats];
                // he may be behind the wrong side of the wall now
                if (_state isEqualTo "InCover" && {((_record get "shifts") select {time - _x < SHIFT_WINDOW}) isEqualTo []}) then {_record set ["shiftAt", time + 1];};
            };
        };
    };
    true
};

private _serious = switch (_event) do {
    case "hit": {_record set ["lastHit", time]; true};
    case "suppressed": {true};
    case "nearMiss": {
        private _misses = (_record get "nearMisses") select {time - _x < NEAR_MISS_WINDOW};
        _misses pushBack time;
        _record set ["nearMisses", _misses];
        count _misses >= NEAR_MISS_COUNT
    };
    default {false};
};
if (!_serious) exitWith {true};

// in position: down, and after a moment somewhere else
if (_state isEqualTo "InCover") then {
    private _position = _record get "position";
    private _cover = if (_position isEqualTo []) then {0} else {_position select 1};
    _record set ["phase", "down"];
    private _downFor = HEAD_DOWN_MIN + random (HEAD_DOWN_MAX - HEAD_DOWN_MIN);
    _record set ["flipAt", time + _downFor];
    _unit setUnitPos (["DOWN", "MIDDLE"] select (_cover >= 2));
    private _recent = (_record get "shifts") select {time - _x < SHIFT_WINDOW};
    if (count _recent < SHIFT_MAX && {(_record get "shiftAt") isEqualTo 0}) then {
        _record set ["shiftAt", time + _downFor];
    };
};

true
