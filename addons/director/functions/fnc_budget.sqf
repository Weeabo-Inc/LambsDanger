#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Reads or sets a side's budget. Keys: "reinforcements", "fireMissions". The Director
 * spends against these; when one is exhausted it changes tactics instead of stopping.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Key <STRING>
 * 2: New value, omit to read <NUMBER>
 *
 * Return Value:
 * remaining budget <NUMBER>
 *
 * Example:
 * [east, "fireMissions", 6] call hostis_director_fnc_budget;
 * [east, "reinforcements"] call hostis_director_fnc_budget;
 *
 * Public: Yes
*/
params [["_side", sideUnknown, [sideUnknown]], ["_key", "", [""]], "_value"];

private _state = [_side] call FUNC(sideState);
private _budget = _state get "budget";
if (!isNil "_value") then {
    _budget set [_key, (_value max 0)];
    [_side, format ["budget %1 set to %2", _key, _value]] call FUNC(log);
};
_budget getOrDefault [_key, 0]
