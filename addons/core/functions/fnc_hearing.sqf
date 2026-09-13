#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The scripted ear (ADR-0012): every shot fired by a man is heard by the AI groups of
 * enemy sides within hearingRange, and filed in their picture as a "heard" contact at the
 * shooter's position with an error of 5 m plus a tenth of the distance. Suppressed weapons
 * carry a fraction of the range. Picture only: nothing is revealed to the engine, so the
 * group orients, watches and searches the area but gets no target it cannot see.
 *
 * Why not the engine's own Fire cause: its danger position is the round, not the gun, and
 * it rarely fires beyond 120 m, so a rifleman at 200 m was inaudible (test run 2026-09-13).
 *
 * One sentence: "They heard the shot and know roughly where it came from."
 *
 * Arguments:
 * FiredMan event: 0 shooter <OBJECT>, 1 weapon <STRING>, 2 muzzle <STRING>
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob, "arifle_MX_F", "arifle_MX_F"] call hostis_core_fnc_hearing;
 *
 * Public: No
*/
#define SHOOTER_THROTTLE 1
#define GROUP_THROTTLE 0.5
#define ERROR_BASE 5
#define ERROR_PER_METRE 0.1
#define CONFIDENCE 0.7

params [["_shooter", objNull, [objNull]], ["_weapon", "", [""]], ["_muzzle", "", [""]]];

if (GVAR(hearingRange) <= 0 || {isNull _shooter} || {_weapon in ["Throw", "Put"]}) exitWith {};

// one report per shooter per second, whatever he is firing: forty players on automatic are forty events a second, not four thousand
private _now = CBA_missionTime;
if (_now - (_shooter getVariable [QGVAR(heardTime), -SHOOTER_THROTTLE]) < SHOOTER_THROTTLE) exitWith {};
_shooter setVariable [QGVAR(heardTime), _now];

private _range = GVAR(hearingRange);
private _accessory = (_shooter weaponAccessories _weapon) param [0, ""];
if (_accessory isNotEqualTo "" && {getNumber (configFile >> "CfgWeapons" >> _accessory >> "ItemInfo" >> "type") isEqualTo 101}) then {
    _range = _range * GVAR(hearingSuppressed);
};

private _origin = getPosATL _shooter;
private _side = side group _shooter;
// only the groups the commander runs, distance first, and each group hears at most twice a second
private _groups = missionNamespace getVariable ["lambs_danger_commanderGroups", allGroups];
{
    private _leader = leader _x;
    if (
        !isNull _leader
        && {_leader distance2D _origin <= _range}
        && {local _x}
        && {_now - (_x getVariable [QGVAR(heardTime), -GROUP_THROTTLE]) >= GROUP_THROTTLE}
        && {[_side, side _x] call BIS_fnc_sideIsEnemy}
        && {(units _x) findIf {isPlayer _x} isEqualTo -1}
    ) then {
        _x setVariable [QGVAR(heardTime), _now];
        private _distance = _leader distance2D _origin;
        [_x, objNull, _origin, "heard", ERROR_BASE + ERROR_PER_METRE * _distance, CONFIDENCE, 1, "unknown", -1, "firing"] call FUNC(contactReport);
        [_x, _origin] call FUNC(fireLog);
    };
} forEach _groups;
