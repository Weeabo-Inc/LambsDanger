#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Sends a soldier somewhere the way a trained one goes: from cover to cover in short
 * legs, ending behind something with a field of fire, rather than a straight line to a
 * point in the open. The public face of the per-soldier machine in the danger
 * component (lambs_danger_fnc_unitOrder); without that component it is a plain move.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Destination AGL <ARRAY>
 * 2: Threat positions AGL, first is the main one <ARRAY>, default []
 * 3: Options <HASHMAP>, default empty; see lambs_danger_fnc_unitOrder
 *
 * Return Value:
 * accepted <BOOL>
 *
 * Example:
 * [bob, getPos angryJoe, [getPos angryJoe]] call lambs_main_fnc_moveCover;
 *
 * Public: Yes
*/
params [["_unit", objNull, [objNull]], ["_destination", [], [[]]], ["_threats", [], [[]]], ["_options", createHashMap, [createHashMap]]];

if (isNull _unit || {_destination isEqualTo []}) exitWith {false};

private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (isNil "_order") exitWith {
    _unit doMove _destination;
    true
};

[_unit, "move", _destination, _threats, _options] call _order
