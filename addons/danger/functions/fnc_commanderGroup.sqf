#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One think for one group. Reads the combat picture and the intent, works out the
 * escalation level and the role the side board gave the group, and issues a tactic
 * when nothing else is running. Toy soldiers below level 2, real ones above it.
 *
 * Arguments:
 * 0: Group <GROUP>
 *
 * Return Value:
 * what was decided <STRING>
 *
 * Example:
 * [group bob] call lambs_danger_fnc_commanderGroup;
 *
 * Public: No
*/
#define HOME_SLACK 60
#define PURSUE_STEP 30
#define PURSUE_MAX 400
#define FLANK_STRESS 0.55
#define CAUTIOUS_MORALE 0.5
#define BROKEN_MORALE 0.35
#define OVERWATCH_RANGE 150
#define WITHDRAW_REST 300
#define DEFEND_BUILDING_RANGE 50
#define DEFEND_HIDE_RANGE 150
#define MANEUVER_DISTANCE 150
#define MANEUVER_SIZE 5

params [["_group", grpNull, [grpNull]]];

if (isNull _group || {!local _group}) exitWith {"gone"};
private _leader = leader _group;
if (isPlayer _leader || {!(_leader call EFUNC(main,isAlive))}) exitWith {"no leader"};

// somebody else is in charge ~ a Zeus move, a waypoint task, or a running tactic
if (_group call EFUNC(main,isDirected)) exitWith {"directed"};
if (_group getVariable [QGVAR(disableGroupAI), false]) exitWith {"group AI off"};
if (!isNil {_group getVariable QEGVAR(wp,taskSnapshot)}) exitWith {"task"};
if (_group getVariable [QGVAR(isExecutingTactic), false]) exitWith {"busy"};
if (!(_leader checkAIFeature "PATH") || {!(_leader checkAIFeature "MOVE")}) exitWith {"cannot move"};

private _picture = [_group] call FUNC(pictureGet);
private _intent = [_group] call FUNC(intentGet);
_intent params ["_mode", "_objective", "_radius", "_posture", "", "_home"];
private _level = [_group, _picture] call FUNC(commanderEscalation);

// the small things first ~ a new leader, a driver, shells, strays, ammunition
private _contingency = [_group, _level] call FUNC(commanderContingency);
if (_contingency in ["displace", "joined", "bail out"]) exitWith {
    if (EGVAR(main,debug_functions)) then {["%1 COMMANDER %2: %3", side _group, groupId _group, _contingency] call EFUNC(main,debugLog);};
    _contingency
};
_leader = leader _group;
private _role = _group getVariable [QGVAR(role), ""];
private _threatPos = _picture get "threatPos";
private _decision = "";

private _fnc_run = {
    params ["_name", "_tactic", "_pos", "_maxDuration"];
    [_group, _name, _pos, _maxDuration] call FUNC(tacticsMonitor);
    [_group, _pos] call _tactic;
    _decision = _name;
};

