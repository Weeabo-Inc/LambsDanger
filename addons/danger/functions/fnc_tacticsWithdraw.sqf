#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Leader breaks contact: a covering pair suppresses the threat while the rest of the
 * group falls back to cover away from it under smoke, then the covering pair follows.
 * Used when morale is low instead of hiding in place.
 *
 * Arguments:
 * 0: group executing tactics <GROUP> or group leader <UNIT>
 * 1: group threat unit <OBJECT> or position <ARRAY>
 * 2: units in group, default all <ARRAY>
 * 3: delay until unit is ready again <NUMBER>
 *
 * Return Value:
 * success
 *
 * Example:
 * [bob, angryJoe] call lambs_danger_fnc_tacticsWithdraw;
 *
 * Public: No
*/
#define WITHDRAW_DISTANCE 120
#define SEARCH_RADIUS 80
#define COVER_TEAM_SIZE 2
#define COVER_TIME 12

params ["_group", "_target", ["_units", []], ["_delay", 90]];

// group is missing
if (isNull _group) exitWith {false};

// get leader
if (_group isEqualType objNull) then {_group = group _group;};
if ((units _group) isEqualTo []) exitWith {false};
private _unit = leader _group;
if (_group call EFUNC(main,isDirected)) exitWith {false};

// find target ~ fall back to the picture, then to the leader's facing
if (_target isEqualTo [] || {_target isEqualTo objNull}) then {
    _target = ([_group] call FUNC(pictureGet)) get "threatPos";
};
_target = if (_target isEqualTo []) then {_unit getPos [50, getDir _unit]} else {_target call CBA_fnc_getPos};

// remember
([_group] call FUNC(pictureGet)) set ["withdrawTime", time];
_group setVariable [QGVAR(isExecutingTactic), true];

// reset tactics
[
    {
        params [["_group", grpNull], ["_delay", 0]];
        time > _delay || {isNull _group} || {!(_group getVariable [QGVAR(isExecutingTactic), false])}
    },
    {
        params [["_group", grpNull], "", ["_speedMode", "NORMAL"], ["_formation", "WEDGE"], ["_enableAttack", true]];
        if (!isNull _group) then {
            _group setVariable [QGVAR(isExecutingTactic), nil];
            _group setVariable [QEGVAR(main,currentTactic), nil];
            _group setSpeedMode _speedMode;
            _group setFormation _formation;
            _group enableAttack (_enableAttack || {GVAR(aggression) > 0 && {!(_group call EFUNC(main,isDirected))}});
            {
                _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
                _x setVariable [QGVAR(forceMove), nil];
                _x setUnitPos "AUTO";
                _x forceSpeed -1;
                _x doFollow (leader _x);
            } forEach (units _group);
        };
    },
    [_group, time + _delay, speedMode _group, formation _group, attackEnabled _group]
] call CBA_fnc_waitUntilAndExecute;

// find units
if (_units isEqualTo []) then {
    _units = [_unit, 250] call EFUNC(main,findReadyUnits);
};
if (_units isEqualTo []) exitWith {false};

// destination ~ away from the threat, preferring cover
private _awayDir = _target getDir _unit;
private _searchCentre = _unit getPos [WITHDRAW_DISTANCE, _awayDir];
private _places = selectBestPlaces [_searchCentre, SEARCH_RADIUS, "(2 * forest) + (2 * trees) + houses + hills - (3 * meadow) - (5 * sea)", 20, 3];
_places = (_places apply {[(_x select 0) select 0, (_x select 0) select 1, 0]}) select {!(surfaceIsWater _x)};
private _destination = if (_places isEqualTo []) then {_searchCentre} else {_places select 0};

// covering pair ~ support gunners first
private _gunners = _units select {_x call EFUNC(main,isSupportGunner)};
private _cover = _gunners select [0, COVER_TEAM_SIZE];
{
    if (count _cover < COVER_TEAM_SIZE && {!(_x in _cover)} && {_x isNotEqualTo _unit}) then {_cover pushBack _x;};
} forEach _units;
private _movers = _units - _cover;

