#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Reads the per-soldier machine's record for a unit: one field, or the whole record.
 * "isBusy" answers whether the machine currently owns the man's movement, so group
 * manoeuvres leave him alone the way they leave a man looking after himself alone.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Field, "" for the whole record, "isBusy" for the ownership test <STRING>
 * 2: Default when the unit has no record or the field is unset <ANY>
 *
 * Return Value:
 * value <ANY>
 *
 * Example:
 * [bob, "state"] call lambs_danger_fnc_unitState;
 *
 * Public: Yes
*/
params [["_unit", objNull, [objNull]], ["_field", "", [""]], "_default"];

private _record = _unit getVariable QGVAR(unit);
if (isNil "_record") exitWith {
    if (_field isEqualTo "isBusy") exitWith {false};
    if (isNil "_default") exitWith {nil};
    _default
};

switch (_field) do {
    case "": {_record};
    case "isBusy": {(_record get "state") in ["Moving", "Rushing", "Surviving"] || {(_record get "state") isEqualTo "InCover" && {(_record getOrDefault ["holdUntil", 0]) > time}}};
    default {
        if (isNil "_default") then {_record get _field} else {_record getOrDefault [_field, _default]}
    };
}
