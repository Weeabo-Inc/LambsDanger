#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Returns copies of a group's contacts with their confidence and error as they stand right
 * now (decayed and grown since the last evidence), newest first. This is how every layer
 * above 0 reads the picture.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Maximum age in seconds, default the memory setting <NUMBER>
 * 2: Minimum effective confidence, default 0 <NUMBER>
 * 3: Accepted sources, [] for all <ARRAY of STRING>
 * 4: Centre for a radius filter, [] for none <ARRAY>
 * 5: Radius in metres, 0 for none <NUMBER>
 * 6: Include contacts known to be dead, default false <BOOL>
 *
 * Return Value:
 * contact records, see CONTACT_* <ARRAY>
 *
 * Example:
 * [group bob, 60] call hostis_core_fnc_contactsGet;
 * [group bob, 300, 0.3, ["seen", "shotAt"], getPos bob, 400] call hostis_core_fnc_contactsGet;
 *
 * Public: Yes
*/
params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_maxAge", -1, [0]],
    ["_minConfidence", 0, [0]],
    ["_sources", [], [[]]],
    ["_center", [], [[]]],
    ["_radius", 0, [0]],
    ["_includeDead", false, [false]]
];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {[]};
if (_maxAge < 0) then {_maxAge = GVAR(contactMaxAge);};

private _picture = [_group] call FUNC(pictureRefresh);
private _now = time;
private _out = [];
{
    if (
        (_includeDead || {!(_x select CONTACT_DEAD)})
        && {_now - (_x select CONTACT_TIME) < _maxAge}
        && {_sources isEqualTo [] || {(_x select CONTACT_SOURCE) in _sources}}
        && {_radius <= 0 || {_center isEqualTo []} || {(_x select CONTACT_POS) distance2D _center <= _radius}}
    ) then {
        private _confidence = CONTACT_CONFIDENCE(_x);
        if (_confidence >= _minConfidence) then {
            private _record = +_x;
            _record set [CONTACT_CONF, _confidence];
            _record set [CONTACT_ERROR, CONTACT_ERROR_NOW(_x)];
            _out pushBack [-(_x select CONTACT_TIME), _record];
        };
    };
} forEach (_picture get "contacts");

_out sort true;
_out apply {_x select 1}
