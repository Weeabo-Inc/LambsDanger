#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Start of the search (docs/systems/tactics.md, RESEARCH.md C-03, C-40): the group has
 * lost its contact and goes to look where he could have gone, not where he is. Pairs
 * move to points on the edge of the last known position's error circle, on the far side
 * and to both flanks, and hold there facing outward; the leader and the rest take a
 * vantage short of the last known position. Nothing here reads the enemy's true
 * position; the circle is the picture's own error (FAIRNESS.md R4).
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Context <HASHMAP>
 * 2: Tactic state <HASHMAP>
 *
 * Return Value:
 * started <BOOL>
 *
 * Example:
 * called by hostis_squad_fnc_tacticStart
 *
 * Public: No
*/
#define MIN_RADIUS 25
#define VANTAGE 40

params [["_group", grpNull, [grpNull]], ["_ctx", createHashMap, [createHashMap]], ["_state", createHashMap, [createHashMap]]];

private _leader = leader _group;
private _last = [_group, -1, 0, [], [], 0, false] call EFUNC(core,contactsGet);
if (_last isEqualTo []) exitWith {false};
_last = _last select 0;
private _lastKnown = _last select CONTACT_POS;
private _radius = (_last select CONTACT_ERROR) max MIN_RADIUS;
private _units = _ctx get "onFoot";
if (count _units < 2) exitWith {false};

private _approach = _leader getDir _lastKnown;
_group enableAttack true;
_group setCombatMode "RED";
_group setSpeedMode "NORMAL";
_group setBehaviourStrong "AWARE";

// the exits: beyond, left and right of the last known position, on the edge of the circle
private _exits = [_approach, _approach + 120, _approach - 120] apply {_lastKnown getPos [_radius, _x]};
private _searchers = _units - [_leader];
private _pairs = [];
for "_i" from 0 to ((count _searchers) - 1) step 2 do {
    _pairs pushBack (_searchers select [_i, 2]);
};
{
    private _exit = _exits select (_forEachIndex mod (count _exits));
    {
        private _slot = _exit getPos [3 * _forEachIndex, _approach + 90];
        private _options = createHashMapFromArray [["onArrive", "hold"], ["radius", 12], ["sector", [_lastKnown getDir _exit, 70]], ["task", "Searching"], ["covered", true]];
        [_x, "move", _slot, [_lastKnown], _options] call LFUNC(danger,unitOrder);
    } forEach _x;
} forEach _pairs;

// the leader watches from short of it
private _vantage = _lastKnown getPos [_radius + VANTAGE, _approach + 180];
[_leader, "move", _vantage, [_lastKnown], createHashMapFromArray [["onArrive", "hold"], ["radius", 15], ["sector", [_approach, 60]], ["task", "Searching, overwatch"], ["covered", true]]] call LFUNC(danger,unitOrder);
[_leader, "keepFocused", true] call EFUNC(agent,bark);

private _data = _state get "data";
_data set ["lastKnown", _lastKnown];
_data set ["radius", _radius];
_state set ["objective", _lastKnown];

if (SQUAD_DEBUG) then {
    ["%1 TACTIC %2: search around a %3 s old %4 contact, circle %5 m, %6 pairs", side _group, groupId _group, round (time - (_last select CONTACT_TIME)), _last select CONTACT_SOURCE, round _radius, count _pairs] call LFUNC(main,debugLog);
    private _m = [_lastKnown, "last known", _leader call LFUNC(main,debugMarkerColor), "hd_unknown"] call LFUNC(main,dotMarker);
    [{deleteMarker _this}, _m, 300] call CBA_fnc_waitAndExecute;
};

true
