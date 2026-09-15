#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Toggles the curator overlay on this client: a label over every commander-run group
 * near the Zeus camera with its intent, escalation, cohesion, running tactic and contact
 * count, and a line to its threat centre. The data comes from the server every
 * overlayInterval seconds (fnc_snapshot); the drawing is a Draw3D handler.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * overlay now on <BOOL>
 *
 * Example:
 * call hostis_zeus_fnc_overlay;
 *
 * Public: Yes
*/
if (!hasInterface) exitWith {false};

GVAR(overlayOn) = !GVAR(overlayOn);
if (GVAR(overlayOn)) then {
    GVAR(overlayDrawHandle) = addMissionEventHandler ["Draw3D", {call FUNC(overlayDraw);}];
    [{
        params ["", "_handle"];
        if (!GVAR(overlayOn)) exitWith {[_handle] call CBA_fnc_removePerFrameHandler;};
        private _camera = curatorCamera;
        private _pos = if (isNull _camera) then {positionCameraToWorld [0, 0, 0]} else {getPosATL _camera};
        [QGVAR(snapshotRequest), [clientOwner, _pos, GVAR(overlayRange)]] call CBA_fnc_serverEvent;
    }, GVAR(overlayInterval)] call CBA_fnc_addPerFrameHandler;
} else {
    removeMissionEventHandler ["Draw3D", GVAR(overlayDrawHandle)];
    GVAR(overlayData) = [];
};

[QLGVAR(danger,curatorFeedback), [format ["HOSTIS overlay %1", ["off", "on"] select GVAR(overlayOn)]], clientOwner] call CBA_fnc_targetEvent;
GVAR(overlayOn)
