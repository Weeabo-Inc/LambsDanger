#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
#include "settings.inc.sqf"

// the Director's dials and the overlay's data live on the server (ADR-0013)
if (isServer) then {
    [QGVAR(director), {_this call FUNC(director);}] call CBA_fnc_addEventHandler;
    [QGVAR(snapshotRequest), {_this call FUNC(snapshot);}] call CBA_fnc_addEventHandler;
};

// the overlay draws on the curator's own client from the last snapshot it received
if (hasInterface) then {
    GVAR(overlayOn) = false;
    GVAR(overlayData) = [];
    [QGVAR(snapshot), {GVAR(overlayData) = _this;}] call CBA_fnc_addEventHandler;
};

ADDON = true;
