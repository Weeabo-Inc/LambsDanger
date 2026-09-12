#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A deliberate attack on a position, the way a trained squad does it rather than a
 * rush down the direct line:
 *   plan         analyse the ground (lambs_main_fnc_findApproach), split the squad into a
 *                support element (leader, machine guns, launchers) and an assault element
 *   approach     support moves to a support by fire position with eyes on the objective,
 *                the assault element follows a covered route to an assault position on the
 *                flank, in a free-form wedge, both at the same time
 *   assault      support suppresses and fires rockets and grenade launchers into the
 *                objective, the assault element closes with fire and movement in pairs
 *                (lambs_main_fnc_doGroupBound); support shifts and lifts as they get close
 *   clear        the assault element sweeps the buildings, support moves up
 *   consolidate  everyone takes a sector on a perimeter around the objective facing out
 * A squad too small to split assaults with fire and movement straight from the approach.
 * Reacts on the way: fired on before the assault position it goes straight into the
 * assault from where it is; losses or broken morale end it. Runs on its own per frame
 * handler every 4 s and owns the group's tactic state until it ends.
 *
 * Arguments:
 * 0: group executing tactics <GROUP> or group leader <UNIT>
 * 1: objective position or unit <ARRAY> or <OBJECT>
 * 2: maximum duration in seconds <NUMBER>
 *
 * Return Value:
 * success
 *
 * Example:
 * [group bob, getPos angryJoe] call lambs_danger_fnc_tacticsManeuver;
 *
 * Public: No
*/
#define CYCLE 4
#define MIN_SPLIT_SIZE 5
#define MIN_ASSAULT 3
#define ASSAULT_SPACING 4
#define SUPPORT_SPACING 5
#define SHIFT_FIRE_DISTANCE 60
#define PERIMETER_RADIUS 20
#define CONSOLIDATE_OFFSET 35
#define SECURITY_DISTANCE 45
#define COUNTERATTACK_RANGE 150
#define CLEAR_QUIET 30
#define REACT_STRESS 0.5
#define REACT_RANGE 150
#define FAIL_MORALE 0.35
#define FAIL_LOSSES 3
#define STALL_STEP 8
#define STALL_TIME 60
#define DISMOUNT_DISTANCE 60
#define DISMOUNT_CLEARANCE 50
#define DISMOUNT_REACHED 15
#define DISMOUNT_STOPPED 40
#define COVER_SEARCH_RADIUS 40
#define FAN_TIMEOUT 25
#define MOUNTED_TIMEOUT 75
#define CONTACT_DISMOUNT_RANGE 300
#define CONTACT_RETARGET 150
#define EMERGENCY_BACK 40
#define EMERGENCY_SUPPORT 120
#define EMERGENCY_TIMEOUT 15
#define CRIPPLED_DAMAGE 0.7
#define RALLY_TIMEOUT 35
#define SUPPRESS_POSITIONS 10

params ["_group", "_objective", ["_maxDuration", 420]];

// group is missing
if (isNull _group) exitWith {false};
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;
if (_group call EFUNC(main,isDirected)) exitWith {false};
_objective = _objective call CBA_fnc_getPos;
if (_objective isEqualTo [0, 0, 0]) exitWith {false};

// units on foot ~ vehicles stay back as a fire base through the bound code
private _units = [_unit, 300] call EFUNC(main,findReadyUnits);

// mechanized ~ troops still aboard, or on foot next to their carrier: the vehicles carry them to a dismount
// point short of the objective, then hold there as the fire base while the infantry fans out and assaults
private _vehicles = ([_unit, 400] call EFUNC(main,findGroupVehicles)) select {(effectiveCommander _x) call EFUNC(main,isAlive) && {alive (driver _x)}};
private _mounted = [];
{
    private _vehicle = _x;
    _mounted append ((fullCrew [_vehicle, "cargo"]) apply {_x select 0});
    _mounted append (((fullCrew [_vehicle, "turret"]) select {_x select 4}) apply {_x select 0});
} forEach _vehicles;
_mounted = _mounted select {_x call EFUNC(main,isAlive) && {!isPlayer _x} && {(group _x) isEqualTo _group}};
private _mechanized = _vehicles isNotEqualTo [] && {_mounted isNotEqualTo [] || {(_units findIf {private _foot = _x; (_vehicles findIf {_x distance2D _foot < 40}) isNotEqualTo -1}) isNotEqualTo -1}};
if (_mechanized) then {_units = _units + _mounted;};
if (_units isEqualTo []) exitWith {
    if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2: nobody available (%3 vehicles, %4 mounted)", side _unit, groupId _group, count _vehicles, count _mounted] call EFUNC(main,debugLog);};
    false
};

// stop whatever else was running
private _oldPFH = _group getVariable [QGVAR(maneuverPFH), -1];
if (_oldPFH isNotEqualTo -1) then {[_oldPFH] call CBA_fnc_removePerFrameHandler;};
_group setVariable [QGVAR(boundToken), nil];
private _monitor = _group getVariable [QGVAR(tacticPFH), -1];
if (_monitor isNotEqualTo -1) then {[_monitor] call CBA_fnc_removePerFrameHandler; _group setVariable [QGVAR(tacticPFH), nil];};

