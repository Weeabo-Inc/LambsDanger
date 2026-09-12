#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The picture of a group as plain text: what it believes, how sure it is, how old the
 * belief is, and how well it can talk. For the Zeus diagnose module, the acceptance
 * tests and the log.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Most contacts to list, default 8 <NUMBER>
 *
 * Return Value:
 * report lines <ARRAY of STRING>
 *
 * Example:
 * [group bob] call hostis_core_fnc_pictureReport;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_max", 8, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {["No group"]};

private _picture = [_group] call FUNC(pictureRefresh);
private _contacts = [_group, -1, 0, [], [], 0, true] call FUNC(contactsGet);
private _live = _contacts select {!(_x select CONTACT_DEAD)};
private _leader = leader _group;
private _now = time;
private _lines = [];

private _threatPos = _picture get "threatPos";
private _threat = if (_threatPos isEqualTo []) then {"no threat centre"} else {
    format ["threat centre %1 m at %2 deg", round (_leader distance2D _threatPos), round (_picture get "threatDir")]
};
private _age = _picture get "pictureAge";
_lines pushBack format ["Picture %1: %2 contacts (%3 live, %4 dead), %5, newest evidence %6 s ago",
    groupId _group, count _contacts, count _live, (count _contacts) - (count _live), _threat,
    ["-", round _age] select (_age < 1e8)];

private _lastContact = _picture get "lastContact";
private _lastReport = _picture get "lastReport";
private _lastOut = _picture get "lastReportOut";
private _net = [_group] call FUNC(netParams);
_lines pushBack format ["Net: %1, range %2 m, delay %3 s, loss %4, quality %5%6; last direct evidence %7, last report in %8, last report out %9",
    ["shouting", "radio"] select (_net get "radio"), round (_net get "range"), (_net get "delay") toFixed 1, (_net get "loss") toFixed 2, _net get "quality",
    ["", ", LEADERLESS"] select (_net get "leaderless"),
    ["never", format ["%1 s ago", round (_now - _lastContact)]] select (_lastContact > -1e8),
    ["never", format ["%1 s ago", round (_now - _lastReport)]] select (_lastReport > -1e8),
    ["never", format ["%1 s ago", round (_now - _lastOut)]] select (_lastOut > -1e8)];

{
    if (_forEachIndex < _max) then {
        _lines pushBack format ["  %1 %2 x%3 at %4 m bearing %5, error %6 m, confidence %7, %8 s old, %9%10",
            _x select CONTACT_SOURCE, _x select CONTACT_TYPE, _x select CONTACT_STRENGTH,
            round (_leader distance2D (_x select CONTACT_POS)), round (_leader getDir (_x select CONTACT_POS)),
            round (_x select CONTACT_ERROR), (_x select CONTACT_CONF) toFixed 2, round (_now - (_x select CONTACT_TIME)),
            _x select CONTACT_ACTIVITY, ["", " (chain " + str (_x select CONTACT_CHAIN) + ")"] select ((_x select CONTACT_CHAIN) > 0)];
    };
} forEach _contacts;
if (count _contacts > _max) then {_lines pushBack format ["  ... and %1 more", (count _contacts) - _max];};

_lines
