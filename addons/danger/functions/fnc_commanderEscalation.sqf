#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * How serious things are for a group, on a scale the Zeus can cap:
 *   0 routine   nothing known
 *   1 alert     a contact was reported nearby or seen a while ago
 *   2 engaged   enemy seen in the last half minute
 *   3 decisive  taking losses, under close fire, or ordered to attack
 * Rises at once, falls one level per minute of quiet. Stored in the picture.
 *
 * Arguments:
 * 0: Group <GROUP>
 * 1: Combat picture <HASHMAP>
 *
 * Return Value:
 * escalation level <NUMBER>
 *
 * Example:
 * [group bob, [group bob] call lambs_danger_fnc_pictureGet] call lambs_danger_fnc_commanderEscalation;
 *
 * Public: No
*/
#define ENGAGED_AGE 30
#define ALERT_AGE 180
#define CLOSE_FIRE 120
#define DECISIVE_LOSSES 2
#define DECISIVE_STRESS 0.4
#define DECAY_TIME 60

params [["_group", grpNull, [grpNull]], ["_picture", createHashMap, [createHashMap]]];

private _leader = leader _group;
private _age = time - (_picture get "lastContact");
private _threatPos = _picture get "threatPos";
private _intent = [_group] call FUNC(intentGet);

private _level = 0;
if (_age < ALERT_AGE || {(_group getVariable [QGVAR(alertTime), -1e9]) > time - ALERT_AGE}) then {_level = 1;};
if (_age < ENGAGED_AGE) then {_level = 2;};
if (
    _level isEqualTo 2
    && {
        (_picture get "losses") >= DECISIVE_LOSSES
        || {(_intent select 0) isEqualTo "attack"}
        || {_threatPos isNotEqualTo [] && {_leader distance2D _threatPos < CLOSE_FIRE} && {(_leader call EFUNC(main,getStress)) > DECISIVE_STRESS}}
    }
) then {_level = 3;};

// falls slowly, rises at once
private _old = _picture getOrDefault ["escalation", 0];
private _oldTime = _picture getOrDefault ["escalationTime", -1e9];
if (_level < _old) then {
    if (time - _oldTime < DECAY_TIME) then {_level = _old;} else {_level = _old - 1;};
};

// the Zeus decides how real this gets
_level = _level min (_intent select 4);

if (_level isNotEqualTo _old) then {
    _picture set ["escalation", _level];
    _picture set ["escalationTime", time];
    _picture set ["escalationPrev", _old];
};

_level
