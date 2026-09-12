#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Recomputes the derived values of a group's picture: forgets contacts older than the
 * memory setting, keeps dead ones a little longer, weighs the threat centre by confidence
 * and source, counts losses and notices a lost leader. Cheap, and gated to once per
 * second unless forced.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Force a refresh now, default false <BOOL>
 *
 * Return Value:
 * combat picture <HASHMAP>
 *
 * Example:
 * [group bob] call hostis_core_fnc_pictureRefresh;
 *
 * Public: Yes
*/
#define REFRESH_INTERVAL 1
#define DEAD_KEEP 120

params [["_group", grpNull, [grpNull, objNull]], ["_force", false, [false]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {createHashMap};

private _picture = [_group] call FUNC(pictureGet);
private _now = time;
if (!_force && {_now - (_picture get "updated") < REFRESH_INTERVAL}) exitWith {_picture};
_picture set ["updated", _now];

// forget
private _maxAge = GVAR(contactMaxAge);
private _contacts = (_picture get "contacts") select {
    private _age = _now - (_x select CONTACT_TIME);
    _age < _maxAge && {!(_x select CONTACT_DEAD) || {_age < DEAD_KEEP}}
};
_picture set ["contacts", _contacts];

// threat centre weighted by confidence, source and strength
private _live = _contacts select {!(_x select CONTACT_DEAD)};
if (_live isEqualTo []) then {
    _picture set ["threatPos", []];
    _picture set ["threatDir", -1];
    _picture set ["pictureAge", 1e9];
} else {
    private _sum = [0, 0, 0];
    private _weightSum = 0;
    private _newest = -1e9;
    {
        private _weight = (CONTACT_CONFIDENCE(_x)) * (SOURCE_WEIGHT(_x select CONTACT_SOURCE)) * ((_x select CONTACT_STRENGTH) max 1);
        _sum = _sum vectorAdd ((_x select CONTACT_POS) vectorMultiply _weight);
        _weightSum = _weightSum + _weight;
        _newest = _newest max (_x select CONTACT_TIME);
    } forEach _live;
    private _threatPos = _sum vectorMultiply (1 / (_weightSum max 0.01));
    _picture set ["threatPos", _threatPos];
    private _leader = leader _group;
    _picture set ["threatDir", [-1, _leader getDir _threatPos] select (!isNull _leader)];
    _picture set ["pictureAge", _now - _newest];
};

// losses
private _alive = {_x call LFUNC(main,isAlive)} count (units _group);
private _maxCount = (_picture get "maxCount") max (count units _group);
_picture set ["maxCount", _maxCount];
_picture set ["losses", (_maxCount - _alive) max 0];

// a lost leader slows everything the group says (docs/systems/knowledge.md, The net)
private _leader = leader _group;
private _lastLeader = _picture get "leaderUnit";
if (_leader isNotEqualTo _lastLeader && {!isNull _lastLeader} && {!(_lastLeader call LFUNC(main,isAlive))}) then {
    _picture set ["leaderLostTime", _now];
};
_picture set ["leaderUnit", _leader];

_picture
