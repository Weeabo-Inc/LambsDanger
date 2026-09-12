#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Whether a unit carries a support weapon (machine gun or automatic rifle), judged by
 * the capacity of its primary magazine so that modded weapons are covered too.
 * Results are cached per magazine class.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * true for support gunners <BOOL>
 *
 * Example:
 * bob call lambs_main_fnc_isSupportGunner;
 *
 * Public: Yes
*/
#define SUPPORT_MAGAZINE_ROUNDS 60

params [["_unit", objNull, [objNull]]];

private _magazine = (primaryWeaponMagazine _unit) param [0, ""];
if (_magazine isEqualTo "") exitWith {false};

if (isNil QGVAR(supportMagazineCache)) then {
    GVAR(supportMagazineCache) = createHashMap;
};

GVAR(supportMagazineCache) getOrDefaultCall [_magazine, {
    getNumber (configFile >> "CfgMagazines" >> _magazine >> "count") >= SUPPORT_MAGAZINE_ROUNDS
}, true]
