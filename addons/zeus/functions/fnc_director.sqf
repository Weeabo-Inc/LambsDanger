#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Applies the Director's dials on the server: the throttle setting for every side, the
 * side's two budgets, its area of operations, and the squad-layer pause. Answers the
 * curator with one line.
 *
 * Arguments:
 * 0: Side <SIDE>
 * 1: Throttle 0-2 <NUMBER>
 * 2: Reinforcement budget <NUMBER>
 * 3: Fire mission budget <NUMBER>
 * 4: Area of operations centre <ARRAY>
 * 5: Area of operations radius, 0 for none <NUMBER>
 * 6: Squad layer paused <BOOL>
 * 7: Curator client that gets feedback, -1 for none <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east, 1, 3, 4, getPos player, 1500, false, -1] call hostis_zeus_fnc_director;
 *
 * Public: Yes
*/
params [["_side", sideUnknown, [sideUnknown]], ["_throttle", 1, [0]], ["_reinforcements", 3, [0]], ["_fireMissions", 4, [0]], ["_aoPos", [], [[]]], ["_aoRadius", 0, [0]], ["_paused", false, [false]], ["_curatorOwner", -1, [0]]];

if (!isServer) exitWith {};

[QEGVAR(director,throttle), _throttle, true, "mission"] call CBA_settings_fnc_set;
[_side, "reinforcements", _reinforcements] call EFUNC(director,budget);
[_side, "fireMissions", _fireMissions] call EFUNC(director,budget);
[_side, _aoPos, _aoRadius] call EFUNC(director,area);
if (_paused isNotEqualTo (missionNamespace getVariable [QEGVAR(squad,paused), false])) then {[_paused] call EFUNC(squad,pause);};

private _text = format ["Director %1: throttle %2, reinforcements %3, fire missions %4, AO %5, AI %6",
    _side, _throttle, _reinforcements, _fireMissions,
    [format ["%1 m at %2", round _aoRadius, mapGridPosition _aoPos], "none"] select (_aoRadius <= 0),
    ["running", "PAUSED"] select _paused];
if (_curatorOwner >= 0) then {[QLGVAR(danger,curatorFeedback), [_text], _curatorOwner] call CBA_fnc_targetEvent;};
if (ZEUS_DEBUG) then {["ZEUS %1", _text] call LFUNC(main,debugLog);};
