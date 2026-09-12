private _curCat = LSTRING(Settings_KnowledgeCat);

// memory
[
    QGVAR(contactMaxAge),
    "SLIDER",
    [LSTRING(Settings_ContactMaxAge), LSTRING(Settings_ContactMaxAge_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [60, 1800, 600, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(confidenceHalfLife),
    "SLIDER",
    [LSTRING(Settings_ConfidenceHalfLife), LSTRING(Settings_ConfidenceHalfLife_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [5, 300, 45, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(confidenceFloor),
    "SLIDER",
    [LSTRING(Settings_ConfidenceFloor), LSTRING(Settings_ConfidenceFloor_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 0.5, 0.1, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(errorGrowth),
    "SLIDER",
    [LSTRING(Settings_ErrorGrowth), LSTRING(Settings_ErrorGrowth_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 5, 0.5, 1],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(errorCap),
    "SLIDER",
    [LSTRING(Settings_ErrorCap), LSTRING(Settings_ErrorCap_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [50, 1000, 300, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(storeCap),
    "SLIDER",
    [LSTRING(Settings_StoreCap), LSTRING(Settings_StoreCap_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [8, 64, 24, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(mergeRadius),
    "SLIDER",
    [LSTRING(Settings_MergeRadius), LSTRING(Settings_MergeRadius_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [5, 100, 20, 0],
    1
] call CBA_fnc_addSetting;

// senses
[
    QGVAR(sweepRange),
    "SLIDER",
    [LSTRING(Settings_SweepRange), LSTRING(Settings_SweepRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [200, 3000, 1200, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(sweepUnits),
    "SLIDER",
    [LSTRING(Settings_SweepUnits), LSTRING(Settings_SweepUnits_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 6, 2, 0],
    1
] call CBA_fnc_addSetting;

// the net
_curCat = LSTRING(Settings_NetCat);

[
    QGVAR(reportDelay),
    "SLIDER",
    [LSTRING(Settings_ReportDelay), LSTRING(Settings_ReportDelay_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 30, 3, 1],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(reportSpeed),
    "SLIDER",
    [LSTRING(Settings_ReportSpeed), LSTRING(Settings_ReportSpeed_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [10, 1000, 150, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(reportInterval),
    "SLIDER",
    [LSTRING(Settings_ReportInterval), LSTRING(Settings_ReportInterval_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [2, 60, 10, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(reportLossChance),
    "SLIDER",
    [LSTRING(Settings_ReportLossChance), LSTRING(Settings_ReportLossChance_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 0.9, 0.1, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(leaderlessFactor),
    "SLIDER",
    [LSTRING(Settings_LeaderlessFactor), LSTRING(Settings_LeaderlessFactor_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [1, 10, 3, 1],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(leaderlessTime),
    "SLIDER",
    [LSTRING(Settings_LeaderlessTime), LSTRING(Settings_LeaderlessTime_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 600, 120, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(engineReveal),
    "CHECKBOX",
    [LSTRING(Settings_EngineReveal), LSTRING(Settings_EngineReveal_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    1
] call CBA_fnc_addSetting;

// debug
_curCat = LSTRING(Settings_DebugCat);

[
    QGVAR(debugPicture),
    "CHECKBOX",
    [LSTRING(Settings_DebugPicture), LSTRING(Settings_DebugPicture_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    1
] call CBA_fnc_addSetting;
