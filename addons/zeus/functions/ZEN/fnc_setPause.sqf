#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action and module back end. Pauses or resumes the squad layer everywhere.
 *
 * Arguments:
 * 0: Pause <BOOL>
 *
 * Return Value:
 * None
 *
 * Example:
 * [true] call hostis_zeus_fnc_setPause;
 *
 * Public: No
*/
params [["_paused", true, [false, 0]]];

if (_paused isEqualType 0) then {_paused = _paused > 0;};
[_paused] call EFUNC(squad,pause);
[QLGVAR(danger,curatorFeedback), [["HOSTIS AI resumed", "HOSTIS AI PAUSED"] select _paused], clientOwner] call CBA_fnc_targetEvent;
