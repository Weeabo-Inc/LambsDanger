#include "script_component.hpp"
/*
 * Author: nkenny, bluefield-creator
 * Defend
 *      The group holds a position the way a trained squad does: the ground is split
 *      into sectors weighted towards where the enemy is expected, every man gets a
 *      fighting position with cover and a field of fire on his sector (a window, a
 *      wall, a dip) plus an alternate, a third of the squad waits in hiding on the far
 *      side as a reserve, and the per-soldier machine runs the peek and duck rhythm and
 *      shifts a man who is shot at. An enemy inside the perimeter brings the reserve
 *      out to meet him; a third of the squad lost gives the position up for the next
 *      line back. The group will not leave the area on its own.
 *
 * Arguments:
 * 0: Group performing action, either unit <OBJECT> or group <GROUP>
 * 1: Position to defend, default group location <ARRAY or OBJECT>
 * 2: Range the group defends, default is 75 meters <NUMBER>
 * 3: Area the group defends, default [] <ARRAY>
 * 4: Teleport Units to Position <BOOL>
 * 5: Cover types, 0 all, 1 buildings, 2 walls, 3 vegetation, 4 buildings and vegetation,
 *    5 buildings and walls, 6 walls and vegetation <NUMBER>
 * 6: Unit is waiting in ambush, default is TRUE <BOOL>
 * 7: Group sets a sub-unit to Patrol the area <BOOL>
 *
 * Return Value:
 * none
 *
 * Example:
 * [bob, bob, 50] spawn lambs_wp_fnc_taskDefend;
 *
 * Public: Yes
*/
#define TICK 8
#define RELAYOUT_TIME 60
#define RELAYOUT_ANGLE 45
#define SECTOR_RANGE 150
#define RESERVE_MIN_SIZE 4
#define FALLBACK_LOSSES 0.34
#define FALLBACK_REST 300
#define PENETRATION_HOLD 60

if (canSuspend) exitWith { [FUNC(taskDefend), _this] call CBA_fnc_directCall; };

params [
    ["_group", grpNull, [grpNull, objNull]],
    ["_pos", [], [objNull, []]],
    ["_radius", TASK_DEFEND_SIZE, [0]],
    ["_area", [], [[]]],
    ["_teleport", TASK_DEFEND_TELEPORT, [false]],
    ["_useCover", TASK_DEFEND_USECOVER, [0]],
    ["_stealth", TASK_DEFEND_STEALTH, [false]],
    ["_patrol", TASK_DEFEND_PATROL, [false]]
];

// sort grp
if (!local _group) exitWith {false};
if (_group isEqualType objNull) then { _group = group _group; };

// sort pos
if (_pos isEqualTo []) then {_pos = leader _group;};
_pos = _pos call CBA_fnc_getPos;

// task lifecycle ~ this ground is the group's intent from now on
private _token = [_group, "taskDefend"] call FUNC(taskBegin);
[_group, "defend", _pos, _radius] call EFUNC(danger,intentSet);

// orders
_group enableAttack false;
_group setFormation (["DIAMOND", "LINE"] select _stealth);
_group setVariable [QEGVAR(danger,disableGroupAI), true, true];
if (_stealth || _teleport) then {_group setBehaviour (["COMBAT", "STEALTH"] select _stealth);};

// set group task
_group setVariable [QEGVAR(main,currentTactic), "taskDefend", EGVAR(main,debug_functions)];
[_group] call CBA_fnc_clearWaypoints;

// orders
private _wp = _group addWaypoint [_pos, 0, 0];
_wp setWaypointType "HOLD";
_wp setWaypointName QGVAR(defend);

