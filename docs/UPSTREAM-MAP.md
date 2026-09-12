# Upstream map

Every function, config and script in the tree at commit `b1885db`, with what it does, what it
costs, which layer of the HOSTIS architecture it belongs to, and whether it is kept,
rewritten, extended or deleted. The tree at that commit is upstream LAMBS Danger.fsm 2.6.2
plus the fork's pre-brief work (see [CHANGES-FROM-UPSTREAM.md](CHANGES-FROM-UPSTREAM.md)).

The per-addon tables are long and live in their own files:

| Addon | File | Functions | Keep | Rewrite / extend | Delete |
|---|---|---|---|---|---|
| `lambs_main` | [map/main.md](map/main.md) | 86 | 76 | 7 | 3 |
| `lambs_danger` | [map/danger.md](map/danger.md) | 76 (+2 FSMs, 5 init/config files) | 52 | 21 | 10 |
| `lambs_wp` | [map/wp.md](map/wp.md) | 60 (+ waypoint scripts, events, 3DEN attribute) | 42 | 17 | 1 |
| `lambs_eventhandlers`, `lambs_formations`, `lambs_range` | [map/wp.md §5](map/wp.md#5-eventhandlers-formations-range) | 3 functions, 9 config items | all | 2 settings | 1 dead config block |

Counts are per row of the tables; "rewrite / extend" includes the `extend` verdicts on the
Zeus surface.

Verdict meanings:

- **keep**: moves into its layer addon as is, or stays in the compatibility surface.
- **extend**: stays with its public signature; gains a guard, a budget or an owner check.
- **rewrite**: the public signature (if any) stays; the body is replaced to fit the layer's
  interface, the fairness contract or the performance budget.
- **delete**: removed in the milestone named in the row, with a no-op shim for one release
  where a public name is involved.

## How control flows today

Read [map/danger.md §1](map/danger.md#1-what-danger-is-and-how-control-flows) first. In one
paragraph: the engine's danger FSM is replaced per soldier and dispatches every danger cause
through `fnc_brain` to four brain functions; a ready leader falls through to `fnc_tactics`,
which on first contact feeds the group picture and registers the group with the commander;
from then on a 1 s per-frame handler thinks for 8 groups per tick, each every 5 s, and a side
board every 10 s hands out assault and support roles; a 0.5 s per-frame handler runs the
soldier machine for every registered man with a budget of 12 expensive thinks per tick; Zeus
directed moves and `lambs_wp` tasks take precedence over all of it through one predicate.

That is already most of the five-layer shape, which is why ADR-0008 adopts it rather than
starting over. The differences from the target architecture are listed below.

## What the map says, in order of consequence

1. **Two planners compete for a group.** `fnc_tacticsAssess` (upstream, reactive,
   `selectRandom` over heuristics) and `fnc_commanderGroup` (fork, intent-driven) both issue
   tactics. Assess defers to the commander only above escalation 2. Milestone 4 folds the
   useful geometry heuristics of assess into the commander and makes the FSM leader path
   feed the picture only.
2. **Knowledge is a private list per group with no source, confidence or error.** The
   picture is fair (it goes through the leader's `getHideFrom`) but it forgets after 90 s,
   cannot hold a rifleman's sighting the leader has not registered, knows death instantly,
   and shares between groups only by engine `reveal`. `groupMemory` is a second, unaged
   store beside it. ADR-0003 replaces both.
3. **Fairness leaks are few, specific and listed.** `findClosestTarget` (allUnits and
   playableUnits by exact position, used by hunt, rush and creep), `taskHunt`'s conjured
   flare, `taskCQB`'s hidden 3.5 m teleport, `doUGL`'s free magazine, `lambs_danger.fsm:475`'s
   exact position re-queue, `brainEngage` and `tacticsAssess` reading exact enemy state,
   `tacticsReinforce` claiming empty vehicles, and `moduleTarget`'s attach-to-unit. The full
   list with file and line is in [FAIRNESS.md §3](FAIRNESS.md#3-audit-of-the-current-tree).
4. **The Director is embryonic and unbudgeted.** Reinforcement (`commanderSide`,
   `tacticsReinforce`, the `OnInformationShared` handler) and indirect fire (`doCallArtillery`
   from any leader, mortar missions inside `brainVehicle`) happen with no Zeus budget, no
   pacing and no boundary. Milestone 5 builds `hostis_director` around the existing side
   board and the artillery registry, which is sound.
5. **Reset is per-tactic and leaks.** No group-wide `tacticsReset`; `tacticsMonitor` ends a
   tactic without releasing men; timer resets run late; AUTOCOMBAT is restored by only two
   tactics. ADR-0011 gives every tactic one lifecycle and one reset.
6. **Cost hot spots are known.** `findOverwatch` (up to 16 `BIS_fnc_findSafePos`),
   `doGroupBound`'s 3 s fan scan, `commanderContingency`'s `allGroups` and per-man
   `nearestObjects` every think, `commanderSide`'s O(groups²) clustering over `allGroups`,
   `tacticsManeuver`'s per-4 s geometry, `ArtilleryScan` on every machine, and every
   `lambs_wp` task that still runs a scheduled `sleep` loop (assault, camp, CQB, creep, hunt,
   rush, doArtillery). None is per-frame per unit; all get budgets under ADR-0005.
7. **Player-side and civilian code is dead weight.** The client keybinds, two player-group
   settings, the civilian FSM and its helper, `disablePlayerGroupSuppression`, and about
   forty `isPlayer` guards. ADR-0006 deletes them in milestone 2.
8. **The Zeus surface is intact and mostly correct.** 9 waypoint classes, 12 3DEN modules,
   20 Zeus modules, 13 plus 13 ZEN entries, 15 public task functions and their events. The
   only changes are filtering player groups from dropdowns, dropping the "players only"
   option from creep, hunt and rush, dropping attach-to-unit targets, and adding owner
   checks inside the two task PFHs that lack them.

## Migration order

Derived from the verdicts and the milestones in [README.md](README.md):

| Milestone | Moves and rewrites | Deletes |
|---|---|---|
| 2 | picture → `hostis_core` contact store; `doShareInformation`, `getShareInformationParams`, `addShareInformationHandler`, `OnInformationShared` handler → report pipeline; `pictureContacts` death ageing; fairness CI check | civilian FSM and binding, `fsmAllowAnimation`, `XEH_preInitClient`, player-group settings, `disablePlayerGroupSuppression`, `debug_FSM_civ`, `findClosestTarget` (hunt, rush and creep take an area), deprecated `lambs_danger_On*` mirrors, `brainAdjust`, `tacticsProfiles`, `tacticsCQB`, `doAssaultCQB`, `doReposition`, `findCover` |
| 3 | unit machine → `hostis_agent`; `findPositions` family to the query form; `brainEngage`, `brainAssess`, `brainHide`, `brainVehicle` (infantry parts) onto the picture; `doFleeing` onto the survive order; `applyStress` skill write removed; `doUGL` magazine fix; `doSuppress` fed scored suppress positions; barks on `doCallout`; `lambs_danger.fsm:475` fix | `groupMemory` pattern |
| 4 | tactics → `hostis_squad` with the ADR-0011 lifecycle; `tacticsAssess` folded into the commander; `tacticsFlank`, `tacticsHide`, `tacticsAssault` onto `unitOrder`; `doGroupSuppress` volume signal; `contact` cleanup; `taskAssault` and `taskCamp` onto the machine | `tacticsAttack`, `tacticsHold`, `doAssaultUnitReset` |
| 5 | `commanderSide` → `hostis_director` with menace, pacing, reserves, influence map; `tacticsReinforce`, `doCallArtillery`, `brainVehicle` mortar missions, `doArtillery` under the budget and the observer model; `ArtilleryScan` server-gated; `findOverwatch` rewrite | `enableGroupReinforce` flag (becomes a budget) |
| 6 | Zeus modules, ZEN actions, intent, directed move, diagnose → `hostis_zeus`; curator overlay; module dropdown filters; owner checks in `taskAttack` and `taskDefend` PFHs; `moduleTarget` attach removed | |
| 7 | `taskCQB` rewrite as the CQB tactic; combined arms on `brainVehicle`, `tacticsManeuver` mechanised path, `doHeliInsert`; adaptation | |
| 8 | remaining `lambs_wp` sleep loops onto handlers; eventhandlers settings server-authoritative; `range` sensitivity exposed as a setting; shims for deleted public names removed | |
