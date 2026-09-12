# Map: `addons/danger`

Part of [UPSTREAM-MAP.md](../UPSTREAM-MAP.md). Paths are relative to `addons/danger/`; line
numbers refer to the tree at the time of writing (commit `b1885db`).

## 1. What `danger` is and how control flows

`danger` is the reactive core of LAMBS: it replaces the engine's `fsmDanger` for every infantry
class (`CfgVehicles.hpp:5-13` set `fsmDanger` on `SoldierWB/EB/GB` to
`scripts/lambs_danger.fsm`; `CfgVehicles.hpp:14-16` give `Civilian_F`
`scripts/lambs_dangerCivilian.fsm`) and on top of that FSM the fork has added a group combat
picture, a per-side AI commander, a per-soldier movement machine, and Zeus directed-move
plumbing. The engine starts the FSM on a unit whenever a danger cause (DCEnemyDetected,
DCFire, DCHit, ... DCBulletClose) fires; the FSM is therefore event-driven per unit, not a
script loop.

Flow inside `lambs_danger.fsm`: `Start_Danger` pushes `[cause, pos, until, causedBy]` onto
`_queue`; `Init` exits at once if `fnc_isForcedExit` (unit `disableAI` variable, `CARELESS`, or
MOVE feature off, `fnc_isForcedExit.sqf:17-19`), goes to `Check_self` (`fnc_brainForced`) if
`fnc_isForced` (fleeing, `forceMove` variable, engine ATTACK/GET IN/HEAL command, unconscious,
ACE heal queue, or player-led group with the player-group toggle, `fnc_isForced.sqf:17-22`),
to `Evaluate_Infantr` if on foot, else `Evaluate_Vehicle`. `Evaluate_Infantr` calls
`fnc_brain`, which sorts the queue by `GVAR(fsmPriorities)` (`XEH_preInit.sqf:12-24`, DCHit
highest at 9, DCCanFire 8, DCBulletClose 7, ... Assess 0), registers the unit with the
per-soldier machine (`fnc_brain.sqf:71`), and returns four flags that route to `Roll_dodge`
(`fnc_brainReact`, causes HIT, BULLETCLOSE, EXPLOSION, FIRE from an enemy side while
suppression < 0.9), `Attack` (`fnc_brainEngage`, ENEMYDETECTED, ENEMYNEAR, CANFIRE from an
enemy side), `Stay_firm` (`fnc_brainHide`, DEADBODYGROUP, DEADBODY, SCREAM or a panic roll) or
`Check_self_1` (`fnc_brainAssess`). Every one of those returns a timeout the FSM waits on,
then `Reset_foot` re-queues a live CQB target within 35 m and hands a ready leader
(`fnc_isLeader`: leader or leader dead, suppression under 0.2/0.6, and no `isExecutingTactic`)
to the `Tactics` state, which calls `fnc_tactics`. `fnc_tactics` (`fnc_tactics.sqf:28-38`)
exits if `disableGroupAI`, runs `fnc_contact` when the group's `contact` timer has lapsed
(first contact: 600 s contact window, `pictureUpdate`, `commanderRegister`, callouts, leader
into cover via `unitOrder`), otherwise runs `fnc_tacticsAssess` unless the leader is a player
or the group is Zeus-directed. `fnc_tacticsAssess` defers entirely to the commander once the
group's escalation is ≥ 2 and it is on the commander list (`fnc_tacticsAssess.sqf:39-42`);
otherwise it pulls `targets [true, range]`, feeds the picture, falls back to `pictureContacts`
when nothing is in sight, builds a weighted plan list from geometry heuristics (tank in view
→ hide, indoor or near → assault, fortified or far → flank or suppress), rewrites it by last
failure, side-board role, intent and morale, then `selectRandom`s a tactic, arms
`fnc_tacticsMonitor` and schedules the `fnc_tacticsX` call with a random delay
(`fnc_tacticsAssess.sqf:314-349`); no plan means `fnc_tacticsHold`. Vehicles skip all of
that: `fnc_brainVehicle` handles artillery, static, armour, armed and unarmed cars itself and
only calls `fnc_tactics` for a mounted leader (`fnc_brainVehicle.sqf:178-180`).

Above the FSM, two CBA per-frame handlers tick on every machine that owns groups. The
**commander PFH** is registered in `fnc_commanderInit.sqf:30-31` with `TICK 1` s; each tick it
thinks for at most `GROUPS_PER_TICK 8` groups whose `commanderNext` is due (`GROUP_INTERVAL 5`
s + random 2, `fnc_commanderInit.sqf:65-66`), refreshes the side board every `SIDE_INTERVAL
10` s (`fnc_commanderInit.sqf:36-43`, `fnc_commanderSide`), and drops groups idle for
`IDLE_DROP 900` s with intent `free` (`fnc_commanderInit.sqf:55-63`). Groups reach the list
through `fnc_commanderRegister` from first contact (`fnc_contact.sqf:41`), from
`fnc_intentSet` (`fnc_intentSet.sqf:46`) and when picked as reinforcements
(`fnc_commanderSide.sqf:125`). `fnc_commanderGroup` reads picture and intent, computes
escalation, bails if the group is directed, `disableGroupAI`, under a `lambs_wp` task snapshot,
already `isExecutingTactic` or cannot move (`fnc_commanderGroup.sqf:51-55`), runs
`fnc_commanderContingency`, and issues one tactic through `fnc_tacticsMonitor` with a 20 s
same-tactic cooldown (`fnc_commanderGroup.sqf:68-80`). The **unit cycle PFH** is registered in
`fnc_unitInit.sqf:26-30` with `TICK 0.5` s; `fnc_unitCycle` does a cheap pass over every
registered soldier (arrival, timeouts, peek and duck flips, suppression events, idle drop
after `IDLE_DROP 180` s) and then runs the expensive pass `fnc_unitThink` (position queries
and `doMove`) for at most `THINK_BUDGET 12` men per tick, oldest request first
(`fnc_unitCycle.sqf:21,235-239`). Per-group PFHs also exist: `fnc_tacticsMonitor` at 5 s
(`fnc_tacticsMonitor.sqf:120`), `fnc_tacticsManeuver` at 4 s (`fnc_tacticsManeuver.sqf:706`),
`fnc_directedMoveWatchdog` at 10 s (`fnc_directedMoveSet.sqf:195`), and a client-side 5 s
poll in `fnc_zeusWaypointInit.sqf:23-27` that waits for a curator logic to hook waypoint
events.