switch (true) do {

    // routine ~ groups with ground to hold go back to it; everyone else stays where the fight left them
    case (_level < 1): {
        private _anchor = [[], _objective] select (_mode in ["hold", "defend"] && {_objective isNotEqualTo []});
        if (
            _anchor isNotEqualTo []
            && {_leader distance2D _anchor > _radius}
            && {count waypoints _group <= 1}
            && {unitReady _leader || {((expectedDestination _leader) select 1) isEqualTo "DoNotPlan"}}
        ) then {
            _group setBehaviour "AWARE";
            _group setSpeedMode "NORMAL";
            _group enableAttack true;
            {_x setUnitPos "AUTO"; _x doFollow _leader;} forEach (units _group);
            _group move _anchor;
            _decision = "returning";
        };
    };

    // alert ~ face it, get low, aggressive groups go and look
    case (_level isEqualTo 1): {
        if (_threatPos isNotEqualTo []) then {
            _group setFormDir (_leader getDir _threatPos);
            {if ((unitPos _x) isEqualTo "Auto") then {_x setUnitPosWeak "MIDDLE";};} forEach (units _group);
            _decision = "alert";
            if (_posture isEqualTo 2 && {_mode isEqualTo "free"} && {_leader distance2D _threatPos > OVERWATCH_RANGE} && {unitReady _leader}) then {
                private _overwatch = [_threatPos, OVERWATCH_RANGE, 60, 5, getPosATL _leader] call EFUNC(main,findOverwatch);
                if (_overwatch isNotEqualTo []) then {
                    _group setBehaviour "AWARE";
                    _group move _overwatch;
                    _decision = "moving to overwatch";
                };
            };
        };
    };

    // engaged or decisive ~ real soldiers
    default {
        if (_threatPos isEqualTo []) exitWith {_decision = "no threat position";};
        private _distance = _leader distance2D _threatPos;
        private _morale = [_group] call FUNC(getMorale);
        private _restedFromWithdraw = time - (_picture get "withdrawTime") > WITHDRAW_REST;

        // broken ~ break contact and ask for help
        if (_morale < BROKEN_MORALE && {_restedFromWithdraw} && {_posture < 2 || {_level isEqualTo 3}}) exitWith {
            _group setVariable [QGVAR(reinforceRequest), [time, _threatPos]];
            ["withdraw", {_this call FUNC(tacticsWithdraw)}, _threatPos, 90] call _fnc_run;
        };

        // defenders stay on their ground and counterattack only inside it ~ and they fight from cover, not the open
        private _defending = _mode in ["hold", "defend"] && {_objective isNotEqualTo []};
        private _insideArea = _defending && {_threatPos distance2D _objective < _radius};
        if (_defending && {!_insideArea || {_mode isEqualTo "hold"}}) exitWith {
            private _exposed = !(_leader call EFUNC(main,isIndoor)) && {(nearestTerrainObjects [_leader, ["BUSH", "TREE", "HOUSE", "HIDE", "WALL", "ROCK"], 4, false, true]) isEqualTo []};
            private _buildings = if (_exposed) then {[_leader, DEFEND_BUILDING_RANGE, true, true] call EFUNC(main,findBuildings)} else {[]};
            switch (true) do {
                case (_buildings isNotEqualTo [] && {(_picture get "lastTactic") isNotEqualTo "garrison" || {(_picture get "lastResult") isNotEqualTo "failed"}}): {
                    ["garrison", {_this call FUNC(tacticsGarrison)}, _threatPos, 180] call _fnc_run;
                };
                case (_exposed && {_distance > DEFEND_HIDE_RANGE}): {
                    ["hide", {_this call FUNC(tacticsHide)}, _threatPos, 120] call _fnc_run;
                };
                default {
                    ["suppress", {_this call FUNC(tacticsSuppress)}, _threatPos, 45] call _fnc_run;
                };
            };
        };

        // cautious posture ~ fire from where it stands, never closes
        if (_posture isEqualTo 0) exitWith {
            if (_morale < CAUTIOUS_MORALE && {_restedFromWithdraw}) then {
                ["withdraw", {_this call FUNC(tacticsWithdraw)}, _threatPos, 90] call _fnc_run;
            } else {
                ["suppress", {_this call FUNC(tacticsSuppress)}, _threatPos, 45] call _fnc_run;
            };
        };

        // platoon role from the side board
        if (_role isEqualTo "support") exitWith {
            ["suppress", {_this call FUNC(tacticsSuppress)}, _threatPos, 60] call _fnc_run;
        };

        // pinned with a base of fire behind us ~ go round
        private _stress = 0;
        {_stress = _stress + (_x call EFUNC(main,getStress));} forEach (units _group);
        _stress = _stress / ((count units _group) max 1);
        if (_stress > FLANK_STRESS && {_role isEqualTo "assault"} && {_distance > GVAR(cqbRange)}) exitWith {
            ["flank", {_this call FUNC(tacticsFlank)}, _threatPos, 120] call _fnc_run;
        };

        // pursue ~ the enemy is pulling back, keep the pressure on (not beyond the leash)
        private _prevThreat = _picture getOrDefault ["pursuePos", []];
        _picture set ["pursuePos", _threatPos];
        private _leash = [_home, _objective] select _defending;
        if (
            _prevThreat isNotEqualTo []
            && {_posture > 0}
            && {_threatPos distance2D _prevThreat > PURSUE_STEP}
            && {_leader distance2D _prevThreat < _threatPos distance2D _prevThreat}
            && {_leash isEqualTo [] || {_threatPos distance2D _leash < ([PURSUE_MAX, _radius] select _defending)}}
        ) exitWith {
            ["bound", {_this call FUNC(tacticsBound)}, _threatPos, 150] call _fnc_run;
            _decision = "pursue";
        };

        // close with the enemy ~ a squad plans a deliberate attack, a fire team bounds, everyone rushes inside CQB range
        switch (true) do {
            case (_distance > MANEUVER_DISTANCE && {count (units _group) >= MANEUVER_SIZE}): {
                [_group, _threatPos] call FUNC(tacticsManeuver);
                _decision = "maneuver";
            };
            case (_distance > GVAR(cqbRange)): {
                ["bound", {_this call FUNC(tacticsBound)}, _threatPos, 150] call _fnc_run;
            };
            default {
                ["assault", {_this call FUNC(tacticsAssault)}, _threatPos, 85] call _fnc_run;
            };
        };
    };
};

// contact just ended ~ consolidate: face the last threat, stand down, count heads
if ((_picture getOrDefault ["escalationPrev", 0]) >= 2 && {_level < 2} && {time - (_picture getOrDefault ["escalationTime", 0]) < 8}) then {
    _picture set ["escalationPrev", 0];
    if (_threatPos isNotEqualTo []) then {_group setFormDir (_leader getDir _threatPos);};
    _group setFormation "WEDGE";
    _group setSpeedMode "NORMAL";
    _group enableAttack true;
    {
        _x setUnitPos "AUTO";
        _x forceSpeed -1;
        _x setVariable [QGVAR(forceMove), nil];
        _x doFollow _leader;
    } forEach (units _group);
    [_leader, "combat", "KeepFocused", 100] call EFUNC(main,doCallout);
    if ((_picture get "losses") > 0) then {
        [{_this call EFUNC(main,doCallout)}, [_leader, "combat", "mandown", 100], 3 + random 3] call CBA_fnc_waitAndExecute;
    };
    _decision = "consolidate";
};

// debug
if (EGVAR(main,debug_functions) && {_decision isNotEqualTo ""}) then {
    ["%1 COMMANDER %2: %3 (level %4, %5, role %6, morale %7)", side _group, groupId _group, _decision, _level, _mode, ["-", _role] select (_role isNotEqualTo ""), ([_group] call FUNC(getMorale)) toFixed 2] call EFUNC(main,debugLog);
};

_decision
