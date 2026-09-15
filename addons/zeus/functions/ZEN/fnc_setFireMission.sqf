#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * ZEN context action and module back end. Asks a side's Director for a fire mission on
 * the clicked position with the error the Zeus chooses.
 *
 * Arguments:
 * 0: Clicked position <ARRAY>
 *
 * Return Value:
 * None
 *
 * Example:
 * [getPos player] call hostis_zeus_fnc_setFireMission;
 *
 * Public: No
*/
params [["_position", [], [[]]]];

if (_position isEqualTo []) exitWith {};
[LSTRING(Module_FireMission_DisplayName), [
    [LSTRING(Dialog_Side), "DROPDOWN", LSTRING(Dialog_Side_ToolTip), ["OPFOR", "BLUFOR", "Independent"], 0],
    [LSTRING(Dialog_Error), "SLIDER", LSTRING(Dialog_Error_ToolTip), [20, 200], [10, 50], 50, 0]
], {
    params ["_data", "_args"];
    _args params ["_position"];
    _data params ["_sideIndex", "_error"];
    private _side = [east, west, independent] select _sideIndex;
    [QEGVAR(director,fireMission), [_side, _position, _error, "zeus", grpNull]] call CBA_fnc_serverEvent;
    [QLGVAR(danger,curatorFeedback), [format ["Fire mission asked of %1 on %2, error %3 m; the Director's log says whether it fires", _side, mapGridPosition _position, _error]], clientOwner] call CBA_fnc_targetEvent;
}, {}, {}, [_position]] call LFUNC(main,showDialog);
