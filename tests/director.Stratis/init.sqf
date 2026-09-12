/*
    HOSTIS director test (docs/systems/director.md, tests/director.Stratis/README.md)

    A defended point, two reserves, a mortar team, and a mortar for the player. Prints the
    Director's report every 10 s.
*/
if (!isServer) exitWith {};

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
        } forEach ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_GL_F", "O_medic_F"];
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setGroupIdGlobal [_name];
        missionNamespace setVariable [_name, _group, true];
        _group
    };

    // the compound: four bunkers around the defended point
    private _objective = _origin getPos [350, 0];
    {
        private _bunker = createVehicle ["Land_BagBunker_Small_F", _objective getPos [12, _x], [], 0, "CAN_COLLIDE"];
        _bunker setDir (_x + 180);
    } forEach [0, 90, 180, 270];

    private _hold = ["hostis_hold", _objective, 180] call _fnc_spawnSquad;
    [_hold, "defend", _objective, 80, 1] call lambs_danger_fnc_intentSet;
    [_hold, _objective, 80] call lambs_wp_fnc_taskDefend;

    private _res1 = ["hostis_res1", _origin getPos [800, 45], 225] call _fnc_spawnSquad;
    private _res2 = ["hostis_res2", _origin getPos [800, 315], 135] call _fnc_spawnSquad;
    {[_x, "free", [], 200, 1] call lambs_danger_fnc_intentSet;} forEach [_res1, _res2];

    // the mortar team, registered as the side's artillery
    private _mortarPos = _origin getPos [1200, 0];
    private _mortar = createVehicle ["O_Mortar_01_F", _mortarPos, [], 0, "NONE"];
    private _mortarGroup = createGroup [east, true];
    private _gunner = _mortarGroup createUnit ["O_Soldier_F", _mortarPos getPos [3, 90], [], 0, "NONE"];
    _gunner moveInGunner _mortar;
    _mortarGroup setGroupIdGlobal ["hostis_mortar"];
    [_mortarGroup] call lambs_wp_fnc_taskArtilleryRegister;

    // a mortar for the player, behind him
    private _playerMortar = createVehicle ["B_Mortar_01_F", _origin getPos [30, 180], [], 0, "NONE"];
    _playerMortar setDir 0;

    diag_log format ["HOSTIS TEST start: defenders at %1, reserves NE and NW at 800 m, OPFOR mortar at %2, your mortar 30 m behind you", mapGridPosition _objective, mapGridPosition _mortarPos];

    [{
        params ["_args"];
        _args params ["_player"];
        diag_log format ["HOSTIS TEST player at %1", mapGridPosition _player];
        {diag_log ("HOSTIS TEST director " + _x);} forEach ([east] call hostis_director_fnc_report);
    }, 10, [_player]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
