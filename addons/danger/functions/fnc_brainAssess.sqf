#include "script_component.hpp"
/*
 * Author: nkenny
 * handles assessment of own situation
 *
 * Arguments:
 * 0: unit doing the evaluation <OBJECT>
 * 1: known target threatening unit <OBJECT>
 *
 * Return Value:
 * number, timeout!
 *
 * Example:
 * [bob] call lambs_danger_fnc_brainAssess;
 *
 * Public: No
*/

/*
    Assess actions
    10 Assess
*/

#define REJOIN_DISTANCE 60

params ["_unit", ["_target", objNull]];

// timeout
private _timeout = time + 2;

// stress recovers, aiming with it
[_unit] call EFUNC(main,applyStress);
if ((_unit getVariable [QEGVAR(main,survival), 0]) > time) exitWith {_timeout};

// looking after himself between the drills: rejoin when cut off, ammunition, a wound
private _leader = leader _unit;
private _picture = (group _unit) getVariable QEGVAR(danger,picture);
private _inContact = !isNil "_picture" && {time - (_picture get "lastContact") < 60};
if (
    isNull objectParent _unit && {_unit isNotEqualTo _leader} && {_leader call EFUNC(main,isAlive)} && {isNull objectParent _leader}
    && {_unit distance2D _leader > REJOIN_DISTANCE} && {unitReady _unit}
) exitWith {
    _unit setVariable [QEGVAR(main,currentTask), "Cut off, rejoining", EGVAR(main,debug_functions)];
    _unit forceSpeed -1;
    _unit doFollow _leader;
    _timeout + 3
};
private _primary = primaryWeapon _unit;
if (_primary isNotEqualTo "" && {(_unit magazinesTurret [-1] select {_x in (getArray (configFile >> "CfgWeapons" >> _primary >> "magazines"))}) isEqualTo []} && {unitReady _unit}) exitWith {
    private _bodies = (_unit nearEntities ["CAManBase", 25]) select {!alive _x};
    if (_bodies isNotEqualTo []) then {
        _unit setVariable [QEGVAR(main,currentTask), "Out of ammunition, searching a body", EGVAR(main,debug_functions)];
        [_unit, getPosATL (_bodies select 0), 4] call EFUNC(main,doCheckBody);
    } else {
        _unit setVariable [QEGVAR(main,currentTask), "Out of ammunition", EGVAR(main,debug_functions)];
        _unit doFollow _leader;
    };
    _timeout + 4
};
if (
    damage _unit > 0.3 && {!_inContact} && {unitReady _unit}
    && {!isClass (configFile >> "CfgPatches" >> "ace_medical")} && {"FirstAidKit" in (items _unit)}
) exitWith {
    _unit setVariable [QEGVAR(main,currentTask), "Patching up", EGVAR(main,debug_functions)];
    _unit action ["HealSoldierSelf", _unit];
    _timeout + 6
};
// assertive units keep repositioning under light fire; -1 (suppression disabled) counts as not suppressed
private _suppressed = (getSuppression _unit) > ([0, 0.5] select (GVAR(aggression) > 0));

// check if stopped
if (
    _suppressed
    || !(_unit checkAIFeature "PATH")
    || ((behaviour _unit)) isEqualTo "STEALTH"
    || (currentCommand _unit) isEqualTo "STOP"
    || (combatMode _unit) in ["BLUE", "GREEN"]
) exitWith {_timeout};

// directed by a Zeus ~ no sympathetic assaults, drop the building memory so the FSM stops re-queueing assessments
if (_unit call EFUNC(main,isDirected)) exitWith {
    (group _unit) setVariable [QEGVAR(main,groupMemory), []];
    _timeout
};

// group memory
private _groupMemory = (group _unit) getVariable [QEGVAR(main,groupMemory), []];

// sympathetic CQB/suppressive fire
if (_groupMemory isNotEqualTo []) exitWith {
    [_unit, _groupMemory] call EFUNC(main,doAssaultMemory);
    _timeout
};

// building
if (RND(EGVAR(main,indoorMove)) && {_unit call EFUNC(main,isIndoor)}) exitWith {
    [_unit, _target] call EFUNC(main,doReposition);
    _timeout
};

// reset look
_unit setUnitPosWeak "MIDDLE";
//_unit doWatch objNull;

// end
_timeout
