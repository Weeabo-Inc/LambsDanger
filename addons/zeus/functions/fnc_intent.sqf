#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The one door through which a Zeus, a waypoint or a mission maker tells a group what it
 * is for (ADR-0013). Sets the intent on the group's owner and starts the task the intent
 * needs: attack runs the Attack Position task, defend the Defend task, and the rest stop
 * whatever task was running. Fields left nil keep their value.
 *
 * One sentence: "Zeus told them what to do, not how."
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Mode "free", "hold", "defend", "attack" or "reserve" <STRING>
 * 2: Objective position, [] for the leader's position <ARRAY>, optional
 * 3: Radius <NUMBER>, optional
 * 4: Posture 0-2 <NUMBER>, optional
 * 5: Escalation cap 0-3 <NUMBER>, optional
 * 6: Curator client that gets feedback, -1 for none <NUMBER>, optional
 *
 * Return Value:
 * accepted <BOOL>
 *
 * Example:
 * [group bob, "defend", getPos bob, 100] call hostis_zeus_fnc_intent;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_mode", "free", [""]], ["_objective", [], [[]]], "_radius", "_posture", "_cap", ["_curatorOwner", -1, [0]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!(_mode in INTENT_MODES)}) exitWith {false};
private _leader = leader _group;
if (isNull _leader || {isPlayer _leader}) exitWith {false};

private _current = [_group] call LFUNC(danger,intentGet);
if (isNil "_radius") then {_radius = _current select 2;};
if (isNil "_posture") then {_posture = _current select 3;};
if (isNil "_cap") then {_cap = _current select 4;};
if (_objective isEqualTo [] && {_mode in ["hold", "defend", "attack"]}) then {_objective = getPosATL _leader;};
if (_mode in ["free", "reserve"]) then {_objective = [];};

// the intent itself, on the group owner
[QLGVAR(danger,intent), [_group, _mode, _objective, _radius, _posture, _cap], _leader] call CBA_fnc_targetEvent;

// the task that gets the group there; free, hold and reserve drop whatever task ran
switch (_mode) do {
    case "attack": {[QLGVAR(wp,taskAttack), [_group, _objective, _radius, -1, _curatorOwner], _leader] call CBA_fnc_targetEvent;};
    case "defend": {[QLGVAR(wp,taskDefend), [_group, _objective, _radius, [], false, 0, true, false], _leader] call CBA_fnc_targetEvent;};
    default {[QLGVAR(wp,taskReset), [_group], _leader] call CBA_fnc_targetEvent;};
};

if (_curatorOwner >= 0) then {
    [QLGVAR(danger,curatorFeedback), [format ["%1: %2%3", groupId _group, _mode, ["", format [" at %1", mapGridPosition _objective]] select (_objective isNotEqualTo [])]], _curatorOwner] call CBA_fnc_targetEvent;
};
if (ZEUS_DEBUG) then {["ZEUS intent %1 %2: %3 radius %4 posture %5 cap %6", side _group, groupId _group, _mode, _radius, _posture, _cap] call LFUNC(main,debugLog);};

true
