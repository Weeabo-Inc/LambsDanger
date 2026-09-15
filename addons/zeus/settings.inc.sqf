private _curCat = LSTRING(Settings_OverlayCat);

[
    QGVAR(overlayRange),
    "SLIDER",
    [LSTRING(Settings_OverlayRange), LSTRING(Settings_OverlayRange_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [300, 5000, 1500, 0],
    0
] call CBA_fnc_addSetting;

[
    QGVAR(overlayInterval),
    "SLIDER",
    [LSTRING(Settings_OverlayInterval), LSTRING(Settings_OverlayInterval_ToolTip)],
    [COMPONENT_NAME, _curCat],
    [1, 10, 3, 0],
    0
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
