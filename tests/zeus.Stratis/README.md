# Zeus test (layer 4, brief tests 9 and 10)

Checks 1 to 5 of [docs/systems/zeus.md](../../docs/systems/zeus.md).

Layout on Stratis, placed by `init.sqf`. The player is made a Zeus at start (press the
Zeus key, Y by default).

- **Player**: one BLUFOR rifleman, curator of everything.
- **Alpha** (`hostis_alpha`): six OPFOR men 300 m north.
- **Bravo** (`hostis_bravo`): six OPFOR men 300 m north-east.
- **Charlie** (`hostis_charlie`): six OPFOR men 800 m north, free intent, the Director's
  only reserve.

Every 10 s the RPT prints `HOSTIS TEST intents` with each squad's intent, tactic and
escalation, and the Director's first report line.

Steps:

1. Open Zeus. Drop HOSTIS: Intent on Alpha, choose Hold. Turn the overlay on (HOSTIS:
   Overlay): Alpha's label reads `hold` within 3 s. Fire near Alpha from cover: it fights
   from where it is. Drop Intent on the ground 300 m from Bravo, pick Bravo, choose Attack:
   the label reads `attack`, Bravo moves on the spot, the RPT shows `taskAttack`.
2. With ZEN, give Charlie a HOSTIS Defend waypoint: its label reads `defend` and the RPT
   shows `INTENT hostis_charlie: defend`.
3. Drop HOSTIS: Director near you, throttle 0, area radius 500. Then drop HOSTIS: Release
   reserves 800 m away: the RPT's `HOSTIS TEST director` line and the Director's log say
   nothing was spent. Drop Director again with throttle 1 and radius 0, release again:
   `released ... zeus` appears and Charlie moves.
4. While Bravo is mid-attack, drop HOSTIS: Pause: `TACTIC ... paused` within one second
   and the men stop; drop it again and Bravo plans again.
5. Overlay off: the labels vanish.

Turn on `hostis_zeus_debug`, `hostis_squad_debug`, `hostis_director_debug` and LAMBS
debug functions. Zeus Enhanced is needed for step 2 only.
