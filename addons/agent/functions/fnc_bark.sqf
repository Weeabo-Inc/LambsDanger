#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * A voice line tied to a state change, from the vocabulary in XEH_preInit. Each key has a
 * priority, a per-man cooldown and a per-group cooldown, so the squad does not shout the
 * same thing from six mouths; a high-priority bark cuts a low-priority man's cooldown.
 * Uses the engine's own radio protocol through lambs_main_fnc_doCallout, so there is no
 * audio to license (docs/systems/legibility.md).
 *
 * Arguments:
 * 0: Speaker <OBJECT>
 * 1: Key from the vocabulary <STRING>
 * 2: Ignore the cooldowns, default false <BOOL>
 *
 * Return Value:
 * true when a line was played <BOOL>
 *
 * Example:
 * [bob, "coverMe"] call hostis_agent_fnc_bark;
 *
 * Public: Yes
*/
params [["_unit", objNull, [objNull]], ["_key", "", [""]], ["_force", false, [false]]];

if (!GVAR(barks) || {isNull _unit} || {isPlayer _unit} || {!(_unit call LFUNC(main,isAlive))}) exitWith {false};
private _entry = GVAR(barkVocabulary) get _key;
if (isNil "_entry") exitWith {false};
_entry params ["_sentence", "_behaviour", "_priority", "_unitCooldown", "_groupCooldown", "_range"];

private _now = time;
private _scale = GVAR(barkGroupCooldown);
private _group = group _unit;
private _groupTimes = _group getVariable QGVAR(barkTimes);
if (isNil "_groupTimes") then {
    _groupTimes = createHashMap;
    _group setVariable [QGVAR(barkTimes), _groupTimes];
};

if (!_force) then {
    if (_now < (_groupTimes getOrDefault [_key, -1e9]) + (_groupCooldown * _scale)) exitWith {false};
    private _unitTimes = _unit getVariable [QGVAR(barkTimes), createHashMap];
    if (_now < (_unitTimes getOrDefault [_key, -1e9]) + (_unitCooldown * _scale)) exitWith {false};
    // a loud thing cuts a quiet thing short
    private _lastPriority = _unit getVariable [QGVAR(barkPriority), 0];
    if (_priority >= 3 || {_priority > _lastPriority}) then {_unit setVariable [QLGVAR(main,calloutTime), 0];};
    _unitTimes set [_key, _now];
    _unit setVariable [QGVAR(barkTimes), _unitTimes];
    _groupTimes set [_key, _now];
    _unit setVariable [QGVAR(barkPriority), _priority];
    [_unit, _behaviour, _sentence, _range] call LFUNC(main,doCallout);
    true
} else {
    _unit setVariable [QLGVAR(main,calloutTime), 0];
    _groupTimes set [_key, _now];
    [_unit, _behaviour, _sentence, _range] call LFUNC(main,doCallout);
    true
}
