#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"

// mod check
GVAR(Loaded_WP) = isClass (configFile >> "CfgPatches" >> "lambs_wp");

#include "settings.inc.sqf"

// FSM priorities ~ this could be made into CBA settings. But I kinda want to explore it a little first - nkenny
if (isNil QGVAR(fsmPriorities)) then {
    GVAR(fsmPriorities) = [
        2,      // DCEnemyDetected
        1,      // DCFire
        9,      // DCHit
        4,      // DCEnemyNear
        3,      // DCExplosion
        6,      // DCDeadBodyGroup
        3,      // DCDeadBody
        5,      // DCScream
        8,      // DCCanFire
        7,      // DCBulletClose
        0       // LAMBS Assess
    ];
};

// FSM setting ~ minimum time for danger to last
if (isNil QGVAR(dangerUntil)) then {
    GVAR(dangerUntil) = 3;
};

// EH handling reinforcement and combat mode
[QEGVAR(main,OnInformationShared), {
    params [["_unit", objNull], "", ["_target", objNull], ["_groups", []]];
    {
        private _leader = leader _x;
        if (local _leader) then {
            // reinforce ~ never while a Zeus directs the group
            if (
                !isNull _target
                && {_x getVariable [QGVAR(enableGroupReinforce), false]}
                && {(_x getVariable [QGVAR(enableGroupReinforceTime), -1]) < time }
                && {!(_x call EFUNC(main,isDirected))}
            ) then {
                
                // get pos of enemy if available
                private _pos = [getPosASL _unit, (_unit targetKnowledge _target) select 6] select (_unit knowsAbout _target > 1.5);

                // check for zero pos
                if (_pos isEqualTo [0, 0, 0]) then {_pos = getPosASL _unit;};
                
                // find free space
                private _adjustPos = _pos findEmptyPosition [5, 35, "Land_BagBunker_Large_F"];
                if (_adjustPos isNotEqualTo []) then {_pos = _adjustPos;};
                [_leader, _pos] call FUNC(tacticsReinforce);
            };

            // reorientate group
            if (
                !(_leader getVariable [QGVAR(disableAI), false])
                && {(behaviour _leader) isNotEqualTo "COMBAT"}
            ) then {
                //[units _x, _target, [_leader, 40, true, true] call EFUNC(main,findBuildings), "information"] call EFUNC(main,doGroupHide);
                _x setFormDir (_leader getDir _unit);
            };
        };
    } forEach (_groups select {(side _x) isEqualTo (side _unit)});
}] call CBA_fnc_addEventHandler;

// Zeus directed moves ~ raised on the curator client, handled on the group owner
[QGVAR(directedMove), {
    _this call FUNC(directedMoveSet);
}] call CBA_fnc_addEventHandler;

[QGVAR(directedDeleted), {
    _this call FUNC(directedMoveDeleted);
}] call CBA_fnc_addEventHandler;

[QGVAR(directedRelease), {
    _this call FUNC(directedMoveRelease);
}] call CBA_fnc_addEventHandler;

[QGVAR(diagnose), {
    params [["_group", grpNull, [grpNull]], ["_curatorOwner", -1, [0]]];
    if (isNull _group || {!local _group} || {_curatorOwner < 0}) exitWith {};
    [QGVAR(diagnoseResult), [groupId _group, _group call FUNC(directedMoveDiagnose)], _curatorOwner] call CBA_fnc_ownerEvent;
}] call CBA_fnc_addEventHandler;

// feedback for curators ~ handled on the curator client
[QGVAR(curatorFeedback), {
    params [["_text", "", [""]]];
    if (isNull (findDisplay 312)) then {
        systemChat _text;
    } else {
        [objNull, _text] call BIS_fnc_showCuratorFeedbackMessage;
    };
}] call CBA_fnc_addEventHandler;

[QGVAR(diagnoseResult), {
    params [["_groupId", "", [""]], ["_text", "", [""]]];
    hintSilent parseText _text;
    private _plain = _text regexReplace ["<[^>]+>", ""];
    copyToClipboard (_plain regexReplace ["<br/>", endl]);
    diag_log text format ["LAMBS diagnose %1: %2", _groupId, _plain];
    systemChat format ["LAMBS: diagnosis of %1 shown in hint and copied to clipboard", _groupId];
}] call CBA_fnc_addEventHandler;

ADDON = true;
