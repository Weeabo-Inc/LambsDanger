#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Fired handler on mortars and artillery vehicles: a gun fired by a player is reported to
 * the server as an enemy firing position for the sides hostile to it (counter-battery,
 * RESEARCH.md C-54). A gun's own side never learns anything from this.
 *
 * Arguments:
 * Fired event handler arguments (unit, weapon, muzzle, mode, ammo, magazine, projectile, gunner)
 *
 * Return Value:
 * None
 *
 * Example:
 * called by the Extended_Fired_EventHandlers config
 *
 * Public: No
*/
#define RATE 5

params [["_vehicle", objNull, [objNull]], "", "", "", "", "", "", ["_gunner", objNull, [objNull]]];

if (isNull _vehicle || {!local _vehicle}) exitWith {};
if ((getNumber (configOf _vehicle >> "artilleryScanner")) <= 0) exitWith {};
if (!(isPlayer _gunner || {isPlayer (effectiveCommander _vehicle)})) exitWith {};
if (time - (_vehicle getVariable [QGVAR(firedAt), -1e9]) < RATE) exitWith {};
_vehicle setVariable [QGVAR(firedAt), time];
[QGVAR(enemyArtillery), [side _vehicle, getPosATL _vehicle]] call CBA_fnc_serverEvent;