Zeus takes precedence through one predicate, `lambs_main_fnc_isDirected` (reads
`lambs_danger_directedMove` and its timeout). `fnc_directedMoveSet` cancels `lambs_wp` tasks
(`taskCleanup`), clears `isExecutingTactic`, `inCQB` and `groupMemory`, releases every man from
the soldier machine, re-enables PATH and MOVE, disables AUTOCOMBAT, and in strict mode sets
the unit `disableAI` flag so the FSM exits at `Init` (`fnc_directedMoveSet.sqf:116-147`).
While directed, `fnc_tactics.sqf:38`, `fnc_tacticsAssess.sqf:35`, the head of every
`fnc_tacticsX`, `fnc_commanderGroup.sqf:51`, `fnc_tacticsMonitor.sqf:69` and
`fnc_tacticsManeuver.sqf:259` refuse to plan, and the unit brains keep only self-preservation
(`fnc_brainReact.sqf:54`, `fnc_brainEngage.sqf:43,78,112`, `fnc_brainHide.sqf:49`,
`fnc_brainAssess.sqf:81`, `fnc_brainForced.sqf:43`). SAD and DESTROY waypoints hand the group
to the `lambs_wp` attack task instead (`fnc_directedMoveSet.sqf:91-96`), and `lambs_wp` task
snapshots block the commander (`fnc_commanderGroup.sqf:53`, `fnc_commanderSide.sqf:111`,
`fnc_commanderContingency.sqf:157`). Intent (`fnc_intentSet`) is the softer Zeus channel: the
commander improvises inside mode, objective, radius, posture and escalation cap.

The civilian FSM (`scripts/lambs_dangerCivilian.fsm`, 1003 lines) is a separate machine:
`Init` builds its own priority table and `_fnc_biggestDanger`, `Select_danger` picks hide vs
run vs inspect, `Hide`, `Run` and `Inspect_body` set behaviour and go through `Man` states
(doHide, doMove away 30 to 300 m, doCheckBody), `Order_out*` dismount, `Drop_down` plays
panic animations gated by `fnc_fsmAllowAnimation`, `Check_of_dangers` re-polls, `Clean_up*`
and `End` restore behaviour and stance.

## 2. Function table

