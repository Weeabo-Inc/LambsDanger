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
// a mortar or gun fired by a player is a thing the side can locate (counter-battery, C-54)
class Extended_Fired_EventHandlers {
    class StaticMortar {
        class ADDON {
            fired = QUOTE(_this call FUNC(firedArtillery));
        };
    };
    class Tank {
        class ADDON {
            fired = QUOTE(_this call FUNC(firedArtillery));
        };
    };
};
