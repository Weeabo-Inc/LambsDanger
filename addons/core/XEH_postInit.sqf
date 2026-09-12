#include "script_component.hpp"

// debug draw of every local picture; does nothing while the setting is off
[{
    if (!GVAR(debugPicture)) exitWith {};
    GVAR(pictures) = GVAR(pictures) select {!isNull _x};
    {
        if (local _x) then {[_x] call FUNC(debugDraw);};
    } forEach GVAR(pictures);
}, 5] call CBA_fnc_addPerFrameHandler;