| Function | Author | What it does | Cost | Layer | Verdict | Why |
|---|---|---|---|---|---|---|
| `XEH_preInit.sqf` | nkenny (+fork) | Preps functions, loads settings, defines FSM priorities and `dangerUntil`, wires the `OnInformationShared` reinforce and reorient handler and the Zeus, intent and diagnose CBA events. | cheap; one-shot, plus a per-event handler that calls `findEmptyPosition` and `tacticsReinforce` on every shared report. | infra | rewrite | The event plumbing stays, but the `OnInformationShared` handler is a layer 0 and 3 decision (reinforce, setFormDir) hidden in init and belongs to the Director. |
| `XEH_postInit.sqf` | nkenny (+fork) | Forwards four scripted event hooks and starts zeusWaypointInit, commanderInit and unitInit. | trivial; one-shot. | infra | keep | Startup order is right for the layered design. |
| `XEH_preInitClient.sqf` | nkenny | Adds four CBA keybinds so a player can toggle danger AI for his own group and order quick suppress, hide or assault on friendlies near him. | cheap; per keypress, `allUnits select` and `lineIntersectsSurfaces`. | infra/debug | delete | Exists only to let a player command his own squad, which HOSTIS never has. |
| `XEH_preStart.sqf` | nkenny | Runs the PREP list at pre-start for compile caching. | trivial; one-shot. | infra | keep | Standard CBA boilerplate. |
| `settings.inc.sqf` | nkenny (+fork) | Declares the CBA settings: player-group toggles, feature disables, CQB range, panic, Zeus waypoint discipline and timeout, aggression, dodge cooldown and the commander group. | trivial; one-shot. | 4 | rewrite | `disableAIPlayerGroup` and `disableAIPlayerGroupReaction` (the latter read nowhere in this addon) are player-squad settings to delete; the rest move under Zeus budgets. |
| `CfgVehicles.hpp` | LAMBS | Binds the two danger FSMs to soldier and civilian classes and declares the six Zeus modules. | trivial; config. | infra | rewrite | Drop the `Civilian_F` binding and the civilian FSM; keep the soldier binding and the Zeus modules. |
| `lambs_danger_fnc_brain` | nkenny | Sorts the danger queue by priority, registers the unit with the soldier machine, and returns which FSM branch (react, hide, engage, assess) to take. | cheap; per FSM event, `sort` on a tiny array and a `doCallout` and `doShareInformation` on ENEMYNEAR. | 1 | keep | It is the event dispatcher of layer 1 and only uses the cause the engine gave. |
| `lambs_danger_fnc_brainAdjust` | nkenny | Returns the default priorities unchanged (disabled stub). | trivial; unused. | 1 | delete | Dead code kept "for the future". |
| `lambs_danger_fnc_brainAssess` | nkenny (+fork) | Between drills: recover stress, rejoin a leader 60 m away, loot a body when out of ammo, self-heal without ACE, or hand an in-cover man a `threatSeen` event. | moderate; per 2 s assess tick, `nearestObjects` 25 m and a CfgWeapons `getArray` when out of ammo. | 1 | rewrite | Correct layer, but the ammo, heal and rejoin checks duplicate `commanderContingency` and should live in one place; uses `getHideFrom` (fair). |
| `lambs_danger_fnc_brainEngage` | nkenny (+fork) | On a known enemy: feed the picture, hand busy men a `threatSeen`, assault (with a grenade first if the target is indoors) inside CQB range, else suppress the estimated position. | moderate; per 1.5 s engage tick, `isIndoor` on both units, `doSuppress`, `doAssault`, `doGrenade`. | 1 | rewrite | Reads `speed _target`, `_unit distance2D _target`, `vehicle _target` and `isIndoor _target` on the real object (exact-state leaks) although the aim points use `getHideFrom`; move those tests onto the picture position. |
| `lambs_danger_fnc_brainForced` | nkenny (+fork) | For men under orders: leader feeds the picture with `targets [true,800]`, a fresh hit triggers a `hit` event or `doSurvive`, fleeing runs `doFleeing`, engine ATTACK gets assault speed and cleans up SuppressTarget helpers. | cheap; per 2 to 3 s forced tick, `targets` for leaders only. | 1 | keep | Fair (engine `targets`) and cheap; it is the "even under orders a man ducks" path. |
| `lambs_danger_fnc_brainHide` | nkenny (+fork) | On scream, body or panic: look, add stress, check own dead, mark buildings near enemy dead as group memory, or drop into a low stance. | moderate; per 2 s hide tick, `findBuildings` 15 m once per group memory fill. | 1 | rewrite | Keep the reflex, drop the `groupMemory` building scan (that is knowledge the picture should own). |
| `lambs_danger_fnc_brainReact` | nkenny (+fork) | Immediate reaction to fire, hit or explosion: stress, shell log, `doSurvive` when threat ≥ 2, `nearMiss` and `hit` events for machine-owned men, else `doCover` or `doDodge`. | cheap; per 1.4 s react tick, `getThreat` and one `doCover` or `doDodge`. | 1 | keep | Textbook layer 1 event handling on engine-supplied positions. |
| `lambs_danger_fnc_brainVehicle` | nkenny (+fork) | Vehicle crews: artillery and mortar fire missions, static-weapon dismount, armour unload, jink, rotate and assault, armed car gunner shuffle, unarmed car dismount, warhead selection. | expensive; per 1 to 5 s vehicle tick, `getArtilleryAmmo`, `inRangeOfArtillery`, `findNearbyFriendlies`, `checkVisibility`, `allTurrets` and multiple `waitAndExecute`. | 1/3 | rewrite | Mortar fire missions are a layer 3 indirect-fire budget, not a crew reflex, and `findNearestEnemy`, `eyePos _dangerCausedBy` and `_dangerCausedBy distance _vehicle` read the true enemy object. |
| `lambs_danger_fnc_commanderContingency` | bluefield-creator | Succession, ACE casualty drag, crew replacement or bail-out, displace under shelling, merge strays, self-aid and ammo from the dead. | expensive; per 5 s group think (and every 4 s inside a maneuver), `findGroupVehicles` 400 m, `nearestTerrainObjects`, `nearestObjects` 25 m per low-ammo man, `allGroups select`. | 2 | rewrite | Right ideas for the squad layer, but `allGroups` scans and per-man `nearestObjects` every think need caching and budgeting for 200+ AI. |
| `lambs_danger_fnc_commanderEscalation` | bluefield-creator | Derives escalation 0 to 3 from contact age, losses, intent and leader stress, decays one level per minute, capped by the Zeus intent. | trivial; per group think. | 2/4 | keep | Clean, picture-only, honours the Zeus cap. |
| `lambs_danger_fnc_commanderGroup` | bluefield-creator | One think per group: return home, alert posture, defend with fire discipline, garrison or fallback, withdraw when broken, support or assault by role, pursue, maneuver, bound or assault by distance, consolidate after contact. | expensive; per 5 s group think, `getThreat` per unit, `nearestTerrainObjects`, `findBuildings` 50 m when exposed, `findOverwatch`. | 2 | keep | This is the squad layer's decision tree and reads only the picture and intent. |
| `lambs_danger_fnc_commanderInit` | bluefield-creator | Starts the 1 s commander PFH with round-robin group thinks (8 per tick, 5 s each) and the 10 s side board. | cheap; per-tick bookkeeping. | infra | keep | Budgeted PFH exactly as the performance target asks. |
| `lambs_danger_fnc_commanderRegister` | bluefield-creator | Adds a local group to the commander list and seeds its intent. | trivial; one-shot per group. | infra | keep | Needed so only groups with something to do are ticked. |
| `lambs_danger_fnc_commanderSide` | bluefield-creator | Clusters engaged groups' threat positions, hands out assault and support roles per cluster under a cap, and sends the nearest idle group to answer reinforce requests. | expensive; per 10 s per side, O(groups²) cluster search, `allGroups select` with `pictureGet` and `intentGet` per group. | 3 | rewrite | It is the Director skeleton, but reinforcement bypasses any Zeus budget and `allGroups` scans should use the registered list. |
| `lambs_danger_fnc_contact` | nkenny (+fork) | First contact: 600 s contact window, feed picture, register with commander, formation and formDir, gestures and callouts, building memory when indoors, leader into cover via `unitOrder`. | moderate; one-shot per contact, `findBuildings` 35 m when stealth or indoor, several `waitAndExecute`. | 2 | rewrite | Keep the picture and commander hand-off, drop `groupMemory`, the `enableAttack` toggling and the `!isPlayer` unit filter. |
| `lambs_danger_fnc_directedMoveDeleted` | bluefield-creator | Re-indexes or releases a directed move after a curator deleted a waypoint. | trivial; per Zeus event. | 4 | keep | Necessary Zeus plumbing. |
| `lambs_danger_fnc_directedMoveDiagnose` | bluefield-creator | Builds a text report of why a group is not moving: blockers, commander state, one line per unit. | moderate; one-shot on request, iterates units with `checkAIFeature` and `expectedDestination`. | debug | keep | Zeus-facing diagnostic, no gameplay effect; the seed of the curator overlay. |
| `lambs_danger_fnc_directedMoveFeedback` | bluefield-creator | Sends a curator feedback line via `CBA_fnc_ownerEvent`. | trivial; per message. | 4 | keep | Zeus feedback channel. |
| `lambs_danger_fnc_directedMoveRelease` | bluefield-creator | Ends a directed move: removes the watchdog, restores attack state and AUTOCOMBAT, undoes strict `disableAI`, releases mounts. | trivial; one-shot. | 4 | keep | Clean release path. |
| `lambs_danger_fnc_directedMoveSet` | bluefield-creator | Puts a group on a directed move: cancels tasks and tactics, releases men, mounts up, sets current waypoint, arms the 10 s watchdog, handles SAD and DESTROY hand-off and route extension. | moderate; one-shot per order, `doMountUp`, `waitUntilAndExecute`. | 4 | keep | The Zeus override that makes "Zeus sets intent, AI operates" hold. |
| `lambs_danger_fnc_directedMoveWatchdog` | bluefield-creator | Every 10 s: arrival and next waypoint, waypoint index drift, bail out of crippled carriers, stragglers, stall re-issue and diagnosis to the curator. | cheap; per 10 s per directed group. | 4 | keep | Bounded per-group PFH, no sensor reads. |
| `lambs_danger_fnc_fsmAllowAnimation` | nkenny | Tells the civilian FSM whether a unit may play a panic animation. | trivial; per civilian FSM state. | 1 | delete | Serves only the civilian FSM, which HOSTIS drops. |
| `lambs_danger_fnc_getMorale` | bluefield-creator | Group morale 0 to 1 from losses, average stress, leader down and leader courage, cached 5 s in the picture. | cheap; per call, `getStress` per unit at most every 5 s. | 0 | keep | Pure derived knowledge, no cheating; becomes cohesion in milestone 3. |
| `lambs_danger_fnc_intentGet` | bluefield-creator | Returns the group's intent array, creating defaults on first use. | trivial; per call. | 4 | keep | The Zeus-to-AI contract record. |
| `lambs_danger_fnc_intentSet` | bluefield-creator | Sets mode, objective, radius, posture and cap on the owner, forwards via CBA target event otherwise, registers the group. | trivial; per call. | 4 | keep | Same. |
| `lambs_danger_fnc_isForced` | nkenny (+fork) | FSM predicate: fleeing, `forceMove`, engine commands, unconscious, ACE heal queue, or player-led group with the player-group toggle. | trivial; per FSM pass. | 1 | rewrite | Drop the `disableAIPlayerGroup && isPlayer leader` clause. |
| `lambs_danger_fnc_isForcedExit` | nkenny | FSM predicate: `disableAI` flag, CARELESS or MOVE disabled. | trivial; per FSM pass. | 1 | keep | The Zeus off-switch for the FSM. |
| `lambs_danger_fnc_isLeader` | nkenny (+fork) | FSM predicate: unit leads (or leader dead), not too suppressed, group not executing a tactic. | trivial; per FSM pass. | 2 | keep | Cheap gate into the squad layer. |
| `lambs_danger_fnc_pictureContacts` | bluefield-creator | Returns alive contacts younger than N seconds, newest first. | trivial; per call, sorts a small array. | 0 | rewrite | Only the `alive` filter cheats (instant death knowledge); age it like any other fact. |
| `lambs_danger_fnc_pictureGet` | bluefield-creator | Returns (creating) the group's combat-picture hashmap. | trivial; per call. | 0 | keep | The layer 0 store, rewritten to the record format of ADR-0003. |
| `lambs_danger_fnc_pictureUpdate` | bluefield-creator | Merges sightings through the leader's `getHideFrom` and `knowsAbout`, prunes contacts older than 90 s or dead, recomputes recency-weighted threatPos, threatDir and losses at most once per second. | cheap; per call, O(contacts) with a 1 s refresh gate. | 0 | keep | Fair by construction: an enemy the leader does not know yields `[0,0,0]` and is skipped. |
| `lambs_danger_fnc_tactics` | nkenny (+fork) | Leader entry from the FSM: group AI off, first contact, else assess unless player-led or directed. | trivial; per leader FSM pass. | 2 | rewrite | Keep as the FSM-to-squad bridge but delete the `isPlayer` branch. |
| `lambs_danger_fnc_tacticsAssault` | nkenny (+fork) | Rush a position: LINE and FULL, building memory, vehicles to overwatch, smoke, every man ordered `assault` through the machine, reload check, timed reset. | expensive; one-shot per tactic, `findBuildings` 28 m, `findOverwatch`, `nearRoads`, `findReadyUnits` and `findReadyVehicles`. | 2 | rewrite | Good manoeuvre, but the CBA-timer reset, `groupMemory` and `enableIRLasers` fiddling are pre-monitor leftovers. |
| `lambs_danger_fnc_tacticsAssess` | nkenny (+fork) | Reactive plan picker: gather targets, feed picture, heuristic plan list, artillery call, flares and statics, filter by failure, role, intent and morale, random pick, monitor and delayed dispatch. | expensive; per leader assess, `targets`, `getEnvSoundController`×3, `findNearbyFriendlies`, `nearestObjects` per enemy, `terrainIntersectASL`, `findBuildings` 50 m, `doGroupStaticFind`, `doGroupStaticDeploy`, `doUGL`. | 2 | rewrite | Duplicates `commanderGroup` (two planners), reads exact enemy distances and `eyePos`, and `selectRandom` planning is not intent-driven; fold the useful heuristics into the commander. |
| `lambs_danger_fnc_tacticsAttack` | nkenny | Whole group `doTarget` and `doFire` one enemy in DIAMOND, RED, timed reset. | cheap; one-shot, `findNearestEnemy` fallback. | 2 | delete | Engine attack on a real object with no machine orders; the bound and assault tactics cover it. |
| `lambs_danger_fnc_tacticsBound` | bluefield-creator | Fire and movement: split base and assault, suppress list from picture and buildings, AWARE with no AUTOCOMBAT, starts `doGroupBound` with a token, resets when the monitor ends it. | moderate; one-shot, `findBuildings` 20 m, `findReadyUnits` and `findReadyVehicles`. | 2 | keep | Picture-driven, releases through `unitRelease`, responds to the monitor. |
| `lambs_danger_fnc_tacticsCQB` | nkenny | Declares nearby buildings as CQB assault positions into `inCQB`. | moderate; `findBuildings` per call. | 2 | delete | Disabled ("awaiting polish") and never called. |
| `lambs_danger_fnc_tacticsFlank` | nkenny (+fork) | Probing flank: overwatch via `selectBestPlaces`, FILE, low stance, `forceMove`, hands off to `doGroupFlank`. | expensive; one-shot, `selectBestPlaces` 20 samples, `findBuildings` 12 m, `nearestTerrainObjects`, `findOverwatch`. | 2 | rewrite | Keep the manoeuvre, but it still uses `allowGetIn false`, `forceMove` outside the machine and `doGroupFlank` legacy movement instead of `unitOrder`. |
| `lambs_danger_fnc_tacticsGarrison` | nkenny, bluefield-creator | Every man to a building fighting position with a view of the threat via `findPositions` and `unitOrder hold`, timed reset. | expensive; one-shot, `findPositions` with `count = 2×units`. | 2 | keep | Machine-based, claims positions, releases. |
| `lambs_danger_fnc_tacticsHide` | nkenny (+fork) | Disperse into cover, WHITE hold fire, launcher men engage tanks and air, `doGroupHide`, timed reset. | moderate; one-shot, `targets [true,600]`, `getLauncherUnits`. | 2 | rewrite | Anti-armour reaction is worth keeping, but `doGroupHide` bypasses `unitOrder`. |
| `lambs_danger_fnc_tacticsHold` | nkenny (+fork) | No plan: random facing, and if hurt or suppressed hide, attack (assertive) or withdraw (broken). | cheap; one-shot, `findNearestEnemy`. | 2 | delete | A fallback for a reactive planner that the commander replaces; uses `findNearestEnemy`. |
| `lambs_danger_fnc_tacticsManeuver` | bluefield-creator | Deliberate attack state machine (mounted, dismount, approach, assault, clear, consolidate) on its own 4 s PFH with support-by-fire, shift and lift, emergency dismount, consolidation and intent update. | expensive; one-shot plan (`findApproach`, `findGroupVehicles`, `findBuildings`) then per 4 s `doTeamMove`, `findPositions`, `nearestTerrainObjects`, `contingency` every cycle. | 2 | rewrite | The best squad behaviour in the addon, but 700 lines with the contingency re-run every 4 s and per-phase geometry queries need a budget. |
| `lambs_danger_fnc_tacticsMonitor` | bluefield-creator | Per-group 5 s PFH ending a tactic on completed, failed or timeout, recording result in the picture. | cheap; per 5 s per group, `pictureContacts` and distance loop. | 2 | keep | Outcome-based ending is what makes tactics composable; becomes the `monitor` of ADR-0011. |
| `lambs_danger_fnc_tacticsProfiles` | nkenny | Returns false (stub). | trivial; unused. | 2 | delete | Dead stub. |
| `lambs_danger_fnc_tacticsReinforce` | nkenny | Reinforce a call: clear holding waypoints, grab nearby empty vehicles, statics pack and deploy, flares, `group move`. | expensive; one-shot, `nearestObjects` 75 m, `allDeadMen findIf`, `doGroupStaticPack` and `doGroupStaticDeploy`, `taskReset`. | 3 | rewrite | Reinforcement is a Director action under a Zeus budget; the vehicle grabbing and body looting are unbudgeted side effects. |
| `lambs_danger_fnc_tacticsSuppress` | nkenny (+fork) | Suppress a position from where the group stands (or flank if it cannot), LINE, `doGroupSuppress`, monitor-aware reset. | moderate; one-shot, `shouldSuppressPosition`, `findBuildings` 20 m, `nearestTerrainObjects`. | 2 | keep | Base-of-fire primitive, picture-driven. |
| `lambs_danger_fnc_tacticsWithdraw` | bluefield-creator | Break contact: covering pair suppresses, rest rush to cover 120 m away under smoke, pair follows, monitor-aware reset. | moderate; one-shot, `selectBestPlaces`, `checkVisibilityList`. | 2 | keep | Machine-based, records `withdrawTime`, releases. |
| `lambs_danger_fnc_unitCycle` | bluefield-creator | Cheap pass over all registered men (life, mounted, arrival, timeouts, peek and duck, suppressed event, hold end) then budgeted `unitThink`. | moderate; per 0.5 s tick, O(registered units) cheap checks, `checkVisibilityList` + `doSuppress` on flips, ≤12 thinks. | 1 | keep | Budgeted, event-fed, the layer 1 scheduler. |
| `lambs_danger_fnc_unitEvent` | bluefield-creator | Feeds `hit`, `nearMiss`, `suppressed` and `threatSeen` into a man's record: head down, shift later, retarget watch. | trivial; per event. | 1 | keep | Event-driven, no queries. |
| `lambs_danger_fnc_unitInit` | bluefield-creator | Starts the 0.5 s unit PFH. | trivial; one-shot. | infra | keep | Budgeted PFH. |
| `lambs_danger_fnc_unitOrder` | bluefield-creator | The single movement issuer: move, rush, assault, hold, cover, survive, follow and release with options, sets record and `forceMove`. | trivial; per order, `doSmoke` on survive. | 1 | keep | One movement API is the design goal. |
| `lambs_danger_fnc_unitRegister` | bluefield-creator | Creates a man's record and adds him to the registry (local AI infantry only). | trivial; per call. | 1 | keep | Needed. |
| `lambs_danger_fnc_unitRelease` | bluefield-creator | Hands a man back: release position claim, clear record, restore stance, speed and AI features, follow leader. | trivial; per call. | 1 | keep | The release path every tactic uses. |
| `lambs_danger_fnc_unitState` | bluefield-creator | Reads a record field or the `isBusy` ownership test. | trivial; per call. | 1 | keep | Accessor. |
| `lambs_danger_fnc_unitThink` | bluefield-creator | Expensive half: shift positions, choose hold or cover spot, survive destination, assault building, next leg via `findPositions`. | expensive; per budgeted think, one `findPositions` query per leg with a 3 s query gap. | 1 | keep | Already budgeted by `unitCycle`. |
| `lambs_danger_fnc_zeusWaypointInit` | bluefield-creator | Client 5 s poll hooking `CuratorWaypointPlaced/Edited/Deleted` to raise directed-move events. | trivial; per 5 s client poll. | 4 | keep | Zeus input path; the poll is cheap but could be event-driven on curator assignment. |
| `lambs_danger_fnc_moduleConfigureGroupAI` | LAMBS | Zeus module dialog to set `disableGroupAI` and `enableGroupReinforce` on a group. | trivial; per module drop. | 4 | rewrite | Group AI off stays; `enableGroupReinforce` should become a Director budget rather than a per-group flag. |
| `lambs_danger_fnc_moduleDiagnose` | bluefield-creator | Zeus module asking the owner for a diagnosis of the group under cursor or a chosen one. | trivial; per module drop. | debug | keep | Zeus diagnostic. |
| `lambs_danger_fnc_moduleDirectedMove` | bluefield-creator | Zeus module putting the group under cursor (or chosen) on a directed move to the module position. | trivial; per module drop, `allGroups` sort. | 4 | keep | Zeus command path. |
| `lambs_danger_fnc_moduleDisableAI` | LAMBS | Zeus module toggling the per-unit `disableAI` flag. | trivial; per module drop. | 4 | keep | Zeus off-switch. |
| `lambs_danger_fnc_modulePosture` | bluefield-creator | Zeus module dialog for posture, escalation cap, mode and radius (intent). | trivial; per module drop. | 4 | keep | The intent UI. |
| `lambs_danger_fnc_moduleSetRadio` | LAMBS | Zeus module toggling the per-unit `dangerRadio` flag read by `lambs_main` information sharing. | trivial; per module drop. | 0/4 | keep | Comms capability is a layer 0 knob. |
| `lambs_danger_fnc_setDiagnose` (ZEN) | bluefield-creator | ZEN context action requesting diagnoses for selected groups. | trivial; per action. | debug | keep | Zeus diagnostic. |
| `lambs_danger_fnc_setDisableAI` (ZEN) | LAMBS | ZEN action setting unit `disableAI`. | trivial; per action. | 4 | keep | Zeus off-switch. |
| `lambs_danger_fnc_setDisableGroupAI` (ZEN) | LAMBS | ZEN action setting group `disableGroupAI`. | trivial; per action. | 4 | keep | Zeus off-switch. |
| `lambs_danger_fnc_setFollowWaypoints` (ZEN) | bluefield-creator | ZEN action starting a directed move along the current waypoint or a new MOVE at the click. | trivial; per action. | 4 | keep | Zeus command path. |
| `lambs_danger_fnc_setHasRadio` (ZEN) | LAMBS | ZEN action setting unit `dangerRadio`. | trivial; per action. | 0/4 | keep | Comms knob. |
| `lambs_danger_fnc_setPosture` (ZEN) | bluefield-creator | ZEN action opening the intent dialog for selected groups. | trivial; per action. | 4 | keep | Intent UI. |
| `lambs_danger_fnc_setReinforcement` (ZEN) | LAMBS | ZEN action setting `enableGroupReinforce` on objects. | trivial; per action. | 4 | rewrite | Sets the flag on units, not groups, while every reader checks the group; fold into a Director budget. |
| `lambs_danger_fnc_setResumeBehaviour` (ZEN) | bluefield-creator | ZEN action releasing directed moves. | trivial; per action. | 4 | keep | Zeus release path. |
| `lambs_danger_fnc_showHasRadio` (ZEN) | LAMBS | ZEN visibility condition for the radio toggle. | trivial. | 4 | keep | UI condition. |
| `lambs_danger_fnc_showReinforcement` (ZEN) | LAMBS | ZEN visibility condition for the reinforce toggle. | trivial. | 4 | rewrite | Follows `setReinforcement`. |
| `lambs_danger_fnc_showResumeBehaviour` (ZEN) | bluefield-creator | ZEN visibility condition: any selected group is directed. | trivial. | 4 | keep | UI condition. |
| `lambs_danger_fnc_showSetDisableAI` (ZEN) | LAMBS | ZEN visibility condition for unit AI toggle. | trivial. | 4 | keep | UI condition. |
| `lambs_danger_fnc_showSetDisableGroupAI` (ZEN) | LAMBS | ZEN visibility condition for group AI toggle. | trivial. | 4 | keep | UI condition. |
| `scripts/lambs_danger.fsm` | nkenny | The soldier danger FSM: 17 states routing engine danger causes through the brain functions and the leader into tactics. | cheap; engine-driven per danger event, all work in the called functions. | 1 | rewrite | Structure stays, but `Reset_foot` re-queues `getPosASL _dangerCausedBy` (exact position, `lambs_danger.fsm:475`) and `Check_queue` re-queues on `groupMemory`. |
| `scripts/lambs_dangerCivilian.fsm` | nkenny | Civilian panic FSM: hide, run away, inspect bodies, panic animations, remount. | cheap; engine-driven. | 1 | delete | Civilians are out of scope for an adversary AI. |

