#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The expensive half of the per-soldier machine: everything that asks the tactical
 * position system a question or gives the engine a move. Runs for a bounded number of
 * men per tick (see lambs_danger_fnc_unitCycle). Decides the next leg of a move, where
 * a hold or cover order settles, where a man breaking away runs to, which building a
 * man assaulting closes on, and where a man who has been shot at shifts to.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob] call lambs_danger_fnc_unitThink;
 *
 * Public: No
*/
#define THINK_INTERVAL 1.5
#define QUERY_GAP 3
#define FINAL_RADIUS 8
#define SHIFT_RADIUS 15
#define ASSAULT_RADIUS 12
#define SURVIVE_MIN 20
#define SURVIVE_MAX 35
#define SURVIVE_FALLBACK 25
#define PROGRESS_MIN 0.25
#define HOP_LIMIT 14
#define RESERVE_TIME 60

params [["_unit", objNull, [objNull]]];

private _record = _unit getVariable QGVAR(unit);
if (isNil "_record") exitWith {};
_record set ["needThink", false];
_record set ["nextThink", time + THINK_INTERVAL];

private _state = _record get "state";
if (!(_state in ["Moving", "Rushing", "Surviving", "InCover"])) exitWith {};
private _order = _record get "order";
if (_order isEqualTo []) exitWith {};
_order params ["_type", "_centre", "_threats", "_options"];
private _final = _record get "final";
private _sprint = _record get "sprint";
private _hopMax = _record getOrDefault ["hopMax", 30];
private _unitPos = getPosATL _unit;
private _debug = EGVAR(main,debug_functions);

// one question to the ground
private _fnc_query = {
    params ["_queryCentre", "_queryRadius", "_purpose", ["_extra", []], ["_count", 4]];
    private _queryOptions = createHashMapFromArray ([
        ["purpose", _purpose],
        ["unit", _unit],
        ["count", _count],
        ["indoorBias", _options getOrDefault ["indoorBias", false]]
    ] + _extra);
    _record set ["nextQuery", time + QUERY_GAP];
    [_queryCentre, _queryRadius, _threats, _queryOptions] call EFUNC(main,findPositions)
};

// one leg
private _fnc_go = {
    params ["_destination", "_isFinal", "_position"];
    _record set ["hop", _destination];
    _record set ["hopFinal", _isFinal];
    _record set ["position", _position];
    _record set ["hopStart", time];
    _record set ["hopCount", (_record get "hopCount") + 1];
    if (_isFinal) then {[_unit, _destination, RESERVE_TIME] call EFUNC(main,positionReserve);};
    _unit forceSpeed -1;
    _unit setUnitPos "UP";
    if (_sprint) then {
        _unit disableAI "SUPPRESSION";
        _unit disableAI "TARGET";
        _unit disableAI "AUTOTARGET";
        _unit doWatch objNull;
    } else {
        private _taskDisabled = _unit getVariable [QEGVAR(wp,disabledAI), []];
        {if (!(_x in _taskDisabled)) then {_unit enableAI _x;};} forEach ["SUPPRESSION", "TARGET", "AUTOTARGET"];
    };
    _unit doMove _destination;
    if (_debug) then {
        ["%1 UNIT %2 %3 %4 %5m (%6)", side _unit, name _unit, ["hop", "final"] select _isFinal, _record get "hopCount", round (_unit distance2D _destination), [_position select 5, "straight"] select (_position isEqualTo [])] call EFUNC(main,debugLog);
    };
};

// in position and shot at: somewhere else nearby, without standing in the open to think about it
if (_state isEqualTo "InCover") exitWith {
    if ((_record get "shiftAt") isEqualTo 0 || {time < (_record get "shiftAt")}) exitWith {};
    _record set ["shiftAt", 0];
    private _current = _record get "position";
    private _currentPos = if (_current isEqualTo []) then {_unitPos} else {_current select 0};
    private _blacklist = ((_record get "unreachable") select {time < (_x select 1)}) apply {_x select 0};
    private _fnc_usable = {(_x select 0) distance2D _unit <= SHIFT_RADIUS && {(_x select 0) distance2D _currentPos > 2} && {private _pos = _x select 0; (_blacklist findIf {_x distance2D _pos < 2.5}) isEqualTo -1}};
    private _candidates = (_record get "alternates") select _fnc_usable;
    if (_candidates isEqualTo [] && {time >= (_record get "nextQuery")}) then {
        _candidates = ([_unitPos, SHIFT_RADIUS, ["fight", "hide"] select (_type in ["cover", "survive"])] call _fnc_query) select _fnc_usable;
    };
    if (_candidates isEqualTo []) exitWith {};
    private _pick = _candidates deleteAt 0;
    _record set ["alternates", _candidates];
    (_record get "shifts") pushBack time;
    [_unit] call EFUNC(main,positionRelease);
    _record set ["state", ["Moving", "Rushing"] select _sprint];
    _record set ["pauseUntil", 0];
    _unit setVariable [QEGVAR(main,currentTask), "Shifting position", EGVAR(main,debug_functions)];
    [_pick select 0, true, _pick] call _fnc_go;
    if (_debug) then {["%1 UNIT %2 shift %3m", side _unit, name _unit, round (_unit distance2D (_pick select 0))] call EFUNC(main,debugLog);};
};

