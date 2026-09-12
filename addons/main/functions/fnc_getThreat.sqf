#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * How much personal danger a soldier feels he is in, 0 to 1, and the level that goes
 * with it. Built from what he has just been through (stress, suppression, a hit, a
 * wound) and where he is (in the open, on his own, outnumbered at close range):
 *   0 fine   1 uneasy   2 danger, get to cover   3 mortal, do anything to live
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Cheap check, no target scan <BOOL>, default false
 *
 * Return Value:
 * [level, score] <ARRAY>
 *
 * Example:
 * [bob] call lambs_main_fnc_getThreat;
 *
 * Public: Yes
*/
#define WEIGHT_STRESS 0.35
#define WEIGHT_SUPPRESSION 0.25
#define BONUS_HIT 0.35
#define BONUS_WOUNDED 0.2
#define BONUS_EXPOSED 0.15
#define BONUS_ALONE 0.1
#define BONUS_OUTNUMBERED 0.25
#define HIT_MEMORY 8
#define CONTACT_MEMORY 20
#define CLOSE_RANGE 30
#define ALONE_DISTANCE 40
#define LEVEL_MORTAL 0.85
#define LEVEL_DANGER 0.55
#define LEVEL_UNEASY 0.3

params [["_unit", objNull, [objNull]], ["_cheap", false, [false]]];

if (isNull _unit || {!(_unit call FUNC(isAlive))}) exitWith {[0, 0]};

private _score = (WEIGHT_STRESS * (_unit call FUNC(getStress))) + (WEIGHT_SUPPRESSION * ((getSuppression _unit) max 0));

// just hit, or wounded
if (time - (_unit getVariable [QGVAR(lastHit), -1e9]) < HIT_MEMORY) then {_score = _score + BONUS_HIT;};
if (damage _unit > 0.3) then {_score = _score + BONUS_WOUNDED;};

// the ground he is on only matters while somebody is shooting
private _group = group _unit;
private _picture = _group getVariable QEGVAR(danger,picture);
private _inContact = !isNil "_picture" && {time - (_picture get "lastContact") < CONTACT_MEMORY};
if (_inContact) then {
    if (
        (stance _unit) isNotEqualTo "PRONE"
        && {isNull objectParent _unit}
        && {!(_unit call FUNC(isIndoor))}
        && {(nearestTerrainObjects [_unit, ["BUSH", "TREE", "SMALL TREE", "HIDE", "WALL", "ROCK", "FENCE", "HOUSE"], 5, false, true]) isEqualTo []}
    ) then {_score = _score + BONUS_EXPOSED;};
    if (count (units _group) > 1 && {_unit distance2D (leader _group) > ALONE_DISTANCE}) then {_score = _score + BONUS_ALONE;};
    if (!_cheap) then {
        private _near = _unit targets [true, CLOSE_RANGE];
        if (count _near >= 2 || {_near isNotEqualTo [] && {_unit distance2D (leader _group) > ALONE_DISTANCE}}) then {_score = _score + BONUS_OUTNUMBERED;};
    };
};

_score = _score min 1;
private _level = switch (true) do {
    case (_score >= LEVEL_MORTAL): {3};
    case (_score >= LEVEL_DANGER): {2};
    case (_score >= LEVEL_UNEASY): {1};
    default {0};
};

[_level, _score]
