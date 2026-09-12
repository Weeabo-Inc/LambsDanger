#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The local counterattack (RESEARCH.md C-50): a defended position that fell is retaken by
 * a reserve after the delay, from the side the enemy did not come from, judged by where
 * the influence map says the enemy is. Called with a position to force one, or with none
 * to work through the positions the think marked as fallen.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Objective position, [] to work the fallen list <ARRAY>
 * 2: Radius <NUMBER>
 * 3: Ignore the budget and the pacing, default false <BOOL>
 *
 * Return Value:
 * the group released, grpNull when none <GROUP>
 *
 * Example:
 * [east, getMarkerPos "compound", 100, true] call hostis_director_fnc_counterattack;
 *
 * Public: Yes
*/
#define ENEMY_RANGE 400

params [["_side", sideUnknown, [sideUnknown]], ["_pos", [], [[]]], ["_radius", 100, [0]], ["_force", false, [false]]];

private _state = [_side] call FUNC(sideState);

// where the enemy is around a place, as a bearing, from the influence map
private _fnc_enemyBearing = {
    params ["_centre"];
    private _sum = [0, 0, 0];
    private _weight = 0;
    {
        private _enemy = _y select 1;
        if (_enemy > 0.1) then {
            private _cell = CELL_CENTRE(_x);
            if (_cell distance2D _centre < ENEMY_RANGE && {_cell distance2D _centre > 20}) then {
                _sum = _sum vectorAdd ((_cell vectorDiff _centre) vectorMultiply _enemy);
                _weight = _weight + _enemy;
            };
        };
    } forEach (_state get "influence");
    if (_weight isEqualTo 0) then {-1} else {_centre getDir (_centre vectorAdd _sum)}
};

private _fnc_go = {
    params ["_objective", "_objectiveRadius", "_reason"];
    private _avoid = [_objective] call _fnc_enemyBearing;
    [_side, _objective, _objectiveRadius max 50, _reason, _avoid, _force] call FUNC(release)
};

if (_pos isNotEqualTo []) exitWith {
    [_pos, _radius, "counterattack ordered"] call _fnc_go
};

private _released = grpNull;
{
    _y params ["_objective", "_objectiveRadius", "_since", "_group", "_done"];
    if (!_done && {isNull _released} && {time - _since > GVAR(counterattackDelay)}) then {
        if ([_side, _objective] call FUNC(spendAllowed)) then {
            _released = [_objective, _objectiveRadius, format ["counterattack on %1, lost by %2", mapGridPosition _objective, groupId _group]] call _fnc_go;
            _y set [4, true];
        };
    };
} forEach (_state get "fallen");

_released
