#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Puts a soldier under the per-soldier machine: creates his record if he has none and
 * adds him to the registry the machine cycles. Local AI infantry only.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * record, or nil when the unit cannot be registered <HASHMAP>
 *
 * Example:
 * [bob] call lambs_danger_fnc_unitRegister;
 *
 * Public: No
*/
params [["_unit", objNull, [objNull]]];

if (isNull _unit || {!local _unit} || {isPlayer _unit} || {!(_unit isKindOf "CAManBase")}) exitWith {nil};
if (isNil QGVAR(units)) then {call FUNC(unitInit);};

private _record = _unit getVariable QGVAR(unit);
if (isNil "_record") then {
    _record = createHashMapFromArray [
        ["state", "Idle"],
        ["since", time],
        ["order", []],
        ["final", []],
        ["hop", []],
        ["hopFinal", false],
        ["hopStart", 0],
        ["hopFails", 0],
        ["hopCount", 0],
        ["pauseUntil", 0],
        ["position", []],
        ["alternates", []],
        ["unreachable", []],
        ["nextThink", 0],
        ["nextQuery", 0],
        ["needThink", false],
        ["phase", "down"],
        ["flipAt", 0],
        ["lastHit", -1e9],
        ["nearMisses", []],
        ["shifts", []],
        ["shiftAt", 0],
        ["sector", []],
        ["suppressList", []],
        ["onArrive", "hold"],
        ["sprint", false],
        ["holdUntil", 0],
        ["lastEvent", time]
    ];
    _unit setVariable [QGVAR(unit), _record];
};
GVAR(units) pushBackUnique _unit;

_record