// on the move and between legs
if ((_record get "hop") isNotEqualTo []) exitWith {};
private _purpose = ["fight", "hide"] select (_type in ["cover", "survive"]);

// hold or cover: the nearest position worth having within reach
if (_type in ["hold", "cover"]) exitWith {
    private _positions = [_final, _record getOrDefault ["radius", 15], _purpose] call _fnc_query;
    if (_positions isEqualTo []) then {
        [_final, true, []] call _fnc_go;
    } else {
        private _pick = _positions deleteAt 0;
        _record set ["alternates", _positions];
        [_pick select 0, true, _pick] call _fnc_go;
    };
};

// breaking away: cover 20-35 m off, diagonally away from the fire, never straight back into the beaten zone
if (_type isEqualTo "survive") exitWith {
    private _away = if (_threats isEqualTo []) then {getDir _unit} else {(_threats select 0) getDir _unit};
    private _awayVector = [sin _away, cos _away, 0];
    private _positions = [_unitPos, SURVIVE_MAX, "hide", [["minDistance", SURVIVE_MIN]], 8] call _fnc_query;
    private _pick = [];
    {
        private _minDot = _x;
        private _maxDot = [0.85, 1.01] select (_minDot < -0.2);
        {
            private _offset = (_x select 0) vectorDiff _unitPos;
            _offset set [2, 0];
            private _dot = (vectorNormalized _offset) vectorDotProduct _awayVector;
            if (_pick isEqualTo [] && {_dot > _minDot} && {_dot < _maxDot}) then {_pick = _x;};
        } forEach _positions;
    } forEach [-0.2, -0.3];
    if (_pick isEqualTo [] && {_positions isNotEqualTo []}) then {_pick = _positions select 0;};
    private _destination = if (_pick isEqualTo []) then {_unitPos getPos [SURVIVE_FALLBACK, _away + (-45 + random 90)]} else {_pick select 0};
    _record set ["final", _destination];
    _record set ["alternates", _positions - [_pick]];
    [_destination, true, _pick] call _fnc_go;
};

// assault: the building position nearest the enemy's, when there is a building
if (_type isEqualTo "assault" && {!(_record getOrDefault ["assaultChosen", false])}) then {
    _record set ["assaultChosen", true];
    private _positions = [_final, ASSAULT_RADIUS, "fight", [["buildingsOnly", true]]] call _fnc_query;
    if (_positions isNotEqualTo []) then {
        private _pick = _positions deleteAt 0;
        _final = _pick select 0;
        _record set ["final", _final];
        _record set ["position", _pick];
        _record set ["alternates", _positions];
    };
};

// the last leg: into the destination, or into cover right next to it when there is a threat to hide from
private _distance = _unit distance2D _final;
if (_distance <= _hopMax + 3 || {(_record get "hopCount") >= HOP_LIMIT}) exitWith {
    private _destination = _final;
    private _position = _record get "position";
    if (_position isEqualTo [] && {_threats isNotEqualTo []} && {!(_options getOrDefault ["exact", false])}) then {
        private _positions = [_final, FINAL_RADIUS, _purpose] call _fnc_query;
        if (_positions isNotEqualTo []) then {
            _position = _positions deleteAt 0;
            _destination = _position select 0;
            _record set ["alternates", _positions];
        };
    };
    [_destination, true, _position] call _fnc_go;
};

// an intermediate leg: a stepping stone that gains ground and stands behind something
private _direction = _unit getDir _final;
private _destination = _unitPos getPos [_hopMax, _direction];
private _position = [];
if (_threats isNotEqualTo [] || {_options getOrDefault ["indoorBias", false]}) then {
    private _ahead = _unitPos getPos [_hopMax * 0.7, _direction];
    private _positions = [_ahead, _hopMax * 0.45, "move", [["objective", _final]], 3] call _fnc_query;
    _positions = _positions select {(_distance - ((_x select 0) distance2D _final)) > _hopMax * PROGRESS_MIN};
    if (_positions isNotEqualTo []) then {
        _position = _positions select 0;
        _destination = _position select 0;
    };
};
[_destination, false, _position] call _fnc_go;
