#include "script_component.hpp"
/*
 * Author: nkenny
 * Unit hides inside building or in nearby cover position
 *
 * Arguments:
 * 0: unit hiding <OBJECT>
 * 1: source of danger <OBJECT> or position <ARRAY>
 * 2: range to search for cover and concealment, default is 50 <NUMBER>
 * 3: array of predetermined building positions <ARRAY>
 *
 * Return Value:
 * boolean
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doHide;
 *
 * Public: No
*/
params ["_unit", "_pos", ["_range", 35], ["_buildings", []]];

// stopped -- exit
if (
    (currentCommand _unit) in ["GET IN", "ACTION", "HEAL"]
    || !(_unit checkAIFeature "PATH")
    || !(_unit checkAIFeature "MOVE")
) exitWith {false};

// do nothing when already inside
if (RND(GVAR(indoorMove)) && {_unit call FUNC(isIndoor)}) exitWith {
    _unit setUnitPosWeak (_unit call FUNC(getLowStance));
    doStop _unit;
    false
};

// define buildings
if (_buildings isEqualTo []) then {
    _buildings = [_unit, _range, true, true] call FUNC(findBuildings);
};

// variables
_unit setVariable [QGVAR(currentTarget), _pos, GVAR(debug_functions)];
_unit setVariable [QGVAR(currentTask), "Hide!", GVAR(debug_functions)];

// set speed
_unit forceSpeed 24;

// set stance and speed reset
[
    {
        if (alive _this) then {
            _this setUnitPos "AUTO";
            _this setUnitPosWeak (_this call FUNC(getLowStance));
            _this forceSpeed -1;
        };
    },
    _unit,
    6 + random 4
] call CBA_fnc_waitAndExecute;

// Randomly scatter into buildings or hide!
if ( RND(0.2) && { _buildings isNotEqualTo [] } ) exitWith {

    // update variable
    _unit setVariable [QGVAR(currentTask), "Hide (inside)", GVAR(debug_functions)];

    // execute move
    _unit setUnitPos "MIDDLE";
    _unit doMove (_buildings selectRandomWeighted (_buildings apply { _unit distance2D _x }) );

    // debug
    if (GVAR(debug_functions)) then {
        ["%1 hide in building (%2 - %3x positions)", side _unit, name _unit, count _buildings] call FUNC(debugLog);
    };
};

// hide
_unit setUnitPos (_unit call FUNC(getLowStance));

// check for rear-cover
private _cover = nearestTerrainObjects [ _unit getPos [5, _pos getDir _unit], ["BUSH", "TREE", "SMALL TREE", "HIDE", "WALL", "FENCE"], 15, false, true ];

// remove those close to danger
private _distance2D = (_unit distance2D _pos) + 2;
_cover = _cover select {_x distance2D _pos > _distance2D;};

// targetPos
private _targetPos = if (_cover isEqualTo []) then {
    _unit getPos [25 + random _range, (_pos getDir _unit) + 20 - random 40]
} else {
    (_cover select 0) getPos [1, _pos getDir (_cover select 0)]
};

// water means hold
if (surfaceIsWater _targetPos) exitWith {
    false
};

// cover move or stay put ~ the stop is bounded so the unit rejoins its formation on its own
private _fnc_stopThenFollow = {
    doStop _this;
    [{if (alive _this) then {_this doFollow (leader _this);};}, _this, 20 + random 10] call CBA_fnc_waitAndExecute;
};
if (_unit distanceSqr _targetPos > 1.5) then {
    _unit doMove _targetPos;
    [{unitReady _this}, _fnc_stopThenFollow, _unit, 2] call CBA_fnc_waitUntilAndExecute;
} else {
    _unit call _fnc_stopThenFollow;
};

// debug
if (GVAR(debug_functions)) then {
    ["%1 hide in bush (%2)", side _unit, name _unit] call FUNC(debugLog);
};

// end
true
