#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Group morale 0 (broken) to 1 (fresh), from losses, the stress of its members,
 * the state of the leader and the leader's courage. Cached for a few seconds.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * morale 0..1 <NUMBER>
 *
 * Example:
 * [group bob] call lambs_danger_fnc_getMorale;
 *
 * Public: Yes
*/
#define CACHE_TIME 5
#define WEIGHT_LOSSES 0.6
#define WEIGHT_STRESS 0.3
#define PENALTY_LEADER_DOWN 0.15
#define WEIGHT_COURAGE 0.3

params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {1};

private _picture = [_group] call FUNC(pictureGet);
if (time - (_picture get "moraleTime") < CACHE_TIME) exitWith {_picture get "morale"};

private _units = (units _group) select {_x call EFUNC(main,isAlive)};
if (_units isEqualTo []) exitWith {0};

// losses
private _maxCount = (_picture get "maxCount") max 1;
private _lossRatio = ((_picture get "losses") / _maxCount) min 1;

// stress
private _stress = 0;
{_stress = _stress + (_x call EFUNC(main,getStress));} forEach _units;
_stress = _stress / (count _units);

// leadership
private _leader = leader _group;
private _leaderDown = !(_leader call EFUNC(main,isAlive));
private _courage = (_leader skillFinal "courage") - 0.5;

private _morale = 1 - (WEIGHT_LOSSES * _lossRatio) - (WEIGHT_STRESS * _stress) - ([0, PENALTY_LEADER_DOWN] select _leaderDown) + (WEIGHT_COURAGE * _courage);
_morale = (_morale max 0) min 1;

_picture set ["morale", _morale];
_picture set ["moraleTime", time];

_morale
