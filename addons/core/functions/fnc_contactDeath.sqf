#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Marks a contact dead. Called when a man of the group sees a kill or finds a body (the
 * DeadBody danger causes, RESEARCH.md C-61) or when another group reports one. A body
 * nobody was tracking still becomes a dead record: proof the enemy has been here.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: The dead unit, or the body position <OBJECT> or <ARRAY>
 * 2: Match radius for a position, default 6 <NUMBER>
 *
 * Return Value:
 * true when a tracked contact was marked <BOOL>
 *
 * Example:
 * [group bob, angryJoe] call hostis_core_fnc_contactDeath;
 * [group bob, [1200, 3400, 0]] call hostis_core_fnc_contactDeath;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_what", objNull, [objNull, []]], ["_radius", 6, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {false};
private _byObject = _what isEqualType objNull;
if (_byObject && {isNull _what}) exitWith {false};
if (!_byObject && {count _what < 2}) exitWith {false};

private _picture = [_group] call FUNC(pictureGet);
private _now = time;
private _hit = false;
{
    private _match = if (_byObject) then {
        (_x select CONTACT_OBJECT) isEqualTo _what || {(_x select CONTACT_REF) isEqualTo _what}
    } else {
        (_x select CONTACT_TYPE) in ["infantry", "unknown"] && {(_x select CONTACT_POS) distance2D _what < _radius}
    };
    if (_match && {!(_x select CONTACT_DEAD)}) then {
        _x set [CONTACT_DEAD, true];
        _x set [CONTACT_TIME, _now];
        _x set [CONTACT_CONF, 1];
        _x set [CONTACT_ACTIVITY, "dead"];
        _hit = true;
    };
} forEach (_picture get "contacts");

// a body nobody tracked
if (!_hit) then {
    private _pos = [_what, getPosATL _what] select _byObject;
    private _record = [_group, objNull, _pos, "seen", 3, 1, 1, ["infantry", [_what] call FUNC(contactType)] select _byObject, -1, "dead", 0, [objNull, _what] select _byObject] call FUNC(contactReport);
    if (_record isNotEqualTo []) then {_record set [CONTACT_DEAD, true];};
};

[_group, true] call FUNC(pictureRefresh);
_hit
