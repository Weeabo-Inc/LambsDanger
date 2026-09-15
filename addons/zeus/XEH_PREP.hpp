// Layer 4, Zeus (docs/systems/zeus.md)
PREP(intent);
PREP(groupsNear);
PREP(dialogIntent);
PREP(dialogDirector);
PREP(director);
PREP(snapshot);
PREP(overlay);
PREP(overlayDraw);

SUBPREP(Modules,moduleIntent);
SUBPREP(Modules,moduleDirector);
SUBPREP(Modules,moduleFireMission);
SUBPREP(Modules,moduleRelease);
SUBPREP(Modules,moduleOverlay);
SUBPREP(Modules,modulePause);

SUBPREP(ZEN,setIntent);
SUBPREP(ZEN,setDirector);
SUBPREP(ZEN,setFireMission);
SUBPREP(ZEN,setRelease);
SUBPREP(ZEN,setPause);
SUBPREP(ZEN,showPause);
