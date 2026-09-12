#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Claims a fighting position for one man so nobody else in his group is sent to the
 * same spot. Reservations live on the group, keyed by the unit, and lapse on their own
 * so a dead or re-tasked man does not keep a wall to himself. Renew while moving to or
 * holding the position.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Position AGL <ARRAY>
 * 2: How long the claim lasts in seconds, default 60 <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob, getPos bob] call lambs_main_fnc_positionReserve;
 *
 * Public: No
*/
#define DEFAULT_EXPIRY 60

params [["_unit", objNull, [objNull]], ["_pos", [], [[]]], ["_expiry", DEFAULT_EXPIRY, [0]]];

if (isNull _unit || {_pos isEqualTo []}) exitWith {};
private _group = group _unit;
if (isNull _group) exitWith {};

private _reserved = _group getVariable QGVAR(reserved);
if (isNil "_reserved") then {
    _reserved = createHashMap;
    _group setVariable [QGVAR(reserved), _reserved];
};

// lapsed claims go every time somebody makes a new one
private _now = time;
{
    if (_now > (_y select 1)) then {_reserved deleteAt _x;};
} forEach +_reserved;

_reserved set [hashValue _unit, [_pos, _now + _expiry]];
