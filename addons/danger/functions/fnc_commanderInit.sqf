#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Starts the AI commander on this machine: one per frame handler that gives each
 * registered local group a think every few seconds, a few groups per second, and
 * refreshes the side board (threat clusters, roles, reinforcements) every ten. The
 * tick's body is commanderCycle, booked under "commander" in the performance log.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call lambs_danger_fnc_commanderInit;
 *
 * Public: No
*/
#define TICK 1

if (!isNil QGVAR(commanderPFH)) exitWith {};
GVAR(commanderGroups) = [];
GVAR(commanderCursor) = 0;
GVAR(commanderSideNext) = 0;

GVAR(commanderPFH) = [{
    if (!GVAR(commander)) exitWith {};
    if (GVAR(commanderGroups) isEqualTo []) exitWith {};
    ["commander", FUNC(commanderCycle)] call HFUNC(core,profile);
}, TICK, []] call CBA_fnc_addPerFrameHandler;
