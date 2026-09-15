#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * The overlay's Draw3D handler: one label per snapshot row above the group's leader,
 * coloured by escalation, and a line to the threat centre when the group has one.
 *
 * Arguments:
 * None
 *
 * Return Value:
 * None
 *
 * Example:
 * call hostis_zeus_fnc_overlayDraw;
 *
 * Public: No
*/
private _paused = missionNamespace getVariable [QEGVAR(squad,paused), false];
{
    _x params ["_leader", "_id", "_mode", "_escalation", "_cohesion", "_tactic", "_contacts", "_threat", "_alive"];
    if (!isNull _leader) then {
        private _pos = _leader modelToWorldVisual [0, 0, 2.6];
        private _color = ESCALATION_COLORS select ((_escalation max 0) min 3);
        private _text = format ["%1 [%2] %3 | %4%5 | %6 | %7 contacts", _id, _alive, _mode, _cohesion, ["", " PAUSED"] select _paused, _tactic, _contacts];
        drawIcon3D ["", _color, _pos, 0, 0, 0, _text, 1, 0.035, "PuristaMedium", "center"];
        if (_threat isNotEqualTo []) then {
            drawLine3D [_pos, [_threat select 0, _threat select 1, (_threat select 2) + 1.5], [_color select 0, _color select 1, _color select 2, 0.5]];
        };
    };
} forEach GVAR(overlayData);
