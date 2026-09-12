#define COMPONENT director
#define COMPONENT_BEAUTIFIED Director
#include "\z\hostis\addons\core\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE

#ifdef DEBUG_ENABLED_DIRECTOR
    #define DEBUG_MODE_FULL
#endif
#ifdef DEBUG_SETTINGS_DIRECTOR
    #define DEBUG_SETTINGS DEBUG_SETTINGS_DIRECTOR
#endif

#include "\z\hostis\addons\core\script_macros.hpp"

#define DIRECTOR_DEBUG (GVAR(debug) || {LGVAR(main,debug_functions)})
// influence and route cells (docs/systems/director.md)
#define CELL_SIZE 100
#define CELL_KEY(pos) (format ["%1_%2", floor (((pos) select 0) / CELL_SIZE), floor (((pos) select 1) / CELL_SIZE)])
#define CELL_CENTRE(key) (call {private _k = (key) splitString "_"; [((parseNumber (_k select 0)) + 0.5) * CELL_SIZE, ((parseNumber (_k select 1)) + 0.5) * CELL_SIZE, 0]})
