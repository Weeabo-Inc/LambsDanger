/*
    HOSTIS contact test (docs/systems/tactics.md, tests/contact.Stratis/README.md)

    A six-man OPFOR squad 300 m north of the player in the open, aggressive; a second squad
    700 m north with a radio. Prints the running tactic of both every 5 s.
*/
if (!isServer) exitWith {};

[{
    private _player = (allPlayers select {alive _x}) param [0, objNull];
    if (isNull _player) exitWith {};

    private _origin = getPosATL _player;
    private _fnc_spawnSquad = {
        params ["_name", "_pos", "_dir", "_radio"];
        private _group = createGroup [east, true];
        {
            private _unit = _group createUnit [_x, _pos getPos [3 * _forEachIndex, _dir + 90], [], 0, "NONE"];
            _unit setDir _dir;
        } forEach ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_GL_F", "O_medic_F"];
        _group setBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setFormDir _dir;
        if (_radio) then {(leader _group) addBackpack "B_RadioBag_01_black_F";};
        _group setGroupIdGlobal [_name];
        missionNamespace setVariable [_name, _group, true];
        // free intent, aggressive posture, so the planner may close
        [_group, "free", [], 200, 2] call lambs_danger_fnc_intentSet;
        _group
    };
    private _near = ["hostis_near", _origin getPos [300, 0], 180, false] call _fnc_spawnSquad;
    private _far = ["hostis_far", _origin getPos [700, 0], 180, true] call _fnc_spawnSquad;
    diag_log format ["HOSTIS TEST start: player %1, near squad %2 at 300 m, far squad %3 at 700 m", name _player, groupId _near, groupId _far];

    [{
        params ["_args"];
        _args params ["_near", "_far"];
        {
            private _group = _x;
            private _state = [_group] call hostis_squad_fnc_tacticRunning;
            private _picture = [_group] call hostis_core_fnc_pictureGet;
            private _line = if (isNil "_state") then {"idle"} else {
                private _data = _state get "data";
                format ["%1 since %2 s%3", _state get "name", round (time - (_state get "since")),
                    ["", format [", phase %1, base %2, manoeuvre %3", _data getOrDefault ["phase", "-"], count (_data getOrDefault ["base", []]), count (_data getOrDefault ["maneuver", []])]] select ((_state get "name") isEqualTo "suppressAndFlank")]
            };
            private _log = _picture getOrDefault ["tacticLog", []];
            diag_log format ["HOSTIS TEST tactic %1: %2 | escalation %3, cohesion %4 | %5", groupId _group, _line, _picture getOrDefault ["escalation", 0], _picture getOrDefault ["cohesion", "steady"], (_log select [((count _log) - 3) max 0, 3]) joinString " ; "];
        } forEach [_near, _far];
    }, 5, [_near, _far]] call CBA_fnc_addPerFrameHandler;
}, [], 5] call CBA_fnc_waitAndExecute;
