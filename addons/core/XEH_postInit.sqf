#include "script_component.hpp"

// debug draw of every local picture; does nothing while the setting is off
[{
    if (!GVAR(debugPicture)) exitWith {};
    ["debugDraw", {
        GVAR(pictures) = GVAR(pictures) select {!isNull _x};
        {
            if (local _x) then {[_x] call FUNC(debugDraw);};
        } forEach GVAR(pictures);
    }] call FUNC(profile);
}, 5] call CBA_fnc_addPerFrameHandler;

// the performance log: what every layer costs on this machine, one slice every 30 s (ADR-0014)
[{
    if (!GVAR(debugPerformance)) exitWith {};
    private _machine = if (isServer) then {"server"} else {[format ["client %1", clientOwner], format ["headless %1", clientOwner]] select (!hasInterface)};
    {diag_log format ["HOSTIS PERF %1 %2", _machine, _x];} forEach ([true] call FUNC(profileReport));
}, 30] call CBA_fnc_addPerFrameHandler;
