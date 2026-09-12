/*
    HOSTIS morale test (docs/systems/morale.md, tests/morale.Stratis/README.md)

    Two OPFOR squads north of the player, the player carrying a machine gun. Prints every
    man's morale state, the group cohesion and aimingAccuracy every 5 s.
*/
if (!isServer) exitWith {};

[{
    private _player = (allPlayers select {alive _x}) param [0, objNull];
    if (isNull _player) exitWith {};

    // a machine gun and plenty for it
    removeAllWeapons _player;
    for "_i" from 1 to 8 do {_player addMagazine "200Rnd_65x39_cased_Box_Tracer";};
    _player addWeapon "arifle_MX_SW_F";
    _player addPrimaryWeaponItem "optic_Hamr";

    private _origin = getPosATL _player;
    private _fnc_spawnSquad = {
        params ["_name", "_pos", "_dir"];
        private _group = createGroup [east, true];
        for "_i" from 0 to 5 do {
            private _unit = _group createUnit ["O_Soldier_F", _pos getPos [3 * _i, _dir + 90], [], 0, "NONE"];
            _unit setDir _dir;
            _unit setUnitPos "MIDDLE";
        };
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setFormDir _dir;
        _group setGroupIdGlobal [_name];
        missionNamespace setVariable [_name, _group, true];
        _group
    };
    private _near = ["hostis_near", _origin getPos [200, 0], 180] call _fnc_spawnSquad;
    private _far = ["hostis_far", _origin getPos [600, 0], 180] call _fnc_spawnSquad;
    diag_log format ["HOSTIS TEST start: player %1 with %2, near squad %3 at 200 m, far squad %4 at 600 m", name _player, primaryWeapon _player, groupId _near, groupId _far];

    [{
        params ["_args"];
        _args params ["_near", "_far"];
        {
            private _group = _x;
            private _states = (units _group) apply {
                format ["%1=%2%3", name _x, (_x getVariable ["hostis_agent_morale", ["steady"]]) select 0, ["", "(dead)"] select (!alive _x)]
            };
            private _picture = [_group] call hostis_core_fnc_pictureGet;
            diag_log format ["HOSTIS TEST morale %1: cohesion %2, incoming %3/s | %4", groupId _group, _picture getOrDefault ["cohesion", "steady"], ([_group, 5] call hostis_core_fnc_fireIncoming) toFixed 1, _states joinString " "];
            diag_log format ["HOSTIS TEST accuracy %1: %2", groupId _group, ((units _group) apply {(_x skill "aimingAccuracy") toFixed 2}) joinString " "];
        } forEach [_near, _far];
    }, 5, [_near, _far]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
