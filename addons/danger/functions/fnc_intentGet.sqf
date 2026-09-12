#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns the intent a Zeus or mission maker gave a group: the box the AI commander
 * improvises inside. Created with defaults on first use.
 *
 *   0: mode          "free" (react, then go home), "hold" (stay on the objective),
 *                    "defend" (stay, counterattack inside the radius), "attack" (task running)
 *   1: objective     position the mode refers to, [] for none
 *   2: radius        how far from the objective the group may roam (m)
 *   3: posture       0 cautious, 1 balanced, 2 aggressive
 *   4: escalationCap highest escalation level the group may reach (0-3)
 *   5: home          where the group started, used by "free"
 *   6: set           time the intent was last set
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * intent <ARRAY>
 *
 * Example:
 * [group bob] call lambs_danger_fnc_intentGet;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {["free", [], 50, 1, 3, [0, 0, 0], -1]};

private _intent = _group getVariable QGVAR(intent);
if (isNil "_intent") then {
    _intent = ["free", [], 50, GVAR(commanderPosture), 3, getPosATL (leader _group), time];
    _group setVariable [QGVAR(intent), _intent];
};

_intent
