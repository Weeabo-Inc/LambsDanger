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

## Milestone 5: layer 3, the Director (`hostis_director`)

- **One Director per side on the server** ([docs/systems/director.md](systems/director.md)),
  thinking every 10 s: a board built from the groups' reports, an influence map, a menace
  gauge and pacing machine per player element (build up, sustain, fade, relax), a reserve
  pool, budgets for reinforcements and fire missions, a plain-language log.
- **Reinforcement** answers a breaking group's request with one reserve from a different
  bearing, spending budget, only while the nearest player element is building up.
  Upstream's `enableGroupReinforce` handler and the side board's dispatch stand down when
  the Director runs.
- **Counterattack**: a fallen hold or defend objective is retaken after 90 s from the side
  the influence map says the enemy did not come from.
- **Observed fire missions**: `doCallArtillery` becomes a call for fire with the observer's
  error; one adjusting round, then a correction from what the observer still holds, then
  fire for effect; killing the observer or losing the target cancels it. Budgeted, pacing
  gated, danger close checked.
- **Counter-battery**: a player gun fired twice from within 60 m in 10 minutes is hit 3
  minutes later.
- **Adaptation**: a route cell entered on two separate visits gets a reserve lying on it.
- API: `hostis_director_fnc_budget`, `release`, `counterattack`, `fireRequest`, `report`,
  `reserves`, and the events `hostis_director_setBudget`, `release`, `counterattack`,
  `fireMission`. The Diagnose module shows the Director's report on the server.
- Settings under HOSTIS Director. Test: `tests/director.Stratis` (brief tests 2 and 4).

## Milestone 4: layer 2, the Squad (`hostis_squad`)

- **One tactic lifecycle** ([docs/systems/tactics.md](systems/tactics.md), ADR-0011):
  registered tactics with precondition, start, monitor, abort, reset, commitment and
  timeout; one monitor per running tactic; one reset that hands the men back and restores
  the group's settings; interrupt classes now, blend, finish; a log with reasons in the
  picture. Zeus directed moves and task cleanup reset through it. `hostis_squad_fnc_pause`
  is the Zeus brake.
- **The planner** replaces the reactive random plan of `tacticsAssess` for any group the
  commander holds: break contact, hasty ambush, suppress and flank, bounding overwatch,
  assault, suppress, search, by priority and precondition. The commander's defence tree
  keeps running first for hold and defend intents and starts its tactics through the same
  lifecycle.
- **Suppress and flank**: base of fire from cover with a suppress list, manoeuvre element
  bounds to a flank point chosen for cover, the bound halts while the base is not firing,
  turns in from the flank, hands over to the building assault.
- **Hasty ambush**: an L across the enemy's approach, gun on the short leg, hold fire until
  150 m or fired upon.
- **Search**: pairs to the edge of the last known position's error circle, never onto the
  position itself.
- Upstream `tacticsAssault`, `tacticsGarrison` and `tacticsHide` timer resets are guarded by
  the lifecycle token so a stale timer never releases a later tactic's men.
- `doGroupBound` gained a static base of fire mode.
- Settings under HOSTIS Squad. Test: `tests/contact.Stratis`.

## Milestone 3: layer 1, the Agent (`hostis_agent`)

- **Morale states per man** ([docs/systems/morale.md](systems/morale.md)): steady, suppressed,
  pinned, shaken, broken, rallying, from engine suppression, stress, hits, isolation and the
  leader. Consequences are behavioural: a pinned man refuses to move sideways without
  covering fire, a shaken man refuses to assault and only rallies with a living leader
  within 25 m, a broken man breaks away from the fire. **Group cohesion** (steady, strained,
  broken, rallying) in the picture; a broken group breaks contact.
- **Volume of fire is measured, not guessed**: every Fire, BulletClose and Hit cause logs an
  incoming event with a bearing; a FiredMan handler stamps every shooter. The bound in
  `doGroupBound` only goes while the stationary team is actually firing when fire is coming
  in; otherwise the runners wait and call for covering fire.
- **Barks** ([docs/systems/legibility.md](systems/legibility.md)): a vocabulary with priorities
  and per-man and per-group cooldowns over the engine's radio protocol.
