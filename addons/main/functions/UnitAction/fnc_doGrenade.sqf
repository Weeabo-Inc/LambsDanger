#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Unit throws a fragmentation grenade at a position before going in: the room, the
 * corner, the trench bay. Never inside 8 m of a friend, never further than a man can
 * throw, one grenade per twenty seconds.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Target position AGL <ARRAY>
 *
 * Return Value:
 * thrown <BOOL>
 *
 * Example:
 * [bob, getPos angryJoe] call lambs_main_fnc_doGrenade;
 *
 * Public: No
*/
#define MIN_RANGE 7
#define MAX_RANGE 32
#define FRIENDLY_CLEARANCE 8
#define COOLDOWN 20
#define AIM_TIME 0.8

params [["_unit", objNull, [objNull]], ["_pos", [], [[]]]];

if (
    isNull _unit || {_pos isEqualTo []} || {!local _unit} || {isPlayer _unit} || {!(_unit call FUNC(isAlive))}
    || {time < (_unit getVariable [QGVAR(grenadeTime), 0])}
) exitWith {false};

private _distance = _unit distance2D _pos;
if (_distance < MIN_RANGE || {_distance > MAX_RANGE}) exitWith {false};

// a fragmentation grenade in the throwables
private _throwables = throwables _unit;
private _index = _throwables findIf {
    private _ammo = getText (configFile >> "CfgMagazines" >> (_x select 0) >> "ammo");
    (getText (configFile >> "CfgAmmo" >> _ammo >> "simulation")) isEqualTo "shotGrenade"
    && {(getNumber (configFile >> "CfgAmmo" >> _ammo >> "hit")) > 5}
};
if (_index isEqualTo -1) exitWith {false};
(_throwables select _index) params ["_magazine", "_muzzle"];
if (_muzzle isEqualTo "") then {_muzzle = _magazine call FUNC(getCompatibleThrowMuzzle);};
if (_muzzle isEqualTo "") exitWith {false};

// not on our own people
if (([_unit, _pos, FRIENDLY_CLEARANCE] call FUNC(findNearbyFriendlies)) isNotEqualTo []) exitWith {false};

_unit setVariable [QGVAR(grenadeTime), time + COOLDOWN];
_unit doWatch _pos;
_unit setVariable [QGVAR(currentTask), "Frag out", GVAR(debug_functions)];
_unit setVariable [QGVAR(currentTarget), _pos, GVAR(debug_functions)];
[_unit, "combat", "grenadeout", 40] call FUNC(doCallout);
[
    {
        params ["_unit", "_muzzle", "_pos"];
        if (!(_unit call FUNC(isAlive))) exitWith {};
        _unit doWatch _pos;
        _unit forceWeaponFire [_muzzle, _muzzle];
    },
    [_unit, _muzzle, _pos],
    AIM_TIME
] call CBA_fnc_waitAndExecute;

if (GVAR(debug_functions)) then {["%1 %2 throws a grenade at %3m", side _unit, name _unit, round _distance] call FUNC(debugLog);};

true
