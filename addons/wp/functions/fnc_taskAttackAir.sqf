#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The air assault part of the Attack Position task, one step per task tick:
 *   plan     pick a landing zone 250-400 m short of the objective, on the group's side,
 *            out of the objective's line of sight where the ground allows, flat and empty
 *   fly      the helicopter flies itself to the LZ; a contact near the LZ before the
 *            landing moves the LZ further out once
 *   land     the scripted insert (doHeliInsert) puts it down and unloads
 *   release  the aircrew leaves the group: an armed helicopter loiters 300 m off the
 *            objective as fire support, an unarmed one returns to where it took off
 * Returns true once the infantry is on the ground and the task can carry on on foot.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Objective position AGL <ARRAY>
 * 2: Helicopters carrying the group <ARRAY>
 *
 * Return Value:
 * infantry on the ground, air assault over <BOOL>
 *
 * Example:
 * [group bob, getPos angryJoe, [heli]] call lambs_wp_fnc_taskAttackAir;
 *
 * Public: No
*/
#define LZ_MIN 250
#define LZ_MAX 400
#define LZ_STEP 50
#define LZ_ANGLES [0, 25, -25, 50, -50, 80, -80]
#define LZ_CLEARANCE 12
#define LZ_GRADIENT 0.15
#define HOT_LZ 200
#define START_INSERT 120
#define APPROACH_ALTITUDE 60
#define LOITER_RADIUS 300
#define LOITER_ALTITUDE 120

params [["_group", grpNull, [grpNull]], ["_pos", [], [[]]], ["_helis", [], [[]]]];

private _air = _group getVariable QGVAR(attackAir);
_helis = _helis select {alive _x && {canMove _x} && {alive (driver _x)}};

// plan ~ once
if (isNil "_air") then {
    if (_helis isEqualTo []) exitWith {true};
    private _heli = _helis select 0;
    private _axis = _pos getDir _heli;
    private _objectiveASL = (AGLToASL _pos) vectorAdd [0, 0, 1.5];
    private _lz = [];
    private _best = -1e9;
    for "_range" from LZ_MIN to LZ_MAX step LZ_STEP do {
        {
            private _candidate = _pos getPos [_range, _axis + _x];
            if (!surfaceIsWater _candidate && {(_candidate isFlatEmpty [LZ_CLEARANCE, -1, LZ_GRADIENT, LZ_CLEARANCE, 0, false, objNull]) isNotEqualTo []}) then {
                private _score = ([0, 4] select (terrainIntersectASL [(AGLToASL _candidate) vectorAdd [0, 0, 2], _objectiveASL])) - (abs _x / 40) - ((_range - LZ_MIN) / 100);
                if (_score > _best) then {_best = _score; _lz = _candidate;};
            };
        } forEach LZ_ANGLES;
    };
    if (_lz isEqualTo []) then {_lz = _pos getPos [LZ_MAX, _axis];};
    _lz set [2, 0];
    _air = createHashMapFromArray [
        ["phase", "fly"],
        ["heli", _heli],
        ["lz", _lz],
        ["start", getPosATL _heli],
        ["moved", false],
        ["time", time]
    ];
    _group setVariable [QGVAR(attackAir), _air];
    {
        _x flyInHeight APPROACH_ALTITUDE;
        (driver _x) doMove _lz;
        {_x setVariable [QEGVAR(main,currentTask), "Air assault (flying in)", EGVAR(main,debug_functions)];} forEach (crew _x);
    } forEach _helis;
    if (EGVAR(main,debug_functions)) then {
        ["%1 taskAttack: %2 air assault, LZ %3m from the objective", side _group, groupId _group, round (_lz distance2D _pos)] call EFUNC(main,debugLog);
        private _marker = [_lz, "LZ", (leader _group) call EFUNC(main,debugMarkerColor), "hd_pickup"] call EFUNC(main,dotMarker);
        [{deleteMarker _this}, _marker, 300] call CBA_fnc_waitAndExecute;
    };
};

private _heli = _air get "heli";
private _lz = _air get "lz";
private _phase = _air get "phase";

// aircraft gone before the troops were out ~ whoever survived fights on foot from where they are
if (_phase in ["fly", "land"] && {!alive _heli || {!canMove _heli}}) exitWith {
    _air set ["phase", "done"];
    {[_x] allowGetIn false;} forEach (units _group);
    if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 lost its helicopter", side _group, groupId _group] call EFUNC(main,debugLog);};
    true
};

