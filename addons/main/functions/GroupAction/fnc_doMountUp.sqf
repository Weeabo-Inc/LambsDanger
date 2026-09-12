#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Gets a group's infantry back into its vehicles and keeps them there: every man on
 * foot is assigned a free seat (cargo first, then empty turrets and the commander
 * seat), ordered aboard, and the vehicles are told not to unload in combat. Nothing
 * in the danger layer will pull them out again until the mount-up is released.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Vehicles to use, default the group's own <ARRAY>
 *
 * Return Value:
 * units that were told to board <ARRAY>
 *
 * Example:
 * [group bob] call lambs_main_fnc_doMountUp;
 *
 * Public: Yes
*/
#define MOUNT_RANGE 300

params [["_group", grpNull, [grpNull, objNull]], ["_vehicles", [], [[]]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group}) exitWith {[]};

private _leader = leader _group;
if (_vehicles isEqualTo []) then {
    _vehicles = ((units _group) apply {vehicle _x}) select {_x isNotEqualTo (vehicle _leader) || {!isNull objectParent _leader}};
    _vehicles = (_vehicles arrayIntersect _vehicles) select {_x isKindOf "LandVehicle" && {alive _x} && {canMove _x}};
    // unmanned group vehicles nearby count too
    {
        if ((_x isKindOf "LandVehicle") && {alive _x} && {canMove _x} && {(crew _x) isEqualTo [] || {(group (effectiveCommander _x)) isEqualTo _group}}) then {_vehicles pushBackUnique _x;};
    } forEach ((nearestObjects [_leader, ["LandVehicle"], MOUNT_RANGE, true]) select {(_x getVariable [QGVAR(groupVehicle), grpNull]) isEqualTo _group});
};
_vehicles = _vehicles select {alive _x && {_x distance2D _leader < MOUNT_RANGE}};
if (_vehicles isEqualTo []) exitWith {[]};

// whoever is aboard stays aboard, even when nobody needs a seat
{
    _x setUnloadInCombat [false, false];
    _x setVariable [QGVAR(groupVehicle), _group];
    _x setVariable [QGVAR(keepMounted), true];
} forEach _vehicles;

// who needs a seat
private _onFoot = (units _group) select {isNull objectParent _x && {_x call FUNC(isAlive)} && {!isPlayer _x}};
if (_onFoot isEqualTo []) exitWith {[]};

// seats: cargo first, then turrets and the commander seat, driver only if the vehicle has none
private _boarding = [];
{
    private _vehicle = _x;
    if (isNull (driver _vehicle) && {_onFoot isNotEqualTo []}) then {
        private _unit = _onFoot deleteAt 0;
        _unit assignAsDriver _vehicle;
        _boarding pushBack _unit;
    };
    private _cargo = _vehicle emptyPositions "cargo";
    while {_cargo > 0 && {_onFoot isNotEqualTo []}} do {
        private _unit = _onFoot deleteAt 0;
        _unit assignAsCargo _vehicle;
        _boarding pushBack _unit;
        _cargo = _cargo - 1;
    };
    {
        _x params ["_role", "_assign"];
        if ((_vehicle emptyPositions _role) > 0 && {_onFoot isNotEqualTo []}) then {
            private _unit = _onFoot deleteAt 0;
            [_unit, _vehicle] call _assign;
            _boarding pushBack _unit;
        };
    } forEach [["gunner", {(_this select 0) assignAsGunner (_this select 1)}], ["commander", {(_this select 0) assignAsCommander (_this select 1)}]];
    private _turrets = (allTurrets [_vehicle, false]) select {isNull (_vehicle turretUnit _x)};
    {
        if (_onFoot isNotEqualTo []) then {
            private _unit = _onFoot deleteAt 0;
            [_unit, _vehicle, _x] call {(_this select 0) assignAsTurret [_this select 1, _this select 2]};
            _boarding pushBack _unit;
        };
    } forEach _turrets;
} forEach _vehicles;

// aboard
{
    [_x] allowGetIn true;
    _x setVariable [QEGVAR(danger,forceMove), true];
    _x setVariable [QGVAR(currentTask), "Mounting up", GVAR(debug_functions)];
} forEach _boarding;
_boarding orderGetIn true;
if (_boarding isNotEqualTo []) then {[_leader, "gestureFollow"] call FUNC(doGesture);};

// debug
if (GVAR(debug_functions)) then {
    ["%1 %2 mounting up: %3 boarding %4 vehicles (%5 left on foot)", side _group, groupId _group, count _boarding, count _vehicles, count _onFoot] call FUNC(debugLog);
};

_boarding
