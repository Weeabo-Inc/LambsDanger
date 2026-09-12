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
#define GROUP_FEAR 0.7
#define OVERWATCH_RANGE 150
#define WITHDRAW_REST 300
#define DEFEND_BUILDING_RANGE 50
#define DEFEND_HIDE_RANGE 150
#define AMBUSH_RANGE 150
#define FALLBACK_LOSSES 0.34
#define MANEUVER_DISTANCE 150
#define MANEUVER_SIZE 5
#define BOUND_MAX_DISTANCE 400
#define BOUND_MIN_SIZE 3
#define TACTIC_COOLDOWN 20

params [["_group", grpNull, [grpNull]]];

if (isNull _group || {!local _group}) exitWith {"gone"};
private _leader = leader _group;
if (isPlayer _leader || {!(_leader call EFUNC(main,isAlive))}) exitWith {"no leader"};

// the men's own eyes feed the picture every think, and what is fresh goes out over the net
private _picture = [_group] call HFUNC(core,contactSweep);
[_group] call HFUNC(core,netSend);

// the level is kept current even while somebody else runs the group ~ the side board reads it
private _intent = [_group] call FUNC(intentGet);
_intent params ["_mode", "_objective", "_radius", "_posture", "", "_home"];
private _level = [_group, _picture] call FUNC(commanderEscalation);

