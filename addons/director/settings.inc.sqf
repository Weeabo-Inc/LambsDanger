private _curCat = LSTRING(Settings_DirectorCat);

[
    QGVAR(enabled),
    "CHECKBOX",
    [LSTRING(Settings_Enabled), LSTRING(Settings_Enabled_ToolTip)],
    [COMPONENT_NAME, _curCat],
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(thinkInterval),
    "SLIDER",
    [LSTRING(Settings_ThinkInterval), LSTRING(Settings_ThinkInterval_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [5, 60, 10, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(throttle),
    "SLIDER",
    [LSTRING(Settings_Throttle), LSTRING(Settings_Throttle_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 1, 1, 2],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(relaxTime),
    "SLIDER",
    [LSTRING(Settings_RelaxTime), LSTRING(Settings_RelaxTime_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 180, 40, 0],
    1
] call CBA_fnc_addSetting;

_curCat = LSTRING(Settings_BudgetCat);

[
    QGVAR(reinforcements),
    "SLIDER",
    [LSTRING(Settings_Reinforcements), LSTRING(Settings_Reinforcements_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 20, 3, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(fireMissions),
    "SLIDER",
    [LSTRING(Settings_FireMissions), LSTRING(Settings_FireMissions_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 30, 4, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(reservePoolAuto),
    "CHECKBOX",
    [LSTRING(Settings_ReservePoolAuto), LSTRING(Settings_ReservePoolAuto_ToolTip)],
    [COMPONENT_NAME, _curCat],
    true,
    1
] call CBA_fnc_addSetting;

[
    QGVAR(reserveRange),
    "SLIDER",
    [LSTRING(Settings_ReserveRange), LSTRING(Settings_ReserveRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [200, 5000, 1500, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(counterattackDelay),
    "SLIDER",
    [LSTRING(Settings_CounterattackDelay), LSTRING(Settings_CounterattackDelay_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [10, 600, 90, 0],
    1
] call CBA_fnc_addSetting;

_curCat = LSTRING(Settings_FireCat);

[
    QGVAR(dangerClose),
    "SLIDER",
    [LSTRING(Settings_DangerClose), LSTRING(Settings_DangerClose_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [50, 600, 200, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(observerError),
    "SLIDER",
    [LSTRING(Settings_ObserverError), LSTRING(Settings_ObserverError_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [20, 300, 80, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(counterBatteryWindow),
    "SLIDER",
    [LSTRING(Settings_CounterBatteryWindow), LSTRING(Settings_CounterBatteryWindow_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [0, 1800, 600, 0],
    1
] call CBA_fnc_addSetting;

[
    QGVAR(counterBatteryDelay),
    "SLIDER",
    [LSTRING(Settings_CounterBatteryDelay), LSTRING(Settings_CounterBatteryDelay_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [30, 600, 180, 0],
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
