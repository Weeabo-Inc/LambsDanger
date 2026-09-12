#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Terrain analysis for an attack on a position. Compares the left and right flank of
 * the direct line by concealment (trees, forest, buildings) and dead ground from the
 * objective, and returns:
 *   0: route         positions the assault element follows, ending at the assault position
 *   1: assaultPos    last covered spot short of the objective, on the chosen flank
 *   2: supportPos    support by fire position with a line of sight to the objective
 *   3: side          -1 left, 1 right of the direct line
 *
 * Arguments:
 * 0: Start position AGL <ARRAY>
 * 1: Objective position AGL <ARRAY>
 *
 * Return Value:
 * [route, assaultPos, supportPos, side] <ARRAY>
 *
 * Example:
 * [getPos bob, getPos angryJoe] call lambs_main_fnc_findApproach;
 *
 * Public: No
*/
#define FLANK_ANGLE 65
#define ASSAULT_DISTANCE 110
#define MIDPOINT_OFFSET_MAX 250
#define SUPPORT_MIN 120
#define SUPPORT_MAX 260
#define SEARCH_RADIUS 50
#define SEARCH_PRECISION 25
#define CONCEALMENT "(3 * forest) + (2 * trees) + (1.5 * houses) + (0.5 * hills) - (2 * meadow) - (5 * sea)"

params [["_from", [0, 0, 0], [[]]], ["_objective", [0, 0, 0], [[]]]];

private _direction = _from getDir _objective;
private _distance = _from distance2D _objective;
private _objectiveASL = (AGLToASL _objective) vectorAdd [0, 0, 1.5];

// score one candidate spot: how concealed it is, and whether the objective can see it
private _fnc_score = {
    params ["_pos"];
    private _places = selectBestPlaces [_pos, SEARCH_RADIUS, CONCEALMENT, SEARCH_PRECISION, 1];
    private _best = _pos;
    private _score = 0;
    if (_places isNotEqualTo []) then {
        (_places select 0) params ["_bestPos", "_value"];
        if (!surfaceIsWater _bestPos) then {_best = _bestPos;};
        _score = _value;
    };
    if (terrainIntersectASL [(AGLToASL _best) vectorAdd [0, 0, 1], _objectiveASL]) then {_score = _score + 2;};
    [_best, _score]
};

// both flanks
private _candidates = [];
{
    private _side = _x;
    private _lateral = (_distance * 0.4) min MIDPOINT_OFFSET_MAX;
    private _midpoint = (_from getPos [_distance * 0.5, _direction]) getPos [_lateral, _direction + (_side * 90)];
    private _assaultPos = _objective getPos [ASSAULT_DISTANCE min (_distance * 0.6), _direction + 180 + (_side * FLANK_ANGLE)];
    ([_midpoint] call _fnc_score) params ["_midBest", "_midScore"];
    ([_assaultPos] call _fnc_score) params ["_assaultBest", "_assaultScore"];
    _candidates pushBack [_midScore + (2 * _assaultScore), _side, [_midBest, _assaultBest], _assaultBest];
} forEach [-1, 1];
_candidates sort false;
(_candidates select 0) params ["", "_side", "_route", "_assaultPos"];

// support by fire ~ height and a line of sight, on our side of the objective, off the assault flank
private _supportCentre = _objective getPos [(SUPPORT_MIN + SUPPORT_MAX) / 2, _direction + 180 - (_side * 25)];
private _supportPos = [_objective, SUPPORT_MAX - SUPPORT_MIN, SUPPORT_MIN, 4, _supportCentre] call FUNC(findOverwatch);
if (_supportPos isEqualTo [] || {_supportPos isEqualTo [0, 0, 0]}) then {_supportPos = _supportCentre;};

[_route, _assaultPos, _supportPos, _side]
