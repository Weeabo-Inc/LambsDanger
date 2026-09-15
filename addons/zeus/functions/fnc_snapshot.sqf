#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Answers a curator's overlay request from the server: for the commander's groups
 * within range of the Zeus camera, nearest first and at most forty, one row of what
 * the overlay labels show. Objects and positions only, so the reply serialises.
 *
 * Arguments:
 * 0: Curator client <NUMBER>
 * 1: Camera position <ARRAY>
 * 2: Range in metres <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [clientOwner, getPos player, 1500] call hostis_zeus_fnc_snapshot;
 *
 * Public: No
*/
#define MAX_ROWS 40
#define CONTACT_AGE 120

params [["_client", -1, [0]], ["_pos", [], [[]]], ["_range", 1500, [0]]];

if (!isServer || {_client < 0} || {_pos isEqualTo []}) exitWith {};

private _groups = (missionNamespace getVariable [QLGVAR(danger,commanderGroups), []]) select {
    !isNull _x && {!isNull (leader _x)} && {(leader _x) distance2D _pos < _range}
};
_groups = [_groups, [], {(leader _x) distance2D _pos}, "ASCEND"] call BIS_fnc_sortBy;
if (count _groups > MAX_ROWS) then {_groups resize MAX_ROWS;};

private _rows = _groups apply {
    private _picture = [_x] call EFUNC(core,pictureGet);
    private _intent = [_x] call LFUNC(danger,intentGet);
    private _tactic = [_x] call EFUNC(squad,tacticRunning);
    private _tacticText = if (isNil "_tactic") then {"-"} else {format ["%1 %2 s", _tactic get "name", round (time - (_tactic get "since"))]};
    [
        leader _x,
        groupId _x,
        _intent select 0,
        _picture getOrDefault ["escalation", 0],
        _picture getOrDefault ["cohesion", "steady"],
        _tacticText,
        count ([_x, CONTACT_AGE] call EFUNC(core,contactsGet)),
        _picture getOrDefault ["threatPos", []],
        {alive _x} count (units _x)
    ]
};

[QGVAR(snapshot), _rows, _client] call CBA_fnc_targetEvent;
