#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Asks a side's Director for a fire mission on the drop point. The Director
 * decides whether it fires: budget, danger close, a gun free. Its log says which.
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
[_position] call FUNC(setFireMission);
