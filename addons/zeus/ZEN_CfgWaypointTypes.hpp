// Zeus Enhanced waypoint types: the intents as waypoints
class ZEN_WaypointTypes {
    class GVAR(Hold) {
        displayName = CSTRING(Waypoint_Hold_DisplayName);
        type = "SCRIPTED";
        script = QPATHTOF(scripts\fnc_wpHold.sqf);
    };
    class GVAR(Defend) {
        displayName = CSTRING(Waypoint_Defend_DisplayName);
        type = "SCRIPTED";
        script = QPATHTOF(scripts\fnc_wpDefend.sqf);
    };
    class GVAR(Attack) {
        displayName = CSTRING(Waypoint_Attack_DisplayName);
        type = "SCRIPTED";
        script = QPATHTOF(scripts\fnc_wpAttack.sqf);
    };
    class GVAR(Reserve) {
        displayName = CSTRING(Waypoint_Reserve_DisplayName);
        type = "SCRIPTED";
        script = QPATHTOF(scripts\fnc_wpReserve.sqf);
    };
};
