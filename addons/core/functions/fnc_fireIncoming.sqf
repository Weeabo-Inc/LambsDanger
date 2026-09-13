#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The volume of fire coming at a group: fire events per second inside a window,
 * optionally only from a sector. What the suppression model and the Director read
 * instead of guessing (C-58).
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Window in seconds, default 5 <NUMBER>
 * 2: Bearing of the sector, -1 for all round <NUMBER>
 * 3: Half-width of the sector in degrees, default 45 <NUMBER>
 *
 * Return Value:
 * events per second <NUMBER>
 *
 * Example:
 * [group bob, 5] call hostis_core_fnc_fireIncoming;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_window", 5, [0]], ["_bearing", -1, [0]], ["_halfWidth", 45, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {0};
private _picture = [_group] call FUNC(pictureGet);
private _log = _picture getOrDefault ["fire", []];
private _since = time - _window;
private _count = 0;
{
    _x params ["_time", "_dir"];
    if (_time >= _since && {_bearing < 0 || {_dir < 0} || {abs ((_dir - _bearing + 540) mod 360 - 180) <= _halfWidth}}) then {_count = _count + 1;};
} forEach _log;

_count / (_window max 1)
