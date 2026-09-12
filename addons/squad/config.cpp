#include "script_component.hpp"
class CfgPatches {
    class ADDON {
        name = COMPONENT_NAME;
        units[] = {};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"cba_main", "lambs_main", "hostis_core", "hostis_agent", "lambs_danger"};
        author = "bluefield-creator";
        VERSION_CONFIG;
    };
};

#include "CfgEventHandlers.hpp"
