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
 * 1: Position the fire came from, or the impact position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob, [1200, 3400, 0]] call hostis_core_fnc_fireLog;
 *
 * Public: Yes
*/
#define FIRE_LOG_SIZE 60

params [["_group", grpNull, [grpNull, objNull]], ["_pos", [], [[]]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {count _pos < 2}) exitWith {};
private _picture = [_group] call FUNC(pictureGet);
private _log = _picture getOrDefault ["fire", []];
private _leader = leader _group;
_log pushBack [time, [0, _leader getDir _pos] select (!isNull _leader)];
if (count _log > FIRE_LOG_SIZE) then {_log deleteAt 0;};
_picture set ["fire", _log];
