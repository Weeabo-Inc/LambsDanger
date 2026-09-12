#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Draws a group's picture as global map markers: one per live contact, coloured by
 * source and faded by confidence, sized by error, plus one for the threat centre.
 * Markers are created once per slot and moved afterwards, so the cost is a handful of
 * setMarker calls per group every five seconds. Debug only (setting debugPicture).
 *
 * Arguments:
 * 0: Group <GROUP>
 *
 * Return Value:
 * None
 *
 * Example:
 * [group bob] call hostis_core_fnc_debugDraw;
 *
 * Public: No
*/
#define MAX_MARKERS 8

params [["_group", grpNull, [grpNull]]];
if (isNull _group) exitWith {};

private _picture = [_group] call FUNC(pictureRefresh);
private _id = _picture get "id";
private _contacts = [_group, -1, 0, [], [], 0, false] call FUNC(contactsGet);
private _leader = leader _group;
private _sideColor = switch (side _group) do {
    case west: {"ColorWEST"};
    case east: {"ColorEAST"};
    case independent: {"ColorGUER"};
    default {"ColorCIV"};
};

private _fnc_marker = {
    params ["_name", "_type"];
    if ((getMarkerType _name) isEqualTo "") then {
        private _m = createMarker [_name, [0, 0, 0]];
        _m setMarkerTypeLocal _type;
        _m setMarkerSize [0.6, 0.6];
    };
    _name
};

// contacts
for "_i" from 0 to (MAX_MARKERS - 1) do {
    private _name = format [QGVAR(pic_%1_%2), _id, _i];
    if (_i < count _contacts) then {
        private _contact = _contacts select _i;
        private _source = _contact select CONTACT_SOURCE;
        private _color = switch (_source) do {
            case "seen": {"ColorRed"};
            case "shotAt": {"ColorOrange"};
            case "heard": {"ColorYellow"};
            case "reported": {"ColorBlue"};
            default {"ColorGrey"};
        };
        [_name, "mil_dot"] call _fnc_marker;
        _name setMarkerPosLocal (_contact select CONTACT_POS);
        _name setMarkerColorLocal _color;
        _name setMarkerAlphaLocal (0.3 + 0.7 * (_contact select CONTACT_CONF));
        _name setMarkerText format ["%1 %2 %3 %4s e%5", groupId _group, _source, _contact select CONTACT_TYPE, round (time - (_contact select CONTACT_TIME)), round (_contact select CONTACT_ERROR)];
    } else {
        if ((getMarkerType _name) isNotEqualTo "") then {_name setMarkerAlpha 0;};
    };
};

// threat centre
private _centre = format [QGVAR(pic_%1_centre), _id];
private _threatPos = _picture get "threatPos";
if (_threatPos isEqualTo []) then {
    if ((getMarkerType _centre) isNotEqualTo "") then {_centre setMarkerAlpha 0;};
} else {
    [_centre, "mil_objective"] call _fnc_marker;
    _centre setMarkerPosLocal _threatPos;
    _centre setMarkerColorLocal _sideColor;
    _centre setMarkerAlphaLocal 0.8;
    _centre setMarkerText format ["%1 threat (%2 s)", groupId _group, round (_picture get "pictureAge")];
};
