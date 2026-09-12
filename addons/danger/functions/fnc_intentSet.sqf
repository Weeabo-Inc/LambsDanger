#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Sets what a group is meant to do (see intentGet). Fields passed as nil keep their
 * current value. Runs on the group owner; forwarded there if called elsewhere.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Mode "free", "hold", "defend" or "attack" <STRING>, optional
 * 2: Objective position <ARRAY>, optional
 * 3: Radius <NUMBER>, optional
 * 4: Posture 0-2 <NUMBER>, optional
 * 5: Escalation cap 0-3 <NUMBER>, optional
 *
 * Return Value:
 * intent <ARRAY>
 *
 * Example:
 * [group bob, "defend", getPos bob, 100, 2] call lambs_danger_fnc_intentSet;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], "_mode", "_objective", "_radius", "_posture", "_cap"];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {[]};
if (!local _group) exitWith {
    [QGVAR(intent), _this, leader _group] call CBA_fnc_targetEvent;
    []
};

private _intent = +([_group] call FUNC(intentGet));
if (!isNil "_mode") then {_intent set [0, _mode];};
if (!isNil "_objective") then {_intent set [1, _objective];};
if (!isNil "_radius") then {_intent set [2, _radius max 10];};
if (!isNil "_posture") then {_intent set [3, (_posture max 0) min 2];};
if (!isNil "_cap") then {_intent set [4, (_cap max 0) min 3];};
_intent set [6, time];

// hold and defend make the objective the new home
if ((_intent select 0) in ["hold", "defend"] && {(_intent select 1) isNotEqualTo []}) then {
    _intent set [5, _intent select 1];
};

_group setVariable [QGVAR(intent), _intent, true];
[_group] call FUNC(commanderRegister);

if (EGVAR(main,debug_functions)) then {
    ["%1 INTENT %2: %3 posture %4 cap %5", side _group, groupId _group, _intent select 0, _intent select 3, _intent select 4] call EFUNC(main,debugLog);
};

_intent
