#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Is a chosen position still good enough? The cheap single-point check from the position
 * selection research (C-26): conditions only, no scoring, at most two rays. A man already
 * moving keeps his destination unless this fails, so movement has inertia.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Position, plain or a findPositions result <ARRAY>
 * 2: Threat positions, first is the main one <ARRAY>
 * 3: Require cover from the main threat, default true <BOOL>
 *
 * Return Value:
 * still good <BOOL>
 *
 * Example:
 * [bob, [1200, 3400, 0], [[1500, 3500, 0]]] call hostis_agent_fnc_positionValid;
 *
 * Public: Yes
*/
#define BODY_HEIGHT 0.45
#define THREAT_EYE 1.5
#define RESERVED_BLOCK 2.5
#define THREAT_CLEARANCE 20

params [["_unit", objNull, [objNull]], ["_position", [], [[]]], ["_threats", [], [[]]], ["_needCover", true, [false]]];

if (_position isEqualTo []) exitWith {false};
private _pos = if ((_position select 0) isEqualType []) then {_position select 0} else {_position};
if (surfaceIsWater _pos) exitWith {false};
if ((_threats findIf {_x distance2D _pos < THREAT_CLEARANCE}) isNotEqualTo -1) exitWith {false};

// somebody else's now
if (!isNull _unit) then {
    private _table = (group _unit) getVariable QLGVAR(main,reserved);
    if (!isNil "_table") then {
        private _own = hashValue _unit;
        private _taken = false;
        {
            if (_x isNotEqualTo _own && {time < (_y select 1)} && {(_y select 0) distance2D _pos < RESERVED_BLOCK}) exitWith {_taken = true;};
        } forEach _table;
        if (_taken) exitWith {false};
    };
};

if (!_needCover || {_threats isEqualTo []}) exitWith {true};
private _posASL = (AGLToASL _pos) vectorAdd [0, 0, BODY_HEIGHT];
private _threatASL = (AGLToASL (_threats select 0)) vectorAdd [0, 0, THREAT_EYE];
terrainIntersectASL [_posASL, _threatASL] || {lineIntersects [_posASL, _threatASL]}
