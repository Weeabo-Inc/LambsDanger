#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Opens the Director's dials; the drop point is the area of operations
 * centre.
 *
 * Arguments:
 * Arma 3 Module Function Parameters
 *
 * Return Value:
 * None
 *
 * Public: No
*/
params ["_logic", "", "_activated"];

if (!(_activated && local _logic)) exitWith {};
private _position = getPosATL _logic;
deleteVehicle _logic;
[_position, clientOwner] call FUNC(dialogDirector);