switch (_phase) do {

    case "fly": {
        // hot LZ ~ known enemy near it: push it out along the same bearing, once
        if (!(_air get "moved")) then {
            private _contacts = [_group, 30] call EFUNC(danger,pictureContacts);
            if ((_contacts findIf {(_x select 1) distance2D _lz < HOT_LZ}) isNotEqualTo -1) then {
                _lz = _lz getPos [150, _pos getDir _lz];
                _lz set [2, 0];
                _air set ["lz", _lz];
                _air set ["moved", true];
                (driver _heli) doMove _lz;
                if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 hot LZ, moving it out", side _group, groupId _group] call EFUNC(main,debugLog);};
            };
        };
        if (unitReady (driver _heli)) then {(driver _heli) doMove _lz;};
        if (_heli distance2D _lz < START_INSERT) then {
            _air set ["phase", "land"];
            private _troops = (units _group) select {(vehicle _x) isEqualTo _heli && {_x isNotEqualTo (driver _heli)} && {!(_x in [gunner _heli, commander _heli])} && {!((fullCrew [_heli, "turret"] select {!(_x select 4)}) apply {_x select 0} find _x > -1)}};
            private _exit = _lz getPos [400, _pos getDir _lz];
            [_heli, _lz, _troops, _exit, {
                params ["_heli", "_troopsOut", "_aborted"];
                if (isNull _heli) exitWith {};
                private _group = (_troopsOut param [0, objNull]) call {if (isNull _this) then {grpNull} else {group _this}};
                if (isNull _group) then {_group = group (driver _heli);};
                private _air = _group getVariable QGVAR(attackAir);
                if (!isNil "_air") then {_air set ["phase", "release"];};
            }] call FUNC(doHeliInsert);
        };
        false
    };

    case "land": {false};

    case "release": {
        _air set ["phase", "done"];
        // the infantry leads from here
        private _onFoot = (units _group) select {isNull objectParent _x && {_x call EFUNC(main,isAlive)} && {!isPlayer _x}};
        if (_onFoot isNotEqualTo [] && {!(isNull objectParent (leader _group))}) then {_group selectLeader (_onFoot select 0);};
        // the aircrew becomes its own element
        if (alive _heli) then {
            private _crew = (crew _heli) select {(group _x) isEqualTo _group};
            if (_crew isNotEqualTo [] && {_crew isNotEqualTo (units _group)}) then {
                private _airGroup = createGroup [side _group, true];
                _crew joinSilent _airGroup;
                _airGroup setBehaviour "AWARE";
                _airGroup setCombatMode "YELLOW";
                _airGroup setVariable [QEGVAR(danger,disableGroupAI), true, true];
                [_airGroup] call CBA_fnc_clearWaypoints;
                _heli flyInHeight LOITER_ALTITUDE;
                if (someAmmo _heli && {(_crew findIf {_x isEqualTo (gunner _heli) || {(_heli unitTurret _x) isNotEqualTo []}}) isNotEqualTo -1}) then {
                    // armed: circle the objective at a distance and shoot what shows itself
                    private _wp = _airGroup addWaypoint [_pos, 0];
                    _wp setWaypointType "LOITER";
                    _wp setWaypointLoiterType "CIRCLE_L";
                    _wp setWaypointLoiterRadius LOITER_RADIUS;
                    _airGroup setCombatMode "RED";
                    {_x setVariable [QEGVAR(main,currentTask), "Air support (loiter)", EGVAR(main,debug_functions)];} forEach _crew;
                } else {
                    // unarmed: back to where it came from, out of the fight
                    private _wp = _airGroup addWaypoint [_air get "start", 0];
                    _wp setWaypointType "MOVE";
                    private _loiter = _airGroup addWaypoint [_air get "start", 0];
                    _loiter setWaypointType "LOITER";
                    _loiter setWaypointLoiterRadius 200;
                    {_x setVariable [QEGVAR(main,currentTask), "Returning to base", EGVAR(main,debug_functions)];} forEach _crew;
                };
            };
        };
        [leader _group, "combat", "Advance", 125] call EFUNC(main,doCallout);
        if (EGVAR(main,debug_functions)) then {["%1 taskAttack: %2 on the ground, %3 men", side _group, groupId _group, count (units _group)] call EFUNC(main,debugLog);};
        true
    };

    default {true};
};
