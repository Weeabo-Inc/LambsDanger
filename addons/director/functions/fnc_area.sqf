#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Sets or clears a side's area of operations. While one is set the Director spends
 * nothing on a position outside it (fnc_spendAllowed): no reinforcement, no
 * counterattack, no fire mission. Reserves outside it are still reserves.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Centre <ARRAY>
 * 2: Radius in metres, 0 or less clears the area <NUMBER>
 *
 * Return Value:
 * the area [centre, radius], [] when none <ARRAY>
 *
 * Example:
 * [east, getPos player, 1500] call hostis_director_fnc_area;
 *
 * Public: Yes
*/
params [["_side", sideUnknown, [sideUnknown]], ["_pos", [], [[]]], ["_radius", 0, [0]]];

private _state = [_side] call FUNC(sideState);
private _area = [];
if (_radius > 0 && {_pos isNotEqualTo []}) then {_area = [+_pos, _radius];};
_state set ["ao", _area];
[_side, ["area of operations cleared", format ["area of operations %1 m around %2", round _radius, mapGridPosition _pos]] select (_area isNotEqualTo [])] call FUNC(log);

_area
