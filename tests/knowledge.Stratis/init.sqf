/*
    HOSTIS knowledge test (docs/systems/knowledge.md, tests/knowledge.Stratis/README.md)

    Places two OPFOR squads relative to the player and prints both pictures to the RPT
    every 10 s. Runs on the server (or the host); the player only has to be there.
*/
if (!isServer) exitWith {};

[{
    // the one player
    private _player = (allPlayers select {alive _x}) param [0, objNull];
    if (isNull _player) exitWith {};

    private _origin = getPosATL _player;
    private _fnc_spawnSquad = {
        params ["_name", "_pos", "_dir", "_radio"];
        private _group = createGroup [east, true];
        for "_i" from 0 to 3 do {
            private _unit = _group createUnit ["O_Soldier_F", _pos getPos [2 * _i, _dir + 90], [], 0, "NONE"];
            _unit setDir _dir;
            _unit setUnitPos "MIDDLE";
        };
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setFormDir _dir;
        if (_radio) then {(leader _group) addBackpack "B_RadioBag_01_black_F";};
        _group setGroupIdGlobal [_name];
        missionNamespace setVariable [_name, _group, true];
        _group
    };

    private _near = [
        "hostis_near",
        _origin getPos [250, 45],
        225,
        true
    ] call _fnc_spawnSquad;
    private _far = [
        "hostis_far",
        _origin getPos [700, 0],
        180,
        true
    ] call _fnc_spawnSquad;

    diag_log format ["HOSTIS TEST start: player %1, near squad %2 at 250 m, far squad %3 at 700 m", name _player, groupId _near, groupId _far];

    // every shot the player fires goes in the RPT, so the timeline reads back
    _player addEventHandler ["FiredMan", {
        params ["_unit"];
        diag_log format ["HOSTIS TEST player fired at %1, near leader %2 m away, knowsAbout %3", mapGridPosition _unit, round (_unit distance2D leader hostis_near), (leader hostis_near) knowsAbout _unit];
    }];

    // print both pictures every 10 s
    [{
        params ["_args"];
        _args params ["_player", "_near", "_far"];
        {
            private _lines = [_x] call hostis_core_fnc_pictureReport;
            private _picture = [_x] call hostis_core_fnc_pictureGet;
            private _threatPos = _picture get "threatPos";
            private _threatText = if (_threatPos isEqualTo []) then {"-"} else {round (_threatPos distance2D _player)};
            diag_log format ["HOSTIS TEST picture %1 (threat centre %2 m from the player's true position)", groupId _x, _threatText];
            {diag_log ("HOSTIS TEST   " + _x);} forEach _lines;
        } forEach [_near, _far];
        diag_log format ["HOSTIS TEST knowsAbout: near leader %1, far leader %2, engineReveal %3, player %4 m from near, %5 m from far", (leader _near) knowsAbout _player, (leader _far) knowsAbout _player, hostis_core_engineReveal, round (_player distance2D leader _near), round (_player distance2D leader _far)];
    }, 10, [_player, _near, _far]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
