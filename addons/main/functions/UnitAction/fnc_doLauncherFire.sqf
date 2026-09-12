#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Unit fires its rocket launcher, or an underbarrel grenade launcher with an HE round,
 * at a position: a building the enemy holds, a machine gun nest, a known enemy spot.
 * Used by the base of fire during fire and movement. One shot per call, with a per
 * unit cooldown so a squad does not empty its tubes in one go.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Target position AGL <ARRAY>
 *
 * Return Value:
 * fired <BOOL>
 *
 * Example:
 * [bob, getPos angryJoe] call lambs_main_fnc_doLauncherFire;
 *
 * Public: No
*/
#define MIN_RANGE 40
#define MAX_RANGE_LAUNCHER 500
#define MAX_RANGE_UGL 300
#define COOLDOWN_LAUNCHER 30
#define COOLDOWN_UGL 20
#define FRIENDLY_CLEARANCE 30
#define AIM_TIME 1.5

params [["_unit", objNull, [objNull]], ["_pos", [], [[]]]];

if (
    isNull _unit || {_pos isEqualTo []} || {!local _unit} || {isPlayer _unit}
    || {!(_unit call FUNC(isAlive))}
    || {time < (_unit getVariable [QGVAR(launcherTime), 0])}
) exitWith {false};

private _distance = _unit distance2D _pos;
if (_distance < MIN_RANGE) exitWith {false};

// what can we shoot with
private _weapon = "";
private _muzzle = "";
private _cooldown = 0;
private _launcher = secondaryWeapon _unit;
if (_launcher isNotEqualTo "" && {(secondaryWeaponMagazine _unit) isNotEqualTo []} && {_distance < MAX_RANGE_LAUNCHER}) then {
    _weapon = _launcher;
    _muzzle = (getArray (configFile >> "CfgWeapons" >> _launcher >> "muzzles")) param [0, "this"];
    if (_muzzle isEqualTo "this") then {_muzzle = _launcher;};
    _cooldown = COOLDOWN_LAUNCHER;
} else {
    if (_distance < MAX_RANGE_UGL) then {
        private _primary = primaryWeapon _unit;
        private _uglMuzzle = (getArray (configFile >> "CfgWeapons" >> _primary >> "muzzles") - ["SAFE", "this"]) param [0, ""];
        if (_uglMuzzle isNotEqualTo "") then {
            // an HE round is loaded or carried?
            private _magazines = getArray (configFile >> "CfgWeapons" >> _primary >> _uglMuzzle >> "magazines");
            {
                private _well = _x;
                {_magazines append (getArray _x);} forEach (configProperties [configFile >> "CfgMagazineWells" >> _well]);
            } forEach (getArray (configFile >> "CfgWeapons" >> _primary >> _uglMuzzle >> "magazineWell"));
            _magazines = (_magazines apply {toLower _x}) arrayIntersect ((magazines _unit) apply {toLower _x});
            private _he = _magazines findIf {
                private _ammo = getText (configFile >> "CfgMagazines" >> _x >> "ammo");
                (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation")) isEqualTo "shotShell"
                && {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit")) > 5}
            };
            if (_he isNotEqualTo -1) then {
                _weapon = _primary;
                _muzzle = _uglMuzzle;
                _cooldown = COOLDOWN_UGL;
            };
        };
    };
};
if (_weapon isEqualTo "") exitWith {false};

// never into our own people
if (([_unit, _pos, FRIENDLY_CLEARANCE] call FUNC(findNearbyFriendlies)) isNotEqualTo []) exitWith {false};

// aim and fire
_unit setVariable [QGVAR(launcherTime), time + _cooldown + random 10];
_unit doWatch _pos;
_unit setVariable [QGVAR(currentTask), ["Rocket", "Grenade launcher"] select (_weapon isEqualTo (primaryWeapon _unit)), GVAR(debug_functions)];
_unit setVariable [QGVAR(currentTarget), _pos, GVAR(debug_functions)];
if (_weapon isNotEqualTo (primaryWeapon _unit)) then {_unit selectWeapon _weapon;};
[
    {
        params ["_unit", "_weapon", "_muzzle", "_pos"];
        if (!(_unit call FUNC(isAlive))) exitWith {};
        _unit doWatch _pos;
        _unit forceWeaponFire [_muzzle, _muzzle];
        // back to the rifle once the rocket is away
        if (_weapon isNotEqualTo (primaryWeapon _unit)) then {
            [{if (_this call FUNC(isAlive)) then {_this selectWeapon (primaryWeapon _this);};}, _unit, 3] call CBA_fnc_waitAndExecute;
        };
    },
    [_unit, _weapon, _muzzle, _pos],
    AIM_TIME
] call CBA_fnc_waitAndExecute;

// debug
if (GVAR(debug_functions)) then {
    ["%1 %2 fires %3 at %4m", side _unit, name _unit, _weapon, round _distance] call FUNC(debugLog);
};

true