// somebody else is in charge ~ a Zeus move, a waypoint task, or a running tactic
if (_group call EFUNC(main,isDirected)) exitWith {"directed"};
if (_group getVariable [QGVAR(disableGroupAI), false]) exitWith {"group AI off"};
if (!isNil {_group getVariable QEGVAR(wp,taskSnapshot)}) exitWith {"task"};
if (_group getVariable [QGVAR(isExecutingTactic), false]) exitWith {"busy"};
if (!(_leader checkAIFeature "PATH") || {!(_leader checkAIFeature "MOVE")}) exitWith {"cannot move"};

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
    // the same tactic that just ended on the same ground is not run again straight away ~ that is the loop
    // that shoves a squad about on a position it already holds
    if (
        (_picture get "lastTactic") isEqualTo _name
        && {time - (_picture getOrDefault ["lastTacticTime", -1e9]) < TACTIC_COOLDOWN}
        && {(_picture get "lastResult") in ["completed", "failed"]}
    ) exitWith {_decision = format ["%1 (cooldown)", _name];};
    [_group, _name, _pos, _maxDuration] call FUNC(tacticsMonitor);
    [_group, _pos] call _tactic;
    _decision = _name;
};
private _onFoot = (units _group) select {isNull objectParent _x && {_x call EFUNC(main,isAlive)} && {!isPlayer _x}};

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

        // broken ~ break contact and ask for help; a squad where most men feel they are about to die is broken too
        private _fear = 0;
        {_fear = _fear + (([_x, true] call EFUNC(main,getThreat)) select 1);} forEach (units _group);
        _fear = _fear / ((count units _group) max 1);
        if ((_morale < BROKEN_MORALE || {_fear > GROUP_FEAR && {(_picture get "losses") > 0}}) && {_restedFromWithdraw} && {_posture < 2 || {_level isEqualTo 3}}) exitWith {
            _group setVariable [QGVAR(reinforceRequest), [time, _threatPos]];
            ["withdraw", {_this call FUNC(tacticsWithdraw)}, _threatPos, 90] call _fnc_run;
        };

        // defenders stay on their ground and counterattack only inside it ~ and they fight from cover, not the open
        private _defending = _mode in ["hold", "defend"] && {_objective isNotEqualTo []};
        private _insideArea = _defending && {_threatPos distance2D _objective < _radius};
        if (_defending && {!_insideArea || {_mode isEqualTo "hold"}}) exitWith {
            // a position that has cost a third of the squad is given up for the next line back, by bounds under
            // smoke, and that line becomes the ground to hold ~ trading ground beats dying on it
            private _lossRatio = (_picture get "losses") / ((_picture get "maxCount") max 1);
            if (_mode isEqualTo "defend" && {_lossRatio >= FALLBACK_LOSSES} && {_restedFromWithdraw} && {_posture < 2}) exitWith {
                _picture set ["fallingBack", true];
                ["withdraw", {_this call FUNC(tacticsWithdraw)}, _threatPos, 90] call _fnc_run;
                _decision = "fall back to the next line";
            };
            private _exposed = !(_leader call EFUNC(main,isIndoor)) && {(nearestTerrainObjects [_leader, ["BUSH", "TREE", "HOUSE", "HIDE", "WALL", "ROCK"], 4, false, true]) isEqualTo []};
            private _buildings = if (_exposed) then {[_leader, DEFEND_BUILDING_RANGE, true, true] call EFUNC(main,findBuildings)} else {[]};

            // fire discipline ~ a defence that opens up at 400 m gives itself away for nothing. Weapons stay quiet
            // until the enemy is inside the kill range or has started shooting at us, then everyone opens at once.
            private _sprung = _picture getOrDefault ["ambushSprung", false];
            private _underFire = (_leader call EFUNC(main,getStress)) > 0.25 || {(units _group) findIf {time - (_x getVariable [QEGVAR(main,lastHit), -1e9]) < 10} != -1};
            if (!_sprung && {_posture < 2} && {_distance > AMBUSH_RANGE} && {!_underFire}) then {
                if ((combatMode _group) isNotEqualTo "GREEN") then {
                    _group setCombatMode "GREEN";
                    {
                        // men the machine holds in position are already low and looking the right way
                        if (([_x, "state", "Idle"] call FUNC(unitState)) isEqualTo "Idle") then {_x setUnitPos (_x call EFUNC(main,getLowStance)); _x doWatch _threatPos;};
                    } forEach (units _group);
                    [_leader, "combat", "StayAlert", 60] call EFUNC(main,doCallout);
                    if (EGVAR(main,debug_functions)) then {["%1 COMMANDER %2: holding fire, enemy at %3m", side _group, groupId _group, round _distance] call EFUNC(main,debugLog);};
                };
                // in cover while waiting
                if (_buildings isNotEqualTo [] && {(_picture get "lastTactic") isNotEqualTo "garrison"}) then {
                    ["garrison", {_this call FUNC(tacticsGarrison)}, _threatPos, 180] call _fnc_run;
                };
                _decision = "holding fire";
            } else {
                if (!_sprung) then {
                    _picture set ["ambushSprung", true];
                    _group setCombatMode "RED";
                    _group enableAttack false;
                    {_x doTarget objNull; _x doWatch _threatPos;} forEach (units _group);
                    [_leader, "combat", "suppress", 125] call EFUNC(main,doCallout);
                    if (EGVAR(main,debug_functions)) then {["%1 COMMANDER %2: open fire, enemy at %3m", side _group, groupId _group, round _distance] call EFUNC(main,debugLog);};
                };
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

        // close with the enemy ~ a squad plans a deliberate attack, a fire team bounds, everyone rushes inside CQB range;
        // one or two men, or an enemy far beyond rifle range, fight from where they are instead
        switch (true) do {
            case (_distance > BOUND_MAX_DISTANCE || {count _onFoot < BOUND_MIN_SIZE}): {
                ["suppress", {_this call FUNC(tacticsSuppress)}, _threatPos, 45] call _fnc_run;
            };
            case (_distance > MANEUVER_DISTANCE && {count _onFoot >= MANEUVER_SIZE}): {
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

// a defence that fell back holds the new line, it does not walk back into the old position
if (_picture getOrDefault ["fallingBack", false] && {!(_group getVariable [QGVAR(isExecutingTactic), false])}) then {
    _picture set ["fallingBack", false];
    if (_mode isEqualTo "defend") then {
        [_group, "defend", getPosATL _leader, _radius] call FUNC(intentSet);
        if (EGVAR(main,debug_functions)) then {["%1 COMMANDER %2: new line %3m from the old position", side _group, groupId _group, round (_leader distance2D _objective)] call EFUNC(main,debugLog);};
    };
};

// contact just ended ~ consolidate: face the last threat, stand down, count heads
if ((_picture getOrDefault ["escalationPrev", 0]) >= 2 && {_level < 2} && {time - (_picture getOrDefault ["escalationTime", 0]) < 8}) then {
    _picture set ["escalationPrev", 0];
    // the next ambush is held again
    _picture set ["ambushSprung", false];
    if ((combatMode _group) isEqualTo "GREEN") then {_group setCombatMode "RED";};
    if (_threatPos isNotEqualTo []) then {_group setFormDir (_leader getDir _threatPos);};
    _group setFormation "WEDGE";
    _group setSpeedMode "NORMAL";
    _group enableAttack true;
    {
        [_x, true] call FUNC(unitRelease);
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
