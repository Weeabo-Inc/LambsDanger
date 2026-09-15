// Eden waypoints: each one sets an intent at its position (docs/systems/zeus.md)
class CfgWaypoints {
    class HOSTIS {
        displayName = "HOSTIS";
        class GVAR(Hold) {
            displayName = CSTRING(Waypoint_Hold_DisplayName);
            displayNameDebug = QGVAR(Hold);
            file = QPATHTOF(scripts\fnc_wpHold.sqf);
            icon = "\a3\3DEN\Data\CfgWaypoints\Hold_ca.paa";
            tooltip = CSTRING(Waypoint_Hold_ToolTip);
        };
        class GVAR(Defend) {
            displayName = CSTRING(Waypoint_Defend_DisplayName);
            displayNameDebug = QGVAR(Defend);
            file = QPATHTOF(scripts\fnc_wpDefend.sqf);
            icon = "\a3\3DEN\Data\CfgWaypoints\Guard_ca.paa";
            tooltip = CSTRING(Waypoint_Defend_ToolTip);
        };
        class GVAR(Attack) {
            displayName = CSTRING(Waypoint_Attack_DisplayName);
            displayNameDebug = QGVAR(Attack);
            file = QPATHTOF(scripts\fnc_wpAttack.sqf);
            icon = "\a3\ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa";
            tooltip = CSTRING(Waypoint_Attack_ToolTip);
        };
        class GVAR(Reserve) {
            displayName = CSTRING(Waypoint_Reserve_DisplayName);
            displayNameDebug = QGVAR(Reserve);
            file = QPATHTOF(scripts\fnc_wpReserve.sqf);
            icon = "\a3\3DEN\Data\CfgWaypoints\Loiter_ca.paa";
            tooltip = CSTRING(Waypoint_Reserve_ToolTip);
        };
    };
};
