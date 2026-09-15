#define COMPONENT zeus
#define COMPONENT_BEAUTIFIED Zeus
#include "\z\hostis\addons\core\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE

#ifdef DEBUG_ENABLED_ZEUS
    #define DEBUG_MODE_FULL
#endif
#ifdef DEBUG_SETTINGS_ZEUS
    #define DEBUG_SETTINGS DEBUG_SETTINGS_ZEUS
#endif

#include "\z\hostis\addons\core\script_macros.hpp"

#define ZEUS_DEBUG (GVAR(debug) || {LGVAR(main,debug_functions)})
// the intents a Zeus can give, in dialog order (lambs_danger_fnc_intentGet)
#define INTENT_MODES ["free", "hold", "defend", "attack", "reserve"]
// overlay label colour by escalation: routine, alert, engaged, decisive
#define ESCALATION_COLORS [[0.8, 0.8, 0.8, 1], [1, 0.9, 0.3, 1], [1, 0.55, 0.1, 1], [1, 0.25, 0.25, 1]]
