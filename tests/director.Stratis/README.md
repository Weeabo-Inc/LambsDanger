# Director test (layer 3, brief tests 2 and 4)

Checks 1 to 4 of [docs/systems/director.md](../../docs/systems/director.md).

Layout on Stratis, placed by `init.sqf` relative to the player:

- **Player**: one BLUFOR rifleman; an empty BLUFOR mortar 30 m behind you for check 3.
- **Defenders** (`hostis_hold`): six OPFOR men with a defend intent on a point 350 m north
  (a small compound of placed bunkers).
- **Reserves** (`hostis_res1`, `hostis_res2`): six men each, 800 m to the north-east and
  north-west, free intent.
- **Mortar team** (`hostis_mortar`): an OPFOR mortar 1200 m north, registered as artillery.

Every 10 s the RPT prints `HOSTIS TEST director` followed by the Director's report lines,
and `HOSTIS TEST player at <grid>`.

Steps:

1. Assault the compound and take it. Within 3 minutes of the last defender leaving:
   `DIRECTOR: ... lost ...`, then `released ... counterattack ...`; the reserve that comes
   is the one on the side you did not approach from.
2. Before that, while the defenders can see you: `fire mission ... adjusting round`, then
   `correction ... fire for effect`. In a second run, kill the defenders' leader between
   the two lines: `cancelled: observer lost`.
3. Fire the mortar twice from where it stands: `counter-battery on ... in 180 s`, then rounds
   on it about three minutes later.
4. After the fight: `pacing ... -> relax`, and no `released` line during the relax.

Turn on `hostis_director_debug` and LAMBS debug functions.
