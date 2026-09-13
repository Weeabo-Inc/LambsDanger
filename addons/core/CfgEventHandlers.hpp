class Extended_PreStart_EventHandlers {
    class ADDON {
        init = QUOTE(call COMPILE_SCRIPT(XEH_preStart));
    };
};
class Extended_PreInit_EventHandlers {
    class ADDON {
        init = QUOTE(call COMPILE_SCRIPT(XEH_preInit));
    };
};
class Extended_PostInit_EventHandlers {
    class ADDON {
        init = QUOTE(call COMPILE_SCRIPT(XEH_postInit));
    };
};
// every shot is heard by the enemy groups in range (ADR-0012)
class Extended_FiredMan_EventHandlers {
    class CAManBase {
        class ADDON {
            firedMan = QUOTE(_this call FUNC(hearing));
        };
    };
};
