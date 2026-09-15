#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Releases one of a side's reserves toward the drop point, budget and pacing
 * notwithstanding: Zeus holds the reins.
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
[_position] call FUNC(setRelease);
