#include "script_component.hpp"
/*
 * Author: nkenny
 * Plays an immediate reaction unit getting hit (internal to FSM)
 *
 * Arguments:
 * 0: unit hit <OBJECT>
 * 1: position of danger <ARRAY> or <OBJECT>
 *
 * Return Value:
 * bool
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doDodge;
 *
 * Public: No
*/
#define NEAR_DISTANCE 22

params ["_unit", ["_pos", [0, 0, 0]]];

// ACE3 captive exit, dodge cooldown
if (
    GVAR(disableAIDodge)
    || {!(_unit checkAIFeature "MOVE")}
    || {!(_unit checkAIFeature "PATH")}
    || {((currentWeapon _unit) isNotEqualTo (primaryWeapon _unit))}
    || {(_unit getVariable [QGVAR(dodgeTime), -1]) > time}
) exitWith {false};

// dodge
_unit setVariable [QGVAR(currentTask), "Dodge!", GVAR(debug_functions)];
_unit setVariable [QGVAR(currentTarget), _pos, GVAR(debug_functions)];
_unit setVariable [QGVAR(dodgeTime), time + (missionNamespace getVariable [QEGVAR(danger,dodgeCooldown), 0])];

// settings
private _stance = stance _unit;
private _dir = _unit getRelDir _pos;
private _still = (speed _unit) isEqualTo 0;
private _assertive = (missionNamespace getVariable [QEGVAR(danger,aggression), 0]) > 0;
private _directed = _unit call FUNC(isDirected);

// prone override ~ assertive units only roll when they are being suppressed
if (_still && {_stance isEqualTo "PRONE"} && {!_assertive || {getSuppression _unit > 0.5}} && {!(lineIntersects [eyePos _unit, (eyePos _unit) vectorAdd [0, 0, 7]])}) exitWith {
    [_unit, ["EvasiveLeft", "EvasiveRight"] select (_dir > 180), true] call FUNC(doGesture);
    true
};

// callout
if (RND(0.8)) then {
    [_unit, "Combat", "UnderFireE", 125] call FUNC(doCallout);
};

// settings
private _nearDistance = (_unit distance2D _pos) < NEAR_DISTANCE;

// drop stance
if (_stance isEqualTo "STAND") then {_unit setUnitPosWeak "MIDDLE";};

// chose anim
private _anim = call {

    // drop down ~ not while a Zeus directs the group, assertive units crouch instead of diving
    if (!(_nearDistance || _still) && {!_directed}) exitWith {
        private _lowStance = _unit call FUNC(getLowStance);
        _unit setUnitPosWeak _lowStance;
        [["Down"], ["TactLB", "TactRB"]] select (_lowStance isEqualTo "MIDDLE")
    };

    // move back ~ more checks because sometimes we want the AI to move forward in CQB - nkenny
    if (_still && {!_nearDistance} && {!_directed} && {_dir > 320 || { _dir < 40 }}) exitWith {
        [["FastB", "FastLB", "FastRB"], ["TactB", "TactLB","TactRB"]] select (getSuppression _unit > 0.7);
    };

    // move left
    if ( _dir < 80) exitWith {
        [["FastL", "FastLF"], ["TactL", "TactLF"]] select _nearDistance;
    };

    // move right
    if (_dir > 250) exitWith {
        [["FastR", "FastRF"], ["TactR", "TactRF"]] select _nearDistance;
    };

    // default
    ["FastF", "TactF"] select _nearDistance;
};

// execute dodge
[_unit, _anim, true] call FUNC(doGesture);

// end
true
