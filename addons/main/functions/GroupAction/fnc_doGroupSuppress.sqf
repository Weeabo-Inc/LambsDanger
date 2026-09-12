#include "script_component.hpp"
/*
 * Author: nkenny
 * Actualisation of Suppression cycle
 *
 * Arguments:
 * 0: group conducting the suppression <GROUP>
 * 1: units list <ARRAY>
 * 2: list of group vehicles <ARRAY>
 * 3: list of building/enemy positions <ARRAY>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe] call lambs_main_fnc_doGroupSuppress;
 *
 * Public: No
*/
params [["_group", grpNull], ["_units", []], ["_vehicles", []], ["_posList", []]];

// exit!
if !(_group getVariable [QEGVAR(danger,isExecutingTactic), false]) exitWith {false};

// update
_units = _units select { !( _x getVariable [QEGVAR(danger,disableAI), false] ) && { _x call FUNC(isAlive) } && { !isPlayer _x } };
_vehicles = _vehicles select { canFire _x };

// infantry
[_posList, true] call CBA_fnc_shuffle;
private _index = -1;
private _checkCount = 3;

private _target = _posList select -1;
{
    // find target
    if (_index isEqualTo -1 && _checkCount > 0) then {
        _index = [_x, _posList] call FUNC(checkVisibilityList);
        _checkCount = _checkCount - 1;
    };

    // found good target ~ fight from the nearest cover, the machine keeps him peeking and ducking
    if (_index isNotEqualTo -1) then {
        [_x, "hold", getPosATL _x, [_target], createHashMapFromArray [["onArrive", "hold"], ["radius", 8], ["suppressList", _posList], ["task", "Group Suppress"]]] call EFUNC(danger,unitOrder);
        private _suppressing = [_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call FUNC(doSuppress);
        if (!_suppressing) then {
            _index = -1;
        };
    };

    // failed to suppress ~ a leg forward from cover to cover until something can be seen
    if (_index isEqualTo -1) then {
        [_x, "move", _x getPos [20, _x getDir _target], [_target], createHashMapFromArray [["onArrive", "hold"], ["suppressList", _posList], ["task", "Group Suppress (Move)"]]] call EFUNC(danger,unitOrder);
    };
} forEach (_units select {(currentCommand _x) isNotEqualTo "Suppress"});

// vehicles
{

    // get vehicle
    private _vehicle = _x;

    // find target
    if (_index isEqualTo -1) then {_index = [_vehicle, _posList] call FUNC(checkVisibilityList);};

    // execute suppression
    if (_index isNotEqualTo -1) then {

        // vehicle suppress
        private _suppressing = [_vehicle, (_posList select _index) vectorAdd [0, 0, random 1]] call FUNC(doVehicleSuppress);
        if (_suppressing) then {
            // debug variable
            (effectiveCommander _vehicle) setVariable [QGVAR(currentTask), "Group Suppress (Move)", GVAR(debug_functions)];
        } else {
            _index = -1;
        };
    };

    // failed to suppress
    if (_index isEqualTo -1) then {

        private _lookPos = _posList select _index;

        // debug variable
        (effectiveCommander _vehicle) setVariable [QGVAR(currentTask), "Group Suppress (Move)", GVAR(debug_functions)];

        // move up behind leader
        _vehicle doWatch _lookPos;
        private _movePos = _vehicle getPos [50, _vehicle getDir _lookPos];

        // adjust for vehicle
        private _adjustPos = _movePos findEmptyPosition [5, 35, typeOf _vehicle];
        if (_adjustPos isNotEqualTo []) then {_movePos = _adjustPos};

        // execute move
        (driver _vehicle) doMove _movePos;

    };

} forEach (_vehicles select {(currentCommand _x) isNotEqualTo "Suppress"});

// recursive cyclic
if (_units isNotEqualTo [] && { _group getVariable [QEGVAR(danger,isExecutingTactic), false] }) then {
    [
        {_this call FUNC(doGroupSuppress)},
        [_group, _units, _vehicles, _posList],
        6 + random 2
    ] call CBA_fnc_waitAndExecute;
} else {
    // cycle over ~ the machine lets the men go
    {[_x, true] call EFUNC(danger,unitRelease);} forEach _units;
};

// end
true