- **Evidence from the danger causes**: a known shooter files as `shotAt`, an unknown one as
  `heard` at the fire position, a scream as `heard` infantry.
- **Position selection** ([docs/systems/positions.md](systems/positions.md)): `findPositions`
  gained a `directness` condition and weight, a 25 m cell cache for the world queries (20 s),
  and `hostis_agent_fnc_positionValid` for the cheap "still good enough" check.
- **Fairness**: `applyStress` no longer writes `aimingAccuracy` (stress acts through morale);
  the danger FSM re-queues `getHideFrom` instead of the target's true position;
  `brainEngage`, `brainVehicle` and `doFleeing` decide from the believed position; `doUGL`
  no longer adds a magazine; `doFleeing` runs the infantry through the soldier machine's
  `survive` order.
- Settings under HOSTIS Agent. Test: `tests/morale.Stratis`.

## Milestone 2: layer 0, the knowledge model (`hostis_core`)

- The group combat picture is now a contact store owned by `hostis_core`
  ([docs/systems/knowledge.md](systems/knowledge.md)): records carry source, error radius,
  confidence, strength, type, heading, activity, death and report chain; confidence decays
  to a floor and error grows, so a contact becomes "last known" instead of vanishing after
  90 s. `lambs_danger_fnc_pictureGet`, `pictureUpdate` and `pictureContacts` forward to it and
  keep their signatures; contact records keep `select 0..3` compatible.
- The sensor sweep (`hostis_core_fnc_contactSweep`) is the only code that asks the engine
  where an enemy is, and it takes the engine's own error margin.
- Information sharing is a modelled net: `lambs_main_fnc_doShareInformation` files the
  sighting and calls `hostis_core_fnc_netSend`, which delays by distance, may lose the
  report, widens the error, strips the enemy object and delivers to the receiving group's
  owner. A group that lost its leader reports three times slower and lossier. Reports no
  longer `reveal` at `lambs_main_maxRevealValue`; that setting now has no effect. A new
  `hostis_core_engineReveal` setting (off) allows `reveal` at accuracy 1 only.
- Deaths enter the picture from the DeadBody danger causes, not from `alive`.
- The commander sweeps and reports every think; a report from another group puts a group
  on alert but never makes it "engaged".
- `taskHunt`, `taskRush` and `taskCreep` take their target from the group's own picture
  (`hostis_core_fnc_contactNearest`) instead of scanning `allUnits`; the "players only"
  option of their modules and functions is accepted and ignored.
- The Zeus Diagnose report gains a Knowledge section; the `hostis_core_debugPicture`
  setting draws every group's picture as map markers.
- Deleted (ADR-0006, hostile only): the client keybinds for player-group AI, the settings
  `lambs_danger_disableAIPlayerGroup`, `lambs_danger_disableAIPlayerGroupReaction`,
  `lambs_main_disablePlayerGroupSuppression` and `lambs_main_debug_FSM_civ` (CBA logs an
  unknown-setting line if a server config still names them), the civilian danger FSM and
  its `Civilian_F` binding, and the dead functions `findClosestTarget`, `findCover`,
  `doReposition`, `doAssaultCQB`, `brainAdjust`, `tacticsProfiles`, `tacticsCQB`,
  `fsmAllowAnimation`, plus the pre-2.5.0 `lambs_danger_On*` event mirrors.
- CI: `tools/fairness_check.py` fails on any restricted command not listed in
  `tools/fairness_allow.txt`; the stringtable tools accept the `hostis` project name.
- Test: `tests/knowledge.Stratis`.

## Documentation (milestone 1)

- `docs/RESEARCH.md`, `docs/UPSTREAM-MAP.md` with `docs/map/*`, `docs/FAIRNESS.md`,
  `docs/adr/0001` to `0011`, `docs/systems/README.md`, this file.
- The pull request template asks for the fairness checklist and the one-sentence
  explanation.

## Planned removals (with the milestone)

See the "Migration order" table in [UPSTREAM-MAP.md](UPSTREAM-MAP.md). Public names that go
away keep a no-op shim for one release; the shim logs a deprecation line once.
