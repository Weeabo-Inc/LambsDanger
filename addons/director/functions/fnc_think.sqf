#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * One think of one side's Director (docs/systems/director.md): refresh the groups, build
 * the board from their reports, update the influence map and the pacing, note the routes
 * the enemy uses, check for counter-battery, mark defended positions that fell, answer
 * reinforcement requests, launch counterattacks, and step the fire missions.
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * None
 *
 * Example:
 * [east] call hostis_director_fnc_think;
 *
 * Public: No
*/
#define FALLEN_FORGET 900

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);

// the side's groups: everything with a picture that a player does not lead
private _groups = allGroups select {
    (side _x) isEqualTo _side
    && {!isNull leader _x}
    && {!isPlayer leader _x}
    && {!isNil {_x getVariable QLGVAR(danger,picture)}}
    && {((units _x) findIf {isPlayer _x}) isEqualTo -1}
};
_state set ["groups", _groups];

[_side] call FUNC(board);
[_side] call FUNC(influence);
[_side] call FUNC(pacing);
[_side] call FUNC(routes);
[_side] call FUNC(counterBattery);

// defended ground that fell: the defender is gone or has left it, and the enemy is reported on it
private _fallen = _state get "fallen";
{
    private _group = _x;
    private _intent = [_group] call LFUNC(danger,intentGet);
    _intent params ["_mode", "_objective", "_radius"];
    if (_mode in ["hold", "defend"] && {_objective isNotEqualTo []}) then {
        private _key = mapGridPosition _objective;
        if (isNil {_fallen get _key}) then {
            private _alive = (units _group) select {_x call LFUNC(main,isAlive)};
            private _held = (_alive findIf {_x distance2D _objective < _radius}) isNotEqualTo -1;
            private _enemyOnIt = ((_state get "board") findIf {(_x select 0) distance2D _objective < _radius && {(_x select 2) >= 0.4}}) isNotEqualTo -1;
            if (!_held && {_enemyOnIt || {_alive isEqualTo []}}) then {
                _fallen set [_key, [_objective, _radius, time, _group, false]];
                [_side, format ["%1 lost %2", groupId _group, _key]] call FUNC(log);
            };
        };
    };
} forEach _groups;
{
    if (time - (_y select 2) > FALLEN_FORGET) then {_fallen deleteAt _x;};
} forEach +_fallen;

[_side] call FUNC(reinforce);
[_side, [], 100, false] call FUNC(counterattack);
[_side] call FUNC(fireMissions);
_state set ["lastThink", time];
