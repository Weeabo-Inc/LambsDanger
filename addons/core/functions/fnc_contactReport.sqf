#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Files one piece of evidence about an enemy in a group's picture. Evidence about an
 * object the group already tracks updates that record; objectless evidence (a report, a
 * sound) merges with an objectless record of the same type nearby; anything else becomes
 * a new record. Better evidence (a sighting over a report, a smaller error, or anything
 * newer than 30 s) replaces the position; weaker evidence only refreshes the time and
 * confidence. Direct evidence stamps lastContact, reports stamp lastReport.
 *
 * Nothing here reads the engine's knowledge; the caller supplies what it honestly has
 * (FAIRNESS.md R1, R4).
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Enemy object for direct evidence, objNull for a report or a sound <OBJECT>
 * 2: Believed position ATL <ARRAY>
 * 3: Source: "seen", "shotAt", "heard", "reported", "suspected", default "seen" <STRING>
 * 4: Error radius in metres, default 25 <NUMBER>
 * 5: Confidence 0..1, default 1 <NUMBER>
 * 6: Estimated strength, default 1 <NUMBER>
 * 7: Type, default derived from the object <STRING>
 * 8: Heading, default -1 <NUMBER>
 * 9: Activity, default "unknown" <STRING>
 * 10: Engine knowsAbout at this evidence, default 0 <NUMBER>
 * 11: Referenced object of a report, default objNull <OBJECT>
 * 12: Report chain length, default 0 <NUMBER>
 *
 * Return Value:
 * the contact record, [] when nothing was filed <ARRAY>
 *
 * Example:
 * [group bob, objNull, [1200, 3400, 0], "reported", 80, 0.6, 4, "infantry"] call hostis_core_fnc_contactReport;
 *
 * Public: Yes
*/
#define STALE_POSITION 30

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_object", objNull, [objNull]],
    ["_pos", [], [[]]],
    ["_source", "seen", [""]],
    ["_error", 25, [0]],
    ["_confidence", 1, [0]],
    ["_strength", 1, [0]],
    ["_type", "", [""]],
    ["_heading", -1, [0]],
    ["_activity", "unknown", [""]],
    ["_knowsAbout", 0, [0]],
    ["_ref", objNull, [objNull]],
    ["_chain", 0, [0]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {count _pos < 2} || {_pos isEqualTo [0, 0, 0]}) exitWith {[]};
if (!(_source in CONTACT_SOURCES)) then {_source = "suspected";};
_pos = +_pos;
_pos resize 3;
_error = (_error max 1) min GVAR(errorCap);
_confidence = (_confidence max 0) min 1;
if (_type isEqualTo "") then {_type = [[_object, _ref] select (isNull _object)] call FUNC(contactType);};

private _picture = [_group] call FUNC(pictureGet);
private _contacts = _picture get "contacts";
private _now = time;
private _direct = _source in DIRECT_SOURCES;

// which record is this about
private _index = -1;
if (!isNull _object) then {
    _index = _contacts findIf {(_x select CONTACT_OBJECT) isEqualTo _object || {(_x select CONTACT_REF) isEqualTo _object}};
};
if (_index isEqualTo -1 && {!isNull _ref}) then {
    _index = _contacts findIf {(_x select CONTACT_OBJECT) isEqualTo _ref || {(_x select CONTACT_REF) isEqualTo _ref}};
};
if (_index isEqualTo -1) then {
    private _merge = GVAR(mergeRadius) max _error;
    _index = _contacts findIf {
        isNull (_x select CONTACT_OBJECT)
        && {!(_x select CONTACT_DEAD)}
        && {(_x select CONTACT_TYPE) isEqualTo _type}
        && {(_x select CONTACT_POS) distance2D _pos < (_merge max (_x select CONTACT_ERROR))}
    };
};

private _record = [];
if (_index isEqualTo -1) then {
    _record = [_object, _pos, _now, _knowsAbout, _error, _confidence, _source, _now, _strength, _type, _heading, _activity, false, _ref, _chain];
    _contacts pushBack _record;
} else {
    _record = _contacts select _index;
    private _oldTime = _record select CONTACT_TIME;
    private _oldPos = _record select CONTACT_POS;
    private _better = (SOURCE_RANK(_source)) >= (SOURCE_RANK(_record select CONTACT_SOURCE))
        || {_error <= (_record select CONTACT_ERROR)}
        || {_now - _oldTime > STALE_POSITION};
    if (_better) then {
        // a direct sighting of a tracked contact tells us whether he moves
        if (_direct && {(_record select CONTACT_SOURCE) in DIRECT_SOURCES} && {_now - _oldTime < STALE_POSITION}) then {
            if (_oldPos distance2D _pos > 3) then {
                _heading = _oldPos getDir _pos;
                if (_activity isEqualTo "unknown") then {_activity = "moving";};
            } else {
                if (_activity isEqualTo "unknown") then {_activity = "static";};
            };
        };
        _record set [CONTACT_POS, _pos];
        _record set [CONTACT_ERROR, _error];
        _record set [CONTACT_SOURCE, _source];
        if (_heading >= 0) then {_record set [CONTACT_HEADING, _heading];};
        if (_activity isNotEqualTo "unknown") then {_record set [CONTACT_ACTIVITY, _activity];};
    };
    _record set [CONTACT_TIME, _now];
    _record set [CONTACT_CONF, _confidence max (CONTACT_CONFIDENCE(_record))];
    if (_direct) then {
        _record set [CONTACT_KNOWS, _knowsAbout];
        _record set [CONTACT_DEAD, false];
    };
    if (!isNull _object) then {_record set [CONTACT_OBJECT, _object];};
    if (!isNull _ref && {isNull (_record select CONTACT_REF)}) then {_record set [CONTACT_REF, _ref];};
    _record set [CONTACT_STRENGTH, (_record select CONTACT_STRENGTH) max _strength];
    _record set [CONTACT_CHAIN, (_record select CONTACT_CHAIN) min _chain];
};

// the weakest objectless records make room
if (count _contacts > GVAR(storeCap)) then {
    private _scored = [];
    {
        if (isNull (_x select CONTACT_OBJECT) || {_x select CONTACT_DEAD}) then {
            _scored pushBack [CONTACT_CONFIDENCE(_x), _forEachIndex];
        };
    } forEach _contacts;
    _scored sort true;
    private _drop = (count _contacts) - GVAR(storeCap);
    private _indices = (_scored select [0, _drop]) apply {_x select 1};
    _indices sort false;
    {_contacts deleteAt _x;} forEach _indices;
};

if (_direct) then {_picture set ["lastContact", _now];} else {_picture set ["lastReport", _now];};
_picture set ["contacts", _contacts];
[_group] call FUNC(pictureRefresh);

_record
