#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Reports a group's fresh contacts to friendly groups over the modelled net. Each report
 * is delayed by the sender's net parameters and the distance, may be lost, carries the
 * sender's positions with a wider error, strips the enemy objects (a receiver gets an
 * area, never a target) and arrives on the receiving group's owner as a CBA target event.
 * Rate limited per group unless forced.
 *
 * Arguments:
 * 0: Sending group, or a unit of it <GROUP> or <OBJECT>
 * 1: Records to send, [] for the group's fresh contacts <ARRAY>
 * 2: Range override in metres, -1 for the net's own range <NUMBER>
 * 3: Ignore the rate limit, default false <BOOL>
 *
 * Return Value:
 * the groups the report was sent to <ARRAY of GROUP>
 *
 * Example:
 * [group bob] call hostis_core_fnc_netSend;
 *
 * Public: Yes
*/
#define FRESH_AGE 20
#define FRESH_CONFIDENCE 0.4
#define MAX_CHAIN 2
#define SHOUT_ERROR 60
#define RADIO_ERROR 30
#define DISTANCE_ERROR 0.02
#define FRIEND 0.6

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_records", [], [[]]],
    ["_rangeOverride", -1, [0]],
    ["_force", false, [false]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group || {!local _group}) exitWith {[]};
private _picture = [_group] call FUNC(pictureGet);
if (!_force && {time - (_picture get "lastReportOut") < GVAR(reportInterval)}) exitWith {[]};

if (_records isEqualTo []) then {
    _records = ([_group, FRESH_AGE, FRESH_CONFIDENCE] call FUNC(contactsGet)) select {(_x select CONTACT_CHAIN) < MAX_CHAIN};
};
if (_records isEqualTo []) exitWith {[]};

private _net = [_group] call FUNC(netParams);
private _sender = _net get "sender";
if (isNull _sender) exitWith {[]};
private _range = [_net get "range", _rangeOverride] select (_rangeOverride > 0);
private _shout = _net get "shout";
private _side = side _group;

private _recipients = allGroups select {
    _x isNotEqualTo _group
    && {!isNull leader _x}
    && {((side _x) getFriend _side) > FRIEND}
    && {(leader _x) distance2D _sender < _range}
    && {!isPlayer leader _x}
    && {simulationEnabled (vehicle leader _x)}
    && {(behaviour leader _x) isNotEqualTo "CARELESS"}
};
_picture set ["lastReportOut", time];
if (_recipients isEqualTo []) exitWith {[]};

// what leaves the group: positions and errors, no targets
private _quality = _net get "quality";
private _payload = _records apply {
    private _r = +_x;
    _r set [CONTACT_REF, [_x select CONTACT_OBJECT, _x select CONTACT_REF] select (isNull (_x select CONTACT_OBJECT))];
    _r set [CONTACT_OBJECT, objNull];
    _r set [CONTACT_SOURCE, "reported"];
    _r set [CONTACT_KNOWS, 0];
    _r set [CONTACT_CHAIN, (_x select CONTACT_CHAIN) + 1];
    _r set [CONTACT_CONF, (_x select CONTACT_CONF) * _quality];
    _r
};

private _delayBase = _net get "delay";
private _loss = _net get "loss";
private _sent = [];
{
    private _receiver = _x;
    private _distance = _sender distance2D (leader _receiver);
    private _delay = _delayBase + (_distance / (GVAR(reportSpeed) max 1));
    private _errorAdd = ([SHOUT_ERROR, RADIO_ERROR] select (_net get "radio")) + (_distance * DISTANCE_ERROR);
    if (random 1 >= _loss) then {
        [{
            params ["_receiver", "_payload", "_sender", "_errorAdd"];
            if (isNull _receiver) exitWith {};
            [QGVAR(contactReport), [_receiver, _payload, _sender, _errorAdd], groupOwner _receiver] call CBA_fnc_targetEvent;
        }, [_receiver, _payload, _group, _errorAdd], _delay] call CBA_fnc_waitAndExecute;
        _sent pushBack _receiver;
    };
} forEach _recipients;

if (LGVAR(main,debug_functions)) then {
    ["%1 KNOWLEDGE %2 reports %3 contact(s) to %4 of %5 groups (%6, delay %7 s, loss %8)", side _group, groupId _group, count _payload, count _sent, count _recipients, ["shout", "radio"] select (_net get "radio"), round _delayBase, _loss] call LFUNC(main,debugLog);
};

_sent