## 3. Knowledge model today

**What the picture stores.** `fnc_pictureGet.sqf:38-52` creates one hashmap per group in
`lambs_danger_picture` with: `contacts` (array of `[enemy object, positionATL from the leader's
getHideFrom, lastSeenTime, leader knowsAbout]`), `threatPos` (recency-weighted centroid of
contact positions, `[]` when none), `threatDir` (leader bearing to threatPos, -1),
`lastContact`, `updated` (last derived-value refresh), `maxCount`, `losses`, `morale`,
`moraleTime`, `lastTactic`, `lastResult`, `lastTacticTime`, `withdrawTime`. Other code adds
keys to the same map: `escalation`, `escalationTime`, `escalationPrev`
(`fnc_commanderEscalation.sqf:59-63`), `pursuePos`, `fallingBack`, `ambushSprung`
(`fnc_commanderGroup.sqf:144,153,172,217`). There is no per-contact confidence, no source
(who saw it), no error radius, and no side-level store: every group's picture is private and
the only cross-group channel is `lambs_main` `OnInformationShared` (positions) and the side
board's clustering of `threatPos` values.

**How contacts enter.** Only through `fnc_pictureUpdate`, which is called with: the FSM's
engage target (`fnc_brainEngage.sqf:65`), the leader's `targets [true, 800]` while under
orders (`fnc_brainForced.sqf:35`) and every 4 s inside a maneuver
(`fnc_tacticsManeuver.sqf:281`), the first-contact enemy (`fnc_contact.sqf:40`), and the
leader's `targets [true, range]` in the reactive assess (`fnc_tacticsAssess.sqf:63`). Every
sighting is re-projected through the **leader's** knowledge (`fnc_pictureUpdate.sqf:37-39`):
`getHideFrom` gives `[0,0,0]` for an enemy the leader does not know and the entry is skipped,
so the picture cannot hold a contact the group leader's engine sensors have not registered.
That is the addon's de facto fairness filter, and also its blind spot (a rifleman's sighting
the leader has not shared is lost).

