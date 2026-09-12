#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The tactic a group is running under the squad lifecycle, if any.
 *
 * Arguments:
 * 0: Group <GROUP>
 *
 * Return Value:
 * the tactic state hashmap (name, since, objective, token, data ...) or nil <HASHMAP>
 *
 * Example:
 * [group bob] call hostis_squad_fnc_tacticRunning;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {nil};
_group getVariable QGVAR(tactic)
