#include "script_component.hpp"
/*
 * Author: bluefield-creator
 * Ends a Zeus directed move and hands the group back to LAMBS.
 *
 * Arguments:
 * 0: Group, or a unit of the group <GROUP> or <OBJECT>
 * 1: Reason, used in feedback and debug output <STRING>
 *
 * Return Value:
 * true when a directed move was active <BOOL>
 *
 * Example:
 * [group bob, "completed"] call lambs_danger_fnc_directedMoveRelease;
 *
 * Public: Yes
*/
params [["_group", grpNull, [grpNull, objNull]], ["_reason", "", [""]]];

if (_group isEqualType objNull) then {_group = group _group;};
if (isNull _group) exitWith {false};

// watchdog
private _pfh = _group getVariable [QGVAR(directedPFH), -1];
if (_pfh isNotEqualTo -1) then {
    [_pfh] call CBA_fnc_removePerFrameHandler;
    _group setVariable [QGVAR(directedPFH), nil];
};

// state
private _state = _group getVariable [QGVAR(directedMove), []];
private _wasActive = _state isNotEqualTo [];

if (_wasActive && {local _group}) then {
    _state params ["_wpIndex", "", "", "_curatorOwner", "", "_prevAttackEnabled"];

    // group orders
    _group enableAttack _prevAttackEnabled;
    _group setVariable [QEGVAR(main,currentTactic), nil, EGVAR(main,debug_functions)];

    // strict mode switched the FSM off ~ only undo that where we did it
    {
        if (_x getVariable [QGVAR(directedStrict), false]) then {
            _x setVariable [QGVAR(disableAI), nil, true];
            _x setVariable [QGVAR(directedStrict), nil];
        };
        if (_x getVariable [QGVAR(directedAutoCombat), false]) then {
            _x enableAI "AUTOCOMBAT";
            _x setVariable [QGVAR(directedAutoCombat), nil];
        };
        _x setVariable [QEGVAR(main,currentTask), nil, EGVAR(main,debug_functions)];
    } forEach (units _group);

    // feedback
    [_curatorOwner, format [localize LSTRING(Feedback_Released), groupId _group, _wpIndex, _reason]] call FUNC(directedMoveFeedback);
    if (EGVAR(main,debug_functions)) then {
        ["%1 DIRECTED MOVE %2 released (%3)", side _group, groupId _group, _reason] call EFUNC(main,debugLog);
    };
};

_group setVariable [QGVAR(directedMove), nil, true];
_group setVariable [QGVAR(directedProgress), nil];

// end
_wasActive
