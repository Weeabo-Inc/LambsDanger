#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
#include "settings.inc.sqf"

// the tactic registry (ADR-0011): name -> descriptor
GVAR(tactics) = createHashMap;
GVAR(paused) = false;
call FUNC(registerBuiltins);

// the Zeus brake, raised on any machine, applied where the groups are
[QGVAR(pause), {
    params [["_paused", true, [false]]];
    [_paused, false] call FUNC(pause);
}] call CBA_fnc_addEventHandler;

ADDON = true;
