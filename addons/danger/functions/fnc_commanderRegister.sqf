#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Puts a local group on the commander's list and pins it to this machine. Groups get here
 * on first contact, on hearing, or when given an intent; the commander drops and unpins
 * them again once they are idle for a long time.
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

// pinned to this machine while registered (ADR-0007): a load balancer that moves the group mid-fight
// loses its picture and its tactic. ACE's headless module honours the unit blacklist; others read hostis_pinned.
_group setVariable ["hostis_pinned", true, true];
{_x setVariable ["ace_headless_blacklist", true, true];} forEach (units _group);

true