**How contacts age.** `fnc_pictureUpdate.sqf:59` drops contacts dead or older than
`CONTACT_MAX_AGE 90` s, only when the derived refresh runs (≥1 s since `updated`);
`threatPos` weights each contact by `1 - age/90` (`fnc_pictureUpdate.sqf:71`). Readers apply
their own window: `pictureContacts` default 60 s, 30 s (`tacticsAssault`), 20 s (`maneuver`
mounted and approach), 25 s (`tacticsMonitor`), 90 s (maneuver dismount). Escalation decays
from contact age (`ENGAGED_AGE 30`, `ALERT_AGE 180`, one level per `DECAY_TIME 60`). Nothing
ages the stored position itself: an 89 s old contact still contributes its last-seen position
at 1% weight, and `threatPos` is never "unknown" until every contact expires.

**Where code still reads engine truth or direct enemy state (file:line, judgement):**

- `XEH_preInit.sqf:47` `_unit targetKnowledge _target select 6` / `knowsAbout > 1.5`: the reporter's own estimate, fair; but the estimate is passed to other groups verbatim, so the receiver must add error and age under the report rule.
- `scripts/lambs_danger.fsm:475` `ASLtoAGL (getPosASL _dangerCausedBy)` re-queued as an ENEMYDETECTED cause for a live target under 35 m: exact position, violates R1 even at short range; use `getHideFrom`.
- `fnc_brain.sqf:324,338` `side (group _dangerCausedBy)`: side of the cause object, fair (the engine already told the unit).
- `fnc_brainAssess.sqf:85` `getHideFrom`: fair.
- `fnc_brainEngage.sqf:55` `knowsAbout`: fair; `:55` `speed _target`, `:62` `distance2D _target`, `:79` `vehicle _target`, `:85` `_target isIndoor`: exact state of the real object, violates (use the picture position and its `knowsAbout`); `:70,87,114` `getHideFrom`: fair.
- `fnc_brainForced.sqf:35` `targets [true, 800]`: engine sensor list, fair.
- `fnc_brainVehicle.sqf:62` `getHideFrom`: fair; `:76` `_dangerCausedBy distance _vehicle`, `:90` `isTouchingGround _dangerCausedBy`, `:208` `distance`, `:225,289,302` `eyePos _dangerCausedBy` in LOS tests: exact position used for distance and LOS; the LOS boolean is defensible, the distances are not; `:157` `findNearestEnemy`: engine knowledge-limited, borderline; `:224,359` `knowsAbout`: fair.
- `fnc_contact.sqf:25` `targets [true]`, `:50` `getDir _enemy` (exact bearing), `:110` `getHideFrom`, `:130` `distance2D _enemy` (debug only): `targets` fair, the formDir bearing is a small leak.
- `fnc_pictureUpdate.sqf:37-39` `getHideFrom` and `knowsAbout` of the leader: fair, the filter described above; `:59` and `fnc_pictureContacts.sqf:26` `alive (_x select 0)`: instant global death knowledge, minor violation (age it instead).
- `fnc_tacticsAssess.sqf:59` `targets [true, range]`: fair; `:91,110,124,143,152,177,203` `_unit distance2D _x` on real enemies and `:125` `getPos _x`, `:205` `nearestObjects [_x, ...]`, `:179` `getPosASL _x select 2`, `:180,224` `eyePos _x`: exact positions drive every plan branch, violates; `:98-212` `getHideFrom` for the plan position: fair; `:178` `knowsAbout`: fair.
- `fnc_tacticsHide.sqf:90` `targets [true, 600, [], 0, _target]`: fair.
- `fnc_tacticsHold.sqf:30` and `fnc_tacticsAttack.sqf:32`, `fnc_tacticsCQB.sqf:51` `findNearestEnemy`: engine picks a known enemy, then `tacticsAttack` `doTarget` and `doFire` the object; borderline (engine-side), but the tactics are slated for deletion.
- `fnc_tacticsManeuver.sqf:281` `targets [true, 800]`: fair; everything else in the commander, maneuver, bound, withdraw and garrison chain reads `threatPos` and `pictureContacts` only.
- `XEH_preInitClient.sqf:49,56,109` `findNearestEnemy` and `cursorObject`: player quick commands, delete with the file.
- Skill is never raised anywhere in the addon; `brainVehicle.sqf:83,162,401` and `contingency` only `setSuppression 0.94` (a handicap) on dismount. No teleport or ammo grant exists; `tacticsReinforce.sqf:83-91` claims nearby empty vehicles into the group (`addVehicle`), which is a resource acquisition without a resupply action and should go under a Director budget.

