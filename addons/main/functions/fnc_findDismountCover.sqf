#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Where dismounting infantry should go instead of standing in the open next to the
 * carrier: prone spots behind the hull on the side away from the enemy (while the
 * vehicle is intact and not the thing being shot at), then whatever the tactical
 * position system finds within reach (ditches below the enemy's line of sight, walls,
 * rocks, vegetation, wrecks), then a fallback spread to the side. One spot per man,
 * never closer than 2.5 m to another.
 *
 * Arguments:
 * 0: Vehicle, or a position where it was <OBJECT> or <ARRAY>
 * 1: Threat position AGL <ARRAY>
 * 2: How many spots <NUMBER>
 * 3: Use the hull as cover <BOOL>, default true
 * 4: Search radius for ditches and cover <NUMBER>, default 40
 *
 * Return Value:
 * spots, each [positionAGL, stance] <ARRAY>
 *
 * Example:
 * [apc, getPos angryJoe, 8] call lambs_main_fnc_findDismountCover;
 *
 * Public: No
*/
#define SPOT_SPACING 2.5
#define HULL_CLEARANCE 2
#define FALLBACK_DISTANCE 14
#define FALLBACK_BACK 4

params [["_vehicle", objNull, [objNull, []]], ["_threatPos", [], [[]]], ["_count", 1, [0]], ["_useHull", true, [false]], ["_radius", 40, [0]]];

private _vehiclePos = _vehicle call CBA_fnc_getPos;
if (_threatPos isEqualTo []) then {_threatPos = _vehiclePos getPos [100, 0];};
private _away = _threatPos getDir _vehiclePos;
private _spots = [];

private _fnc_far = {
    params ["_pos"];
    (_spots findIf {(_x select 0) distance2D _pos < SPOT_SPACING}) isEqualTo -1
};

// 1. behind the hull ~ as many men as its shadow is wide, 2 m off the far side
if (_useHull && {_vehicle isEqualType objNull} && {!isNull _vehicle} && {alive _vehicle}) then {
    (boundingBoxReal _vehicle) params ["_min", "_max"];
    private _length = (_max select 1) - (_min select 1);
    private _width = (_max select 0) - (_min select 0);
    private _relative = _away - (getDir _vehicle);
    private _shadow = (abs (_length * sin _relative)) + (abs (_width * cos _relative));
    private _depth = (abs (_length * cos _relative)) + (abs (_width * sin _relative));
    private _slots = ((floor (_shadow / SPOT_SPACING)) max 1) min _count;
    private _centre = _vehiclePos getPos [(_depth / 2) + HULL_CLEARANCE, _away];
    for "_i" from 0 to (_slots - 1) do {
        private _offset = (_i - ((_slots - 1) / 2)) * SPOT_SPACING;
        private _pos = _centre getPos [_offset, _away + 90];
        if ([_pos] call _fnc_far) then {_spots pushBack [_pos, "DOWN"];};
    };
};

// 2. the ground around ~ dips, walls, rocks, vegetation, wrecks, scored against the threat
if (count _spots < _count) then {
    private _options = createHashMapFromArray [["purpose", "hide"], ["count", (_count * 2) max 6], ["minDistance", 4]];
    {
        _x params ["_pos", "_cover", "", "_stance"];
        // never forward into the fire
        if (count _spots < _count && {_cover > 0} && {[_pos] call _fnc_far} && {(_pos distance2D _threatPos) >= (_vehiclePos distance2D _threatPos) - 10}) then {
            _spots pushBack [_pos, _stance];
        };
    } forEach ([_vehiclePos, _radius, [_threatPos], _options] call FUNC(findPositions));
};

// 3. fallback ~ spread to the side, a few metres back, prone
private _side = [90, -90] select (random 1 > 0.5);
private _index = 0;
while {count _spots < _count && {_index < _count * 3}} do {
    private _pos = (_vehiclePos getPos [FALLBACK_DISTANCE + (SPOT_SPACING * _index), _away + _side]) getPos [FALLBACK_BACK, _away];
    if ([_pos] call _fnc_far && {!surfaceIsWater _pos}) then {_spots pushBack [_pos, "DOWN"];};
    _index = _index + 1;
};

// nearest first, so the men closest to the hull take the hull
_spots = [_spots, [], {(_x select 0) distance2D _vehiclePos}, "ASCEND"] call BIS_fnc_sortBy;
_spots select [0, _count]
