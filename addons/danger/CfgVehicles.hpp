class CBA_Extended_EventHandlers_base;
class CfgVehicles {
    class CAManBase;
    class SoldierWB: CAManBase {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_danger.fsm));
    };
    class SoldierEB: CAManBase {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_danger.fsm));
    };
    class SoldierGB: CAManBase {
        fsmDanger = QUOTE(PATHTOF2_SYS(PREFIX,COMPONENT,scripts\lambs_danger.fsm));
    };
    // civilians keep the engine FSM: HOSTIS never runs a non-hostile side (ADR-0006)

    class Module_F;

    class GVAR(SetRadio) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(SetRadio);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_SetRadio_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleSetRadio);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(DisableAI) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(DisableAI);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_DisableAI_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleDisableAI);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(ConfigureGroupAI) : Module_F {
        _generalMacro = QGVAR(ConfigureGroupAI);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_ConfigureGroupAI_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleConfigureGroupAI);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(DirectedMove) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(DirectedMove);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_DirectedMove_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\a3\3den\Data\CfgWaypoints\move_ca.paa";
        function = QFUNC(moduleDirectedMove);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(Posture) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(Posture);
        scope = 1;
        scopeCurator = 2;
        // the function expects the CBA ["init", ...] form that initModules only sends with is3DEN
        is3DEN = 1;
        displayName = CSTRING(Module_Posture_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\defend_ca.paa";
        function = QFUNC(modulePosture);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };

    class GVAR(Diagnose) : Module_F {
        author = "LAMBS Dev Team";
        _generalMacro = QGVAR(Diagnose);
        scope = 1;
        scopeCurator = 2;
        displayName = CSTRING(Module_Diagnose_DisplayName);
        isGlobal = 0;
        category = "Lambs_Danger_Cat";
        icon = "\A3\ui_f\data\igui\cfg\simpleTasks\types\intel_ca.paa";
        function = QFUNC(moduleDiagnose);
        class EventHandlers {
            class CBA_Extended_EventHandlers: CBA_Extended_EventHandlers_base {};
            class ADDON {
                init = QUOTE(call EFUNC(main,initModules));
            };
        };
    };
};
