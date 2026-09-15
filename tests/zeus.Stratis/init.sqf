/*
    HOSTIS zeus test (docs/systems/zeus.md, tests/zeus.Stratis/README.md)

    Makes the player a Zeus, places three OPFOR squads, and prints every squad's intent,
    tactic and escalation every 10 s together with the Director's first report line.
*/
if (!isServer) exitWith {};

[{
    private _player = (allPlayers select {alive _x}) param [0, objNull];
    if (isNull _player) exitWith {};
    private _origin = getPosATL _player;

    // the player holds the reins
    private _curator = (createGroup sideLogic) createUnit ["ModuleCurator_F", [0, 0, 0], [], 0, "NONE"];
    _curator setVariable ["Addons", 3, true];
    _curator setVariable ["Owner", name _player, true];
    _player assignCurator _curator;

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

    private _alpha = ["hostis_alpha", _origin getPos [300, 0], 180] call _fnc_spawnSquad;
    private _bravo = ["hostis_bravo", _origin getPos [300, 45], 225] call _fnc_spawnSquad;
    private _charlie = ["hostis_charlie", _origin getPos [800, 0], 180] call _fnc_spawnSquad;
    {[_x, "free", [], 100, 1] call lambs_danger_fnc_intentSet;} forEach [_alpha, _bravo, _charlie];

    diag_log format ["HOSTIS TEST start: %1 is Zeus; Alpha 300 m N, Bravo 300 m NE, Charlie 800 m N (reserve)", name _player];

    [{
        params ["_args"];
        _args params ["_groups"];
        private _parts = _groups apply {
            private _intent = [_x] call lambs_danger_fnc_intentGet;
            private _picture = [_x] call hostis_core_fnc_pictureGet;
            private _tactic = [_x] call hostis_squad_fnc_tacticRunning;
            format ["%1=%2/%3/esc %4", groupId _x, _intent select 0, [_tactic get "name", "-"] select (isNil "_tactic"), _picture getOrDefault ["escalation", 0]]
        };
        diag_log format ["HOSTIS TEST intents: %1, paused %2", _parts joinString ", ", missionNamespace getVariable ["hostis_squad_paused", false]];
        diag_log ("HOSTIS TEST director " + (([east] call hostis_director_fnc_report) select 0));
    }, 10, [[_alpha, _bravo, _charlie]]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