## 4. Notes

**Group variables (all `lambs_danger_` unless prefixed):** `picture` (combat picture hashmap,
above); `intent` (`[mode, objective, radius, posture, cap, home, setTime]`, public); `contact`
(time until which the group counts as "in contact"; `tactics` calls `fnc_contact` when
expired); `isExecutingTactic` (a tactic owns the group; gates `isLeader`, commander, monitor);
`role` and `roleTime` (side-board "assault" or "support", sticky 60 s); `commanderNext` (next
think time); `reinforceRequest` (`[time, threatPos]` from a broken group);
`enableGroupReinforce` and `enableGroupReinforceTime` (legacy opt-in and cooldown, public);
`alertTime` (helper became alert); `explosions` (last 6 `[time,pos]` shell impacts);
`shelledTime` (spacing doubles for 60 s); `boundToken` (identifies the live `doGroupBound`
cycle); `tacticPFH` (monitor handle); `maneuver` and `maneuverPFH` (deliberate-attack state
hashmap and handle); `inCQB` (dead, cleared only by directedMoveSet); `disableGroupAI` (Zeus
and 3DEN off-switch, public); `dangerFormation` (read in `contact.sqf:49`, never written
here); `directedMove` (`[wpIndex, wpPos, until, curatorOwner, discipline, prevAttackEnabled]`,
public, read by `lambs_main_fnc_isDirected`); `directedProgress` (`[lastDistance,
lastProgressTime, reissues, diagnosisSent]`); `directedPFH`; `directedMounting`;
`lambs_main_groupMemory` (building positions, legacy); `lambs_main_currentTactic` (debug
label); `lambs_main_staticWeaponList`; `lambs_wp_taskSnapshot` and `lambs_wp_attackWaypoint`
(read only).

