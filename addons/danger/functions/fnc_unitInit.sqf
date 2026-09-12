#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Starts the per-soldier machine on this machine: one per frame handler that, twice a
 * second, runs the cheap pass over every registered soldier (stance rhythm, arrivals,
 * timeouts) and the expensive pass (position queries and move orders) for a bounded
 * number of them.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call lambs_danger_fnc_unitInit;
 *
 * Public: No
*/
#define TICK 0.5

if (!isNil QGVAR(unitPFH)) exitWith {};
GVAR(units) = [];
GVAR(unitCursor) = 0;

GVAR(unitPFH) = [{
    if ((GVAR(units)) isEqualTo []) exitWith {};
    call FUNC(unitCycle);
}, TICK, []] call CBA_fnc_addPerFrameHandler;
