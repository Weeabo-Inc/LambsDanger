#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * How well a group can report right now: who speaks, how far the word carries, how long
 * it takes, how likely it is lost, and how much of it survives. A group that lost its
 * leader recently is slow, lossy and vague; a suppressed reporter is slower still; a
 * radio man carries the word to the side's radio range, otherwise it is shouted
 * (docs/systems/knowledge.md, The net).
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * hashmap: sender, range, shout, radio, delay, loss, quality, leaderless <HASHMAP>
 *
 * Example:
 * [group bob] call hostis_core_fnc_netParams;
 *
 * Public: Yes
*/
#define SUPPRESSED 0.7

params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
private _net = createHashMapFromArray [
    ["sender", objNull], ["range", 0], ["shout", LGVAR(main,radioShout)], ["radio", false],
    ["delay", GVAR(reportDelay)], ["loss", 1], ["quality", 0], ["leaderless", true]
];
if (isNull _group) exitWith {_net};

private _picture = [_group] call FUNC(pictureRefresh);
private _leader = leader _group;
private _units = (units _group) select {_x call LFUNC(main,isAlive)};
if (_units isEqualTo []) exitWith {_net};
if (!(_leader in _units)) then {_leader = _units select 0;};

([_leader, 1000, false] call LFUNC(main,getShareInformationParams)) params ["_sender", "_range", "_radio"];
if (LGVAR(main,radioDisabled)) then {_radio = false;};

private _leaderless = time - (_picture get "leaderLostTime") < GVAR(leaderlessTime);
private _delay = GVAR(reportDelay);
private _loss = GVAR(reportLossChance);
private _quality = 1;
if (_leaderless) then {
    _delay = _delay * GVAR(leaderlessFactor);
    _loss = (_loss * GVAR(leaderlessFactor)) min 0.95;
    _quality = 0.5;
};
if (getSuppression _sender > SUPPRESSED) then {
    _delay = _delay * 2;
    _loss = (_loss * 2) min 0.95;
};

_net set ["sender", _sender];
_net set ["range", [LGVAR(main,radioShout), _range] select _radio];
_net set ["radio", _radio];
_net set ["delay", _delay];
_net set ["loss", _loss];
_net set ["quality", _quality];
_net set ["leaderless", _leaderless];
_picture set ["netQuality", _quality];

_net
