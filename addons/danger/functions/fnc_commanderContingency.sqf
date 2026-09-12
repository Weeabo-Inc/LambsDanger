#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The things a real squad sorts out on its own before anyone plans a manoeuvre, checked
 * every commander think and whenever a plan ticks:
 *   succession     a dead or unconscious leader is replaced at once
 *   crew           a carrier whose driver or gunner died gets one from the passengers,
 *                  unless the enemy is close, in which case everyone bails out
 *   indirect fire  shells landing with no enemy in sight: displace out of the beaten zone
 *   strays         two men or fewer left, nobody shooting at them: join the nearest squad
 *   reorganise     after a fight: self aid where there is no ACE medic, take ammunition
 *                  from the dead when running low
 * Returns what it did so callers can skip their own planning this tick.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Escalation level <NUMBER>
 *
 * Return Value:
 * action taken, "" for none <STRING>
 *
 * Example:
 * [group bob, 2] call lambs_danger_fnc_commanderContingency;
 *
 * Public: No
*/
#define SHELLING_COUNT 2
#define SHELLING_WINDOW 45
#define SHELLING_RADIUS 60
#define SHELLING_QUIET 150
#define STRAY_SIZE 2
#define STRAY_RANGE 300
#define CREW_CONTACT 120
#define CREW_REPLACE_TIME 15
#define LOW_AMMO 2
#define BODY_RANGE 25
#define SELF_AID_DAMAGE 0.3

params [["_group", grpNull, [grpNull]], ["_level", 0, [0]]];

if (isNull _group || {!local _group}) exitWith {""};
private _units = (units _group) select {!isPlayer _x};
if (_units isEqualTo []) exitWith {""};
private _leader = leader _group;
private _picture = [_group] call FUNC(pictureGet);
private _action = "";

// succession ~ the next man takes over the moment the leader is down
if (!(_leader call EFUNC(main,isAlive))) then {
    private _candidates = _units select {_x call EFUNC(main,isAlive) && {isNull objectParent _x || {(vehicle _x) in ([_x, 400] call EFUNC(main,findGroupVehicles))}}};
    if (_candidates isNotEqualTo []) then {
        _leader = _candidates select 0;
        _group selectLeader _leader;
        [_leader, "combat", "KeepFocused", 100] call EFUNC(main,doCallout);
        _action = "succession";
    };
};

// crew ~ carriers need a driver and a gunner; passengers fill the seats unless the enemy is on top of them
private _threatPos = _picture get "threatPos";
private _contactNear = _threatPos isNotEqualTo [] && {time - (_picture get "lastContact") < 30} && {_leader distance2D _threatPos < CREW_CONTACT};
{
    private _vehicle = _x;
    if (time < (_vehicle getVariable [QGVAR(crewReplaceUntil), 0])) then {continue};
    private _aboard = (units _group) select {(vehicle _x) isEqualTo _vehicle && {_x call EFUNC(main,isAlive)}};
    private _passengers = _aboard select {_x isNotEqualTo (driver _vehicle) && {_x isNotEqualTo (gunner _vehicle)} && {_x isNotEqualTo (commander _vehicle)}};
    private _driverDown = !alive (driver _vehicle);
    private _gunnerDown = someAmmo _vehicle && {(_vehicle emptyPositions "gunner") > 0 || {!isNull (gunner _vehicle) && {!alive (gunner _vehicle)}}};
    if (_passengers isNotEqualTo [] && {_driverDown || _gunnerDown}) then {
        if (_contactNear) then {
            // no time to shuffle seats under fire ~ out
            _aboard orderGetIn false;
            {_x action ["Eject", _vehicle]; [_x] allowGetIn false;} forEach _aboard;
            _action = "bail out";
        } else {
            private _seat = ["gunner", "driver"] select _driverDown;
            // the dead man is taken off the seat first, or nobody can take it
            private _corpse = [gunner _vehicle, driver _vehicle] select _driverDown;
            if (!isNull _corpse && {!alive _corpse}) then {moveOut _corpse;};
            private _replacement = _passengers select 0;
            _vehicle setVariable [QGVAR(crewReplaceUntil), time + CREW_REPLACE_TIME];
            _replacement action ["Eject", _vehicle];
            [
                {
                    params ["_replacement", "_vehicle", "_seat"];
                    if (!(_replacement call EFUNC(main,isAlive)) || {!alive _vehicle}) exitWith {};
                    if (_seat isEqualTo "driver") then {_replacement assignAsDriver _vehicle;} else {_replacement assignAsGunner _vehicle;};
                    [_replacement] orderGetIn true;
                },
                [_replacement, _vehicle, _seat],
                2
            ] call CBA_fnc_waitAndExecute;
            _action = "new " + _seat;
        };
    };
} forEach ([_leader, 400] call EFUNC(main,findGroupVehicles));
if (_action isNotEqualTo "") exitWith {_action};

