#include "script_component.hpp"

if (!isServer) exitWith {};

// the Director's tick: every side that has HOSTIS groups, one after the other
[{
    if (!GVAR(enabled)) exitWith {};
    private _sides = [];
    {
        private _side = side _x;
        if (!isNull _x && {!isNil {_x getVariable QLGVAR(danger,picture)}} && {!(_side in _sides)} && {!isPlayer leader _x} && {_side in [west, east, independent]}) then {
            _sides pushBack _side;
        };
    } forEach allGroups;
    {[_x] call FUNC(think);} forEach _sides;
}, GVAR(thinkInterval)] call CBA_fnc_addPerFrameHandler;