// plan
private _leadVehicle = _vehicles param [0, objNull];
private _planFrom = [getPosATL _unit, getPosATL _leadVehicle] select _mechanized;
([_planFrom, _objective] call EFUNC(main,findApproach)) params ["_route", "_assaultPos", "_supportPos", "_side"];
private _support = [];
private _assault = _units;

// mechanized: the vehicles are the support element, every rifleman assaults; dismount point on the approach axis,
// as close as 60 m to the objective but never inside 50 m of a known enemy
private _dismountPos = [];
if (_mechanized) then {
    private _axis = _objective getDir _planFrom;
    private _distance = DISMOUNT_DISTANCE;
    {
        private _contact = _x select 1;
        private _candidate = _objective getPos [_distance, _axis];
        if (_candidate distance2D _contact < DISMOUNT_CLEARANCE) then {_distance = _distance + (DISMOUNT_CLEARANCE - (_candidate distance2D _contact));};
    } forEach ([_group, 90] call FUNC(pictureContacts));
    _dismountPos = _objective getPos [_distance min (_planFrom distance2D _objective), _axis];
    private _empty = _dismountPos findEmptyPosition [0, 25, typeOf _leadVehicle];
    if (_empty isNotEqualTo []) then {_dismountPos = _empty;};
    _assaultPos = _dismountPos;
    _route = [_dismountPos];
};

if (!_mechanized && {count _units >= MIN_SPLIT_SIZE}) then {
    _support = [_unit] + ((_units - [_unit]) select {_x call EFUNC(main,isSupportGunner) || {(secondaryWeapon _x) isNotEqualTo ""}});
    _assault = _units - _support;
    while {count _assault < MIN_ASSAULT && {count _support > 2}} do {
        private _mover = (_support - [_unit]) select -1;
        _assault pushBack _mover;
        _support = _support - [_mover];
    };
    while {count _support > count _assault && {count _support > 2}} do {
        private _mover = (_support - [_unit]) select -1;
        _assault pushBack _mover;
        _support = _support - [_mover];
    };
};

// what the support element shoots at
private _posList = ([_group, 90] call FUNC(pictureContacts)) apply {_x select 1};
_posList append ([_objective, 30, true, false] call EFUNC(main,findBuildings));
_posList pushBack _objective;
if (count _posList > SUPPRESS_POSITIONS) then {_posList resize SUPPRESS_POSITIONS;};

// state
private _state = createHashMapFromArray [
    ["phase", ["approach", "mounted"] select _mechanized],
    ["mechanized", _mechanized],
    ["vehicles", _vehicles],
    ["mounted", _mounted],
    ["dismountPos", _dismountPos],
    ["phaseTime", time],
    ["startTime", time],
    ["startPos", _planFrom],
    ["endTime", time + _maxDuration],
    ["support", _support],
    ["assault", _assault],
    ["route", _route],
    ["routeIndex", 0],
    ["assaultPos", _assaultPos],
    ["supportPos", _supportPos],
    ["objective", _objective],
    ["posList", _posList],
    ["supportIndex", 0],
    ["supportArrived", _support isEqualTo []],
    ["lifted", false],
    ["quietSince", -1],
    ["startLosses", ([_group] call FUNC(pictureGet)) get "losses"]
];
_group setVariable [QGVAR(maneuver), _state];
_group setVariable [QGVAR(isExecutingTactic), true];
_group setVariable [QEGVAR(main,currentTactic), "Deliberate attack", EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTarget), _objective, EGVAR(main,debug_functions)];

// orders ~ AWARE, no automatic COMBAT, engine formation out of the way, everyone on their own slots
_group enableAttack false;
_group setCombatMode "RED";
_group setSpeedMode "FULL";
_group setBehaviourStrong "AWARE";
_group setFormDir (_unit getDir _objective);
{
    _x setVariable [QGVAR(forceMove), true];
    _x disableAI "AUTOCOMBAT";
    _x forceSpeed -1;
    _x setUnitPos "AUTO";
    _x setVariable [QEGVAR(main,currentTask), ["Assault element", "Support element"] select (_x in _support), EGVAR(main,debug_functions)];
} forEach _units;
[_unit, "gesturePoint"] call EFUNC(main,doGesture);
[_unit, "combat", "Advance", 125] call EFUNC(main,doCallout);

// mechanized: carriers drive to the dismount point and nowhere further, troops stay aboard until then
if (_mechanized) then {
    {
        _x setUnloadInCombat [false, false];
        _x setVariable [QEGVAR(main,keepMounted), true];
        (effectiveCommander _x) setVariable [QGVAR(forceMove), true];
        _x doWatch _objective;
        (driver _x) doMove _dismountPos;
        (effectiveCommander _x) setVariable [QEGVAR(main,currentTask), "Carrying troops forward", EGVAR(main,debug_functions)];
    } forEach _vehicles;
    {_x setVariable [QEGVAR(main,currentTask), "Mounted", EGVAR(main,debug_functions)];} forEach _mounted;
};

