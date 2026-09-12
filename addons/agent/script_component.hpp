#define COMPONENT agent
#define COMPONENT_BEAUTIFIED Agent
#include "\z\hostis\addons\core\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE

#ifdef DEBUG_ENABLED_AGENT
    #define DEBUG_MODE_FULL
#endif
#ifdef DEBUG_SETTINGS_AGENT
    #define DEBUG_SETTINGS DEBUG_SETTINGS_AGENT
#endif

#include "\z\hostis\addons\core\script_macros.hpp"

// morale states, worst last (docs/systems/morale.md)
#define MORALE_STATES ["steady", "rallying", "suppressed", "pinned", "shaken", "broken"]
#define MORALE_RANK(state) ((MORALE_STATES find (state)) max 0)
