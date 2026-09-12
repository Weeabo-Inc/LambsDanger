#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The one way LAMBS moves a soldier. Every group manoeuvre, drill and reflex ends here
 * with a purpose and a place, and the per-soldier machine turns it into legs from
 * cover to cover, a stance, a field of fire and the peek and duck rhythm once he is
 * there. Orders:
 *   move     get to a place in 15-35 m legs between cover, pausing to look at each
 *   rush     sprint there in up to 50 m legs, no shooting on the way
 *   assault  close on an enemy position, into the building that holds it if there is one
 *   hold     find the nearest fighting position within reach and fight from it
 *   cover    find the nearest hiding position within reach and get behind it
 *   survive  break away from the threat to cover 20-35 m off, diagonally, under smoke
 *   follow   release the man to his leader
 *   release  release the man where he stands
 * An order to a place he is already moving to or holding is a refresh, not a new move.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Order type <STRING>
 * 2: Centre or destination AGL, [] for the unit's own position <ARRAY>
 * 3: Threat positions AGL, the first is the main one <ARRAY>, default the group's picture
 * 4: Options <HASHMAP>, default empty, any of:
 *      "onArrive"      "hold" (default), "follow" or "release"
 *      "suppressList"  positions worth suppressing from the fighting position <ARRAY>
 *      "sector"        [bearing, width] the man watches when nothing is visible <ARRAY>
 *      "delay"         seconds before the first move (staggered rushes) <NUMBER>
 *      "hopMax"        longest leg in metres <NUMBER>
 *      "radius"        search radius for hold and cover <NUMBER>
 *      "indoorBias"    prefer positions under a roof <BOOL>
 *      "sprint"        no shooting while moving <BOOL>
 *      "holdTime"      seconds to hold on arrival before following the leader <NUMBER>
 *      "smoke"         chance to throw smoke before a rush or a survive <NUMBER>
 *      "task"          text for the debug label <STRING>
 *
 * Return Value:
 * accepted <BOOL>
 *
 * Example:
 * [bob, "move", getPos angryJoe, [getPos angryJoe]] call lambs_danger_fnc_unitOrder;
 *
 * Public: Yes
*/
#define SAME_PLACE 3
#define HOP_MOVE 30
#define HOP_RUSH 50
#define HOP_ASSAULT 15
#define HOLD_RADIUS 15
#define SURVIVE_HOLD 12
#define SURVIVE_SMOKE 0.5

params [["_unit", objNull, [objNull]], ["_type", "move", [""]], ["_centre", [], [[]]], ["_threats", [], [[]]], ["_options", createHashMap, [createHashMap]]];

if (isNull _unit || {!local _unit} || {isPlayer _unit}) exitWith {false};

// hand back
if (_type in ["follow", "release"]) exitWith {
    [_unit, _type isEqualTo "follow"] call FUNC(unitRelease);
    true
};

if (!(_unit call EFUNC(main,isAlive)) || {!isNull objectParent _unit} || {!(_unit checkAIFeature "PATH")} || {!(_unit checkAIFeature "MOVE")}) exitWith {false};
private _record = [_unit] call FUNC(unitRegister);
if (isNil "_record") exitWith {false};

if (_centre isEqualTo []) then {_centre = getPosATL _unit;};
if (_threats isEqualTo []) then {
    private _picture = (group _unit) getVariable QGVAR(picture);
    if (!isNil "_picture") then {
        private _threatPos = _picture get "threatPos";
        if (_threatPos isNotEqualTo []) then {_threats = [_threatPos];};
    };
};

// a repeat of the current order: keep going, take the new details
private _current = _record get "order";
private _state = _record get "state";
private _samePlace = (_record get "final") isNotEqualTo [] && {(_record get "final") distance2D _centre < SAME_PLACE};
if (
    _current isNotEqualTo []
    && {_state isNotEqualTo "Idle"}
    && {
        ((_current select 0) isEqualTo _type && _samePlace)
        // a man already fighting from cover where he is asked to hold keeps his position
        || {_type isEqualTo "hold" && {_state isEqualTo "InCover"} && {_unit distance2D _centre < SAME_PLACE}}
    }
) exitWith {
    _current set [2, _threats];
    _current set [3, _options];
    _record set ["suppressList", _options getOrDefault ["suppressList", _record get "suppressList"]];
    _record set ["sector", _options getOrDefault ["sector", _record get "sector"]];
    _record set ["lastEvent", time];
    true
};

// a new order: the old position claim goes, the man is ours
[_unit] call EFUNC(main,positionRelease);
_record set ["order", [_type, _centre, _threats, _options]];
_record set ["final", _centre];
_record set ["hop", []];
_record set ["hopFinal", false];
_record set ["hopFails", 0];
_record set ["hopCount", 0];
_record set ["pauseUntil", 0];
_record set ["position", []];
_record set ["alternates", []];
_record set ["suppressList", _options getOrDefault ["suppressList", []]];
_record set ["sector", _options getOrDefault ["sector", []]];
_record set ["onArrive", _options getOrDefault ["onArrive", "hold"]];
_record set ["sprint", _options getOrDefault ["sprint", _type in ["rush", "survive"]]];
_record set ["holdUntil", 0];
_record set ["shiftAt", 0];
_record set ["since", time];
_record set ["lastEvent", time];
_record set ["nextThink", time + (_options getOrDefault ["delay", 0])];
_record set ["needThink", true];

_record set ["state", switch (_type) do {
    case "rush": {"Rushing"};
    case "survive": {"Surviving"};
    default {"Moving"};
}];
_record set ["hopMax", _options getOrDefault ["hopMax", switch (_type) do {case "rush": {HOP_RUSH}; case "assault": {HOP_ASSAULT}; default {HOP_MOVE};}]];
_record set ["radius", _options getOrDefault ["radius", HOLD_RADIUS]];
_record set ["holdTime", _options getOrDefault ["holdTime", [0, SURVIVE_HOLD] select (_type isEqualTo "survive")]];

// the man is under orders: the FSM's own reflexes stand down for him
_unit setVariable [QGVAR(forceMove), true];
if (_type isEqualTo "survive") then {
    _unit setVariable [QEGVAR(main,survival), time + SURVIVE_HOLD + 10];
    if (random 1 < (_options getOrDefault ["smoke", SURVIVE_SMOKE]) && {!(_unit call EFUNC(main,isIndoor))} && {_threats isNotEqualTo []}) then {[_unit, _threats select 0] call EFUNC(main,doSmoke);};
};
_unit setVariable [QEGVAR(main,currentTask), _options getOrDefault ["task", switch (_type) do {
    case "rush": {"Rushing"};
    case "assault": {"Assaulting"};
    case "hold": {"Taking a fighting position"};
    case "cover": {"Getting into cover"};
    case "survive": {"Breaking away"};
    default {"Moving cover to cover"};
}], EGVAR(main,debug_functions)];
_unit setVariable [QEGVAR(main,currentTarget), _centre, EGVAR(main,debug_functions)];

true
