#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Builds a report explaining why a group may not be moving: likely causes first, then the
 * group state and one line per unit. Runs on the machine that owns the group.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * Structured text source, lines separated by <br/> <STRING>
 *
 * Example:
 * [group bob] call lambs_danger_fnc_directedMoveDiagnose;
 *
 * Public: Yes
*/
#define HOLDING_WAYPOINTS ["HOLD", "GUARD", "SENTRY", "DISMISS", "SUPPORT"]
#define SUPPRESSED 0.5

params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {"No group"};
if (!local _group) exitWith {format ["%1 is not local to this machine (owner %2)", groupId _group, groupOwner _group]};

private _leader = leader _group;
private _units = units _group;
private _waypoints = waypoints _group;
private _current = currentWaypoint _group;
private _hasWaypoint = _current < count _waypoints;
private _wpType = "";
private _wpName = "";
if (_hasWaypoint) then {
    _wpType = waypointType (_waypoints select _current);
    _wpName = waypointName (_waypoints select _current);
};

// likely causes, most decisive first
private _causes = [];
if (!(_leader call EFUNC(main,isAlive))) then {_causes pushBack "Leader is dead or unconscious: the group has nobody to follow";};
if (_wpType in HOLDING_WAYPOINTS) then {
    _causes pushBack format ["Current waypoint %1 is %2%3: the group will not advance past it on its own", _current, _wpType, ["", format [" (placed by LAMBS %1)", _wpName]] select (_wpName isNotEqualTo "")];
};
if (!(_leader checkAIFeature "PATH")) then {_causes pushBack "Leader pathfinding (PATH) is disabled, typically by a garrison or camp task";};
if (!(_leader checkAIFeature "MOVE")) then {_causes pushBack "Leader movement (MOVE) is disabled";};
if ((currentCommand _leader) isEqualTo "STOP") then {_causes pushBack "Leader has a STOP command";};
if (_hasWaypoint && {!(_wpType in HOLDING_WAYPOINTS)} && {((expectedDestination _leader) select 1) isEqualTo "DoNotPlan"}) then {
    _causes pushBack "Leader is not planning a path although a waypoint remains";
};
if (_group getVariable [QGVAR(isExecutingTactic), false]) then {
    _causes pushBack format ["LAMBS tactic in progress: %1", _group getVariable [QEGVAR(main,currentTactic), "unknown"]];
};
if (EGVAR(main,Loaded_WP) && {!isNil {_group getVariable QEGVAR(wp,taskSnapshot)}}) then {
    _causes pushBack format ["LAMBS task running: %1", _group getVariable [QEGVAR(main,currentTactic), "unknown"]];
};
if (_group call EFUNC(main,isDirected)) then {
    _causes pushBack format ["Zeus directed move to waypoint %1 is active", (_group getVariable [QGVAR(directedMove), [-1]]) select 0];
};
if (attackEnabled _group && {(currentCommand _leader) isEqualTo "ATTACK"}) then {_causes pushBack "Leader is attacking a target (engine attack order)";};
if (fleeing _leader) then {_causes pushBack "Group is fleeing";};
if ((behaviour _leader) isEqualTo "STEALTH") then {_causes pushBack "Behaviour STEALTH: movement is very slow";};
if ((behaviour _leader) isEqualTo "COMBAT") then {_causes pushBack "Behaviour COMBAT: bounding overwatch is slow, set AWARE on the waypoint for speed";};
if ((combatMode _group) in ["BLUE", "GREEN"]) then {_causes pushBack format ["Combat mode %1: units hold fire", combatMode _group];};
if (!simulationEnabled _leader) then {_causes pushBack "Simulation is disabled (dynamic simulation or hidden)";};
if (_group getVariable [QGVAR(disableGroupAI), false]) then {_causes pushBack "LAMBS group AI is disabled for this group";};
private _suppressed = _units select {getSuppression _x > SUPPRESSED};
if (getSuppression _leader > SUPPRESSED) then {_causes pushBack format ["Leader is suppressed (%1)", getSuppression _leader toFixed 2];};
if (_suppressed isNotEqualTo []) then {_causes pushBack format ["%1 of %2 units are suppressed", count _suppressed, count _units];};
if (_causes isEqualTo []) then {_causes pushBack "No blocking state found: the group should be moving";};