**Unit variables:** `unit` (the soldier-machine record hashmap: state Idle, Moving, Rushing,
Surviving, InCover, Casualty, Mounted; order, final, hop, hopFinal, hopStart, hopFails,
hopCount, pauseUntil, position, alternates, unreachable, nextThink, nextQuery, needThink,
phase up or down, flipAt, lastHit, nearMisses, shifts, shiftAt, sector, suppressList,
onArrive, sprint, holdUntil, holdTime, hopMax, radius, assaultChosen, lastEvent); `forceMove`
(FSM takes the Forced branch; set by `unitOrder`, bound, flank, maneuver, cleared by
`unitRelease`, consolidate, directedMoveSet); `disableAI` (FSM exits; public); `dangerRadio`
(read by `lambs_main_fnc_getShareInformationParams`); `directedStrict` and
`directedAutoCombat` (what directedMoveSet changed, to undo); `lambs_main_currentTask`,
`currentTarget`, `FSMDangerCauseData` (debug); `lambs_main_survival` (self-preservation
window, also used as a hold lock); `lambs_main_lastHit`, `lambs_main_lastDamage`;
`lambs_main_rescuer` and `lambs_wp_disabledAI` (read only); `ace_medical_ai_lastHit` and
`lastFired` (written for ACE), `ace_medical_ai_healQueue` (read).

