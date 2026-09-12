#include "\x\cba\addons\main\script_macros_common.hpp"

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
