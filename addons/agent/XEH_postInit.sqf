#include "script_component.hpp"

// morale and cohesion, time-sliced over the groups the commander knows about
GVAR(moraleCursor) = 0;
[{
    if (!GVAR(morale)) exitWith {};
    call FUNC(moraleCycle);
}, 2] call CBA_fnc_addPerFrameHandler;
