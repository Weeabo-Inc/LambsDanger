/*
    HOSTIS load test (docs/systems/performance.md, tests/load.Stratis/README.md)

    Thirty squads of six, four APCs with crews and a mortar team around the player: two
    hundred AI. Half the squads defend where they stand, half are free (the reserve pool).
    Forces the performance log on; every machine writes HOSTIS PERF slices every 30 s.
*/
if (!isServer) exitWith {};

["hostis_core_debugPerformance", true, true, "mission"] call CBA_settings_fnc_set;

[{
    private _player = (allPlayers select {alive _x}) param [0, objNull];
    if (isNull _player) exitWith {};
    private _origin = getPosATL _player;

    private _fnc_spawnSquad = {
        params ["_name", "_pos", "_dir"];
        private _group = createGroup [east, true];
        {
            private _unit = _group createUnit [_x, _pos getPos [3 * _forEachIndex, _dir + 90], [], 0, "NONE"];
            _unit setDir _dir;
        } forEach ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_GL_F", "O_Soldier_F", "O_Soldier_F", "O_medic_F"];
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setGroupIdGlobal [_name];
        _group
    };

    // thirty squads on three rings, 400, 800 and 1200 m, ten per ring, facing the player
    private _squads = [];
    {
        private _range = _x;
        for "_i" from 0 to 9 do {
            private _bearing = _i * 36 + (_forEachIndex * 12);
            private _pos = _origin getPos [_range, _bearing];
            private _group = [format ["hostis_load_%1_%2", _forEachIndex, _i], _pos, _bearing + 180] call _fnc_spawnSquad;
            if (_i mod 2 isEqualTo 0) then {
                [_group, "defend", _pos, 100, 1] call lambs_danger_fnc_intentSet;
            } else {
                [_group, "free", [], 100, 1] call lambs_danger_fnc_intentSet;
            };
            _squads pushBack _group;
        };
    } forEach [400, 800, 1200];

    // four APCs on the 800 m ring, crewed
    private _vehicles = [];
    {
        private _pos = _origin getPos [800, _x];
        private _apc = createVehicle ["O_APC_Wheeled_02_rcws_v2_F", _pos, [], 0, "NONE"];
        _apc setDir (_x + 180);
        private _crew = createGroup [east, true];
        private _driver = _crew createUnit ["O_crew_F", _pos getPos [5, 90], [], 0, "NONE"];
        private _gunner = _crew createUnit ["O_crew_F", _pos getPos [8, 90], [], 0, "NONE"];
        _driver moveInDriver _apc;
        _gunner moveInGunner _apc;
        _crew setGroupIdGlobal [format ["hostis_load_apc_%1", _forEachIndex]];
        [_crew, "hold", _pos, 60, 1] call lambs_danger_fnc_intentSet;
        _vehicles pushBack _apc;
    } forEach [45, 135, 225, 315];

    // the mortar team, registered as the side's artillery
    private _mortarPos = _origin getPos [1500, 0];
    private _mortar = createVehicle ["O_Mortar_01_F", _mortarPos, [], 0, "NONE"];
    private _mortarGroup = createGroup [east, true];
    private _gunner = _mortarGroup createUnit ["O_Soldier_F", _mortarPos getPos [3, 90], [], 0, "NONE"];
    _gunner moveInGunner _mortar;
    _mortarGroup setGroupIdGlobal ["hostis_load_mortar"];
    [_mortarGroup] call lambs_wp_fnc_taskArtilleryRegister;

    private _ai = {side _x isEqualTo east && {!isPlayer _x}} count allUnits;
    diag_log format ["HOSTIS TEST start: %1 OPFOR AI in %2 squads, %3 APCs, one mortar, rings at 400, 800 and 1200 m around %4", _ai, count _squads, count _vehicles, mapGridPosition _origin];

    [{
        params ["_args"];
        _args params ["_player"];
        private _alive = {side _x isEqualTo east && {!isPlayer _x} && {alive _x}} count allUnits;
        private _inContact = {!isNil {_x getVariable "lambs_danger_picture"} && {time - ((_x getVariable "lambs_danger_picture") getOrDefault ["lastContact", -1e9]) < 60}} count allGroups;
        diag_log format ["HOSTIS TEST player at %1 | OPFOR alive %2 | groups in contact %3 | fps %4", mapGridPosition _player, _alive, _inContact, round diag_fps];
    }, 30, [_player]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
