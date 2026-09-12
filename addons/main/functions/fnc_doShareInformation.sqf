#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * A unit passes a sighting to nearby friendly groups. The sighting is filed in the unit's
 * own group picture first, then sent over the modelled net (hostis_core_fnc_netSend):
 * delayed by distance, lossy, widened in error, and carrying a position rather than a
 * target. Nothing is revealed to the engine here (FAIRNESS.md R4); see the
 * hostis_core engineReveal setting.
 *
 * Arguments:
 * 0: unit sharing information <OBJECT>
 * 1: enemy target <OBJECT>
 * 2: range to share information, default 350 <NUMBER>
 * 3: override radio ranges, default false <BOOLEAN>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe, 350, false] call lambs_main_fnc_doShareInformation;
 *
 * Public: No
*/
params ["_unit", ["_target", objNull], ["_range", 350], ["_override", false]];

// nil or captured
if (
    GVAR(radioDisabled)
    || {!(_unit call FUNC(isAlive))}
    || {_unit getVariable ["ace_captives_isHandcuffed", false]}
    || {_unit getVariable ["ace_captives_issurrendering", false]}
) exitWith {false};

// no target
if (isNull _target) then {
    _target = _unit findNearestEnemy _unit;
};

// range
([_unit, _range, _override] call FUNC(getShareInformationParams)) params ["_newUnit", "_newRange", "_radio"];

// custom handlers
private _stopShare = false;
{
    private _callbackResult = [_unit, _target, _range, _override, _newUnit, _newRange, _radio] call _x;
    if (!(isNil "_callbackResult") && {_callbackResult isEqualTo true}) exitWith {_stopShare = true};
} forEach GVAR(shareHandlers);
if (_stopShare) exitWith {false};

_unit setVariable [QGVAR(currentTarget), _target, GVAR(debug_functions)];

// what this man knows goes into his group's picture, then out over the net
private _group = group _newUnit;
private _records = [];
if (!isNull _target) then {
    [_group, [_target], "seen", _unit] call HFUNC(core,contactSweep);
    _records = ([_group, 5] call HFUNC(core,contactsGet)) select {(_x select 0) isEqualTo _target};
};
private _groups = [_group, _records, [-1, _newRange] select _override] call HFUNC(core,netSend);

[QGVAR(OnInformationShared), [_newUnit, _group, _target, _groups]] call FUNC(eventCallback);

// play animation
if (
    RND(0.2)
    && {_newRange > 100}
    && {!isNull _target}
    && {_newUnit distance2D _target > 4}
) then {
    [_newUnit, "HandSignalRadio"] call FUNC(doGesture);
};

// debug
if (GVAR(debug_functions)) then {
    ["%1 share information (%2 reports %3 contact(s) to %4 groups @ %5m range)", side _newUnit, name _newUnit, count _records, count _groups, round _newRange] call FUNC(debugLog);
};

// end
true
