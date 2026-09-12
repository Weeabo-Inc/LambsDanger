#include "script_component.hpp"
ADDON = false;
#include "XEH_PREP.hpp"
#include "settings.inc.sqf"

// the bark vocabulary: key -> [radio protocol sentence, behaviour, priority, unit cooldown, group cooldown, range]
// sentences are the ones the engine's radio protocol ships (docs/systems/legibility.md)
GVAR(barkVocabulary) = createHashMapFromArray [
    ["contact",     ["contact",        "combat",  3, 6,  4,  125]],
    ["underFire",   ["UnderFireE",     "combat",  2, 8,  6,  125]],
    ["takeCover",   ["TakeCover",      "combat",  2, 8,  6,  125]],
    ["suppress",    ["suppress",       "combat",  2, 6,  4,  125]],
    ["coverMe",     ["SuppressiveFire","combat",  2, 8,  6,  125]],
    ["moving",      ["Advance",        "combat",  1, 6,  4,  100]],
    ["flank",       ["flank",          "combat",  2, 10, 8,  125]],
    ["fallBack",    ["TakeCover",      "combat",  3, 8,  6,  125]],
    ["rally",       ["RallyUp",        "combat",  2, 10, 8,  125]],
    ["stayAlert",   ["StayAlert",      "combat",  1, 12, 10, 60]],
    ["keepFocused", ["KeepFocused",    "combat",  1, 12, 10, 100]],
    ["panic",       ["panic",          "stealth", 2, 8,  4,  55]],
    ["manDown",     ["mandown",        "combat",  3, 8,  6,  80]],
    ["grenade",     ["grenadeout",     "combat",  3, 4,  2,  40]],
    ["attack",      ["Attack",         "combat",  2, 8,  6,  125]],
    ["eject",       ["Eject",          "combat",  3, 6,  4,  125]]
];

ADDON = true;
