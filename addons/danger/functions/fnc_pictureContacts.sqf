#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns the enemies a group knows about from its combat picture, most recently
 * seen first. Dead enemies and contacts older than the given age are left out.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Maximum age of a contact in seconds, default 60 <NUMBER>
 *
 * Return Value:
 * contacts, each [enemy, positionATL, lastSeenTime, knowsAbout] <ARRAY>
 *
 * Example:
 * [group bob, 30] call lambs_danger_fnc_pictureContacts;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_maxAge", 60, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {[]};

private _picture = [_group] call FUNC(pictureGet);
private _now = time;
private _contacts = (_picture get "contacts") select {alive (_x select 0) && {_now - (_x select 2) < _maxAge}};

// newest first
_contacts = _contacts apply {[-(_x select 2), _x]};
_contacts sort true;
_contacts apply {_x select 1}
