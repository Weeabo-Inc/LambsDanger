#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Compatibility forwarder: the combat picture now lives in hostis_core
 * (docs/systems/knowledge.md). Returns the group's picture, creating it on first use.
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
_this call HFUNC(core,pictureGet)
