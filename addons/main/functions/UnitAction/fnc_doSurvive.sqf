#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A soldier looks after himself. Level 2: into the nearest cover, head down, then back
 * up to return fire. Level 3: break away from the threat to cover 20-35 m off, on the
 * diagonal, sprinting, smoke when there is nothing to hide behind, then down and a
 * look. An enemy within arm's reach is fought instead of run from. The movement is an
 * order to the per-soldier machine (lambs_danger_fnc_unitOrder), which picks the spot,
 * runs the legs and the peek and duck rhythm, and hands the man back to his leader.
 * While it lasts the unit is marked so group manoeuvres leave it alone.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Threat level 2 or 3 <NUMBER>
 * 2: Threat position AGL, [] for the group's picture <ARRAY>
 *
 * Return Value:
 * acted <BOOL>
 *
 * Example:
 * [bob, 3, getPos angryJoe] call lambs_main_fnc_doSurvive;
 *
 * Public: No
*/
#define COOLDOWN 8
#define COVER_RANGE 15
#define FIGHT_RANGE 8
#define HOLD_COVER 6

params [["_unit", objNull, [objNull]], ["_level", 2, [0]], ["_threatPos", [], [[]]]];

if (
    isNull _unit || {!(_unit call FUNC(isAlive))} || {isPlayer _unit} || {!isNull objectParent _unit}
    || {time < (_unit getVariable [QGVAR(surviveTime), 0])}
    || {!(_unit checkAIFeature "PATH")} || {!(_unit checkAIFeature "MOVE")}
) exitWith {false};
_unit setVariable [QGVAR(surviveTime), time + COOLDOWN];

// where the danger is
if (_threatPos isEqualTo []) then {
    private _picture = (group _unit) getVariable QEGVAR(danger,picture);
    if (!isNil "_picture") then {_threatPos = _picture get "threatPos";};
};
if (_threatPos isEqualTo []) then {
    private _enemy = _unit findNearestEnemy _unit;
    _threatPos = if (isNull _enemy) then {_unit getPos [50, getDir _unit]} else {_unit getHideFrom _enemy};
};

// somebody on top of him ~ fight, running gets you shot in the back
if (_level >= 3 && {(_unit targets [true, FIGHT_RANGE]) isNotEqualTo []}) exitWith {
    private _target = (_unit targets [true, FIGHT_RANGE]) select 0;
    _unit setVariable [QGVAR(currentTask), "Fighting for his life", GVAR(debug_functions)];
    [_unit, _target] call FUNC(doAssault);
    true
};

// already flat behind something: stay there, hopping between bushes is what gets you killed
if (
    _level < 3
    && {(stance _unit) isEqualTo "PRONE"}
    && {(nearestTerrainObjects [_unit, ["BUSH", "TREE", "SMALL TREE", "HIDE", "WALL", "ROCK", "FENCE", "HOUSE"], 4, false, true]) isNotEqualTo [] || {_unit call FUNC(isIndoor)}}
) exitWith {
    _unit setVariable [QGVAR(currentTask), "Head down", GVAR(debug_functions)];
    false
};

// the machine takes him: cover close by, or a break away
private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (isNil "_order") exitWith {false};
private _acted = if (_level >= 3) then {
    [_unit, "combat", ["contact", "panic"] select (damage _unit > 0.3), 60] call FUNC(doCallout);
    [_unit, "survive", [], [_threatPos], createHashMapFromArray [["onArrive", "hold"], ["task", "Breaking away"]]] call _order
} else {
    private _options = createHashMapFromArray [["radius", COVER_RANGE], ["holdTime", HOLD_COVER], ["onArrive", "hold"], ["task", "Getting to cover"]];
    private _ok = [_unit, "cover", [], [_threatPos], _options] call _order;
    if (_ok) then {_unit setVariable [QGVAR(survival), time + HOLD_COVER + 4];};
    _ok
};

// debug
if (_acted && GVAR(debug_functions)) then {
    ["%1 %2 survives (level %3)", side _unit, name _unit, _level] call FUNC(debugLog);
};

_acted
