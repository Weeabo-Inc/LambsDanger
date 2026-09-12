#include "script_component.hpp"
/*
 * Author: nkenny
 * Actions on forced movement
 *
 * Arguments:
 * 0: unit toggled <OBJECT>
 *
 * Return Value:
 * Bool
 *
 * Example:
 * [bob] call lambs_danger_fnc_brainForced;
 *
 * Public: No
*/
params ["_unit"];

// timeout
private _timeout = time + 2;

// debug variable
_unit setVariable [QEGVAR(main,FSMDangerCauseData), [-2, getPosWorld _unit, _timeout, assignedTarget _unit], EGVAR(main,debug_functions)];

// unconscious or dead
if !(_unit call EFUNC(main,isAlive)) exitWith {
    _unit setVariable [QEGVAR(main,currentTask), "Incapacitated", EGVAR(main,debug_functions)];
    _timeout
};

// forced AI ~ orders or not, a man who just got hit while running looks after himself first
if (_unit getVariable [QGVAR(forceMove), false]) exitWith {
    private _lastDamage = _unit getVariable [QEGVAR(main,lastDamage), 0];
    private _damage = damage _unit;
    if (_damage > _lastDamage + 0.15) then {
        _unit setVariable [QEGVAR(main,lastHit), time];
        [_unit, 0.4] call EFUNC(main,addStress);
        if (isNull objectParent _unit && {(_unit getVariable [QEGVAR(main,survival), 0]) < time} && {!(_unit call EFUNC(main,isDirected))}) then {
            [_unit, 3, []] call EFUNC(main,doSurvive);
        };
    };
    _unit setVariable [QEGVAR(main,lastDamage), _damage];
    _timeout + 1
};

// fleeing
if (fleeing _unit) exitWith {
    [_unit] call EFUNC(main,doFleeing);
    _timeout
};

// attack speed and stance
if ((currentCommand _unit) isEqualTo "ATTACK") then {
    private _attackTarget = getAttackTarget _unit;
    if ((typeOf _attackTarget) isEqualTo "SuppressTarget") exitWith {
        deleteVehicle _attackTarget;
        _unit doWatch objNull;
    };
    [_unit, _attackTarget] call EFUNC(main,doAssaultSpeed);
    _unit setUnitPosWeak (["MIDDLE", "DOWN"] select (getSuppression _unit > 0.9));
    _unit setVariable [QEGVAR(main,currentTarget), _attackTarget, EGVAR(main,debug_functions)];
    _unit setVariable [QEGVAR(main,currentTask), "Attacking", EGVAR(main,debug_functions)];
};

// end
_timeout
