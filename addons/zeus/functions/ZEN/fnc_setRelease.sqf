#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action and module back end. Releases one of a side's reserves toward the
 * clicked position, ignoring budget and pacing: Zeus holds the reins.
 *
 * Arguments:
 * 0: Clicked position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [getPos player] call hostis_zeus_fnc_setRelease;
 *
 * Public: No
*/
params [["_position", [], [[]]]];

if (_position isEqualTo []) exitWith {};
[LSTRING(Module_Release_DisplayName), [
    [LSTRING(Dialog_Side), "DROPDOWN", LSTRING(Dialog_Side_ToolTip), ["OPFOR", "BLUFOR", "Independent"], 0],
    [LSTRING(Dialog_ReleaseRadius), "SLIDER", LSTRING(Dialog_ReleaseRadius_ToolTip), [50, 300], [10, 50], 100, 0]
], {
    params ["_data", "_args"];
    _args params ["_position"];
    _data params ["_sideIndex", "_radius"];
    private _side = [east, west, independent] select _sideIndex;
    [QEGVAR(director,release), [_side, _position, _radius, true]] call CBA_fnc_serverEvent;
    [QLGVAR(danger,curatorFeedback), [format ["Reserve of %1 released toward %2; the Director's log names the group or says why none came", _side, mapGridPosition _position]], clientOwner] call CBA_fnc_targetEvent;
}, {}, {}, [_position]] call LFUNC(main,showDialog);
