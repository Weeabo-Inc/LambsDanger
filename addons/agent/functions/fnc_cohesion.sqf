#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A group's cohesion from its men's morale, its losses and its leader: steady, strained,
 * broken, rallying. Written into the picture so the squad and the Director read it
 * without touching the men. Cohesion loss degrades coordination, never accuracy
 * (docs/systems/morale.md).
 *
 * Arguments:
 * 0: Group <GROUP>
 *
 * Return Value:
 * the state <STRING>
 *
 * Example:
 * [group bob] call hostis_agent_fnc_cohesion;
 *
 * Public: Yes
*/
#define BROKEN_RATIO 0.5
#define BAD_BROKEN_RATIO 0.7
#define STRAINED_RATIO 0.4
#define BROKEN_MORALE 0.35
#define STRAINED_MORALE 0.6
#define RALLY_TIME 20

params [["_group", grpNull, [grpNull]]];

if (isNull _group || {!local _group}) exitWith {"steady"};
private _picture = [_group] call EFUNC(core,pictureGet);
private _state = _picture getOrDefault ["cohesion", "steady"];
private _since = _picture getOrDefault ["cohesionTime", -1e9];
private _now = time;

private _alive = (units _group) select {_x call LFUNC(main,isAlive) && {!isPlayer _x}};
if (_alive isEqualTo []) exitWith {_state};
private _bad = 0;
private _broken = 0;
{
    private _morale = (_x getVariable [QGVAR(morale), ["steady"]]) select 0;
    if (_morale in ["pinned", "shaken", "broken"]) then {_bad = _bad + 1;};
    if (_morale isEqualTo "broken") then {_broken = _broken + 1;};
} forEach _alive;
private _count = count _alive;
private _badRatio = _bad / _count;
private _brokenRatio = _broken / _count;
private _morale = [_group] call LFUNC(danger,getMorale);
private _leaderAlive = (leader _group) call LFUNC(main,isAlive);
private _losses = _picture get "losses";

private _new = switch (true) do {
    case (_brokenRatio >= BROKEN_RATIO || {_morale < BROKEN_MORALE} || {_badRatio >= BAD_BROKEN_RATIO && {_losses > 0}}): {"broken"};
    case (_badRatio >= STRAINED_RATIO || {_morale < STRAINED_MORALE} || {!_leaderAlive}): {"strained"};
    default {"steady"};
};
// a broken group rallies before it is steady again
if (_new isEqualTo "steady" && {_state in ["broken", "rallying"]}) then {
    _new = ["rallying", "steady"] select (_state isEqualTo "rallying" && {_now - _since > RALLY_TIME});
};

if (_new isNotEqualTo _state) then {
    _picture set ["cohesion", _new];
    _picture set ["cohesionTime", _now];
    _picture set ["cohesionPrev", _state];
    if (_new isEqualTo "rallying") then {[leader _group, "rally", true] call FUNC(bark);};
    if (GVAR(debugMorale) || {LGVAR(main,debug_functions)}) then {
        ["%1 COHESION %2: %3 -> %4 (%5 of %6 bad, %7 broken, morale %8, losses %9)", side _group, groupId _group, _state, _new, _bad, _count, _broken, _morale toFixed 2, _losses] call LFUNC(main,debugLog);
    };
};

_new
