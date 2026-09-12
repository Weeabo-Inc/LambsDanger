#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The side's influence map (RESEARCH.md C-31): per 100 m cell, friendly presence, enemy
 * presence as reported, deaths taken, and the last time there was contact. Decays every
 * think. Used to choose which way a reserve comes in and which way a counterattack goes.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * influence map <HASHMAP>
 *
 * Example:
 * [east] call hostis_director_fnc_influence;
 *
 * Public: No
*/
#define DECAY 0.85
#define PRUNE 0.05

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _map = _state get "influence";
private _lastLosses = _state get "lastLosses";

// decay and prune
{
    _y set [0, (_y select 0) * DECAY];
    _y set [1, (_y select 1) * DECAY];
    if ((_y select 0) < PRUNE && {(_y select 1) < PRUNE} && {(_y select 2) isEqualTo 0}) then {_map deleteAt _x;};
} forEach +_map;

private _fnc_cell = {
    params ["_pos"];
    private _key = CELL_KEY(_pos);
    private _cell = _map get _key;
    if (isNil "_cell") then {
        _cell = [0, 0, 0, -1e9];
        _map set [_key, _cell];
    };
    _cell
};

// friendly presence and deaths
{
    private _group = _x;
    private _leader = leader _group;
    if (!isNull _leader) then {
        private _cell = [getPosATL _leader] call _fnc_cell;
        _cell set [0, (_cell select 0) + ({_x call LFUNC(main,isAlive)} count (units _group))];
        private _picture = [_group] call EFUNC(core,pictureGet);
        private _losses = _picture get "losses";
        private _key = hashValue _group;
        private _delta = _losses - (_lastLosses getOrDefault [_key, _losses]);
        if (_delta > 0) then {_cell set [2, (_cell select 2) + _delta];};
        _lastLosses set [_key, _losses];
        if (time - (_picture get "lastContact") < 30) then {_cell set [3, time];};
    };
} forEach (_state get "groups");

// enemy presence as reported
{
    _x params ["_pos", "_strength", "_confidence"];
    private _cell = [_pos] call _fnc_cell;
    _cell set [1, (_cell select 1) + _strength * _confidence];
    _cell set [3, time];
} forEach (_state get "board");

_map