// the plan runs from here
private _handle = [{
    params ["_args", "_handle"];
    _args params ["_group", "_units"];

    private _fnc_end = {
        params ["_group", "_handle", "_units", "_result"];
        [_handle] call CBA_fnc_removePerFrameHandler;
        if (isNull _group) exitWith {};
        private _picture = [_group] call FUNC(pictureGet);
        _picture set ["lastTactic", "maneuver"];
        _picture set ["lastResult", _result];
        _picture set ["lastTacticTime", time];
        _group setVariable [QGVAR(maneuverPFH), nil];
        _group setVariable [QGVAR(boundToken), nil];
        _group setVariable [QGVAR(isExecutingTactic), nil];
        _group setVariable [QEGVAR(main,currentTactic), nil, EGVAR(main,debug_functions)];
        _group enableAttack (GVAR(aggression) > 0 && {!(_group call EFUNC(main,isDirected))});
        _group setSpeedMode "NORMAL";
        {
            if (!isNull _x) then {
                _x setVariable [QGVAR(forceMove), nil];
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x setUnitPos "AUTO";
                _x forceSpeed -1;
                private _taskDisabled = _x getVariable [QEGVAR(wp,disabledAI), []];
                private _maneuverUnit = _x;
                {if (!(_x in _taskDisabled)) then {_maneuverUnit enableAI _x;};} forEach ["SUPPRESSION", "TARGET", "AUTOTARGET", "AUTOCOMBAT"];
                // a completed attack leaves the men where they consolidated, in cover, watching their sectors
                if (_result isNotEqualTo "completed") then {_x doFollow (leader _group);} else {_x setUnitPos "DOWN";};
                [_x] allowGetIn true;
            };
        } forEach _units;
        // carriers get their crews and their freedom back
        {
            if (alive _x) then {
                _x setUnloadInCombat [true, true];
                (effectiveCommander _x) setVariable [QGVAR(forceMove), nil];
                (effectiveCommander _x) setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                if (alive (driver _x)) then {(driver _x) doFollow (leader _group);};
            };
        } forEach ((_group getVariable [QGVAR(maneuver), createHashMap]) getOrDefault ["vehicles", []]);
        if (EGVAR(main,debug_functions)) then {
            ["%1 MANEUVER %2 %3", side _group, groupId _group, _result] call EFUNC(main,debugLog);
        };
        _group setVariable [QGVAR(maneuver), nil];
    };

    // gone, taken over, or out of time
    if (isNull _group || {!local _group} || {_group call EFUNC(main,isDirected)}) exitWith {[_group, _handle, _units, "aborted"] call _fnc_end;};
    private _state = _group getVariable QGVAR(maneuver);
    if (isNil "_state") exitWith {[_group, _handle, _units, "aborted"] call _fnc_end;};
    if (time > (_state get "endTime")) exitWith {[_group, _handle, _units, "timeout"] call _fnc_end;};

    // this plan owns the group's tactic state until it is done
    _group setVariable [QGVAR(isExecutingTactic), true];

    private _picture = [_group] call FUNC(pictureGet);
    private _objective = _state get "objective";
    private _phase = _state get "phase";
    private _mechanized = _state get "mechanized";
    private _vehicles = (_state get "vehicles") select {alive _x && {(effectiveCommander _x) call EFUNC(main,isAlive)}};
    _state set ["vehicles", _vehicles];
    private _aboard = _mechanized && {_phase in ["mounted", "dismount"]};
    private _alive = {_x call EFUNC(main,isAlive) && {_aboard || {isNull objectParent _x}}};
    private _support = (_state get "support") select _alive;
    private _assault = (_state get "assault") select _alive;
    // the leader is under orders like everyone else, so the plan feeds the picture itself
    [_group, (leader _group) targets [true, 800]] call FUNC(pictureUpdate);

    // assault element wiped out ~ the support element either carries the attack on or the attack has failed
    if (_assault isEqualTo []) then {
        if (count _support >= 2 && {_phase in ["assault", "clear"]} && {([_group] call FUNC(getMorale)) >= FAIL_MORALE}) then {
            _assault = _support;
            _support = [];
            _state set ["lifted", true];
            _phase = "assault";
            _state set ["phase", "assault"];
            _state set ["phaseTime", time];
            _state set ["relaunch", true];
            if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2: assault element lost, support carries on", side _group, groupId _group] call EFUNC(main,debugLog);};
        } else {
            _assault = _support;
            _support = [];
        };
    };
    _state set ["support", _support];
    _state set ["assault", _assault];
    if (_assault isEqualTo []) exitWith {[_group, _handle, _units, "failed"] call _fnc_end;};

    // broken or bled out ~ the withdraw tactic takes over from the commander
    private _losses = (_picture get "losses") - (_state get "startLosses");
    if (_losses >= FAIL_LOSSES || {([_group] call FUNC(getMorale)) < FAIL_MORALE}) exitWith {[_group, _handle, _units, "failed"] call _fnc_end;};

    private _leader = leader _group;
    private _assaultCentre = [0, 0, 0];
    {_assaultCentre = _assaultCentre vectorAdd (getPosATL _x);} forEach _assault;
    _assaultCentre = _assaultCentre vectorMultiply (1 / count _assault);
    private _assaultDistance = _assaultCentre distance2D _objective;
    private _posList = _state get "posList";

    // stalled ~ nobody has gained ground for a while during a phase that is meant to move
    private _stalled = false;
    if (_phase in ["approach", "assault"]) then {
        private _bestDistance = _state getOrDefault ["bestDistance", 1e9];
        if (_assaultDistance < _bestDistance - STALL_STEP) then {
            _state set ["bestDistance", _assaultDistance];
            _state set ["progressTime", time];
        };
        _stalled = time - (_state getOrDefault ["progressTime", time]) > STALL_TIME;
    };
    if (_stalled) exitWith {[_group, _handle, _units, "failed"] call _fnc_end;};

    // a fresh fire and movement with whoever is left
    private _fnc_launchBound = {
        private _fireHalf = [];
        private _runHalf = [];
        {[_runHalf, _fireHalf] select ((_forEachIndex % 2) isEqualTo 1) pushBack _x;} forEach _assault;
        if (_runHalf isEqualTo []) then {_runHalf = _fireHalf; _fireHalf = [];};
        private _token = time + random 1;
        _group setVariable [QGVAR(boundToken), _token];
        [{_this call EFUNC(main,doGroupBound)}, [_group, _fireHalf, _runHalf, _posList, _objective, 0, 0, [], [_leader] call EFUNC(main,findReadyVehicles), _token], 0.5] call CBA_fnc_waitAndExecute;
        [_leader, "combat", "Advance", 125] call EFUNC(main,doCallout);
    };
    if (_state getOrDefault ["relaunch", false]) then {
        _state set ["relaunch", false];
        call _fnc_launchBound;
    };
    private _fnc_setPhase = {
        _state set ["phase", _this];
        _state set ["phaseTime", time];
        if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2 -> %3", side _group, groupId _group, _this] call EFUNC(main,debugLog);};
    };

    // support element ~ suppress from its position once there, shift and lift when the assault is close
    private _fnc_supportFire = {
        private _lifted = _state get "lifted";
        {
            _x setUnitPos "DOWN";
            _x enableAI "TARGET";
            _x enableAI "AUTOTARGET";
            if (_lifted) then {
                _x doWatch _objective;
            } else {
                if (!([_x, [_objective, _posList select 0] select (_posList isNotEqualTo [])] call EFUNC(main,doLauncherFire))) then {
                    if ((currentCommand _x) isNotEqualTo "Suppress") then {
                        private _index = [_x, _posList] call EFUNC(main,checkVisibilityList);
                        if (_index isEqualTo -1 || {!([_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call EFUNC(main,doSuppress))}) then {
                            _x doWatch _objective;
                        };
                    };
                };
            };
        } forEach _support;
    };

    // carriers ~ hold where they dismounted the troops and shoot over their heads, lift when the troops are close
    private _fnc_vehicleFire = {
        private _lifted = _state get "lifted";
        {
            private _vehicle = _x;
            // an unarmed carrier is a taxi ~ it waits at the support position, out of the fight
            if (!(canFire _vehicle && {someAmmo _vehicle})) then {
                if (unitReady (driver _vehicle) && {_vehicle distance2D (_state get "supportPos") > 20}) then {(driver _vehicle) doMove (_state get "supportPos");};
                (effectiveCommander _vehicle) setVariable [QEGVAR(main,currentTask), "Waiting (transport)", EGVAR(main,debug_functions)];
                continue;
            };
            if ((currentCommand _vehicle) isNotEqualTo "Suppress") then {
                private _index = if (_lifted) then {-1} else {[_vehicle, _posList] call EFUNC(main,checkVisibilityList)};
                if (_index isEqualTo -1 || {!([_vehicle, (_posList select _index) vectorAdd [0, 0, random 1]] call EFUNC(main,doVehicleSuppress))}) then {
                    _vehicle doWatch _objective;
                };
            };
            (effectiveCommander _vehicle) setVariable [QEGVAR(main,currentTask), ["Fire base (vehicle)", "Fire lifted (vehicle)"] select _lifted, EGVAR(main,debug_functions)];
        } forEach _vehicles;
    };

    switch (_phase) do {

        // mechanized: ride to the dismount point
        case "mounted": {
            // a dead driver or gunner is replaced from the passengers on the way (or everyone bails if the enemy is close)
            [_group, 3] call FUNC(commanderContingency);
            private _lead = _vehicles param [0, objNull];

            // contact on the way ~ actions on contact while mounted: smoke, get off the road away from the
            // threat and behind something, troops off and away from the carrier (it draws the rockets),
            // carrier backs off to a fire position. Never drive on towards the enemy to unload.
            if (!isNull _lead && {!(_state getOrDefault ["emergency", false])}) then {
                private _contacts = [_group, 20] call FUNC(pictureContacts);
                private _nearest = [];
                private _nearestDistance = CONTACT_DISMOUNT_RANGE;
                {
                    private _contactDistance = _lead distance2D (_x select 1);
                    if (_contactDistance < _nearestDistance) then {_nearest = _x select 1; _nearestDistance = _contactDistance;};
                } forEach _contacts;
                if (_nearest isNotEqualTo []) then {
                    _state set ["emergency", true];
                    _state set ["threatPos", _nearest];
                    _state set ["phaseTime", time];
                    private _away = _nearest getDir _lead;
                    private _spot = _lead getPos [EMERGENCY_BACK, _away];
                    private _cover = nearestTerrainObjects [_spot, ["HOUSE", "WALL", "ROCK", "TREE", "BUSH", "HIDE"], 25, false, true];
                    if (_cover isNotEqualTo []) then {_spot = (_cover select 0) getPos [5, _away];};
                    private _empty = _spot findEmptyPosition [0, 20, typeOf _lead];
                    if (_empty isNotEqualTo []) then {_spot = _empty;};
                    _state set ["dismountPos", _spot];
                    // the carrier then fights from further back, with a line of sight
                    private _fallback = _lead getPos [EMERGENCY_SUPPORT, _away];
                    private _supportPos = [_nearest, EMERGENCY_SUPPORT, EMERGENCY_BACK, 3, _fallback] call EFUNC(main,findOverwatch);
                    if (_supportPos isEqualTo [] || {_supportPos isEqualTo [0, 0, 0]}) then {_supportPos = _fallback;};
                    _state set ["supportPos", _supportPos];
                    // the fight is here now
                    if (_objective distance2D _nearest > CONTACT_RETARGET) then {
                        _state set ["objective", _nearest];
                        _objective = _nearest;
                    };
                    (_state get "posList") pushBackUnique _nearest;
                    {
                        private _vehicle = _x;
                        if (time > (_vehicle getVariable [QEGVAR(main,smokescreenTime), 0]) && {"SmokeLauncher" in (weapons _vehicle)}) then {
                            (effectiveCommander _vehicle) forceWeaponFire ["SmokeLauncher", "SmokeLauncher"];
                            _vehicle setVariable [QEGVAR(main,smokescreenTime), time + 30 + random 20];
                        };
                        _vehicle doWatch _nearest;
                        (driver _vehicle) doMove _spot;
                        (effectiveCommander _vehicle) setVariable [QEGVAR(main,currentTask), "Contact! getting off the road", EGVAR(main,debug_functions)];
                    } forEach _vehicles;
                    [_leader, "combat", "contact", 125] call EFUNC(main,doCallout);
                    if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2: contact while mounted at %3m, emergency dismount", side _group, groupId _group, round _nearestDistance] call EFUNC(main,debugLog);};
                };
            };

            // carrier knocked out or crippled ~ everyone out at once, and away from it
            // a dead driver is not crippling while a passenger is on his way to the seat
            private _replacing = !isNull _lead && {time < (_lead getVariable [QGVAR(crewReplaceUntil), 0])};
            private _crippled = isNull _lead || {!canMove _lead} || {!_replacing && {!alive (driver _lead)}} || {damage _lead > CRIPPLED_DAMAGE};
            if (_crippled && {!(_state getOrDefault ["crippled", false])}) then {
                _state set ["crippled", true];
                _state set ["emergency", true];
                private _wreck = if (isNull _lead) then {_state get "dismountPos"} else {getPosATL _lead};
                _state set ["wreckPos", _wreck];
                if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2: carrier knocked out, bailing out", side _group, groupId _group] call EFUNC(main,debugLog);};
            };

            private _dismountPos = _state get "dismountPos";
            private _emergency = _state getOrDefault ["emergency", false];
            private _there = _crippled
                || {_lead distance2D _dismountPos < DISMOUNT_REACHED}
                || {_lead distance2D _dismountPos < DISMOUNT_STOPPED && {speed _lead < 2}}
                || {time - (_state get "phaseTime") > ([MOUNTED_TIMEOUT, EMERGENCY_TIMEOUT] select _emergency)};
            if (!_there) then {
                {
                    private _driver = driver _x;
                    if (alive _driver && {unitReady _driver || {_x distance2D _dismountPos > DISMOUNT_STOPPED}}) then {_driver doMove _dismountPos;};
                } forEach _vehicles;
                {_x setVariable [QEGVAR(main,currentTask), "Mounted", EGVAR(main,debug_functions)];} forEach _assault;
            } else {
                "dismount" call _fnc_setPhase;
                {
                    private _vehicle = _x;
                    doStop (driver _vehicle);
                    _vehicle doWatch _objective;
                    _vehicle setVariable [QEGVAR(main,keepMounted), nil];
                    _vehicle setUnloadInCombat [true, true];
                } forEach _vehicles;
                private _troops = _assault + _support;
                _troops orderGetIn false;
                {
                    if (!isNull objectParent _x) then {_x action ["Eject", vehicle _x];};
                    [_x] allowGetIn false;
                    _x setVariable [QEGVAR(main,currentTask), "Dismounting", EGVAR(main,debug_functions)];
                } forEach _troops;
                [selectRandom _troops, "combat", "Dismount"] call EFUNC(main,doCallout);
            };
        };

        // mechanized: troops out and into cover. With the carrier intact and not under fire they lie behind the
        // hull on the far side and in the nearest dips; under fire or next to a wreck the hull is what draws the
        // rockets, so they go for ditches and terrain cover to the side, and only as a last resort spread out.
        case "dismount": {
            call _fnc_vehicleFire;
            private _lead = _vehicles param [0, objNull];
            private _emergency = _state getOrDefault ["emergency", false];
            private _crippled = _state getOrDefault ["crippled", false];
            private _anchor = if (isNull _lead) then {_state get "dismountPos"} else {getPosATL _lead};
            if (_crippled) then {_anchor = _state getOrDefault ["wreckPos", _anchor];};
            private _threat = _state getOrDefault ["threatPos", _objective];
            private _all = _assault + _support;
            private _onFoot = _all select {isNull objectParent _x};

            // one cover spot per man, picked once and kept, nearest men to the hull take the hull
            if (isNil {_state get "coverSlots"}) then {
                private _from = [_lead, _anchor] select (_crippled || {isNull _lead});
                private _spots = [_from, _threat, count _all, !(_emergency || _crippled), COVER_SEARCH_RADIUS] call EFUNC(main,findDismountCover);
                private _slots = createHashMap;
                private _unassigned = +_all;
                {
                    _x params ["_pos"];
                    if (_unassigned isNotEqualTo []) then {
                        private _nearest = [_unassigned, [], {_x distance2D _pos}, "ASCEND"] call BIS_fnc_sortBy;
                        _slots set [_nearest select 0, _x];
                        _unassigned deleteAt (_unassigned find (_nearest select 0));
                    };
                } forEach _spots;
                _state set ["coverSlots", _slots];
                [_leader, "combat", ["Dismount", "flank"] select _emergency, 125] call EFUNC(main,doCallout);
                if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2: %3 cover spots for %4 men (%5)", side _group, groupId _group, count _spots, count _all, ["behind the hull and in the dips", "ditches and cover off to the side"] select (_emergency || _crippled)] call EFUNC(main,debugLog);};
            };
            private _slots = _state get "coverSlots";

            {
                if (isNull objectParent _x) then {
                    private _slot = _slots getOrDefault [_x, []];
                    if (_slot isEqualTo []) then {
                        // no spot of his own (joined late): the far side of the hull, a little back
                        _slot = [_anchor getPos [8, _threat getDir _anchor], "DOWN"];
                        _slots set [_x, _slot];
                    };
                    _slot params ["_pos", "_stance"];
                    if (_x distance2D _pos > 2.5) then {
                        // run for it: no stopping to shoot until in cover
                        _x disableAI "SUPPRESSION";
                        _x disableAI "TARGET";
                        _x disableAI "AUTOTARGET";
                        _x doWatch objNull;
                        _x setUnitPos "UP";
                        _x forceSpeed -1;
                        _x doMove _pos;
                        _x setVariable [QEGVAR(main,currentTask), "Getting into cover", EGVAR(main,debug_functions)];
                    } else {
                        _x enableAI "SUPPRESSION";
                        _x enableAI "TARGET";
                        _x enableAI "AUTOTARGET";
                        _x setUnitPos _stance;
                        _x doWatch _threat;
                        _x setVariable [QEGVAR(main,currentTask), "In cover", EGVAR(main,debug_functions)];
                    };
                } else {
                    _x action ["Eject", vehicle _x];
                };
            } forEach _all;
            private _notThere = (_onFoot findIf {private _slot = _slots getOrDefault [_x, []]; _slot isEqualTo [] || {_x distance2D (_slot select 0) > 3}}) isNotEqualTo -1;
            private _fanned = (count _onFoot) isEqualTo (count _all) && {!_notThere};
            if (_fanned || {time - (_state get "phaseTime") > ([FAN_TIMEOUT, RALLY_TIMEOUT] select (_emergency || _crippled))}) then {
                {
                    _x enableAI "SUPPRESSION";
                    _x enableAI "TARGET";
                    _x enableAI "AUTOTARGET";
                } forEach _onFoot;
                // the carrier does not sit next to the infantry ~ it backs off to its fire position
                if (_emergency) then {
                    {
                        (driver _x) doMove (_state get "supportPos");
                        _x doWatch _objective;
                        (effectiveCommander _x) setVariable [QEGVAR(main,currentTask), "Backing off to fire position", EGVAR(main,debug_functions)];
                    } forEach _vehicles;
                };
                "assault" call _fnc_setPhase;
                _state set ["assault", _onFoot];
                _state set ["support", []];
                _assault = _onFoot;
                _support = [];
                call _fnc_launchBound;
            };
        };

        case "approach": {
            // support to its position
            if (_support isNotEqualTo [] && {!(_state get "supportArrived")}) then {
                ([_support, [_state get "supportPos"], 0, "line", SUPPORT_SPACING, _objective] call EFUNC(main,doTeamMove)) params ["_arrived"];
                if (_arrived) then {
                    _state set ["supportArrived", true];
                    [_leader, "combat", "suppress", 100] call EFUNC(main,doCallout);
                };
                {_x setVariable [QEGVAR(main,currentTask), "Support moving to position", EGVAR(main,debug_functions)];} forEach _support;
            } else {
                call _fnc_supportFire;
            };

            // assault element along the covered route
            ([_assault, _state get "route", _state get "routeIndex", "wedge", ASSAULT_SPACING, _objective] call EFUNC(main,doTeamMove)) params ["_arrived", "_index"];
            _state set ["routeIndex", _index];
            {
                _x setUnitPos "UP";
                _x setVariable [QEGVAR(main,currentTask), "Assault element approaching", EGVAR(main,debug_functions)];
            } forEach _assault;

            // fired on before the assault position ~ go in from here
            private _stress = 0;
            {_stress = _stress + (_x call EFUNC(main,getStress));} forEach _assault;
            _stress = _stress / count _assault;
            private _contacts = [_group, 20] call FUNC(pictureContacts);
            private _closeContact = (_contacts findIf {(_x select 1) distance2D _assaultCentre < REACT_RANGE}) isNotEqualTo -1;
            if (_arrived || {_stress > REACT_STRESS && _closeContact} || {_assaultDistance < REACT_RANGE * 0.8}) then {
                "assault" call _fnc_setPhase;
                // pairs: half covers, half runs, alternating, straight out of the bound code
                call _fnc_launchBound;
            };
        };

        case "assault": {
            // shift and lift ~ no suppression into the assault element's backs
            if (!(_state get "lifted") && {_assaultDistance < SHIFT_FIRE_DISTANCE}) then {
                _state set ["lifted", true];
                {_x doWatch objNull; _x setUnitPos "MIDDLE";} forEach _support;
                {_x doWatch objNull;} forEach _vehicles;
                [_leader, "combat", "KeepFocused", 100] call EFUNC(main,doCallout);
            };
            call _fnc_supportFire;
            if (_mechanized) then {call _fnc_vehicleFire;};

            // support moves up once fire is lifted, to the assault position
            if (_state get "lifted" && {_support isNotEqualTo []}) then {
                [_support, [_state get "assaultPos"], 0, "line", SUPPORT_SPACING, _objective] call EFUNC(main,doTeamMove);
                {_x setUnitPos "MIDDLE"; _x setVariable [QEGVAR(main,currentTask), "Support moving up", EGVAR(main,debug_functions)];} forEach _support;
            };

            // the bound code hands over to the building assault inside CQB range ~ from there it is the clear
            if (_assaultDistance < GVAR(cqbRange)) then {
                "clear" call _fnc_setPhase;
            };
        };

        case "clear": {
            // support closes to the objective edge and watches outwards; carriers keep watch from where they are
            if (_support isNotEqualTo []) then {
                [_support, [_objective getPos [PERIMETER_RADIUS, _objective getDir _leader]], 0, "line", SUPPORT_SPACING, _objective] call EFUNC(main,doTeamMove);
            };
            if (_mechanized) then {call _fnc_vehicleFire;};
            // done when nothing has been seen for a while and the assault element is on the objective
            private _contacts = [_group, CLEAR_QUIET] call FUNC(pictureContacts);
            _contacts = _contacts select {(_x select 1) distance2D _objective < 100};
            if (_contacts isEqualTo [] && {_assaultDistance < PERIMETER_RADIUS * 2}) then {
                if ((_state get "quietSince") < 0) then {_state set ["quietSince", time];};
                if (time - (_state get "quietSince") > CLEAR_QUIET) then {
                    "consolidate" call _fnc_setPhase;
                    // the captured position is registered for the enemy's guns and rigged for his counterattack:
                    // get off it. Consolidate 35 m to the side with the most cover, facing where the counterattack
                    // will come from (the enemy's side of the objective), and post a pair further out to see it coming.
                    private _all = _assault + _support;
                    private _threatDir = _picture get "threatDir";
                    private _counterDir = if (_threatDir >= 0) then {_threatDir} else {(_state get "startPos") getDir _objective};
                    private _counterOrigin = _objective getPos [COUNTERATTACK_RANGE, _counterDir];
                    private _counterASL = (AGLToASL _counterOrigin) vectorAdd [0, 0, 1.5];
                    private _best = _objective getPos [CONSOLIDATE_OFFSET, _counterDir + 180];
                    private _bestScore = -1e9;
                    {
                        private _candidate = _objective getPos [CONSOLIDATE_OFFSET, _counterDir + _x];
                        if (!surfaceIsWater _candidate) then {
                            private _cover = nearestTerrainObjects [_candidate, ["HOUSE", "WALL", "ROCK", "TREE", "BUSH", "HIDE", "FENCE"], 20, false, true];
                            private _score = ((count _cover) min 6) + ([0, 3] select (terrainIntersectASL [(AGLToASL _candidate) vectorAdd [0, 0, 1], _counterASL])) - ([0, 2] select (isOnRoad _candidate));
                            if (_score > _bestScore) then {_bestScore = _score; _best = _candidate;};
                        };
                    } forEach [180, 120, -120, 90, -90];
                    _state set ["consolidatePos", _best];

                    // security pair ~ the two riflemen nearest the enemy side, out towards the counterattack, in cover
                    private _riflemen = _assault select {!(_x call EFUNC(main,isSupportGunner)) && {_x isNotEqualTo _leader}};
                    if (count _riflemen < 2) then {_riflemen = _all select {_x isNotEqualTo _leader};};
                    _riflemen = [_riflemen, [], {_x distance2D _counterOrigin}, "ASCEND"] call BIS_fnc_sortBy;
                    private _security = _riflemen select [0, 2];
                    private _opCentre = _objective getPos [SECURITY_DISTANCE, _counterDir];
                    private _opSpots = [_opCentre, _counterOrigin, count _security, false, 20] call EFUNC(main,findDismountCover);
                    {
                        private _spot = (_opSpots param [_forEachIndex, [_opCentre, "DOWN"]]) select 0;
                        _x setVariable [QGVAR(forceMove), true];
                        _x setUnitPos "MIDDLE";
                        _x doMove _spot;
                        _x setVariable [QEGVAR(main,currentTask), "Security post", EGVAR(main,debug_functions)];
                        [{params ["_unit", "_watch"]; if (_unit call EFUNC(main,isAlive)) then {_unit setUnitPos "DOWN"; _unit doWatch _watch;};}, [_x, _counterOrigin], 10 + random 4] call CBA_fnc_waitAndExecute;
                    } forEach _security;

                    // everyone else into cover around the consolidation position, sectors all round with the weight
                    // of them looking the way the enemy will come
                    private _rest = _all - _security;
                    private _spots = [_best, _counterOrigin, count _rest, false, 30] call EFUNC(main,findDismountCover);
                    {
                        private _spot = (_spots param [_forEachIndex, [_best getPos [4 + _forEachIndex, _counterDir + 180], "DOWN"]]) select 0;
                        // two thirds face the counterattack, the rest cover the flanks and the rear
                        private _bearing = if (_forEachIndex % 3 isEqualTo 2) then {_counterDir + ([90, -90, 180] select (floor (_forEachIndex / 3) % 3))} else {_counterDir};
                        _x doMove _spot;
                        _x setUnitPos "MIDDLE";
                        _x setVariable [QEGVAR(main,currentTask), "Consolidating", EGVAR(main,debug_functions)];
                        [{params ["_unit", "_spot", "_bearing"]; if (_unit call EFUNC(main,isAlive)) then {_unit setUnitPos "DOWN"; _unit doWatch (_spot getPos [60, _bearing]);};}, [_x, _spot, _bearing], 8 + random 4] call CBA_fnc_waitAndExecute;
                    } forEach _rest;
                    [_leader, "combat", "KeepFocused", 100] call EFUNC(main,doCallout);
                    if (_losses > 0) then {[{_this call EFUNC(main,doCallout)}, [_leader, "combat", "mandown", 100], 3] call CBA_fnc_waitAndExecute;};
                    // carriers pull back behind the consolidation position, hull towards the enemy side
                    {
                        private _spot = _best getPos [25 + (12 * _forEachIndex), _counterDir + 180];
                        private _empty = _spot findEmptyPosition [0, 20, typeOf _x];
                        if (_empty isNotEqualTo []) then {_spot = _empty;};
                        (driver _x) doFollow _leader;
                        _x doMove _spot;
                        _x doWatch _counterOrigin;
                    } forEach _vehicles;
                    if (EGVAR(main,debug_functions)) then {["%1 MANEUVER %2: consolidating %3m off the objective, security %4m out towards %5", side _group, groupId _group, round (_best distance2D _objective), SECURITY_DISTANCE, round _counterDir] call EFUNC(main,debugLog);};
                };
            } else {
                _state set ["quietSince", -1];
            };
        };

        case "consolidate": {
            if (time - (_state get "phaseTime") > 12) then {
                // nothing was ever seen here ~ a mechanized group mounts up again instead of digging in
                private _nothingFound = (_picture get "lastContact") < (_state get "startTime");
                if (_mechanized && _nothingFound) then {
                    [_group, "free"] call FUNC(intentSet);
                    [_group, _handle, _units, "completed"] call _fnc_end;
                    [_group, _vehicles] call EFUNC(main,doMountUp);
                } else {
                    // the ground to hold is where they consolidated, not the position they took
                    [_group, "defend", _state getOrDefault ["consolidatePos", _objective], 60] call FUNC(intentSet);
                    [_group, _handle, _units, "completed"] call _fnc_end;
                };
            };
        };
    };
}, CYCLE, [_group, _units]] call CBA_fnc_addPerFrameHandler;
_group setVariable [QGVAR(maneuverPFH), _handle];

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 MANEUVER %2: %3 support / %4 assault, %5 flank, objective %6m", side _unit, groupId _group, count _support, count _assault, ["left", "right"] select (_side > 0), round (_unit distance2D _objective)] call EFUNC(main,debugLog);
    private _markers = [];
    _markers pushBack ([_supportPos, "SBF", _unit call EFUNC(main,debugMarkerColor), "hd_dot"] call EFUNC(main,dotMarker));
    _markers pushBack ([_assaultPos, "assault pos", _unit call EFUNC(main,debugMarkerColor), "hd_flag"] call EFUNC(main,dotMarker));
    {_markers pushBack ([_x, format ["route %1", _forEachIndex], _unit call EFUNC(main,debugMarkerColor), "hd_arrow"] call EFUNC(main,dotMarker));} forEach _route;
    _markers pushBack ([_objective, "objective", _unit call EFUNC(main,debugMarkerColor), "hd_destroy"] call EFUNC(main,dotMarker));
    [{{deleteMarker _x;true} count _this;}, _markers, _maxDuration] call CBA_fnc_waitAndExecute;
};

// end
true
