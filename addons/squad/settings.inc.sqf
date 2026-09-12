private _curCat = LSTRING(Settings_TacticsCat);

[
    QGVAR(enabled),
    "CHECKBOX",
    [LSTRING(Settings_Enabled), LSTRING(Settings_Enabled_ToolTip)],
    [COMPONENT_NAME, _curCat],
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(tacticCooldown),
    "SLIDER",
    [LSTRING(Settings_TacticCooldown), LSTRING(Settings_TacticCooldown_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 120, 20, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(flankOffset),
    "SLIDER",
    [LSTRING(Settings_FlankOffset), LSTRING(Settings_FlankOffset_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [40, 250, 100, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(ambushRange),
    "SLIDER",
    [LSTRING(Settings_AmbushRange), LSTRING(Settings_AmbushRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [50, 400, 150, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(searchTime),
    "SLIDER",
    [LSTRING(Settings_SearchTime), LSTRING(Settings_SearchTime_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [30, 600, 120, 0],
    1
] call CBA_fnc_addSetting;

_curCat = LSTRING(Settings_DebugCat);

[
    QGVAR(debug),
    "CHECKBOX",
    [LSTRING(Settings_Debug), LSTRING(Settings_Debug_ToolTip)],
    [COMPONENT_NAME, _curCat],
    false,
    1
] call CBA_fnc_addSetting;