// indirect fire ~ shells landing around us and nobody to shoot back at: get out of the beaten zone
private _explosions = (_group getVariable [QGVAR(explosions), []]) select {time - (_x select 0) < SHELLING_WINDOW};
_group setVariable [QGVAR(explosions), _explosions];
if (
    count _explosions >= SHELLING_COUNT
    && {(_explosions findIf {(_x select 1) distance2D _leader > SHELLING_RADIUS}) isEqualTo -1}
    && {_threatPos isEqualTo [] || {_leader distance2D _threatPos > SHELLING_QUIET}}
    && {!(_group getVariable [QGVAR(isExecutingTactic), false])}
    && {time - (_picture get "withdrawTime") > SHELLING_WINDOW}
) exitWith {
    private _centre = [0, 0, 0];
    {_centre = _centre vectorAdd (_x select 1);} forEach _explosions;
    _centre = _centre vectorMultiply (1 / count _explosions);
    _group setVariable [QGVAR(explosions), []];
    [_group, "displace", _centre, 60] call FUNC(tacticsMonitor);
    [_group, _centre, [], 60] call FUNC(tacticsWithdraw);
    [_leader, "combat", "contact", 125] call EFUNC(main,doCallout);
    "displace"
};

// strays ~ a pair left on its own joins the nearest squad once the shooting stops
private _alive = _units select {_x call EFUNC(main,isAlive)};
if (
    GVAR(commanderMergeStrays)
    && {count _alive <= STRAY_SIZE}
    && {_level < 2}
    && {!(_group call EFUNC(main,isDirected))}
    && {isNil {_group getVariable QEGVAR(wp,taskSnapshot)}}
) then {
    private _hosts = allGroups select {
        _x isNotEqualTo _group
        && {(side _x) isEqualTo (side _group)}
        && {local _x}
        && {!isPlayer (leader _x)}
        && {(leader _x) call EFUNC(main,isAlive)}
        && {count (units _x) > STRAY_SIZE}
        && {(leader _x) distance2D _leader < STRAY_RANGE}
        && {!(_x call EFUNC(main,isDirected))}
    };
    if (_hosts isNotEqualTo []) then {
        _hosts = [_hosts, [], {(leader _x) distance2D _leader}, "ASCEND"] call BIS_fnc_sortBy;
        private _host = _hosts select 0;
        if (EGVAR(main,debug_functions)) then {["%1 COMMANDER %2: %3 strays join %4", side _group, groupId _group, count _alive, groupId _host] call EFUNC(main,debugLog);};
        _alive joinSilent _host;
        {_x doFollow (leader _host);} forEach _alive;
        _action = "joined";
    };
};
if (_action isNotEqualTo "") exitWith {_action};

// reorganise ~ only when nothing is happening
if (_level < 2 && {!(_group getVariable [QGVAR(isExecutingTactic), false])}) then {
    private _aceMedical = isClass (configFile >> "CfgPatches" >> "ace_medical");
    {
        if (isNull objectParent _x && {unitReady _x}) then {
            // self aid
            if (!_aceMedical && {damage _x > SELF_AID_DAMAGE} && {"FirstAidKit" in (items _x)}) then {
                _x action ["HealSoldierSelf", _x];
                _action = "reorganise";
            };
            // ammunition from the dead
            private _primary = primaryWeapon _x;
            if (_primary isNotEqualTo "" && {count (_x magazinesTurret [-1] select {_x in (getArray (configFile >> "CfgWeapons" >> _primary >> "magazines"))}) < LOW_AMMO || {(magazines _x) isEqualTo []}}) then {
                private _bodies = (nearestObjects [_x, ["CAManBase"], BODY_RANGE]) select {!alive _x};
                if (_bodies isNotEqualTo []) then {
                    [_x, getPosATL (_bodies select 0), 4] call EFUNC(main,doCheckBody);
                    _action = "reorganise";
                };
            };
        };
    } forEach _alive;
};

_action
