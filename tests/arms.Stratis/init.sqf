/*
    HOSTIS combined arms test (docs/systems/combined-arms.md, tests/arms.Stratis/README.md)

    Two squads (one without a grenadier), a CQB squad by a village, an APC, and for the
    player an armed helicopter and a mortar. Night. Prints the Director's report, the
    squads' pictures and their running tactic every 10 s.
*/
if (!isServer) exitWith {};

// night, for the illumination check
setDate [2035, 6, 24, 23, 0];

[{
    private _player = (allPlayers select {alive _x}) param [0, objNull];
    if (isNull _player) exitWith {};
    private _origin = getPosATL _player;

    private _fnc_spawnSquad = {
        params ["_name", "_pos", "_dir", "_classes"];
        private _group = createGroup [east, true];
        {
            private _unit = _group createUnit [_x, _pos getPos [3 * _forEachIndex, _dir + 90], [], 0, "NONE"];
            _unit setDir _dir;
        } forEach _classes;
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setGroupIdGlobal [_name];
        missionNamespace setVariable [_name, _group, true];
        _group
    };

    // two squads 300 m north: alpha with a grenadier, bravo without
    private _alpha = ["hostis_alpha", _origin getPos [300, 350], 170, ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_GL_F", "O_Soldier_F", "O_Soldier_F", "O_medic_F"]] call _fnc_spawnSquad;
    private _bravo = ["hostis_bravo", _origin getPos [300, 10], 190, ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_F", "O_medic_F"]] call _fnc_spawnSquad;
    {[_x, "defend", getPosATL leader _x, 100, 1] call lambs_danger_fnc_intentSet;} forEach [_alpha, _bravo];

    // the CQB squad, 600 m east, ready for a Zeus CQB task on the nearest houses
    private _cqb = ["hostis_cqb", _origin getPos [600, 90], 270, ["O_Soldier_SL_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_F"]] call _fnc_spawnSquad;
    [_cqb, "free", [], 100, 1] call lambs_danger_fnc_intentSet;

    // an APC 400 m north-east with a crew
    private _apcPos = _origin getPos [400, 45];
    private _apc = createVehicle ["O_APC_Wheeled_02_rcws_v2_F", _apcPos, [], 0, "NONE"];
    _apc setDir 225;
    private _crew = createGroup [east, true];
    private _driver = _crew createUnit ["O_crew_F", _apcPos getPos [5, 90], [], 0, "NONE"];
    private _gunner = _crew createUnit ["O_crew_F", _apcPos getPos [8, 90], [], 0, "NONE"];
    _driver moveInDriver _apc;
    _gunner moveInGunner _apc;
    _crew setGroupIdGlobal ["hostis_apc"];
    [_crew, "hold", _apcPos, 60, 1] call lambs_danger_fnc_intentSet;

    // for the player: an armed helicopter 60 m behind, a mortar 30 m behind
    private _heli = createVehicle ["B_Heli_Light_01_dynamicLoadout_F", _origin getPos [60, 180], [], 0, "NONE"];
    _heli setDir 0;
    private _mortar = createVehicle ["B_Mortar_01_F", _origin getPos [30, 180], [], 0, "NONE"];
    _mortar setDir 0;

    diag_log format ["HOSTIS TEST start: alpha at %1, bravo at %2, CQB squad at %3, APC at %4, your helicopter and mortar behind you, 23:00", mapGridPosition leader _alpha, mapGridPosition leader _bravo, mapGridPosition leader _cqb, mapGridPosition _apc];

    // the player's shots, for reading the hearing lines against
    _player addEventHandler ["FiredMan", {
        params ["_unit", "_weapon", "", "", "", "", "", "_vehicle"];
        private _platform = ["on foot", typeOf _vehicle] select (!isNull _vehicle);
        diag_log format ["HOSTIS TEST player fired %1 %2 at %3", _weapon, _platform, mapGridPosition _unit];
    }];

    [{
        params ["_args"];
        _args params ["_player", "_groups"];
        diag_log format ["HOSTIS TEST player at %1, hug flag %2", mapGridPosition _player, missionNamespace getVariable ["hostis_director_hug_EAST", false]];
        {diag_log ("HOSTIS TEST director " + _x);} forEach ([east] call hostis_director_fnc_report);
        {
            if (!isNull _x && {alive leader _x}) then {
                private _contacts = [_x, 30] call hostis_core_fnc_contactsGet;
                // record: [object, pos, time, knows, error, confidence, source, first, strength, type, ...]
                private _texts = _contacts apply {format ["%1 %2 x%3 err %4 at %5", _x select 6, _x select 9, _x select 8, round (_x select 4), mapGridPosition (_x select 1)]};
                diag_log format ["HOSTIS TEST %1: tactic %2, contacts %3", groupId _x, _x getVariable ["hostis_squad_tactic", "none"], _texts];
            };
        } forEach _groups;
    }, 10, [_player, [_alpha, _bravo, _cqb, _crew]]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
