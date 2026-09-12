#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Counter-battery (RESEARCH.md C-54): player guns that fired twice from within 60 m of
 * each other inside the window are a firing position the side can compute. It is queued
 * as a fire mission without an observer, delayed by the setting, once per position.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east] call hostis_director_fnc_counterBattery;
 *
 * Public: No
*/
#define CLUSTER 60
#define DONE_TIME 900
#define TARGET_ERROR 40

params [["_side", sideUnknown, [sideUnknown]]];

if (GVAR(counterBatteryWindow) <= 0) exitWith {};
private _state = [_side] call FUNC(sideState);
private _since = time - GVAR(counterBatteryWindow);
private _log = (_state get "artilleryLog") select {(_x select 0) > _since};
_state set ["artilleryLog", _log];
private _done = (_state get "counterBatteryDone") select {time - (_x select 1) < DONE_TIME};
_state set ["counterBatteryDone", _done];

private _clusters = [];
{
    _x params ["_time", "_pos"];
    private _index = _clusters findIf {(_x select 0) distance2D _pos < CLUSTER};
    if (_index isEqualTo -1) then {_clusters pushBack [_pos, 1, _time];} else {
        private _cluster = _clusters select _index;
        _cluster set [1, (_cluster select 1) + 1];
        _cluster set [2, (_cluster select 2) max _time];
    };
} forEach _log;

{
    _x params ["_pos", "_count"];
    if (_count >= 2 && {(_done findIf {(_x select 0) distance2D _pos < CLUSTER}) isEqualTo -1}) then {
        _done pushBack [_pos, time];
        if ([_side, _pos, TARGET_ERROR, format ["counter-battery, %1 fire missions from %2", _count, mapGridPosition _pos], grpNull, time + GVAR(counterBatteryDelay)] call FUNC(fireRequest)) then {
            [_side, format ["counter-battery on %1 in %2 s", mapGridPosition _pos, GVAR(counterBatteryDelay)]] call FUNC(log);
        };
    };
} forEach _clusters;