// set tasks
_unit setVariable [QEGVAR(main,currentTarget), _destination, EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTask), "Tactics Withdraw", EGVAR(main,debug_functions)];
_group setVariable [QEGVAR(main,currentTactic), "Breaking contact", EGVAR(main,debug_functions)];

// group orders
_group enableAttack false;
_group setCombatMode "YELLOW";
_group setSpeedMode "FULL";
_group setFormation "LINE";
_group setFormDir _awayDir;

// gesture and callout
[_unit, "gestureFollow"] call EFUNC(main,doGesture);
[_unit, "combat", "TakeCover", 125] call EFUNC(main,doCallout);

// smoke between the group and the threat
if (!GVAR(disableAutonomousSmokeGrenades)) then {
    [_unit, _unit getPos [15, _unit getDir _target]] call EFUNC(main,doSmoke);
};

// movers fall back at once, spread on arrival
{
    private _pos = _destination getPos [3 * ceil (_forEachIndex / 2), _awayDir + ([90, -90] select ((_forEachIndex % 2) isEqualTo 0))];
    _x setVariable [QGVAR(forceMove), true];
    _x setUnitPos "MIDDLE";
    _x forceSpeed -1;
    _x doMove _pos;
    _x setVariable [QEGVAR(main,currentTask), "Falling back", EGVAR(main,debug_functions)];
    [
        {params ["_unit"]; unitReady _unit || {!(_unit call EFUNC(main,isAlive))}},
        {
            params ["_unit", "_target"];
            if (!(_unit call EFUNC(main,isAlive))) exitWith {};
            _unit setUnitPos (_unit call EFUNC(main,getLowStance));
            _unit doWatch _target;
        },
        [_x, _target],
        45
    ] call CBA_fnc_waitUntilAndExecute;
} forEach _movers;

// covering pair suppresses, then follows
private _posList = ([_group, 60] call FUNC(pictureContacts)) apply {_x select 1};
_posList pushBack _target;
{
    _x setVariable [QGVAR(forceMove), true];
    _x setUnitPos (_x call EFUNC(main,getLowStance));
    _x setVariable [QEGVAR(main,currentTask), "Covering withdrawal", EGVAR(main,debug_functions)];
    private _index = [_x, _posList] call EFUNC(main,checkVisibilityList);
    if (_index isNotEqualTo -1) then {
        [_x, AGLToASL ((_posList select _index) vectorAdd [0, 0, random 1])] call EFUNC(main,doSuppress);
    } else {
        _x doWatch _target;
    };
} forEach _cover;
[
    {
        params ["_cover", "_destination", "_awayDir"];
        {
            if (_x call EFUNC(main,isAlive)) then {
                _x setUnitPos "MIDDLE";
                _x doMove (_destination getPos [3 + 3 * _forEachIndex, _awayDir + 180]);
                _x setVariable [QEGVAR(main,currentTask), "Falling back", EGVAR(main,debug_functions)];
            };
        } forEach _cover;
    },
    [_cover, _destination, _awayDir],
    COVER_TIME
] call CBA_fnc_waitAndExecute;

// debug
if (EGVAR(main,debug_functions)) then {
    ["%1 TACTICS WITHDRAW (%2 with %3 units to %4m, %5 covering)", side _unit, name _unit, count _units, round (_unit distance2D _destination), count _cover] call EFUNC(main,debugLog);
    private _m = [_unit, "tactics withdraw", _unit call EFUNC(main,debugMarkerColor), "hd_arrow"] call EFUNC(main,dotMarker);
    private _mt = [_destination, "", _unit call EFUNC(main,debugMarkerColor), "hd_flag"] call EFUNC(main,dotMarker);
    {_x setMarkerSizeLocal [0.6, 0.6];} forEach [_m, _mt];
    _m setMarkerDirLocal _awayDir;
    [{{deleteMarker _x;true} count _this;}, [_m, _mt], _delay + 30] call CBA_fnc_waitAndExecute;
};

// end
true