// group line
private _lines = [
    format ["<t size='1.1'>%1 %2</t> owner %3", side _group, groupId _group, groupOwner _group],
    format ["Waypoint %1 of %2 %3 | attack %4 | %5 / %6 / %7 | %8", _current, count _waypoints, _wpType, attackEnabled _group, behaviour _leader, speedMode _group, combatMode _group, formation _group],
    "<t color='#FFAA00'>Likely causes</t>"
];
_lines append (_causes apply {"- " + _x});

// what the commander thinks
private _picture = [_group] call FUNC(pictureGet);
private _intent = [_group] call FUNC(intentGet);
private _maneuver = _group getVariable QGVAR(maneuver);
private _airTask = _group getVariable QEGVAR(wp,attackAir);
_lines pushBack "<t color='#FFAA00'>Commander</t>";
_lines pushBack format ["Intent %1 | posture %2 | cap %3 | objective %4m", _intent select 0, ["cautious", "balanced", "aggressive"] select (_intent select 3), _intent select 4, [round (_leader distance2D (_intent select 1)), "-"] select ((_intent select 1) isEqualTo [])];
_lines pushBack format ["Escalation %1 | morale %2 | losses %3 | contacts %4 (last %5s ago) | role %6",
    ["routine", "alert", "engaged", "decisive"] select (_picture getOrDefault ["escalation", 0]),
    ([_group] call FUNC(getMorale)) toFixed 2,
    _picture get "losses",
    count ([_group, 60] call FUNC(pictureContacts)),
    round (time - (_picture get "lastContact")) min 9999,
    _group getVariable [QGVAR(role), "-"]
];
_lines pushBack format ["Last tactic %1 %2 | executing %3 | plan %4 | air %5",
    _picture get "lastTactic", _picture get "lastResult",
    _group getVariable [QGVAR(isExecutingTactic), false],
    ["-", _maneuver getOrDefault ["phase", "?"]] select (!isNil "_maneuver"),
    ["-", _airTask getOrDefault ["phase", "?"]] select (!isNil "_airTask")
];
// what the group believes about the enemy (hostis_core)
_lines pushBack "<t color='#FFAA00'>Knowledge</t>";
_lines append ([_group, 6] call HFUNC(core,pictureReport));
// what the side's Director thinks (server only; on a client the report says so)
if (isServer && {!isNil "hostis_director_fnc_report"}) then {
    _lines pushBack "<t color='#FFAA00'>Director</t>";
    _lines append ([side _group] call hostis_director_fnc_report);
};
_lines pushBack "<t color='#FFAA00'>Units</t>";

// unit lines
{
    private _flags = [];
    if (!(_x checkAIFeature "PATH")) then {_flags pushBack "noPATH";};
    if (!(_x checkAIFeature "MOVE")) then {_flags pushBack "noMOVE";};
    if (!(_x checkAIFeature "ANIM")) then {_flags pushBack "noANIM";};
    if (_x getVariable [QGVAR(forceMove), false]) then {_flags pushBack "forced";};
    if (_x getVariable [QGVAR(disableAI), false]) then {_flags pushBack "fsmOff";};
    if (fleeing _x) then {_flags pushBack "fleeing";};
    if (!(_x call EFUNC(main,isAlive))) then {_flags pushBack "down";};
    if (isPlayer _x) then {_flags pushBack "player";};
    // what the per-soldier machine has him doing
    private _record = _x getVariable QGVAR(unit);
    private _machine = if (isNil "_record") then {"-"} else {
        private _final = _record get "final";
        private _position = _record get "position";
        private _finalText = if (_final isEqualTo []) then {"-"} else {round (_x distance2D _final)};
        private _positionText = if (_position isNotEqualTo [] && {count _position > 5}) then {
            format [" (%1, cover %2)", _position select 5, _position select 1]
        } else {""};
        format ["%1 %2 | final %3m | %4%5",
            _record get "state",
            [_record get "phase", ""] select ((_record get "state") isNotEqualTo "InCover"),
            _finalText,
            (_record get "order") param [0, "-"],
            _positionText
        ]
    };
    _lines pushBack format [
        "%1: %2 | ready %3 | %4 | %5 | %6m | %7",
        name _x,
        [currentCommand _x, "-"] select ((currentCommand _x) isEqualTo ""),
        unitReady _x,
        [getUnitState _x, "player"] select (isPlayer _x),
        [_flags joinString " ", "-"] select (_flags isEqualTo []),
        round (_x distance2D _leader),
        _machine
    ];
} forEach _units;

// end
_lines joinString "<br/>"