// patrol
if (_patrol) then {
    private _units = (units _group) select {isNull (objectParent _x)};
    reverse _units;
    private _patrolGroup = createGroup [(side _group), true];
    [_units deleteAt 0] join _patrolGroup;
    if (count _units > 4)  then { [_units deleteAt 0] join _patrolGroup; };

    // performance
    if (dynamicSimulationEnabled _group) then {
        [_patrolGroup, true] remoteExec ["enableDynamicSimulation", 2];
    };

    // id
    _patrolGroup setGroupIdGlobal [format ["Patrol (%1)", groupId _patrolGroup]];

    // orders
    if (_area isEqualTo []) then {
        [_patrolGroup, _pos, _radius, 4, nil, true, false] call FUNC(taskPatrol);
    } else {
        private _area2 = +_area;
        _area2 set [0, (_area2 select 0) * 2];
        _area2 set [1, (_area2 select 1) * 2];
        [_patrolGroup, _pos, _radius, 4, _area2, true, false] call FUNC(taskPatrol);
    };

    // eventhandler
    _group setVariable [QGVAR(baseGroup), _patrolGroup];
    _group addEventHandler ["CombatModeChanged", {
        params ["_group"];
        private _patrolGroup = _group getVariable [QGVAR(baseGroup), grpNull];
        (units _patrolGroup) joinSilent _group;
        _group removeEventHandler [_thisEvent, _thisEventHandler];
    }];

    // stealth patrol
    if (_stealth) then {
        _patrolGroup setBehaviour "AWARE";
        _patrolGroup setCombatMode "GREEN";
    };
};

// stealth
if (_stealth) then {
    _group setCombatMode "WHITE";
};

// how the ground is read
private _queryOptions = createHashMapFromArray [["purpose", "fight"], ["count", 3], ["indoorBias", _useCover in [0, 1, 4, 5]], ["buildingsOnly", _useCover isEqualTo 1]];
private _hideOptions = createHashMapFromArray [["purpose", "hide"], ["count", 3], ["indoorBias", _useCover in [0, 1, 4, 5]]];

// the layout: sectors, a fighting position per man, a reserve in hiding on the far side
private _fnc_layout = {
    params ["_group", "_pos", "_radius", "_area", "_threatDir", "_queryOptions", "_hideOptions", "_stealth"];
    private _men = (units _group) select {!isPlayer _x && {_x call EFUNC(main,isAlive)} && {isNull objectParent _x} && {simulationEnabled _x}};
    if (_men isEqualTo []) exitWith {[]};
    private _count = count _men;
    private _reserveCount = [0, (floor (_count / 3)) max 1] select (_count >= RESERVE_MIN_SIZE);
    private _lineCount = _count - _reserveCount;
    private _known = _threatDir >= 0;
    // the leader stays with the reserve when there is one, or takes the middle sector
    private _leader = leader _group;
    private _line = _men - [_leader];
    private _reserve = [];
    if (_reserveCount > 0) then {
        _reserve = [_leader] + (_line select [0, _reserveCount - 1]);
        _line = _line - _reserve;
    } else {
        _line = [_leader] + _line;
    };
    private _fnc_inArea = {
        params ["_candidate"];
        _area isEqualTo [] || {_candidate inArea [_pos, _area select 0, _area select 1, _area select 2, _area select 3, _area param [4, -1]]}
    };
    private _assignments = [];
    private _positions = 0;
    {
        // sectors: a 180 degree arc towards the threat when it is known, all round when it is not
        private _bearing = if (_known) then {
            _threatDir - 90 + ((_forEachIndex + 0.5) * (180 / _lineCount))
        } else {
            (_forEachIndex + 0.5) * (360 / _lineCount)
        };
        private _width = [360 / _lineCount, 180 / _lineCount] select _known;
        private _sectorPoint = _pos getPos [SECTOR_RANGE, _bearing];
        private _centre = _pos getPos [_radius * 0.5, _bearing];
        _queryOptions set ["unit", _x];
        private _found = ([_centre, _radius * 0.6, [_sectorPoint], _queryOptions] call EFUNC(main,findPositions)) select {[_x select 0] call _fnc_inArea};
        private _primary = if (_found isEqualTo []) then {_centre} else {(_found select 0) select 0};
        [_x, _primary] call EFUNC(main,positionReserve);
        _positions = _positions + count _found;
        private _options = createHashMapFromArray [
            ["onArrive", "hold"],
            ["radius", 6],
            ["sector", [_bearing, _width]],
            ["task", format ["Defending sector %1", round _bearing]]
        ];
        [_x, "hold", _primary, [_sectorPoint], _options] call EFUNC(danger,unitOrder);
        _assignments pushBack [_x, "line", _bearing, _width, _primary];
    } forEach _line;
    {
        // the reserve hides on the far side of the position, ready to meet a penetration
        private _away = [(_forEachIndex + 0.5) * (360 / (count _reserve)), _threatDir + 180 + (-30 + 60 * (_forEachIndex / ((count _reserve) max 1)))] select _known;
        private _centre = _pos getPos [_radius * 0.4, _away];
        _hideOptions set ["unit", _x];
        private _found = ([_centre, _radius * 0.5, [_pos getPos [SECTOR_RANGE, [_away + 180, _threatDir] select _known]], _hideOptions] call EFUNC(main,findPositions)) select {[_x select 0] call _fnc_inArea};
        private _spot = if (_found isEqualTo []) then {_centre} else {(_found select 0) select 0};
        [_x, _spot] call EFUNC(main,positionReserve);
        _positions = _positions + count _found;
        private _options = createHashMapFromArray [
            ["onArrive", "hold"],
            ["radius", 6],
            ["sector", [[_away + 180, _threatDir] select _known, 90]],
            ["task", "Reserve"]
        ];
        [_x, "cover", _spot, [], _options] call EFUNC(danger,unitOrder);
        _assignments pushBack [_x, "reserve", [_away + 180, _threatDir] select _known, 90, _spot];
    } forEach _reserve;
    if (EGVAR(main,debug_functions)) then {
        ["%1 DEFEND %2: %3 sectors, %4 reserve, %5 positions%6", side _group, groupId _group, count _line, count _reserve, _positions, ["", format [" towards %1", round _threatDir]] select _known] call EFUNC(main,debugLog);
    };
    _assignments
};

