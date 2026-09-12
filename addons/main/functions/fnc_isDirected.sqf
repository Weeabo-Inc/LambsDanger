#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Checks whether a group is on a Zeus directed move: it has been given a waypoint by a
 * curator and LAMBS group manoeuvres are suspended until the waypoint is reached.
 *
 * Arguments:
 * 0: Group or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * true while the directed move is active <BOOL>
 *
 * Example:
 * [group bob] call lambs_main_fnc_isDirected;
 *
 * Public: Yes
*/
params [["_target", grpNull, [grpNull, objNull]]];

if (_target isEqualType objNull) then {_target = group _target;};
if (isNull _target) exitWith {false};

private _state = _target getVariable [QEGVAR(danger,directedMove), []];
_state isNotEqualTo [] && {CBA_missionTime < (_state select 2)}
