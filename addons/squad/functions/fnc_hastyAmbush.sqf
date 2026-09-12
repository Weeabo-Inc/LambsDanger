#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Start of the hasty ambush (docs/systems/tactics.md, RESEARCH.md C-51): the group has
 * seen or been told of an enemy moving its way and has not been engaged. It lays an L:
 * riflemen along a line across the enemy's approach, the machine gun on the short leg to
 * one side firing down the long axis of the kill zone, everyone in cover, weapons hold
 * until the enemy is inside the spring range or fires first. The monitor springs it.
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
#define SPACING 6
#define SHORT_LEG 25
#define KILL_ZONE 80

params [["_group", grpNull, [grpNull]], ["_ctx", createHashMap, [createHashMap]], ["_state", createHashMap, [createHashMap]]];

private _threatPos = _ctx get "threatPos";
if (_threatPos isEqualTo []) exitWith {false};
private _leader = leader _group;
private _units = _ctx get "onFoot";
if (count _units < 3) exitWith {false};

private _approach = _leader getDir _threatPos;
private _anchor = getPosATL _leader;
private _killZone = _anchor getPos [KILL_ZONE, _approach];

// the gun goes on the short leg, the side with the better cover
private _gunners = _ctx get "gunners";
private _gun = if (_gunners isEqualTo []) then {objNull} else {_gunners select 0};
private _side = 90;
private _bestScore = -1e9;
{
    private _candidate = _anchor getPos [SHORT_LEG, _approach + _x];
    private _positions = [_candidate, 12, [_killZone], createHashMapFromArray [["purpose", "fight"], ["count", 1], ["group", _group]]] call LFUNC(main,findPositions);
    private _score = if (_positions isEqualTo []) then {-10} else {(_positions select 0) select 4};
    if (_score > _bestScore) then {_bestScore = _score; _side = _x;};
} forEach [90, -90];

// group orders ~ quiet until sprung
_group enableAttack false;
_group setCombatMode "GREEN";
_group setSpeedMode "NORMAL";
_group setFormation "LINE";
_group setFormDir _approach;
_group setBehaviourStrong "AWARE";
{
    _x setVariable [QLGVAR(danger,forceMove), true];
    _x disableAI "AUTOCOMBAT";
} forEach _units;

// the long leg across the approach, the gun on the short leg looking down it
private _riflemen = _units - [_gun];
{
    private _offset = (_forEachIndex - ((count _riflemen) - 1) / 2) * SPACING;
    private _slot = _anchor getPos [_offset, _approach + 90];
    private _options = createHashMapFromArray [["onArrive", "hold"], ["radius", 10], ["sector", [_approach, 50]], ["task", "Ambush, long leg"], ["covered", true]];
    [_x, "hold", _slot, [_killZone], _options] call LFUNC(danger,unitOrder);
} forEach _riflemen;
if (!isNull _gun) then {
    private _slot = _anchor getPos [SHORT_LEG, _approach + _side];
    private _options = createHashMapFromArray [["onArrive", "hold"], ["radius", 10], ["sector", [_slot getDir _killZone, 40]], ["task", "Ambush, gun on the short leg"], ["covered", true]];
    [_gun, "hold", _slot, [_killZone], _options] call LFUNC(danger,unitOrder);
};
[_leader, "stayAlert", true] call EFUNC(agent,bark);

private _data = _state get "data";
_data set ["sprung", false];
_data set ["killZone", _killZone];
_state set ["objective", _threatPos];

if (SQUAD_DEBUG) then {
    ["%1 TACTIC %2: hasty ambush across %3 deg, gun %4, enemy at %5 m", side _group, groupId _group, round _approach, ["absent", ["right", "left"] select (_side < 0)] select (!isNull _gun), round (_ctx get "distance")] call LFUNC(main,debugLog);
    private _m = [_killZone, "kill zone", _leader call LFUNC(main,debugMarkerColor), "hd_destroy"] call LFUNC(main,dotMarker);
    [{deleteMarker _this}, _m, 300] call CBA_fnc_waitAndExecute;
};

true
