#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * What HOSTIS costs on this machine, as text: the frame rate, the engine's script
 * counts, how much is registered with each layer, and per profiled name the calls, the
 * average and worst cost, and the milliseconds per second over the current window
 * (ADR-0014). The window restarts when asked, so the performance log reads as a series of
 * equal slices.
 *
 * Arguments:
 * 0: Restart the window after reporting, default false <BOOL>
 *
 * Return Value:
 * lines <ARRAY>
 *
 * Example:
 * [true] call hostis_core_fnc_profileReport;
 *
 * Public: Yes
*/
params [["_restart", false, [false]]];

private _lines = [];
private _scripts = diag_activeScripts;
_lines pushBack format ["fps %1 | scripts spawn %2 execVM %3 exec %4 fsm %5 | sqf handlers %6",
    round diag_fps, _scripts select 0, _scripts select 1, _scripts select 2, _scripts select 3, count diag_activeSQFScripts
];
_lines pushBack format ["registered: commander groups %1 | soldiers %2 | pictures %3 | hostis groups on this machine %4",
    count (missionNamespace getVariable [QLGVAR(danger,commanderGroups), []]),
    count (missionNamespace getVariable [QLGVAR(danger,units), []]),
    count (GVAR(pictures) select {!isNull _x}),
    {local _x && {!isNil {_x getVariable QLGVAR(danger,picture)}}} count allGroups
];

if (isNil QGVAR(profile)) exitWith {_lines pushBack "nothing profiled yet"; _lines};
private _window = (diag_tickTime - GVAR(profileWindow)) max 0.001;
private _names = keys GVAR(profile);
_names sort true;
{
    (GVAR(profile) get _x) params ["_calls", "_total", "_max", "_windowCalls", "_windowMs"];
    _lines pushBack format ["%1: %2 calls, avg %3 ms, max %4 ms, %5 ms/s over the last %6 s (%7 calls)",
        _x, _calls, (_total / (_calls max 1)) toFixed 2, _max toFixed 1, (_windowMs / _window) toFixed 2, round _window, _windowCalls
    ];
} forEach _names;

if (_restart) then {
    {
        _y set [3, 0];
        _y set [4, 0];
    } forEach GVAR(profile);
    GVAR(profileWindow) = diag_tickTime;
};

_lines
