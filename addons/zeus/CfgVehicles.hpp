class CBA_Extended_EventHandlers_base;
class CfgVehicles {
    class Module_F;

    // one intent per drop: free, hold, defend, attack, reserve (docs/systems/zeus.md)
    class GVAR(ModuleIntent): Module_F {
        author = "bluefield-creator";
        _generalMacro = QGVAR(ModuleIntent);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_Intent_DisplayName);
        isGlobal = 0;
        category = "HOSTIS_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\defend_ca.paa";
        function = QFUNC(moduleIntent);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call LFUNC(main,initModules));
            };
        };
    };

    // the Director's dials: throttle, budgets, area of operations, the pause
    class GVAR(ModuleDirector): Module_F {
        author = "bluefield-creator";
        _generalMacro = QGVAR(ModuleDirector);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_Director_DisplayName);
        isGlobal = 0;
        category = "HOSTIS_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleDirector);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call LFUNC(main,initModules));
            };
        };
    };

    class GVAR(ModuleFireMission): Module_F {
        author = "bluefield-creator";
        _generalMacro = QGVAR(ModuleFireMission);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_FireMission_DisplayName);
        isGlobal = 0;
        category = "HOSTIS_Cat";
        icon = "\a3\ui_f\data\IGUI\Cfg\simpleTasks\types\destroy_ca.paa";
        function = QFUNC(moduleFireMission);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call LFUNC(main,initModules));
            };
        };
    };

    class GVAR(ModuleRelease): Module_F {
        author = "bluefield-creator";
        _generalMacro = QGVAR(ModuleRelease);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_Release_DisplayName);
        isGlobal = 0;
        category = "HOSTIS_Cat";
        icon = "\a3\ui_f\data\GUI\Cfg\CommunicationMenu\attack_ca.paa";
        function = QFUNC(moduleRelease);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call LFUNC(main,initModules));
            };
        };
    };

    class GVAR(ModuleOverlay): Module_F {
        author = "bluefield-creator";
        _generalMacro = QGVAR(ModuleOverlay);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_Overlay_DisplayName);
        isGlobal = 0;
        category = "HOSTIS_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleOverlay);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call LFUNC(main,initModules));
            };
        };
    };

    class GVAR(ModulePause): Module_F {
        author = "bluefield-creator";
        _generalMacro = QGVAR(ModulePause);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_Pause_DisplayName);
        isGlobal = 0;
        category = "HOSTIS_Cat";
        icon = "\a3\3DEN\Data\CfgWaypoints\Hold_ca.paa";
        function = QFUNC(modulePause);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call LFUNC(main,initModules));
            };
        };
    };
};
