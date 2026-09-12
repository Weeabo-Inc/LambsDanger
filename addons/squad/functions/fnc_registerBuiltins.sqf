#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Registers the built-in tactics (docs/systems/tactics.md): wrappers over the upstream
 * implementations that give them the squad lifecycle, and the new ones. Each upstream
 * call is made with a very long delay so its own timer reset never fires; the lifecycle
 * ends it.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call hostis_squad_fnc_registerBuiltins;
 *
 * Public: No
*/
#define NEVER 36000
#define FAR 400
#define BOUND_MAX 600
// the threat centre, or the leader's own position when the picture has none
#define THREAT_OF(ctx) (call {private _p = (ctx) get "threatPos"; if (_p isEqualTo []) then {getPosATL ((ctx) get "leader")} else {_p}})

// break contact: bounds to the rear under covering fire and smoke (upstream tacticsWithdraw)
["withdraw", createHashMapFromArray [
    ["priority", 100], ["planned", true], ["commit", 20], ["maxDuration", 90],
    ["explain", "They broke contact by bounds under covering fire and smoke."],
    ["precondition", {
        params ["_group", "_ctx"];
        (_ctx get "rested") && {!(_ctx get "defending")} && {
            (_ctx get "cohesion") isEqualTo "broken"
            || {(_ctx get "morale") < 0.35}
            || {(_ctx get "posture") isEqualTo 0 && {(_ctx get "morale") < 0.5}}
        }
    }],
    ["start", {
        params ["_group", "_ctx"];
        _group setVariable [QLGVAR(danger,reinforceRequest), [time, _ctx get "threatPos"]];
        [_group, THREAT_OF(_ctx), [], NEVER] call LFUNC(danger,tacticsWithdraw)
    }],
    ["monitor", {
        params ["_group", "_ctx", "_state"];
        ["running", "done"] select ((_ctx get "distance") > 110 && {time - (_state get "since") > 20})
    }]
]] call FUNC(tacticRegister);

// hasty ambush: a moving enemy the group knows about and has not been engaged by (new)
["hastyAmbush", createHashMapFromArray [
    ["priority", 85], ["planned", true], ["commit", 30], ["maxDuration", 240],
    ["explain", "They saw you coming, laid an L along your route and held fire until you were close."],
    ["precondition", {
        params ["_group", "_ctx"];
        private _newest = _ctx get "newest";
        (_ctx get "level") isEqualTo 1
        && {(_ctx get "posture") >= 1}
        && {(_ctx get "count") >= 3}
        && {(_ctx get "incoming") isEqualTo 0}
        && {(_ctx get "confidence") >= 0.4}
        && {(_ctx get "distance") > 80 && {(_ctx get "distance") < FAR}}
        && {_newest isNotEqualTo [] && {(_newest select CONTACT_ACTIVITY) isEqualTo "moving"}}
        && {(_ctx get "cohesion") in ["steady", "rallying"]}
    }],
    ["start", {_this call FUNC(hastyAmbush)}],
    ["monitor", {
        params ["_group", "_ctx", "_state"];
        private _data = _state get "data";
        private _sprung = _data getOrDefault ["sprung", false];
        if (!_sprung) then {
            private _hit = ((units _group) findIf {time - (_x getVariable [QLGVAR(main,lastHit), -1e9]) < 10}) isNotEqualTo -1;
            if ((_ctx get "distance") < GVAR(ambushRange) || {(_ctx get "incoming") > 0} || {_hit}) then {
                _data set ["sprung", true];
                _data set ["sprungAt", time];
                _group setCombatMode "RED";
                _group enableAttack false;
                {_x doTarget objNull; _x doWatch (_ctx get "threatPos");} forEach (units _group);
                [leader _group, "attack", true] call EFUNC(agent,bark);
                if (SQUAD_DEBUG) then {["%1 TACTIC %2: ambush sprung at %3 m", side _group, groupId _group, round (_ctx get "distance")] call LFUNC(main,debugLog);};
            };
            "running"
        } else {
            // ten seconds of the opening volley, then the planner takes it from here
            ["running", "done"] select (time - (_data get "sprungAt") > 10)
        }
    }]
]] call FUNC(tacticRegister);

// suppress and flank: base of fire fixes, manoeuvre element goes round, the bound waits on the volume (new)
["suppressAndFlank", createHashMapFromArray [
    ["priority", 80], ["planned", true], ["commit", 30], ["maxDuration", 300], ["moving", false],
    ["explain", "They put a base of fire on you and sent a team round your flank while you were pinned."],
    ["precondition", {
        params ["_group", "_ctx"];
        (_ctx get "level") >= 2
        && {(_ctx get "posture") >= 1}
        && {(_ctx get "count") >= 4}
        && {(_ctx get "role") isNotEqualTo "support"}
        && {(_ctx get "cohesion") isNotEqualTo "broken"}
        && {(_ctx get "confidence") >= 0.4}
        && {(_ctx get "distance") > (_ctx get "cqbRange") && {(_ctx get "distance") <= FAR}}
        && {(_ctx get "incoming") > 0 || {(_ctx get "lastContactAge") < 30}}
    }],
    ["start", {_this call FUNC(suppressAndFlank)}],
    ["monitor", {_this call FUNC(suppressAndFlankMonitor)}],
    ["reset", {
        params ["_group", "_state", "_result"];
        _group setVariable [QLGVAR(danger,boundToken), nil];
        // the assault the bound handed over keeps its men
        ((_state get "data") getOrDefault ["handedOver", false])
    }]
]] call FUNC(tacticRegister);

