# Changes from upstream

HOSTIS is a modified version of LAMBS Danger.fsm 2.6.2 by nkenny and the LAMBS contributors,
distributed under the same GPLv2 with the two upstream amendments (see [LICENSE](../LICENSE)).
This file lists what the fork has changed, by area, so that a mission maker or a server
administrator can see at a glance where behaviour differs from upstream. Entries are added
with each milestone.

## Identity

- Mod name, folder, PBO names, signing authority and release zip are `HOSTIS` / `@hostis` /
  `hostis_*.pbo` / `hostis` / `hostis-latest.zip`, so the fork never collides with upstream
  on a server (ADR-0002).
- The `lambs_main`, `lambs_danger` and `lambs_wp` addons (and `eventhandlers`, `formations`,
  `range`) keep their CfgPatches names, `\z\lambs\addons\` paths, function prefixes, module
  classnames, waypoint classnames, setting names and group and unit variables. Existing
  missions and `cba_settings.sqf` files keep working. Do not load HOSTIS together with
  upstream LAMBS: both define the same CfgPatches classes.
- New layer addons use the `hostis` prefix; `addons/core` (`hostis_core`) is scaffolded empty
  in milestone 1 to prove the two-prefix build.

## Behaviour (fork work before the HOSTIS brief, commits `241b603` to `b1885db`)

These are in the tree today and are mapped in [UPSTREAM-MAP.md](UPSTREAM-MAP.md). They will be
migrated into the layer addons per ADR-0008.

### Group knowledge and command

- A per-group **combat picture** (`lambs_danger_fnc_picture*`): contacts seen through the
  leader's engine knowledge, a recency-weighted threat centre, losses, morale, last tactic and
  result.
- An **AI commander** (`lambs_danger_fnc_commander*`, `intent*`): per-group intent (free, hold,
  defend, attack; objective, radius, posture, escalation cap), per-group escalation (routine,
  alert, engaged, decisive), a time-sliced group planner (8 groups per second, each every
  5 s), a side board every 10 s that clusters threats and assigns assault and support roles,
  and contingencies (succession, crew replacement, shelling displacement, strays,
  reorganisation, near ambush, taxis, ammunition from the dead, ACE casualty drag).
- Zeus **Posture and intent** module and ZEN action; **Directed move** module, watchdog and
  ZEN actions (follow waypoints, resume behaviour); **Diagnose** module and ZEN action that
  report in plain text why a group is not moving.

### Movement core

- A **tactical position system** (`lambs_main_fnc_findPositions`, `findPositionsBuilding`,
  `positionReserve`, `positionRelease`, `findApproach`): fighting, hiding and stepping-stone
  positions scored from terrain objects, cached building positions, terrain dips and
  vehicles, ray-tested for cover height and field of fire, bounded to 40 candidates and 24
  rays, reserved per group so two men never take one wall.
- A **per-soldier state machine** (`lambs_danger_fnc_unit*`): one movement issuer
  (`unitOrder`: move, rush, assault, hold, cover, survive, follow, release), a 0.5 s cycle with
  a cheap pass over every man and a budgeted expensive pass, event input (hit, near miss,
  suppression, threat seen), peek and duck rhythm in cover, cover-to-cover legs.
- Every upstream caller that ended in a plain `doMove` now goes through the issuer.

### Squad tactics

- **Fire and movement** (`tacticsBound`, `doGroupBound`): base of fire and assault team
  alternating bounds on covered routes, buddy-rush stagger, sprint without shooting, prone on
  arrival, smoke for the support move, rear security, base of fire uses rockets and UGL.
- **Deliberate attack** (`tacticsManeuver`): terrain analysis, task organisation, support by
  fire, flank approach, shift and lift of supporting fire, consolidation with a security pair;
  **mechanised attack** (carry to a dismount point, fan out behind the vehicle, assault under
  its fire, emergency dismount, bail out of a crippled carrier); **air assault** (scripted
  landing, LZ selection short of the objective, egress into a security ring, aircrew released
  to loiter).
- **Break contact** (`tacticsWithdraw`): covering pair, rush to cover under smoke, diagonal
  break out of a beaten zone.
- **Defend** (`taskDefend` rewritten): sectors weighted to the threat, fighting positions with
  a field of fire, a hidden reserve, penetration counterattack, fire discipline, fall back to
  the next line after a third lost, spacing doubles for a minute after shelling.
- **Self-preservation**: a threat sense per soldier (stress, suppression, hits, wounds,
  exposure, isolation) and what he does about it (cover, break away, fight if someone is on
  top of him).
- **Attack Position** (`taskAttack`, `taskAttackAir`): Zeus Seek & Destroy waypoints and the
  Attack module drive a mounted or air approach, an attack through the tactics, a hold when
  quiet, and a clean hand-back to the Zeus route.
- Casualty drill with ACE, grenade before the door, fire discipline for defenders.

### Settings added

`lambs_danger_commander`, `commanderPosture`, `commanderMaxAssault`,
`commanderReinforceRange`, `commanderMergeStrays`, `zeusWaypointDiscipline`,
`zeusWaypointTimeout`, `aggression`, `dodgeCooldown`.

## Documentation (milestone 1)

- `docs/RESEARCH.md`, `docs/UPSTREAM-MAP.md` with `docs/map/*`, `docs/FAIRNESS.md`,
  `docs/adr/0001` to `0011`, `docs/systems/README.md`, this file.
- The pull request template asks for the fairness checklist and the one-sentence
  explanation.

## Planned removals (with the milestone)

See the "Migration order" table in [UPSTREAM-MAP.md](UPSTREAM-MAP.md). Public names that go
away keep a no-op shim for one release; the shim logs a deprecation line once.
