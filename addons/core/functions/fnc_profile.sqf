#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Runs a piece of code and books its cost under a name (ADR-0014). Every layer's per
 * frame handler and the scripted ear go through here, so the Diagnose module and the
 * performance log can say what each layer costs on this machine. Two diag_tickTime reads
 * per call; nothing else.
 *
 * Arguments:
 * 0: Name, one per layer or handler <STRING>
 * 1: Code <CODE>
 * 2: Arguments passed to the code, default [] <ANY>
 *
 * Return Value:
 * what the code returned <ANY>
 *
 * Example:
 * ["commander", {call lambs_danger_fnc_commanderCycle}] call hostis_core_fnc_profile;
 *
 * Public: Yes
*/
params [["_name", "", [""]], ["_code", {}, [{}]], ["_args", []]];

if (isNil QGVAR(profile)) then {
    GVAR(profile) = createHashMap;
    GVAR(profileWindow) = diag_tickTime;
};

private _started = diag_tickTime;
private _result = _args call _code;
private _ms = (diag_tickTime - _started) * 1000;

// [calls, ms total, ms max, calls this window, ms this window]
private _entry = GVAR(profile) get _name;
if (isNil "_entry") then {
    _entry = [0, 0, 0, 0, 0];
    GVAR(profile) set [_name, _entry];
};
_entry set [0, (_entry select 0) + 1];
_entry set [1, (_entry select 1) + _ms];
_entry set [2, (_entry select 2) max _ms];
_entry set [3, (_entry select 3) + 1];
_entry set [4, (_entry select 4) + _ms];

if (isNil "_result") then {nil} else {_result}
