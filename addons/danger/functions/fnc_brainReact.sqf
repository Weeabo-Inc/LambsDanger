#include "script_component.hpp"
/*
 * Author: nkenny
 * handles immediate reaction responses by forcing animation on unit
 *
 * Arguments:
 * 0: unit doing the avaluation <OBJECT>
 * 1: type of danger <NUMBER>
 * 2: position of danger <ARRAY>
 *
 * Return Value:
 * timeout
 *
 * Example:
 * [bob, getPos angryBob] call lambs_danger_fnc_brainReact;
 *
 * Public: No
*/

/*
    Immediate actions
    1 Fire
    2 Hit
    4 Explosion
    9 BulletClose
*/

params ["_unit", ["_type", -1], ["_pos", [0, 0, 0]]];

// timeout
private _timeout = time + 1.4;

// ACE3
_unit setVariable ["ace_medical_ai_lastHit", CBA_missionTime];

// stress ~ being shot at wears a soldier down, hits most of all
private _stressIndex = ([DANGER_FIRE, DANGER_BULLETCLOSE, DANGER_EXPLOSION, DANGER_HIT] find _type) max 0;
// the group remembers where shells land, so the commander can tell a barrage from a stray grenade
if (_type isEqualTo DANGER_EXPLOSION) then {
    private _explosions = (group _unit) getVariable [QGVAR(explosions), []];
    _explosions pushBack [time, _pos];
    if (count _explosions > 6) then {_explosions deleteAt 0;};
    (group _unit) setVariable [QGVAR(explosions), _explosions];
};
[_unit, [0.1, 0.2, 0.3, 0.4] select _stressIndex] call EFUNC(main,addStress);
if (_type isEqualTo DANGER_HIT) then {_unit setVariable [QEGVAR(main,lastHit), time];};

// self preservation comes before any drill ~ a man who feels he is about to die gets himself out of it
if (!(_unit call EFUNC(main,isDirected))) then {
    ([_unit] call EFUNC(main,getThreat)) params ["_threatLevel"];
    if (_threatLevel >= 2 && {[_unit, _threatLevel, [_pos, []] select (_type isEqualTo DANGER_EXPLOSION)] call EFUNC(main,doSurvive)}) exitWith {};
};
if ((_unit getVariable [QEGVAR(main,survival), 0]) > time) exitWith {_timeout + 1};

// cover move when explosion ~ not while a Zeus directs the group; assertive units only sometimes duck on visible fire
private _assertive = GVAR(aggression) > 0;
if (
    !(_unit call EFUNC(main,isDirected))
    && {
        getSuppression _unit > 0.5
        || (getUnitState _unit) isEqualTo "REPLAN"
        || (currentCommand _unit) isEqualTo "STOP"
        || {(_type isEqualTo DANGER_FIRE) && {!_assertive || {RND(0.7)}}}
    }
) exitWith {
    [_unit] call EFUNC(main,doCover);
    _timeout + 1
};

// dodge!
[_unit, _pos] call EFUNC(main,doDodge);

// end
_timeout
