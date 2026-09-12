#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Unit hides inside a building or in nearby cover. Kept for compatibility: the
 * per-soldier machine picks the spot, with a preference for a roof, and brings the man
 * back to his leader afterwards (lambs_danger_fnc_unitOrder "cover").
 *
 * Arguments:
 * 0: unit hiding <OBJECT>
 * 1: source of danger <OBJECT> or position <ARRAY>
 * 2: range to search for cover and concealment, default is 35 <NUMBER>
 * 3: unused, kept for callers <ARRAY>
 *
 * Return Value:
 * boolean
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doHide;
 *
 * Public: No
*/
#define HOLD_MIN 20
#define HOLD_MAX 30

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

private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (isNil "_order") exitWith {false};
private _threat = _pos call CBA_fnc_getPos;
private _options = createHashMapFromArray [["radius", _range min 35], ["indoorBias", true], ["holdTime", HOLD_MIN + random (HOLD_MAX - HOLD_MIN)], ["task", "Hide!"]];
private _ok = [_unit, "cover", [], [[_threat], []] select (_threat isEqualTo [0, 0, 0]), _options] call _order;

// debug
if (_ok && GVAR(debug_functions)) then {
    ["%1 hide (%2)", side _unit, name _unit] call FUNC(debugLog);
};

_ok
