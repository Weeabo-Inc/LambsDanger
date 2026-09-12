#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
#include "settings.inc.sqf"

// one Director per side, on the server (ADR-0007)
GVAR(sides) = createHashMap;
GVAR(missionId) = 0;

if (isServer) then {
    // the mission-maker and Zeus API as events (docs/systems/director.md, API)
    [QGVAR(setBudget), {
        params ["_side", "_key", "_value"];
        [_side, _key, _value] call FUNC(budget);
    }] call CBA_fnc_addEventHandler;
    [QGVAR(release), {
        params ["_side", "_pos", ["_radius", 100]];
        [_side, _pos, _radius, "event"] call FUNC(release);
    }] call CBA_fnc_addEventHandler;
    [QGVAR(counterattack), {
        params ["_side", "_pos", ["_radius", 100]];
        [_side, _pos, _radius, true] call FUNC(counterattack);
    }] call CBA_fnc_addEventHandler;
    [QGVAR(fireMission), {
        params ["_side", "_pos", ["_error", 50], ["_reason", "event"], ["_observer", grpNull]];
        [_side, _pos, _error, _reason, _observer] call FUNC(fireRequest);
    }] call CBA_fnc_addEventHandler;
    // a player's gun fired somewhere: the sides hostile to it may locate it
    [QGVAR(enemyArtillery), {
        params ["_side", "_pos"];
        {
            if ((_x getFriend _side) < 0.6) then {
                private _state = [_x] call FUNC(sideState);
                private _log = _state get "artilleryLog";
                _log pushBack [time, _pos];
                if (count _log > 60) then {_log deleteAt 0;};
            };
        } forEach (keys GVAR(sides));
    }] call CBA_fnc_addEventHandler;
};

ADDON = true;
