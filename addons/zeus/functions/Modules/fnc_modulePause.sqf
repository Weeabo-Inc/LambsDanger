#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Zeus module. Pauses the squad layer everywhere, or resumes it when it was paused.
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
[!(missionNamespace getVariable [QEGVAR(squad,paused), false])] call FUNC(setPause);
