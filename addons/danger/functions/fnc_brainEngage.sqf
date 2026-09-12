#include "script_component.hpp"
/*
 * Author: nkenny
 * handles responses while engaging
 *
 * Arguments:
 * 0: unit doing the evaluation <OBJECT>
 * 1: type of data <NUMBER>
 * 2: known target <OBJECT>
 *
 * Return Value:
 * number, timeout
 *
 * Example:
 * [bob, 0, angryBob] call lambs_danger_fnc_brainEngage;
 *
 * Public: No
*/

/*
    Engage actions
    0 Enemy detected
    3 Enemy near
    8 CanFire
*/

#define GRENADE_RANGE 30
#define GRENADE_DELAY 3

params ["_unit", ["_type", -1], ["_target", objNull]];

// timeout
private _timeout = time + 1.5;

// hide when static and ordered to be stealthy
private _stealth = (behaviour _unit) isEqualTo "STEALTH";
private _holdFire = (combatMode _unit) in ["BLUE", "GREEN"];
private _still = (speed _unit) isEqualTo 0;
if (
    _still
    && _stealth
    && _holdFire
    && {!(_unit call EFUNC(main,isDirected))}
) exitWith {
    [_unit, _target] call EFUNC(main,doHide);
    _timeout + 2
};

// check ~ a man looking after himself is not sent anywhere
if (
    isNull _target
    || _stealth
    || _holdFire
    || {(_unit getVariable [QEGVAR(main,survival), 0]) > time}
    || {(speed _target) > 20 || (_unit knowsAbout _target) isEqualTo 0}
    || {(getUnitState _unit) isEqualTo "PLANNING"}
) exitWith {
    _timeout
};

// distance + group memory
private _distance = _unit distance2D _target;

// feed the group picture, apply stress to aiming
[group _unit, [_target]] call FUNC(pictureUpdate);
[_unit] call EFUNC(main,applyStress);

// a man in a fighting position learns where the enemy is and fights from where he is
if ([_unit, "isBusy"] call FUNC(unitState) || {([_unit, "state", "Idle"] call FUNC(unitState)) isEqualTo "InCover"}) exitWith {
    [_unit, "threatSeen", _unit getHideFrom _target] call FUNC(unitEvent);
    _timeout
};

// near, go for CQB ~ not while a Zeus directs the group
if (
    _distance < GVAR(cqbRange)
    && _unit checkAIFeature "PATH"
    && {!(_unit call EFUNC(main,isDirected))}
    && (vehicle _target) isKindOf "CAManBase"
    && {_target call EFUNC(main,isAlive)}
) exitWith {
    _unit setVariable ["ace_medical_ai_lastFired", CBA_missionTime]; // ACE3
    // grenade first, then the corner: an enemy holed up inside gets one through the door before anyone goes in
    private _fragged = _distance < GRENADE_RANGE
        && {_target call EFUNC(main,isIndoor)}
        && {!(_unit call EFUNC(main,isIndoor)) || {_unit distance2D _target > 8}}
        && {[_unit, _unit getHideFrom _target] call EFUNC(main,doGrenade)};
    if (_fragged) then {
        [{if ((_this select 0) call EFUNC(main,isAlive)) then {_this call EFUNC(main,doAssault);};}, [_unit, _target], GRENADE_DELAY] call CBA_fnc_waitAndExecute;
    } else {
        [_unit, _target] call EFUNC(main,doAssault);
    };
    _timeout + ([0, GRENADE_DELAY] select _fragged)
};

// set low stance
if ((getSuppression _unit) isNotEqualTo 0 && (stance _unit) isEqualTo "STAND") then {
    _unit setUnitPosWeak "MIDDLE";
};

// formation is tight
if (formation _unit in ["FILE", "DIAMOND"]) exitWith {
    _timeout
};

// far, try to suppress ~ not while a Zeus marches the group somewhere, suppressing stops the unit
if (
    _still
    && _distance > EGVAR(main,minSuppressionRange)
    && unitReady _unit
    && (_type isEqualTo DANGER_CANFIRE)
    && {!(_unit call EFUNC(main,isDirected))}
) exitWith {
    private _posASL = ATLToASL (_unit getHideFrom _target);
    if (((ASLToAGL _posASL) select 2) > 6) then {
        _posASL = ASLToAGL _posASL;
        _posASL set [2, 0.5];
        _posASL = AGLToASL _posASL
    };
    [_unit, _posASL vectorAdd [0, 0, 0.8], true] call EFUNC(main,doSuppress);
    _timeout + 3
};

// end
_timeout
