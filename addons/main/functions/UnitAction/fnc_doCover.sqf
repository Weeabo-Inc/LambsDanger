#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Moves the unit into cover. Kept for compatibility: the per-soldier machine picks the
 * spot and runs the move (lambs_danger_fnc_unitOrder "cover"); a man the machine already
 * owns is told rounds are coming in and handles it himself.
 *
 * Arguments:
 * 0: unit seeking cover <OBJECT>
 * 1: position of danger <ARRAY>, optional
 *
 * Return Value:
 * bool
 *
 * Example:
 * [bob] call lambs_main_fnc_doCover;
 *
 * Public: No
*/
#define COVER_RANGE 10
#define HOLD_TIME 6

params ["_unit", ["_pos", [], [[]]]];

// stance change (one step lower)
_unit setUnitPosWeak (["DOWN", "MIDDLE"] select ((stance _unit) isEqualTo "STAND"));

// check if stopped or inside a building
if (!(_unit checkAIFeature "PATH") || {(insideBuilding _unit) isEqualTo 1}) exitWith {false};

private _event = missionNamespace getVariable QEFUNC(danger,unitEvent);
if (!isNil "_event" && {[_unit, "nearMiss", _pos] call _event}) exitWith {true};

private _order = missionNamespace getVariable QEFUNC(danger,unitOrder);
if (isNil "_order") exitWith {false};
[_unit, "cover", [], [_pos, []] select (_pos isEqualTo []), createHashMapFromArray [["radius", COVER_RANGE], ["holdTime", HOLD_TIME], ["task", "Taking cover"]]] call _order
