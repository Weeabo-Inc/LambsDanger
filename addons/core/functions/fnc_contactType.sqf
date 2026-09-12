#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Classifies a contact object for the picture. A man who has seen a tank knows it is a
 * tank; the class of the vehicle is the only exact fact the picture keeps.
 *
 * Arguments:
 * 0: Object <OBJECT>
 *
 * Return Value:
 * "infantry", "vehicle", "armour", "air", "static" or "unknown" <STRING>
 *
 * Example:
 * [angryJoe] call hostis_core_fnc_contactType;
 *
 * Public: Yes
*/
params [["_object", objNull, [objNull]]];

if (isNull _object) exitWith {"unknown"};
private _vehicle = vehicle _object;
if (_vehicle isKindOf "Air") exitWith {"air"};
if (_vehicle isKindOf "Tank") exitWith {"armour"};
if (_vehicle isKindOf "StaticWeapon") exitWith {"static"};
if (_vehicle isKindOf "LandVehicle" || {_vehicle isKindOf "Ship"}) exitWith {"vehicle"};
if (_vehicle isKindOf "CAManBase") exitWith {"infantry"};
"unknown"
