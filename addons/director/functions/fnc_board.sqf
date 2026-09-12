#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The Director's board: the enemy as the side's groups have reported him, clustered.
 * Built from the groups' pictures only, never from the engine (ADR-0004, C-28). A cluster
 * is [position, strength, confidence, age, reporters, error].
 *
 * Arguments:
 * 0: Side <SIDE>
 *
 * Return Value:
 * clusters <ARRAY>
 *
 * Example:
 * [east] call hostis_director_fnc_board;
 *
 * Public: No
*/
#define CLUSTER_RANGE 150
#define CONTACT_AGE 120
#define MIN_CONFIDENCE 0.25

params [["_side", sideUnknown, [sideUnknown]]];

private _state = [_side] call FUNC(sideState);
private _clusters = [];
{
    private _group = _x;
    {
        private _pos = _x select CONTACT_POS;
        private _index = _clusters findIf {(_x select 0) distance2D _pos < CLUSTER_RANGE};
        if (_index isEqualTo -1) then {
            _clusters pushBack [_pos, _x select CONTACT_STRENGTH, _x select CONTACT_CONF, time - (_x select CONTACT_TIME), [_group], _x select CONTACT_ERROR];
        } else {
            private _cluster = _clusters select _index;
            private _weight = _x select CONTACT_CONF;
            private _total = (_cluster select 2) + _weight;
            _cluster set [0, ((_cluster select 0) vectorMultiply ((_cluster select 2) / (_total max 0.01))) vectorAdd (_pos vectorMultiply (_weight / (_total max 0.01)))];
            _cluster set [1, (_cluster select 1) + (_x select CONTACT_STRENGTH)];
            _cluster set [2, (_cluster select 2) max _weight];
            _cluster set [3, (_cluster select 3) min (time - (_x select CONTACT_TIME))];
            (_cluster select 4) pushBackUnique _group;
            _cluster set [5, (_cluster select 5) min (_x select CONTACT_ERROR)];
        };
    } forEach ([_group, CONTACT_AGE, MIN_CONFIDENCE] call EFUNC(core,contactsGet));
} forEach (_state get "groups");

_state set ["board", _clusters];
_clusters
