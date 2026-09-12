#include "\x\cba\addons\main\script_macros_common.hpp"

#define DFUNC(var1) TRIPLES(ADDON,fnc,var1)

// functions live in functions\ and functions\<sub>\, as upstream (lambs_main/script_macros.hpp)
#ifdef DISABLE_COMPILE_CACHE
    #undef PREP
    #define PREP(fncName) DFUNC(fncName) = compileScript [QPATHTOF(functions\DOUBLES(fnc,fncName).sqf)]
#else
    #undef PREP
    #define PREP(fncName) [QPATHTOF(functions\DOUBLES(fnc,fncName).sqf), QFUNC(fncName)] call CBA_fnc_compileFunction
#endif

#ifdef SUBPREP
    #undef SUBPREP
#endif

#ifdef DISABLE_COMPILE_CACHE
    #define SUBPREP(sub,fncName) DFUNC(fncName) = compileScript [QPATHTOF(functions\sub\DOUBLES(fnc,fncName).sqf)]
#else
    #define SUBPREP(sub,fncName) [QPATHTOF(functions\sub\DOUBLES(fnc,fncName).sqf), QFUNC(fncName)] call CBA_fnc_compileFunction
#endif

// Calls into the compatibility addons. EFUNC and EGVAR expand with PREFIX (hostis), so a
// hostis_* addon reaches lambs_* code and variables through these instead.
//   LFUNC(main,isAlive)        -> lambs_main_fnc_isAlive
//   LGVAR(danger,picture)      -> lambs_danger_picture
//   QLGVAR(danger,picture)     -> "lambs_danger_picture"
//   LAMBS_STRING(main,Team)    -> "STR_lambs_main_Team"
#define LFUNC(var1,var2) TRIPLES(lambs,var1,DOUBLES(fnc,var2))
#define LGVAR(var1,var2) TRIPLES(lambs,var1,var2)
#define QLFUNC(var1,var2) QUOTE(LFUNC(var1,var2))
#define QLGVAR(var1,var2) QUOTE(LGVAR(var1,var2))
#define LAMBS_STRING(var1,var2) QUOTE(TRIPLES(STR,DOUBLES(lambs,var1),var2))

// The contact record (docs/systems/knowledge.md). Indices 0 to 3 match the upstream
// picture so readers that index the record keep working.
#define CONTACT_OBJECT 0
#define CONTACT_POS 1
#define CONTACT_TIME 2
#define CONTACT_KNOWS 3
#define CONTACT_ERROR 4
#define CONTACT_CONF 5
#define CONTACT_SOURCE 6
#define CONTACT_FIRST 7
#define CONTACT_STRENGTH 8
#define CONTACT_TYPE 9
#define CONTACT_HEADING 10
#define CONTACT_ACTIVITY 11
#define CONTACT_DEAD 12
#define CONTACT_REF 13
#define CONTACT_CHAIN 14
#define CONTACT_SIZE 15

// evidence quality, worst first
#define CONTACT_SOURCES ["suspected", "reported", "heard", "shotAt", "seen"]
#define SOURCE_RANK(src) ((CONTACT_SOURCES find (src)) max 0)
#define SOURCE_WEIGHT(src) ([0.3, 0.5, 0.7, 1, 1] select SOURCE_RANK(src))
#define DIRECT_SOURCES ["seen", "shotAt", "heard"]

// effective values of a stored record at this moment
#define CONTACT_CONFIDENCE(rec) ((GVAR(confidenceFloor)) max (((rec) select CONTACT_CONF) * (0.5 ^ ((time - ((rec) select CONTACT_TIME)) / (GVAR(confidenceHalfLife) max 1)))))
#define CONTACT_ERROR_NOW(rec) ((GVAR(errorCap)) min (((rec) select CONTACT_ERROR) + (GVAR(errorGrowth) * (time - ((rec) select CONTACT_TIME)) * ([1, 0.2] select (((rec) select CONTACT_ACTIVITY) in ["static", "dead"])))))
