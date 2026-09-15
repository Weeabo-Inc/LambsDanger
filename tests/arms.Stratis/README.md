# Combined arms test (milestone 7)

Checks 1 to 5 of [docs/systems/combined-arms.md](../../docs/systems/combined-arms.md).

Layout on Stratis at 23:00, placed by `init.sqf` relative to the player:

- **Player**: one BLUFOR rifleman; an armed helicopter 60 m behind you, a mortar 30 m behind.
- **Alpha** (`hostis_alpha`): six OPFOR men with a grenadier, 300 m north-north-west,
  defend intent on their own position.
- **Bravo** (`hostis_bravo`): six men without a grenadier, 300 m north-north-east, same.
- **CQB squad** (`hostis_cqb`): four men 600 m east, free intent, for a Zeus CQB task.
- **APC** (`hostis_apc`): a crewed OPFOR wheeled APC 400 m north-east, hold intent.

Every 10 s the RPT prints `HOSTIS TEST player at <grid>, hug flag <bool>`, the Director's
report lines, and one line per group with its running tactic and its contacts (`source
label xstrength err metres`). Every shot you fire prints `HOSTIS TEST player fired`.

Steps:

1. Take the helicopter up, fly 1 km away from the squads and fire its gun. Within 10 s
   both squads list `heard unknown` with an error of about 100 m near where you fired, and
   the Director report shows `hugging: the enemy has indirect fire or air`. The flag also
   shows as `hug flag true`.
2. Land, walk to 250 m from Alpha and engage it. The tactic line for Alpha reads `bound`,
   `assault` or `suppressAndFlank` within 30 s, not `suppress` or `defendPosition`.
3. Within 3 s of that tactic starting, an illumination round bursts over you from Alpha
   (`TACTIC hostis_alpha: illuminates the threat` with LAMBS debug on). Engage Bravo the
   same way: no flare.
4. As Zeus (or with `[hostis_cqb, <village position>, 100] call lambs_wp_fnc_taskCQB` in
   the debug console) send the CQB squad into the nearest village and watch a man stuck in
   a house: he changes room or walks out, never appears outside in one frame.
5. Shoot at the APC from 400 m, then move 50 m sideways without being seen. It turns and
   suppresses where you were, not where you are.

Turn on `hostis_director_debug`, `hostis_squad_debug` and LAMBS debug functions.
