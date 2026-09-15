#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Everything a tactic precondition or start needs to know about a group, read once per
 * think from the picture, the intent and the men. Nothing here reads the engine's truth
 * about the enemy (FAIRNESS.md R6: the squad decides from its own picture).
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Escalation level, -1 to read it from the picture <NUMBER>
 *
 * Return Value:
 * context <HASHMAP>
 *
 * Example:
 * [group bob] call hostis_squad_fnc_tacticContext;
 *
 * Public: Yes
*/
#define CONTACT_AGE 60
#define WITHDRAW_REST 300

params [["_group", grpNull, [grpNull, objNull]], ["_level", -1, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
private _ctx = createHashMap;
if (isNull _group) exitWith {_ctx};

private _leader = leader _group;
private _picture = [_group] call EFUNC(core,pictureRefresh);
private _intent = [_group] call LFUNC(danger,intentGet);
_intent params ["_mode", "_objective", "_radius", "_posture", "_cap", "_home"];
if (_level < 0) then {_level = _picture getOrDefault ["escalation", 0];};
private _threatPos = _picture get "threatPos";
private _contacts = [_group, CONTACT_AGE] call EFUNC(core,contactsGet);
private _confidence = 0;
{_confidence = _confidence max (_x select CONTACT_CONF);} forEach _contacts;
private _newest = _contacts param [0, []];
private _onFoot = (units _group) select {isNull objectParent _x && {_x call LFUNC(main,isAlive)} && {!isPlayer _x}};
private _gunners = _onFoot select {_x call LFUNC(main,isSupportGunner)};
private _distance = if (_threatPos isEqualTo []) then {1e9} else {_leader distance2D _threatPos};
private _defending = _mode in ["hold", "defend"] && {_objective isNotEqualTo []};

_ctx set ["group", _group];
_ctx set ["leader", _leader];
_ctx set ["picture", _picture];
_ctx set ["mode", _mode];
_ctx set ["objective", _objective];
_ctx set ["radius", _radius];
_ctx set ["posture", _posture];
_ctx set ["home", _home];
_ctx set ["level", _level];
_ctx set ["threatPos", _threatPos];
_ctx set ["distance", _distance];
_ctx set ["contacts", _contacts];
_ctx set ["newest", _newest];
_ctx set ["confidence", _confidence];
_ctx set ["onFoot", _onFoot];
_ctx set ["count", count _onFoot];
_ctx set ["gunners", _gunners];
_ctx set ["cohesion", _picture getOrDefault ["cohesion", "steady"]];
_ctx set ["morale", [_group] call LFUNC(danger,getMorale)];
_ctx set ["role", _group getVariable [QLGVAR(danger,role), ""]];
_ctx set ["incoming", [_group, 6] call EFUNC(core,fireIncoming)];
_ctx set ["lastContactAge", time - (_picture get "lastContact")];
_ctx set ["pictureAge", _picture get "pictureAge"];
_ctx set ["cqbRange", LGVAR(danger,cqbRange)];
_ctx set ["rested", time - (_picture get "withdrawTime") > WITHDRAW_REST];
_ctx set ["defending", _defending];
_ctx set ["insideArea", _defending && {_threatPos isNotEqualTo []} && {_threatPos distance2D _objective < _radius}];
_ctx set ["vehicles", ([_leader] call LFUNC(main,findReadyVehicles)) select {someAmmo _x}];
// the Director's word that the enemy has guns or air overhead (C-55), and whether a flare would help
_ctx set ["hug", missionNamespace getVariable [format [QEGVAR(director,hug_%1), side _group], false]];
_ctx set ["night", sunOrMoon < 0.5];

_ctx
