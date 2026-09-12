#define COMPONENT squad
#define COMPONENT_BEAUTIFIED Squad
#include "\z\hostis\addons\core\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE

#ifdef DEBUG_ENABLED_SQUAD
    #define DEBUG_MODE_FULL
#endif
#ifdef DEBUG_SETTINGS_SQUAD
    #define DEBUG_SETTINGS DEBUG_SETTINGS_SQUAD
#endif

#include "\z\hostis\addons\core\script_macros.hpp"

// debug line helper: on when the squad debug setting or LAMBS debug functions is on
#define SQUAD_DEBUG (GVAR(debug) || {LGVAR(main,debug_functions)})
