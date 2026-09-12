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
// every shot a man fires stamps him, so an element's volume of fire can be counted (C-42, C-58)
class Extended_FiredMan_EventHandlers {
    class CAManBase {
        class ADDON {
            firedMan = QUOTE(_this call FUNC(firedMan));
        };
    };
};
