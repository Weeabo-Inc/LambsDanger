private _curCat = ELSTRING(main,Settings_MainCat);
// Toggle advanced danger.fsm features on player group
[
    QGVAR(disableAIPlayerGroup),
    "CHECKBOX",
    [LSTRING(Settings_DisableDangerFSM), LSTRING(Settings_DisableDangerFSM_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0         // players may configure their own preferences
] call CBA_fnc_addSetting;

// Toggle reaction state danger.fsm features on player group
[
    QGVAR(disableAIPlayerGroupReaction),
    "CHECKBOX",
    [LSTRING(Settings_DisableReactPlayerGroup), LSTRING(Settings_DisableReactPlayerGroup_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;

// Toggles group manoevure phase initiated by AI squad leader
[
    QGVAR(disableAIAutonomousManoeuvres),
    "CHECKBOX",
    [LSTRING(Settings_DisableGroupManoevures), LSTRING(Settings_DisableGroupManoevures_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;


// Toggles the concealment AI for units not equipped to damage tanks and aircraft
[
    QGVAR(disableAIHideFromTanksAndAircraft),
    "CHECKBOX",
    [LSTRING(Settings_DisableUnitsHiding), LSTRING(Settings_DisableUnitsHiding_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;


// Toggles units dynamically deploying static weapons
[
    QGVAR(disableAIDeployStaticWeapons),
    "CHECKBOX",
    [LSTRING(Settings_DisableStaticDeployment), LSTRING(Settings_DisableStaticDeployment_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;


// Toggles units dynamically find and using static weapons
[
    QGVAR(disableAIFindStaticWeapons),
    "CHECKBOX",
    [LSTRING(Settings_DisableStaticFinding), LSTRING(Settings_DisableStaticFinding_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;


// Toggles units self-use of smoke grenades for cover
[
    QGVAR(disableAutonomousSmokeGrenades),
    "CHECKBOX",
    [LSTRING(Settings_DisableAutonomousSmokeGrenades), LSTRING(Settings_DisableAutonomousSmokeGrenades_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;


// Toggles units self-use of flares for illumation
[
    QGVAR(disableAutonomousFlares),
    "CHECKBOX",
    [LSTRING(Settings_DisableAutonomousFlares), LSTRING(Settings_DisableAutonomousFlares_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    0
] call CBA_fnc_addSetting;


_curCat = LSTRING(Settings_GeneralCat);

// Range at which units consider themselves in CQB
[
    QGVAR(cqbRange),
    "SLIDER",
    [LSTRING(Settings_CQBRange), LSTRING(Settings_CQBRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [20, 150, 60, 0],
    1
] call CBA_fnc_addSetting;


// Chance of panic expressed as percentage
[
    QGVAR(panicChance),
    "SLIDER",
    [LSTRING(Settings_PanicChance), LSTRING(Settings_PanicChance_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 1, 0, 2, true],
    1
] call CBA_fnc_addSetting;

// Zeus
_curCat = LSTRING(Settings_ZeusCat);

// What a Zeus placed waypoint does to a LAMBS group
[
    QGVAR(zeusWaypointDiscipline),
    "LIST",
    [LSTRING(Settings_ZeusWaypointDiscipline), LSTRING(Settings_ZeusWaypointDiscipline_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [[0, 1, 2], [LSTRING(Settings_ZeusWaypointDiscipline_Off), LSTRING(Settings_ZeusWaypointDiscipline_Move), LSTRING(Settings_ZeusWaypointDiscipline_Strict)], 1],
    1
] call CBA_fnc_addSetting;

// Time after which a directed move is abandoned
[
    QGVAR(zeusWaypointTimeout),
    "SLIDER",
    [LSTRING(Settings_ZeusWaypointTimeout), LSTRING(Settings_ZeusWaypointTimeout_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [60, 1800, 600, 0],
    1
] call CBA_fnc_addSetting;

// Aggression
_curCat = LSTRING(Settings_AggressionCat);

// Stance and planning discipline
[
    QGVAR(aggression),
    "LIST",
    [LSTRING(Settings_Aggression), LSTRING(Settings_Aggression_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [[0, 1], [LSTRING(Settings_Aggression_Default), LSTRING(Settings_Aggression_Assertive)], 1],
    1
] call CBA_fnc_addSetting;

// Minimum time between two dodge reactions of the same unit
[
    QGVAR(dodgeCooldown),
    "SLIDER",
    [LSTRING(Settings_DodgeCooldown), LSTRING(Settings_DodgeCooldown_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 15, 6, 1],
    1
] call CBA_fnc_addSetting;

_curCat = LSTRING(Settings_CommanderCat);

// The group and side level commander
[
    QGVAR(commander),
    "CHECKBOX",
    [LSTRING(Settings_Commander), LSTRING(Settings_Commander_ToolTip)],
    [COMPONENT_NAME, _curCat],
    true,
    1
] call CBA_fnc_addSetting;

// Default posture of groups nobody has given an intent
[
    QGVAR(commanderPosture),
    "LIST",
    [LSTRING(Settings_CommanderPosture), LSTRING(Settings_CommanderPosture_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [[0, 1, 2], [LSTRING(Posture_Cautious), LSTRING(Posture_Balanced), LSTRING(Posture_Aggressive)], 1],
    1
] call CBA_fnc_addSetting;

// How many groups may close on one threat at the same time
[
    QGVAR(commanderMaxAssault),
    "SLIDER",
    [LSTRING(Settings_CommanderMaxAssault), LSTRING(Settings_CommanderMaxAssault_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [1, 6, 2, 0],
    1
] call CBA_fnc_addSetting;

// How far an idle group will travel to help a group asking for it
[
    QGVAR(commanderReinforceRange),
    "SLIDER",
    [LSTRING(Settings_CommanderReinforceRange), LSTRING(Settings_CommanderReinforceRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 2000, 600, 0],
    1
] call CBA_fnc_addSetting;

/*
TEMPORARILY DISABLED FOR VERSION 2.5 RELEASE
WAITING BETTER OR OTHER SOLUTION
nkenny

// Configures CQC formations
_curCat = LSTRING(Settings_CQBFormationsCat);
GVAR(allPossibleFormations) = ["COLUMN", "STAG COLUMN", "WEDGE", "ECH LEFT", "ECH RIGHT", "VEE", "LINE", "FILE", "DIAMOND"];
GVAR(CQB_formations) = ["FILE", "DIAMOND"];     // Special CQB Formations )

DFUNC(UpdateCQBFormations) = {
    params ["_args", "_formation"];
    _args params ["_value"];
    if (_value) then {
        GVAR(CQB_formations) pushBackUnique _formation;
    } else {
        private _index = GVAR(CQB_formations) find _formation;
        if (_index != -1) then {
            GVAR(CQB_formations) deleteAt _index;
        };
    };
};

{
    private _code = compile format ["
        [_this, %1] call %2;
    ", str _x, QFUNC(UpdateCQBFormations)];
    [
        format [QGVAR(CQB_formations_%1), _x],
        "CHECKBOX",
        [_x, format ["%1 %2", _x, LLSTRING(Settings_CQBFormation)]],
        [COMPONENT_NAME, _curCat],
        _x in GVAR(CQB_formations),
        1, _code
    ] call CBA_fnc_addSetting;
} forEach GVAR(allPossibleFormations);

*/
