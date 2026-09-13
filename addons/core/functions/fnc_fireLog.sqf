#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Logs one incoming fire event (a shot seen, a bullet close, a hit) against a group with
 * the bearing it came from, so the group can count the volume of fire on it per sector
 * (C-58). The engine sends one Fire cause per bullet seen, which makes this an honest
 * rounds counter.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Position the fire came from, [] when the shooter is unknown <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob, [1200, 3400, 0]] call hostis_core_fnc_fireLog;
 * [group bob, []] call hostis_core_fnc_fireLog;
 *
 * Public: Yes
*/
#define FIRE_LOG_SIZE 60

params [["_group", grpNull, [grpNull, objNull]], ["_pos", [], [[]]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {};
private _picture = [_group] call FUNC(pictureGet);
private _log = _picture getOrDefault ["fire", []];
private _leader = leader _group;
// a round from nowhere counts toward every sector (bearing -1)
private _bearing = if (count _pos < 2 || {isNull _leader}) then {-1} else {_leader getDir _pos};
_log pushBack [time, _bearing];
if (count _log > FIRE_LOG_SIZE) then {_log deleteAt 0;};
_picture set ["fire", _log];
