// HOSTIS layer addons share one mod prefix and the LAMBS version number.
// The compatibility addons (lambs_main, lambs_danger, lambs_wp) keep PREFIX lambs;
// see docs/adr/0002-fork-identity-and-addon-naming.md.
#define MAINPREFIX z
#define PREFIX hostis

#include "\z\lambs\addons\main\script_version.hpp"

#define VERSION         MAJOR.MINOR
#define VERSION_STR     MAJOR.MINOR.PATCHLVL.BUILD
#define VERSION_AR      MAJOR,MINOR,PATCHLVL,BUILD
#define VERSION_PLUGIN  MAJOR.MINOR.PATCHLVL.BUILD

#define REQUIRED_VERSION 2.18

#ifdef COMPONENT_BEAUTIFIED
    #define COMPONENT_NAME QUOTE(HOSTIS COMPONENT_BEAUTIFIED)
#else
    #define COMPONENT_NAME QUOTE(HOSTIS COMPONENT)
#endif
