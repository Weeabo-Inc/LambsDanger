#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Feeds enemies into a group's combat picture and refreshes the derived values
 * (threat centre, losses). Cheap enough to call from unit level reactions: the
 * derived values are only recomputed once per second per group.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Enemies seen or heard <ARRAY of OBJECT>
 *
 * Return Value:
 * combat picture <HASHMAP>
 *
 * Example:
 * [group bob, [angryJoe]] call lambs_danger_fnc_pictureUpdate;
 *
 * Public: Yes
*/
#define CONTACT_MAX_AGE 90
#define REFRESH_INTERVAL 1

params [["_group", grpNull, [grpNull, objNull]], ["_enemies", [], [[]]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {createHashMap};

private _picture = [_group] call FUNC(pictureGet);
private _leader = leader _group;
private _contacts = _picture get "contacts";
private _now = time;

// merge sightings
{
    private _enemy = _x;
    if (!isNull _enemy && {alive _enemy} && {(side _enemy) isNotEqualTo (side _group)}) then {
        private _pos = _leader getHideFrom _enemy;
        if (_pos isNotEqualTo [0, 0, 0]) then {
            private _knowsAbout = _leader knowsAbout _enemy;
            private _index = _contacts findIf {(_x select 0) isEqualTo _enemy};
            if (_index isEqualTo -1) then {
                _contacts pushBack [_enemy, _pos, _now, _knowsAbout];
            } else {
                _contacts set [_index, [_enemy, _pos, _now, _knowsAbout]];
            };
            _picture set ["lastContact", _now];
        };
    };
} forEach _enemies;

// derived values, at most once per second
if (_now - (_picture get "updated") < REFRESH_INTERVAL) exitWith {
    _picture set ["contacts", _contacts];
    _picture
};
_picture set ["updated", _now];

// forget old and dead contacts
_contacts = _contacts select {alive (_x select 0) && {_now - (_x select 2) < CONTACT_MAX_AGE}};
_picture set ["contacts", _contacts];

// threat centre weighted by recency
if (_contacts isEqualTo []) then {
    _picture set ["threatPos", []];
    _picture set ["threatDir", -1];
} else {
    private _sum = [0, 0, 0];
    private _weightSum = 0;
    {
        _x params ["", "_pos", "_seen"];
        private _weight = 1 - ((_now - _seen) / CONTACT_MAX_AGE);
        _sum = _sum vectorAdd (_pos vectorMultiply _weight);
        _weightSum = _weightSum + _weight;
    } forEach _contacts;
    private _threatPos = _sum vectorMultiply (1 / (_weightSum max 0.01));
    _picture set ["threatPos", _threatPos];
    _picture set ["threatDir", _leader getDir _threatPos];
};

// losses
private _alive = {_x call EFUNC(main,isAlive)} count (units _group);
private _maxCount = (_picture get "maxCount") max (count units _group);
_picture set ["maxCount", _maxCount];
_picture set ["losses", (_maxCount - _alive) max 0];

_picture
