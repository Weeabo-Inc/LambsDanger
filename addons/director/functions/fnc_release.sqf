#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Releases one reserve group toward an area: the group gets a suspected contact with the
 * area's error in its own picture (an area, never a target, FAIRNESS.md R4), an attack
 * intent, and the Attack Position task to get there. Spends one reinforcement. Prefers a
 * reserve that approaches from a different bearing than the one given, so help comes
 * from a side the enemy did not expect.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Position <ARRAY>
 * 2: Error radius in metres <NUMBER>
 * 3: Reason, for the log <STRING>
 * 4: Bearing to avoid, -1 for none <NUMBER>
 * 5: Ignore the budget and the pacing, default false <BOOL>
 *
 * Return Value:
 * the group released, grpNull when none <GROUP>
 *
 * Example:
 * [east, getPos player, 100, "reinforce Alpha"] call hostis_director_fnc_release;
 *
 * Public: Yes
*/
params [["_side", sideUnknown, [sideUnknown]], ["_pos", [], [[]]], ["_error", 100, [0]], ["_reason", "", [""]], ["_avoidBearing", -1, [0]], ["_force", false, [false]]];

if (_pos isEqualTo []) exitWith {grpNull};
private _state = [_side] call FUNC(sideState);
private _budget = _state get "budget";
if (!_force && {(_budget get "reinforcements") <= 0}) exitWith {
    [_side, format ["no reinforcement budget left for: %1", _reason]] call FUNC(log);
    grpNull
};

private _pool = [_side, _pos] call FUNC(reserves);
if (_pool isEqualTo []) exitWith {
    [_side, format ["no reserve within %1 m for: %2", GVAR(reserveRange), _reason]] call FUNC(log);
    grpNull
};

// a different direction beats a shorter road
private _pick = _pool select 0;
if (_avoidBearing >= 0) then {
    private _best = -1;
    {
        private _bearing = _pos getDir (leader _x);
        private _difference = abs (((_bearing - _avoidBearing) + 540) mod 360 - 180);
        if (_difference > 90 && {_difference > _best}) then {_best = _difference; _pick = _x;};
    } forEach _pool;
};

// what it knows: an area
[_pick, objNull, _pos, "suspected", _error, 0.6, 4, "infantry"] call EFUNC(core,contactReport);
[_pick, "attack", _pos, _error max 100, 2] call LFUNC(danger,intentSet);
[_pick] call LFUNC(danger,commanderRegister);
_pick setVariable [QGVAR(releasedAt), time];
_pick setVariable [QLGVAR(danger,alertTime), time];
[QLGVAR(wp,taskAttack), [_pick, _pos, _error max 100], leader _pick] call CBA_fnc_targetEvent;

if (!_force) then {
    _budget set ["reinforcements", (_budget get "reinforcements") - 1];
    (_state get "spent") set ["reinforcements", ((_state get "spent") get "reinforcements") + 1];
};
_state set ["lastRelease", time];
[_side, format ["released %1 (%2 m away) toward %3: %4; %5 reinforcements left", groupId _pick, round ((leader _pick) distance2D _pos), mapGridPosition _pos, _reason, _budget get "reinforcements"]] call FUNC(log);

_pick
