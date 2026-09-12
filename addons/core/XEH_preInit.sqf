#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
#include "settings.inc.sqf"

// every group that has a picture, for the debug draw
GVAR(pictures) = [];

// a report from another group arrives on this group's owner (docs/systems/knowledge.md, The net)
[QGVAR(contactReport), {
    params [["_receiver", grpNull, [grpNull]], ["_payload", [], [[]]], ["_sender", grpNull, [grpNull]], ["_errorAdd", 0, [0]]];
    if (isNull _receiver || {!local _receiver}) exitWith {};

    private _picture = [_receiver] call FUNC(pictureGet);
    private _reports = _picture get "reports";
    _reports pushBack [time, _sender, count _payload];
    if (count _reports > 8) then {_reports deleteAt 0;};

    private _leader = leader _receiver;
    {
        if (count _x >= CONTACT_SIZE) then {
            private _ref = _x select CONTACT_REF;
            private _error = ((_x select CONTACT_ERROR) + _errorAdd) min GVAR(errorCap);
            [
                _receiver, objNull, _x select CONTACT_POS, "reported", _error, _x select CONTACT_CONF,
                _x select CONTACT_STRENGTH, _x select CONTACT_TYPE, _x select CONTACT_HEADING,
                _x select CONTACT_ACTIVITY, 0, _ref, _x select CONTACT_CHAIN
            ] call FUNC(contactReport);
            if (_x select CONTACT_DEAD) then {
                [_receiver, [_ref, _x select CONTACT_POS] select (isNull _ref)] call FUNC(contactDeath);
            };

            // the engine's own suspicion, so his men look that way ~ never above 1 (FAIRNESS R1)
            if (GVAR(engineReveal) && {!isNull _ref} && {!(_x select CONTACT_DEAD)} && {alive _ref} && {!isNull _leader} && {_leader knowsAbout _ref < 1}) then {
                _leader reveal [_ref, 1];
            };
        };
    } forEach _payload;

    if (LGVAR(main,debug_functions)) then {
        ["%1 KNOWLEDGE %2 received %3 contact(s) from %4 (+%5 m error)", side _receiver, groupId _receiver, count _payload, groupId _sender, round _errorAdd] call LFUNC(main,debugLog);
    };
}] call CBA_fnc_addEventHandler;

ADDON = true;
