#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Adaptation (RESEARCH.md C-14, brief 3.8): the positions the side's groups keep
 * reporting the enemy in, per 100 m cell, counted once per visit. The third visit to a
 * cell gets a fire mission on it: the enemy has a favourite spot and the guns are laid on
 * it. Reads the board only, so it is what the groups believe and never where players are.
 *
 * One sentence: "You used that spot three times, so they had the mortars ready for it."
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east] call hostis_director_fnc_favourites;
 *
 * Public: No
*/
#define REVISIT 120
#define VISITS 3
#define FRESH 30
#define INTERVAL 600
#define CELL_ERROR 60

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _favourites = _state get "favourites";
{
    _x params ["_pos"];
    private _key = CELL_KEY(_pos);
    private _entry = _favourites get _key;
    if (isNil "_entry") then {
        _favourites set [_key, [1, time, -1e9]];
    } else {
        _entry params ["_count", "_last"];
        if (time - _last > REVISIT) then {_entry set [0, _count + 1];};
        _entry set [1, time];
    };
} forEach (_state get "board");

if (time - (_state get "lastFavourite") < INTERVAL) exitWith {};
{
    _y params ["_count", "_last", "_fired"];
    if (_count >= VISITS && {time - _last < FRESH} && {time - _fired > INTERVAL}) exitWith {
        private _centre = CELL_CENTRE(_x);
        if ([_side, _centre] call FUNC(spendAllowed) && {[_side, _centre, CELL_ERROR, format ["favourite position at %1, used %2 times", mapGridPosition _centre, _count], grpNull] call FUNC(fireRequest)}) then {
            _y set [2, time];
            _state set ["lastFavourite", time];
            [_side, format ["adaptation: guns laid on the favourite position at %1", mapGridPosition _centre]] call FUNC(log);
        };
    };
} forEach _favourites;
