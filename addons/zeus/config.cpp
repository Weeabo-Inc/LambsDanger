#include "script_component.hpp"
class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {QGVAR(ModuleIntent), QGVAR(ModuleDirector), QGVAR(ModuleFireMission), QGVAR(ModuleRelease), QGVAR(ModuleOverlay), QGVAR(ModulePause)};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"cba_main", "lambs_main", "lambs_danger", "lambs_wp", "hostis_core", "hostis_squad", "hostis_director"};
        author = "bluefield-creator";
        VERSION_CONFIG;
    };
};

#include "CfgEventHandlers.hpp"
#include "CfgFactionClasses.hpp"
#include "CfgVehicles.hpp"
#include "CfgWaypoints.hpp"
#include "ZEN_CfgContext.hpp"
#include "ZEN_CfgWaypointTypes.hpp"
