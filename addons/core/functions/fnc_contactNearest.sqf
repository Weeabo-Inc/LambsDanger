#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The best contact near a position, for the upstream hunt, rush and creep tasks: the
 * group's own eyes are swept first, then the nearest live contact of any source is chosen,
 * a seen one before a reported one. Returns the enemy object only when the group has seen
 * him itself; a reported contact gives a position and objNull, so the task moves on an
 * area, never on a man it has not detected (FAIRNESS.md R4). Replaces
 * lambs_main_fnc_findClosestTarget, which scanned allUnits.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Radius <NUMBER>
 * 2: Area as [a, b, angle, isRectangle, c], [] for none <ARRAY>
 * 3: Centre, [] for the leader <ARRAY> or <OBJECT>
 * 4: Minimum effective confidence, default 0.2 <NUMBER>
 *
 * Return Value:
 * [enemy object or objNull, position or []] <ARRAY>
 *
 * Example:
 * [group bob, 500] call hostis_core_fnc_contactNearest;
 *
 * Public: Yes
*/
params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_radius", 500, [0]],
    ["_area", [], [[]]],
    ["_pos", [], [[], objNull]],
    ["_minConfidence", 0.2, [0]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {[objNull, []]};
if (_pos isEqualTo []) then {_pos = leader _group;};
_pos = _pos call CBA_fnc_getPos;

// own eyes first
[_group] call FUNC(contactSweep);

private _contacts = [_group, -1, _minConfidence, [], _pos, _radius] call FUNC(contactsGet);
if (_area isNotEqualTo []) then {
    _area params ["_a", "_b", "_angle", "_isRectangle", ["_c", -1]];
    _contacts = _contacts select {(_x select CONTACT_POS) inArea [_pos, _a, _b, _angle, _isRectangle, _c]};
};
if (_contacts isEqualTo []) exitWith {[objNull, []]};

private _leaderPos = getPosATL (leader _group);
private _scored = _contacts apply {
    // a contact the group has seen itself beats any reported one, then the nearest wins
    private _penalty = [0, 10000] select (isNull (_x select CONTACT_OBJECT));
    [_penalty + (_leaderPos distance2D (_x select CONTACT_POS)), _x]
};
_scored sort true;
private _best = (_scored select 0) select 1;

[_best select CONTACT_OBJECT, _best select CONTACT_POS]
