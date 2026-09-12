#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Compatibility forwarder: files enemies the caller's men have detected as sightings in
 * the group's picture through the hostis_core sensor sweep, and refreshes the derived
 * values. With no enemies it only refreshes (docs/systems/knowledge.md).
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Enemies seen or heard <ARRAY of OBJECT>
 *
 * Return Value:
 * combat picture <HASHMAP>
 *
 * Example:
 * [group bob, [angryJoe]] call lambs_danger_fnc_pictureUpdate;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_enemies", [], [[]]]];

if (_enemies isEqualTo []) exitWith {[_group] call HFUNC(core,pictureRefresh)};
[_group, _enemies] call HFUNC(core,contactSweep)
