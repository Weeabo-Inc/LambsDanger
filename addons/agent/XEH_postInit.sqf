#include "script_component.hpp"

// morale and cohesion, time-sliced over the groups the commander knows about
GVAR(moraleCursor) = 0;
[{
    if (!GVAR(morale)) exitWith {};
    ["morale", FUNC(moraleCycle)] call EFUNC(core,profile);
}, 2] call CBA_fnc_addPerFrameHandler;
