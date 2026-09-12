#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns the combat picture of a group, creating it on first use. The picture is a
 * hashmap that the tactics layer reads instead of reacting to single danger causes:
 *
 *   contacts     array of [enemy, positionATL, lastSeenTime, knowsAbout]
 *   threatPos    recency weighted centre of the known enemies, [] when none
 *   threatDir    bearing from the leader to threatPos, -1 when none
 *   lastContact  time an enemy was last confirmed
 *   maxCount     most units the group has had
 *   losses       units lost since the picture was created
 *   morale       last computed morale 0..1 (see getMorale)
 *   moraleTime   time morale was computed
 *   lastTactic   name of the last tactic that ran
 *   lastResult   "completed", "failed", "timeout" or ""
 *   lastTacticTime time the last tactic ended
 *   withdrawTime time the group last broke contact
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * combat picture <HASHMAP>
 *
 * Example:
 * [group bob] call lambs_danger_fnc_pictureGet;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {createHashMap};

private _picture = _group getVariable QGVAR(picture);
if (isNil "_picture") then {
    _picture = createHashMapFromArray [
        ["contacts", []],
        ["threatPos", []],
        ["threatDir", -1],
        ["lastContact", -1e9],
        ["updated", -1e9],
        ["maxCount", count units _group],
        ["losses", 0],
        ["morale", 1],
        ["moraleTime", -1e9],
        ["lastTactic", ""],
        ["lastResult", ""],
        ["lastTacticTime", -1e9],
        ["withdrawTime", -1e9]
    ];
    _group setVariable [QGVAR(picture), _picture];
};

_picture
