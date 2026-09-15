#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Toggles the HOSTIS overlay on this curator's client.
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
deleteVehicle _logic;
call FUNC(overlay);