// first layout ~ towards whatever the group already knows, else all round; teleported men start on their positions
private _picture = [_group] call EFUNC(danger,pictureGet);
private _assignments = [_group, _pos, _radius, _area, _picture get "threatDir", _queryOptions, _hideOptions, _stealth] call _fnc_layout;
if (_teleport) then {
    {
        _x params ["_unit", "", "", "", "_spot"];
        _unit setVehiclePosition [_spot, [], 0, "CAN_COLLIDE"];
    } forEach _assignments;
};
private _state = createHashMapFromArray [
    ["assignments", _assignments],
    ["layoutTime", time],
    ["layoutDir", _picture get "threatDir"],
    ["penetrationTime", -1e9],
    ["fallingBack", false],
    ["startLosses", _picture get "losses"]
];

private _handle = [
    {
        params ["_args", "_handle"];
        _args params ["_group", "_pos", "_radius", "_area", "_token", "_waypointCount", "_state", "_queryOptions", "_hideOptions", "_stealth", "_fnc_layout"];

        // end ~ cancelled, all dead, or the waypoints changed (a Zeus gave new orders)
        private _cancelled = [_group, _token] call FUNC(taskIsCancelled);
        if (
            _cancelled
            || {(units _group) findIf {_x call EFUNC(main,isAlive)} == -1}
            || {count (waypoints _group) isNotEqualTo _waypointCount}
        ) exitWith {
            [_handle] call CBA_fnc_removePerFrameHandler;
            if (!isNull _group) then {
                _group setVariable [QGVAR(defendPFH), nil];
                // a cancelled task was already cleaned up by whoever cancelled it
                if (!_cancelled) then {[_group] call FUNC(taskCleanup);};
            };
        };

        private _leader = leader _group;
        private _picture = [_group] call EFUNC(danger,pictureGet);
        private _contacts = [_group, 60] call EFUNC(danger,pictureContacts);
        private _threatDir = _picture get "threatDir";
        private _threatPos = _picture get "threatPos";

        // a third of the squad gone ~ give the position up for the next line back, and hold that
        private _lossRatio = ((_picture get "losses") - (_state get "startLosses")) / ((_picture get "maxCount") max 1);
        if (_state get "fallingBack") then {
            if (!(_group getVariable [QEGVAR(danger,isExecutingTactic), false])) then {
                _state set ["fallingBack", false];
                _pos = getPosATL _leader;
                _args set [1, _pos];
                [_group, "defend", _pos, _radius] call EFUNC(danger,intentSet);
                _state set ["startLosses", _picture get "losses"];
                _state set ["assignments", [_group, _pos, _radius, [], _threatDir, _queryOptions, _hideOptions, _stealth] call _fnc_layout];
                _state set ["layoutTime", time];
                _state set ["layoutDir", _threatDir];
                if (EGVAR(main,debug_functions)) then {["%1 DEFEND %2: new line", side _group, groupId _group] call EFUNC(main,debugLog);};
            };
        } else {
            if (
                _lossRatio >= FALLBACK_LOSSES
                && {_threatPos isNotEqualTo []}
                && {time - (_picture get "withdrawTime") > FALLBACK_REST}
                && {!(_group getVariable [QEGVAR(danger,isExecutingTactic), false])}
            ) exitWith {
                _state set ["fallingBack", true];
                _args set [3, []];
                {[_x, false] call EFUNC(danger,unitRelease);} forEach (units _group);
                [_group, "withdraw", _threatPos, 90] call EFUNC(danger,tacticsMonitor);
                [_group, _threatPos] call EFUNC(danger,tacticsWithdraw);
                if (EGVAR(main,debug_functions)) then {["%1 DEFEND %2: falling back to the next line", side _group, groupId _group] call EFUNC(main,debugLog);};
            };
        };
        if (_group getVariable [QEGVAR(danger,isExecutingTactic), false]) exitWith {};

        // sort units
        private _units = (units _group) select {
            simulationEnabled _x
            && { isNull ( objectParent _x ) }
            && { _x call EFUNC(main,isAlive) }
            && { ! ( currentCommand _x in ["GET IN", "ACTION", "HEAL"] ) }
        };

        // advanced combat moves
        if (_leader call EFUNC(main,isNight) && {_contacts isNotEqualTo []}) then {
            _units = [_units] call EFUNC(main,doUGL);
        };
        _units = [_units, _leader] call EFUNC(main,doGroupStaticFind);

        // share information and call for fire on an enemy outside the perimeter
        if (_contacts isNotEqualTo [] && {_threatPos isNotEqualTo []} && {_threatPos distance2D _pos > _radius} && {getSuppression _leader < 0.5}) then {
            [_leader] call EFUNC(main,doShareInformation);
            if ([side _group] call FUNC(sideHasArtillery) && {([_leader, _threatPos, 200] call EFUNC(main,findNearbyFriendlies)) isEqualTo []}) then {
                [_leader, _threatPos] call EFUNC(main,doCallArtillery);
            };
        };

        // the enemy is inside the perimeter ~ the reserve comes out to meet him where he broke in
        private _inside = _contacts select {(_x select 1) distance2D _pos < _radius};
        if (_inside isNotEqualTo [] && {time - (_state get "penetrationTime") > PENETRATION_HOLD}) then {
            _state set ["penetrationTime", time];
            private _breach = (_inside select 0) select 1;
            private _reserve = (_state get "assignments") select {(_x select 1) isEqualTo "reserve" && {(_x select 0) call EFUNC(main,isAlive)}};
            private _spots = [_pos getPos [((_pos distance2D _breach) - 25) max 5, _pos getDir _breach], 25, [_breach], createHashMapFromArray [["purpose", "fight"], ["count", count _reserve]]] call EFUNC(main,findPositions);
            {
                private _spot = (_spots param [_forEachIndex, [_pos getPos [10, (_pos getDir _breach) + (-30 + 60 * _forEachIndex)]]]) select 0;
                [_x select 0, "rush", _spot, [_breach], createHashMapFromArray [["onArrive", "hold"], ["sector", [_pos getDir _breach, 90]], ["task", "Counterattacking the penetration"]]] call EFUNC(danger,unitOrder);
            } forEach _reserve;
            [_leader, "combat", "contact", 125] call EFUNC(main,doCallout);
            if (EGVAR(main,debug_functions)) then {["%1 DEFEND %2: penetration, %3 reserve counterattack", side _group, groupId _group, count _reserve] call EFUNC(main,debugLog);};
        };

        // the enemy came from an unexpected side, or a while has passed ~ read the ground again
        private _layoutDir = _state get "layoutDir";
        private _turned = _threatDir >= 0 && {_layoutDir < 0 || {abs ((_threatDir - _layoutDir + 540) mod 360 - 180) > RELAYOUT_ANGLE}};
        if (_turned && {time - (_state get "layoutTime") > RELAYOUT_TIME} && {_inside isEqualTo []}) then {
            _state set ["assignments", [_group, _pos, _radius, _area, _threatDir, _queryOptions, _hideOptions, _stealth] call _fnc_layout];
            _state set ["layoutTime", time];
            _state set ["layoutDir", _threatDir];
        };

        // keep every man on his job: back inside the perimeter, or back to his position once the machine let him go
        {
            private _unit = _x;
            if (_unit distance2D _pos > _radius) then {
                [_unit, "move", _pos getPos [_radius * 0.7, _pos getDir _unit], [], createHashMapFromArray [["onArrive", "hold"], ["task", "Back inside the perimeter"]]] call EFUNC(danger,unitOrder);
                continue;
            };
            if (([_unit, "state", "Idle"] call EFUNC(danger,unitState)) isEqualTo "Idle" && {(_unit getVariable [QEGVAR(main,survival), 0]) < time}) then {
                private _index = (_state get "assignments") findIf {(_x select 0) isEqualTo _unit};
                if (_index isNotEqualTo -1) then {
                    ((_state get "assignments") select _index) params ["", "_job", "_bearing", "_width", "_spot"];
                    private _options = createHashMapFromArray [["onArrive", "hold"], ["radius", 6], ["sector", [_bearing, _width]], ["task", ["Defending sector", "Reserve"] select (_job isEqualTo "reserve")]];
                    [_unit, ["hold", "cover"] select (_job isEqualTo "reserve"), _spot, [_pos getPos [SECTOR_RANGE, _bearing]], _options] call EFUNC(danger,unitOrder);
                    if (EGVAR(main,debug_functions)) then {["%1 DEFEND %2: retask %3 -> sector %4", side _group, groupId _group, name _unit, round _bearing] call EFUNC(main,debugLog);};
                };
            };
        } forEach _units;
    },
    TICK,
    [_group, _pos, _radius, _area, _token, count (waypoints _group), _state, _queryOptions, _hideOptions, _stealth, _fnc_layout]
] call CBA_fnc_addPerFrameHandler;
_group setVariable [QGVAR(defendPFH), _handle];

// cover debug
if (EGVAR(main,debug_functions)) then {
    private _marker = [_pos, format ["Defend (%1x @ %2m)", count _assignments, round _radius], "Color1_FD_F"] call EFUNC(main,dotMarker);
    private _mList = [_marker];
    {
        private _marker = [_x select 4, "", "Color1_FD_F", ["loc_Tree", "loc_Bunker"] select ((_x select 1) isEqualTo "reserve")] call EFUNC(main,dotMarker);
        _mList pushBack _marker;
    } forEach _assignments;
    [{[{deleteMarker _x} forEach _this]}, _mList, 60] call CBA_fnc_waitAndExecute;
};

// end
true
