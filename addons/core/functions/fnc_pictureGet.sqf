#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns the combat picture of a group, creating it on first use. The picture is the
 * group's own knowledge of the enemy: what its men have sensed and what it has been told,
 * never the engine's truth (docs/systems/knowledge.md).
 *
 *   contacts       array of contact records, see CONTACT_* in script_macros.hpp
 *   threatPos      confidence weighted centre of the live contacts, [] when none
 *   threatDir      bearing from the leader to threatPos, -1 when none
 *   lastContact    time of the last direct evidence (seen, shot at, heard)
 *   lastReport     time of the last report received from another group
 *   pictureAge     seconds since the newest live evidence, 1e9 when none
 *   maxCount       most units the group has had
 *   losses         units lost since the picture was created
 *   morale         last computed morale 0..1 (lambs_danger_fnc_getMorale)
 *   moraleTime     time morale was computed
 *   lastTactic     name of the last tactic that ran
 *   lastResult     "completed", "failed", "timeout", "aborted" or ""
 *   lastTacticTime time the last tactic ended
 *   withdrawTime   time the group last broke contact
 *   swept          time of the last sensor sweep
 *   sweepCursor    which extra man's eyes joined the last sweep
 *   lastReportOut  time the group last reported to others
 *   reports        last few reports received, [time, sender, count]
 *   netQuality     0..1 quality of the group's last outgoing report
 *   leaderUnit     the leader at the last refresh
 *   leaderLostTime time the group lost its leader, -1e9 if never
 *   id             running number for debug markers
 *
 * The variable is still named lambs_danger_picture while upstream readers open it
 * directly; see docs/systems/knowledge.md.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 *
 * Return Value:
 * combat picture <HASHMAP>
 *
 * Example:
 * [group bob] call hostis_core_fnc_pictureGet;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {createHashMap};

private _picture = _group getVariable QLGVAR(danger,picture);
if (isNil "_picture") then {
    GVAR(pictures) pushBackUnique _group;
    _picture = createHashMapFromArray [
        ["contacts", []],
        ["threatPos", []],
        ["threatDir", -1],
        ["lastContact", -1e9],
        ["lastReport", -1e9],
        ["pictureAge", 1e9],
        ["updated", -1e9],
        ["maxCount", count units _group],
        ["losses", 0],
        ["morale", 1],
        ["moraleTime", -1e9],
        ["lastTactic", ""],
        ["lastResult", ""],
        ["lastTacticTime", -1e9],
        ["withdrawTime", -1e9],
        ["swept", -1e9],
        ["sweepCursor", 0],
        ["lastReportOut", -1e9],
        ["reports", []],
        ["netQuality", 1],
        ["leaderUnit", leader _group],
        ["leaderLostTime", -1e9],
        ["id", count GVAR(pictures)]
    ];
    _group setVariable [QLGVAR(danger,picture), _picture];
};

_picture