// bounding overwatch into contact: small teams, or far enemies for aggressive groups (upstream tacticsBound)
["bound", createHashMapFromArray [
    ["priority", 70], ["planned", true], ["commit", 20], ["maxDuration", 150], ["moving", true],
    ["explain", "They came at you in bounds, one team moving while the other covered."],
    ["precondition", {
        params ["_group", "_ctx"];
        (_ctx get "level") >= 2
        && {(_ctx get "posture") >= 1}
        && {(_ctx get "cohesion") isNotEqualTo "broken"}
        && {(_ctx get "role") isNotEqualTo "support"}
        && {(_ctx get "distance") > (_ctx get "cqbRange") && {(_ctx get "distance") <= BOUND_MAX}}
        && {(_ctx get "count") >= 2}
        && {(_ctx get "count") < 4 || {(_ctx get "posture") isEqualTo 2 && {(_ctx get "distance") > FAR}}}
    }],
    ["start", {
        params ["_group", "_ctx"];
        [_group, THREAT_OF(_ctx), [], NEVER] call LFUNC(danger,tacticsBound)
    }],
    ["reset", {params ["_group"]; _group setVariable [QLGVAR(danger,boundToken), nil]; false}]
]] call FUNC(tacticRegister);

// assault: through the objective inside close range (upstream tacticsAssault)
["assault", createHashMapFromArray [
    ["priority", 60], ["planned", true], ["commit", 15], ["maxDuration", 85], ["moving", true],
    ["explain", "They rushed the position once they were close enough to reach it in one go."],
    ["precondition", {
        params ["_group", "_ctx"];
        (_ctx get "level") >= 2
        && {(_ctx get "posture") >= 1}
        && {(_ctx get "cohesion") isNotEqualTo "broken"}
        && {(_ctx get "distance") <= (_ctx get "cqbRange")}
        && {(_ctx get "count") >= 2}
    }],
    ["start", {
        params ["_group", "_ctx"];
        [_group, THREAT_OF(_ctx), [], NEVER] call LFUNC(danger,tacticsAssault)
    }]
]] call FUNC(tacticRegister);

// suppress: fire from where it stands (upstream tacticsSuppress)
["suppress", createHashMapFromArray [
    ["priority", 50], ["planned", true], ["commit", 15], ["maxDuration", 60],
    ["explain", "They stayed where they were and put fire on your position."],
    ["precondition", {
        params ["_group", "_ctx"];
        (_ctx get "level") >= 2 && {(_ctx get "distance") < 1e8} && {
            (_ctx get "posture") isEqualTo 0
            || {(_ctx get "role") isEqualTo "support"}
            || {(_ctx get "count") < 2}
            || {(_ctx get "distance") > BOUND_MAX}
            || {(_ctx get "cohesion") in ["strained", "broken"]}
        }
    }],
    ["start", {
        params ["_group", "_ctx"];
        [_group, THREAT_OF(_ctx), [], NEVER] call LFUNC(danger,tacticsSuppress)
    }]
]] call FUNC(tacticRegister);

// search: a lost contact is looked for where it could have gone, not where it is (new)
["search", createHashMapFromArray [
    ["priority", 40], ["planned", true], ["commit", 30], ["maxDuration", 180],
    ["explain", "They lost you and swept the ground around where they last saw you, covering the ways out."],
    ["precondition", {
        params ["_group", "_ctx"];
        private _age = _ctx get "pictureAge";
        (_ctx get "level") >= 1
        && {(_ctx get "posture") >= 1}
        && {!(_ctx get "defending")}
        && {(_ctx get "incoming") isEqualTo 0}
        && {(_ctx get "cohesion") in ["steady", "rallying"]}
        && {(_ctx get "count") >= 2}
        && {_age > 30 && {_age < 300}}
        && {(_ctx get "distance") < BOUND_MAX}
    }],
    ["start", {_this call FUNC(search)}],
    ["monitor", {
        params ["_group", "_ctx", "_state"];
        private _seen = [_group, 10, 0, ["seen", "shotAt"]] call EFUNC(core,contactsGet);
        if (_seen isNotEqualTo []) exitWith {"done"};
        private _settled = ((_ctx get "onFoot") findIf {([_x, "state", "Idle"] call LFUNC(danger,unitState)) in ["Moving", "Rushing"]}) isEqualTo -1;
        if (_settled && {time - (_state get "since") > 30}) exitWith {"done"};
        if (time - (_state get "since") > GVAR(searchTime)) exitWith {"done"};
        "running"
    }]
]] call FUNC(tacticRegister);

// the rest of the upstream tactics, startable by name from the commander's defence tree
["garrison", createHashMapFromArray [
    ["priority", 0], ["maxDuration", 180],
    ["explain", "They went into the buildings with a view of you and fought from the windows."],
    ["start", {params ["_group", "_ctx"]; [_group, THREAT_OF(_ctx), [], NEVER] call LFUNC(danger,tacticsGarrison)}]
]] call FUNC(tacticRegister);
["hide", createHashMapFromArray [
    ["priority", 0], ["maxDuration", 120],
    ["explain", "They went to ground and held their fire."],
    ["start", {params ["_group", "_ctx"]; [_group, THREAT_OF(_ctx), false, NEVER] call LFUNC(danger,tacticsHide)}]
]] call FUNC(tacticRegister);
["flank", createHashMapFromArray [
    ["priority", 0], ["maxDuration", 120], ["moving", true],
    ["explain", "They probed round the side of your position."],
    ["start", {params ["_group", "_ctx"]; [_group, THREAT_OF(_ctx), [], [], NEVER] call LFUNC(danger,tacticsFlank)}]
]] call FUNC(tacticRegister);