**Vehicle variables:** `crewReplaceUntil`, `vehicleDamage`, `warheadSwitchTimeout`,
`lambs_main_keepMounted`, `lambs_main_smokescreenTime`, `lambs_main_isArtillery`,
`lambs_main_mortarTime`. **Curator logic:** `waypointEH`. **Globals:** `fsmPriorities`,
`dangerUntil`, `Loaded_WP`, `commanderGroups`, `commanderCursor`, `commanderSideNext`,
`commanderPFH`, `units`, `unitCursor` (unused), `unitPFH`, `disableAIPlayerGroup`.

**Reset path.** There is no `tacticsReset` function. Each tactic schedules its own reset
closure: timer-based `CBA_fnc_waitAndExecute` in `tacticsAssault.sqf:54-69`,
`tacticsAttack.sqf:43-55`, `tacticsCQB.sqf:29-40`, `tacticsGarrison.sqf:40-53`,
`tacticsHide.sqf:37-51`, `tacticsHold.sqf:34-45`, `tacticsReinforce.sqf:49-60`;
condition-based `CBA_fnc_waitUntilAndExecute` (fires on timeout **or** when
`isExecutingTactic` is cleared) in `tacticsBound.sqf:50-79`, `tacticsFlank.sqf:46-65`,
`tacticsSuppress.sqf:44-60`, `tacticsWithdraw.sqf:49-66`; `tacticsManeuver` has its own
`_fnc_end` (`:215-256`). `fnc_tacticsMonitor` ends a tactic by clearing `isExecutingTactic`
and `currentTactic` and recording the result (`fnc_tacticsMonitor.sqf:51-65`) but does
**not** release units or restore group settings, so for the timer-based tactics the men stay
under machine orders (or `forceMove`) until the original timer fires, while the commander may
already have issued the next tactic. Units are released (`unitRelease` on every group member)
by the resets of assault, bound, flank, garrison, hide, suppress, withdraw and by maneuver
(except "completed", where men keep their consolidation positions and only `forceMove` is
cleared); they are **not** released by attack, hold, CQB or reinforce (none of which issue
machine orders, but reinforce leaves `isExecutingTactic` set for `delay*0.5` = 150 s and
`contact` for 300 s), nor by `contact` (its leader order self-releases after 8 s hold).
`tacticsBound` and `tacticsManeuver` `disableAI "AUTOCOMBAT"` and re-enable it in their
resets; `unitRelease` re-enables SUPPRESSION, TARGET and AUTOTARGET but never AUTOCOMBAT.
Group-wide cleanup also happens in `commanderGroup` consolidate (`:269-275`) and in
`directedMoveSet` (`:120-147`). `boundToken` is cleared only by the bound reset and maneuver,
so a monitor-ended bound keeps a stale token until the timer. ADR-0011 replaces all of this
with one lifecycle.

**Exists only to serve player-led groups, civilians or the player's own squad (delete):** the
whole of `XEH_preInitClient.sqf` (player-group AI toggle, quick suppress, hide and assault
keybinds); settings `disableAIPlayerGroup` and `disableAIPlayerGroupReaction`
(`settings.inc.sqf:3-20`, the second has no reader anywhere in the addon);
`fnc_isForced.sqf:22`; the `isPlayer` guards in `fnc_tactics.sqf:38`, `fnc_contact.sqf:70`,
`fnc_commanderGroup.sqf:42`, `fnc_commanderContingency.sqf:43,163`,
`fnc_commanderSide.sqf:105`, `fnc_tacticsManeuver.sqf:90`, `fnc_unitOrder.sqf:54`,
`fnc_unitRegister.sqf:20`, `fnc_directedMoveWatchdog.sqf:47`, `fnc_directedMoveSet.sqf:41`,
`fnc_moduleDirectedMove.sqf:23-25`, `fnc_modulePosture.sqf:27`,
`ZEN/fnc_setFollowWaypoints.sqf:27`, `fnc_moduleDisableAI.sqf:15`,
`fnc_moduleSetRadio.sqf:15` and the `player` flag in `fnc_directedMoveDiagnose.sqf:113,132`
(harmless but dead once no unit can be a player); `scripts/lambs_dangerCivilian.fsm`,
`fnc_fsmAllowAnimation`, and the `Civilian_F` binding in `CfgVehicles.hpp:14-16`. Also worth
removing as dead weight: `fnc_brainAdjust`, `fnc_tacticsProfiles`, `fnc_tacticsCQB` and the
`inCQB` and `CQB_formations` remnants, `unitCursor`, and the `groupMemory` building-list
pattern (`fnc_brainHide.sqf:78-84`, `fnc_contact.sqf:96-98`, `fnc_tacticsAssault.sqf:91`,
`lambs_danger.fsm` `Check_queue`), which is a second, unaged knowledge store outside the
picture.
