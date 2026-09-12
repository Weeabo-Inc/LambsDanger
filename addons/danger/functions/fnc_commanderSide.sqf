#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The side board: the platoon level of the AI commander for one side on this machine.
 * Clusters the threats the engaged groups know about, hands out roles per cluster
 * (a capped number of assault groups, the rest support by fire) so a player squad
 * is manoeuvred against instead of swarmed, and sends idle groups to help groups
 * that asked for it. Runs every ten seconds from commanderInit.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * threat clusters <ARRAY>
 *
 * Example:
 * [east] call lambs_danger_fnc_commanderSide;
 *
 * Public: No
*/
#define CLUSTER_RANGE 150
#define ROLE_STICKY 60
#define REQUEST_AGE 60
#define REINFORCE_COOLDOWN 300

params [["_side", sideUnknown, [sideUnknown]]];

private _groups = GVAR(commanderGroups) select {!isNull _x && {local _x} && {(side _x) isEqualTo _side}};

// engaged groups and what they see
private _engaged = [];
{
    private _picture = [_x] call FUNC(pictureGet);
    if ((_picture getOrDefault ["escalation", 0]) >= 2 && {(_picture get "threatPos") isNotEqualTo []}) then {
        _engaged pushBack [_x, _picture get "threatPos"];
    };
} forEach _groups;

// cluster threats
private _clusters = [];
{
    _x params ["_group", "_threatPos"];
    private _index = _clusters findIf {(_x select 0) distance2D _threatPos < CLUSTER_RANGE};
    if (_index isEqualTo -1) then {
        _clusters pushBack [_threatPos, [_group]];
    } else {
        ((_clusters select _index) select 1) pushBack _group;
    };
} forEach _engaged;

// roles ~ machine guns and vehicles hold the base of fire, the rest close, never more than the cap
{
    _x params ["_threatPos", "_members"];
    if (count _members < 2) then {
        {_x setVariable [QGVAR(role), nil];} forEach _members;
    } else {
        private _assault = [];
        private _support = [];
        private _open = [];
        {
            private _role = _x getVariable [QGVAR(role), ""];
            if (_role isNotEqualTo "" && {time - (_x getVariable [QGVAR(roleTime), -1e9]) < ROLE_STICKY}) then {
                [_support, _assault] select (_role isEqualTo "assault") pushBack _x;
            } else {
                _open pushBack _x;
            };
        } forEach _members;

        // nearest infantry-heavy groups close, gun-heavy groups support
        private _scored = [];
        {
            private _units = units _x;
            private _guns = {_x call EFUNC(main,isSupportGunner)} count _units;
            private _vehicles = {!isNull objectParent _x} count _units;
            _scored pushBack [(_guns + _vehicles) / ((count _units) max 1), (leader _x) distance2D _threatPos, _forEachIndex];
        } forEach _open;
        _scored sort true;
        {
            private _group = _open select (_x select 2);
            if (count _assault < GVAR(commanderMaxAssault)) then {_assault pushBack _group;} else {_support pushBack _group;};
        } forEach _scored;
        if (_assault isEqualTo [] && {_support isNotEqualTo []}) then {_assault pushBack (_support deleteAt 0);};

        {_x setVariable [QGVAR(role), "assault"]; _x setVariable [QGVAR(roleTime), time];} forEach _assault;
        {_x setVariable [QGVAR(role), "support"]; _x setVariable [QGVAR(roleTime), time];} forEach _support;
    };
} forEach _clusters;

// groups in no cluster lose their role
{
    if ((_engaged findIf {(_x select 0) isEqualTo _x}) isEqualTo -1) then {_x setVariable [QGVAR(role), nil];};
} forEach _groups;

// reinforcements ~ the nearest idle group that is free to leave goes to help; the Director owns this when present
if (GVAR(commanderReinforceRange) > 0 && {!(missionNamespace getVariable [QHGVAR(director,enabled), false])}) then {
    private _requests = _groups select {
        private _request = _x getVariable [QGVAR(reinforceRequest), []];
        _request isNotEqualTo [] && {time - (_request select 0) < REQUEST_AGE}
    };
    if (_requests isNotEqualTo []) then {
        private _helpers = allGroups select {
            (side _x) isEqualTo _side
            && {local _x}
            && {!(_x in _requests)}
            && {!isPlayer (leader _x)}
            && {(leader _x) call EFUNC(main,isAlive)}
            && {(([_x] call FUNC(pictureGet)) getOrDefault ["escalation", 0]) < 2}
            && {(([_x] call FUNC(intentGet)) select 0) isEqualTo "free"}
            && {!(_x call EFUNC(main,isDirected))}
            && {!(_x getVariable [QGVAR(disableGroupAI), false])}
            && {isNil {_x getVariable QEGVAR(wp,taskSnapshot)}}
            && {(_x getVariable [QGVAR(enableGroupReinforceTime), -1]) < time}
        };
        {
            private _requester = _x;
            (_requester getVariable QGVAR(reinforceRequest)) params ["", "_threatPos"];
            _requester setVariable [QGVAR(reinforceRequest), nil];
            private _candidates = _helpers select {(leader _x) distance2D (leader _requester) < GVAR(commanderReinforceRange)};
            if (_candidates isNotEqualTo []) then {
                _candidates = [_candidates, [], {(leader _x) distance2D (leader _requester)}, "ASCEND"] call BIS_fnc_sortBy;
                private _helper = _candidates select 0;
                _helpers = _helpers - [_helper];
                _helper setVariable [QGVAR(enableGroupReinforceTime), time + REINFORCE_COOLDOWN];
                _helper setVariable [QGVAR(alertTime), time];
                [_helper] call FUNC(commanderRegister);
                [leader _helper, _threatPos] call FUNC(tacticsReinforce);
                if (EGVAR(main,debug_functions)) then {
                    ["%1 COMMANDER %2 reinforces %3 (%4m)", _side, groupId _helper, groupId _requester, round ((leader _helper) distance2D (leader _requester))] call EFUNC(main,debugLog);
                };
            };
        } forEach _requests;
    };
};

// debug
if (EGVAR(main,debug_functions) && {_clusters isNotEqualTo []}) then {
    {
        ["%1 SIDE BOARD cluster @ %2: %3 groups (%4)", _side, mapGridPosition (_x select 0), count (_x select 1), (_x select 1) apply {format ["%1:%2", groupId _x, _x getVariable [QGVAR(role), "-"]]}] call EFUNC(main,debugLog);
    } forEach _clusters;
};

_clusters
