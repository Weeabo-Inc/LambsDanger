#include "script_component.hpp"
/*
 * Author: nkenny
 * Group leadership handler -- leads to profiles, assessments, contact state and other responses
 *
 * Arguments:
 * 0: group leader <OBJECT>
 * 1: known enemy <OBJECT>
 *
 * Return Value:
 * bool
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tactics;
 *
 * Public: No
*/
params [["_unit", objNull, [objNull]], ["_target", objNull, [objNull]]];

private _group = group _unit;

// check if group AI disabled
if (_group getVariable [QGVAR(disableGroupAI), false]) exitWith {false};

// Initated contact?
private _contactState = _group getVariable [QGVAR(contact), 0];
if (_contactState < time) exitWith {[_unit, _target] call FUNC(contact)};

// Leader assessment ~ not while a Zeus directs the group
if (!(_group call EFUNC(main,isDirected))) then {_unit call FUNC(tacticsAssess);};

// end
true
