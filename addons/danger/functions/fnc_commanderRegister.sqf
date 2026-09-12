#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Puts a local group on the commander's list. Groups get here on first contact or when
 * given an intent; the commander drops them again once they are idle for a long time.
 *
 * Arguments:
 * 0: Group <GROUP>
 *
 * Return Value:
 * registered <BOOL>
 *
 * Example:
 * [group bob] call lambs_danger_fnc_commanderRegister;
 *
 * Public: No
*/
params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group} || {!GVAR(commander)}) exitWith {false};

if (isNil QGVAR(commanderGroups)) then {GVAR(commanderGroups) = [];};
if (_group in GVAR(commanderGroups)) exitWith {true};

GVAR(commanderGroups) pushBack _group;
_group setVariable [QGVAR(commanderNext), time + 2 + random 3];
[_group] call FUNC(intentGet);

true
