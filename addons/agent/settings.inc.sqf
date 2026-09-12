private _curCat = LSTRING(Settings_MoraleCat);

[
    QGVAR(morale),
    "CHECKBOX",
    [LSTRING(Settings_Morale), LSTRING(Settings_Morale_ToolTip)],
    [COMPONENT_NAME, _curCat],
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(suppressedLevel),
    "SLIDER",
    [LSTRING(Settings_SuppressedLevel), LSTRING(Settings_SuppressedLevel_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0.1, 0.9, 0.4, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(pinnedSuppression),
    "SLIDER",
    [LSTRING(Settings_PinnedSuppression), LSTRING(Settings_PinnedSuppression_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0.3, 1, 0.8, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(shakenStress),
    "SLIDER",
    [LSTRING(Settings_ShakenStress), LSTRING(Settings_ShakenStress_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0.2, 1, 0.6, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(brokenStress),
    "SLIDER",
    [LSTRING(Settings_BrokenStress), LSTRING(Settings_BrokenStress_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0.3, 1, 0.8, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(isolationRange),
    "SLIDER",
    [LSTRING(Settings_IsolationRange), LSTRING(Settings_IsolationRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [10, 200, 40, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(rallyRange),
    "SLIDER",
    [LSTRING(Settings_RallyRange), LSTRING(Settings_RallyRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [5, 100, 25, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(rallyTime),
    "SLIDER",
    [LSTRING(Settings_RallyTime), LSTRING(Settings_RallyTime_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [2, 60, 10, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(stateMinTime),
    "SLIDER",
    [LSTRING(Settings_StateMinTime), LSTRING(Settings_StateMinTime_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 20, 3, 0],
    1
] call CBA_fnc_addSetting;

_curCat = LSTRING(Settings_LegibilityCat);

[
    QGVAR(barks),
    "CHECKBOX",
    [LSTRING(Settings_Barks), LSTRING(Settings_Barks_ToolTip)],
    [COMPONENT_NAME, _curCat],
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(barkGroupCooldown),
    "SLIDER",
    [LSTRING(Settings_BarkGroupCooldown), LSTRING(Settings_BarkGroupCooldown_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 30, 1, 1],
    1
] call CBA_fnc_addSetting;

_curCat = LSTRING(Settings_DebugCat);

[
    QGVAR(debugMorale),
    "CHECKBOX",
    [LSTRING(Settings_DebugMorale), LSTRING(Settings_DebugMorale_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    1
] call CBA_fnc_addSetting;
