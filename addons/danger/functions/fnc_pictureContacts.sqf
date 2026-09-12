#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Compatibility forwarder: the live contacts of a group's picture, newest first, with
 * confidence and error as they stand now (docs/systems/knowledge.md). Contacts known to
 * be dead are left out; a contact the group has only been told about has objNull in
 * slot 0 and a position in slot 1.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Maximum age of a contact in seconds, default 60 <NUMBER>
 *
 * Return Value:
 * contact records, [enemy or objNull, positionATL, lastEvidenceTime, knowsAbout, error, confidence, source, ...] <ARRAY>
 *
 * Example:
 * [group bob, 30] call lambs_danger_fnc_pictureContacts;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_maxAge", 60, [0]]];

[_group, _maxAge] call HFUNC(core,contactsGet)
