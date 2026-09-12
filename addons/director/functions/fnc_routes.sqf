#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Adaptation (RESEARCH.md C-14, brief 3.8): the approaches the player elements use, per
 * 100 m cell, counted once per visit. A cell used twice on separate visits gets a reserve
 * with a defend intent on it: a squad lying in wait on the route, holding fire until the
 * players are close. Unlocked by what the players did, never by what killed them. Reads
 * the pacing entries' centres, the one place player positions are used (ADR-0004).
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east] call hostis_director_fnc_routes;
 *
 * Public: No
*/
#define REVISIT 120
#define SEED_INTERVAL 300
#define SEED_RADIUS 100

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _routes = _state get "routes";
{
    private _centre = _y select 5;
    private _key = CELL_KEY(_centre);
    private _entry = _routes get _key;
    if (isNil "_entry") then {
        _routes set [_key, [1, time, false, _x]];
    } else {
        _entry params ["_count", "_last", "_seeded", "_lastElement"];
        // a new visit: another element, or the same one after a while away
        if (_lastElement isNotEqualTo _x || {time - _last > REVISIT}) then {_entry set [0, _count + 1];};
        _entry set [1, time];
        _entry set [3, _x];
    };
} forEach (_state get "pacing");

if (time - (_state getOrDefault ["lastSeed", -1e9]) < SEED_INTERVAL) exitWith {};
{
    _y params ["_count", "_last", "_seeded"];
    if (_count >= 2 && {!_seeded} && {time - _last > REVISIT}) exitWith {
        private _centre = CELL_CENTRE(_x);
        if ([_side, _centre] call FUNC(spendAllowed)) then {
            private _pool = [_side, _centre] call FUNC(reserves);
            if (_pool isNotEqualTo [] && {([_side, "reinforcements"] call FUNC(budget)) > 0}) then {
                private _group = _pool select 0;
                [_group, "defend", _centre, SEED_RADIUS, 1] call LFUNC(danger,intentSet);
                [_group] call LFUNC(danger,commanderRegister);
                _group setVariable [QGVAR(releasedAt), time];
                [QLGVAR(wp,taskAttack), [_group, _centre, SEED_RADIUS], leader _group] call CBA_fnc_targetEvent;
                private _budget = _state get "budget";
                _budget set ["reinforcements", (_budget get "reinforcements") - 1];
                _y set [2, true];
                _state set ["lastSeed", time];
                [_side, format ["route at %1 used %2 times: %3 sent to lie on it", mapGridPosition _centre, _count, groupId _group]] call FUNC(log);
            };
        };
    };
} forEach _routes;
