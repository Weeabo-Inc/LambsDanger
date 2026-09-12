# Map: `addons/wp`, `eventhandlers`, `formations`, `range`

Part of [UPSTREAM-MAP.md](../UPSTREAM-MAP.md). Line numbers refer to the tree at the time of
writing (commit `b1885db`).

## 1. What each addon is

**wp** (`lambs_wp`). The tasking layer: fourteen `task*` and `do*` behaviours a group can be
put into (garrison, defend, camp, CQB, patrol, assault and retreat, rush, hunt, creep, attack
including air assault, artillery, register, reset), the three ways a mission maker or Zeus
reaches them (3DEN modules, Zeus modules, ZEN context actions, plus the deprecated scripted
waypoint classes), a side-wide artillery registry with a request and fire event pair, and a
small task-lifecycle kit (`taskBegin`, `taskIsCancelled`, `taskCleanup`) added by the fork so
tasks can be cancelled and undone. Runtime entry is always a CBA `targetEvent` to the group
leader, so every task starts on the machine that owns the group.

**eventhandlers** (`lambs_eventhandlers`). One XEH `Explosion` handler on `CAManBase` that
makes a local, non-player, dismounted, non-prone AI flinch: after a reaction delay scaled by
distance (speed of sound) and `skill "general"`, it shouts, drops or dives prone away from
the blast via `lambs_main_doSwitchMove`, and sets a short cooldown. Two CBA settings gate it.

**formations** (`lambs_formations`). Config only, no code. It overrides four states of the
engine `Formation` FSM (the two drop-to-ground states and `Reload` become no-ops,
`Search_path__Covering` gets new parameters) and tunes `Man` (crouch probabilities to 0,
faster formation catch-up, tighter spacing, shorter brake distance) and `Static` (`coefInside`
and `coefSpeedInside` 1.5 so units inside static objects are slowed less).

**range** (`lambs_range`). Config only, one value: `CAManBase.sensitivity = 6`, which raises
how far every AI man can perceive.

## 2. wp functions

| Function | Author | What it does | Cost | Locality | Layer | Verdict | Why |
|---|---|---|---|---|---|---|---|
| `lambs_wp_fnc_taskArtillery` | nkenny | Routes a fire mission: if arg 0 is a gun it `targetEvent`s `FireArtillery` to the gun's owner, otherwise it `serverEvent`s `RequestArtillery` for the side. | Trivial, one-shot, two event sends. | Any machine; nothing runs here, the server and gun owner do the work. | 3 | keep | Clean public entry point and the only way `doCallArtillery` and the modules fire; the Director sits behind this signature and adds budget and throttle. |
| `lambs_wp_fnc_taskArtilleryRegister` | nkenny | Collects the vehicles of a group with `artilleryScanner > 0`, tags each as MRLS or not from the gunner turret weapon `nameSound`, and `serverEvent`s `RegisterArtillery`. | Cheap, one-shot (`configOf`, `weaponsTurret`, one `forEach`), forces unscheduled via `CBA_fnc_directCall`. | Any machine; only the server mutates `SideArtilleryHash`, then `publicVariable`s it to all. | 3 | keep | Correct, cheap, and the registry is the Director's inventory of indirect fire. |
| `lambs_wp_fnc_doArtillery` | nkenny | Executes one strike on the gun's owner: turns the gun, waits a distance-scaled delay, fires 1 to 2 check-round barrages then a walking main barrage of `_rounds` × `_salvo` over a cone offset toward the gun, then re-registers the gun. | Expensive in wall time, cheap in CPU: scheduled `spawn` with `sleep` (30 to 90 s, then `_time + random 35` per check round) and `waitUntil {unitReady _gun}` after every `commandArtilleryFire`; runs once per strike. | Runs where the gun is local (arrives by `targetEvent`); if the gun changes owner mid-strike `commandArtilleryFire` silently does nothing and `waitUntil {unitReady _gun}` can hang the thread until the caller dies. | 3 | rewrite | Same behaviour on a `CBA_fnc_waitUntilAndExecute` chain with an ownership check per step, so a migrated gun cannot stall a scheduled thread and the strike can be budgeted by the Director; rebuilt around an observer in milestone 5 (C-52). |
| `lambs_wp_fnc_sideHasArtillery` | joko // Jonas | Returns whether `SideArtilleryHash` holds a gun for the side that `canFire`, is `unitReady`, simulated, and (if a position is given) `inRangeOfArtillery`. | Cheap, one-shot; `inRangeOfArtillery` per registered gun. | Any machine, the hash is public. | 3 | keep | Pure query on public state, used by `tacticsAssess`, `taskDefend`, `doCallArtillery` and the Zeus artillery module. |
| `lambs_wp_fnc_taskBegin` | bluefield-creator | Bumps the group's task token so older loops exit, snapshots attack, speed, formation, behaviour, combatMode and `disableGroupAI` the first time, sets `currentTactic`. | Trivial, one-shot. | Non-broadcast group variables, so it is only meaningful on the owner. | 2 | keep | This is the cancellation contract every task now relies on. |
| `lambs_wp_fnc_taskCleanup` | bluefield-creator | Invalidates the token, removes the defend PFH, re-enables disabled AI features, removes task EHs, releases each unit from the soldier machine, resets speed, stance and getIn, restores the snapshot. | Cheap, one-shot, one `forEach` over units. | Exits unless `local _group`; safe on a group without a task. | 2 | keep | Single undo path for every task, already called from `directedMoveSet` and `directedMoveDeleted`. |
| `lambs_wp_fnc_taskIsCancelled` | bluefield-creator | True when the group is null or its token no longer matches. | Trivial. | Reads a non-broadcast variable, so only the owner's answer is right. | 2 | keep | Two-line predicate that all loops poll. |
| `lambs_wp_fnc_doAssaultUnitReset` | nkenny | Per-unit undo for taskAssault: clears variables, re-enables six AI features, removes EHs, and for retreat plays a drop-to-prone animation via global event. | Cheap, one-shot. | Must run where the unit is local (`enableAI`, `doMove`). | 1 | delete | Duplicates `taskCleanup` per unit; once taskAssault is rewritten on the soldier machine its only caller goes away. |
| `lambs_wp_fnc_doAirLoiter` | bluefield-creator | After a drop, gives the aircrew group a LOITER (armed, 300 m circle around the objective, RED) or a MOVE plus LOITER back at the take-off point (unarmed, YELLOW), sets `disableGroupAI`. | Trivial, one-shot, engine waypoints. | Group-local commands; called from the attack PFH on the owner. | 2 | keep | Engine does the flying; the only scripted choice is armed vs unarmed. |
| `lambs_wp_fnc_doHeliInsert` | bluefield-creator | Takes the pilot's MOVE and FSM, flies the helicopter with `setVelocityTransformation` every frame onto the LZ, unloads the troops one by one into a 20 m security ring, hands control back with a climb-out. | Expensive per aircraft while active: PFH at delay 0 (per frame) doing vector maths and `setVelocityTransformation`, plus nested `CBA_fnc_waitUntilAndExecute` per troop; bounded by a 90 s timeout. | Requires `local _heli`; aborts cleanly if the aircraft dies, is crippled, the pilot dies, the task cancels it, or on timeout. | 1 | keep | One per-frame handler per inserting aircraft is the price of a landing that works without helipads; the cost stops at release. |
| `lambs_wp_fnc_taskAssault` | nkenny | "Rush heedlessly" (or forced retreat): disables TARGET, WEAPONAIM, FSM, COVER and SUPPRESSION on every man, adds Fired and Hit EHs, gives each unit its own PFH that `doMove`s it half-way to the destination at `forceSpeed 24`, and a scheduled loop drives vehicles; ends when all members are within threshold. | Expensive: one CBA PFH **per unit** at about 3 s plus a scheduled `sleep` loop per group, `forgetTarget` on all targets at start, `joinSilent` to a temp group to break ATTACK commands. | `!local _group` exit at start only; on owner change the PFHs and the loop keep running on the old owner and every `doMove` and `forceSpeed` silently no-ops, the task stalls until threshold or cancel. | 2 | rewrite | Keep the signature (waypoints, module, ZEN call it) but issue movement through `unitOrder` and `tacticsBound` rather than per-unit PFHs with the FSM switched off; the retreat variant becomes `tacticsWithdraw`. |
| `lambs_wp_fnc_taskAttack` | bluefield-creator | Attack Position: parks the S&D waypoint as HOLD, mounts and drives to a 300 m standoff or hands off to `taskAttackAir`, then a 6 s PFH approaches, engages through `tacticsManeuver` or `tacticsBound` when within 350 m or a contact is within 200 m, holds when the objective is quiet, gives up after two failed attacks, then sets intent and continues the Zeus route. | Moderate: PFH every 6 s with `pictureContacts`, distance checks, `allGroups findIf` when on the objective, `doMountUp` once. | `!local _group` exit at start; `_fnc_end` has no locality check, so after a migration the old owner still deletes the waypoint and calls `directedMoveSet`. | 2 | keep | Already written on the new core (intent, picture, tactics); only needs an owner check inside the PFH so a migrated group ends cleanly. |
| `lambs_wp_fnc_taskAttackAir` | bluefield-creator | One step per attack tick: plans an LZ 250 to 400 m short of the objective out of its line of sight, flies the helicopter there, moves the LZ once if a contact is within 200 m, lands via `doHeliInsert`, holds 15 s security, then splits the aircrew off and re-tasks other passenger groups with `taskAttack`. | Moderate once (28 `isFlatEmpty` and `terrainIntersectASL` at plan time), trivial per tick afterwards. | Called only from the attack PFH on the owner; it `targetEvent`s `taskAttack` to other groups' leaders so they start on their own owner. | 2 | keep | Uses only the group's own picture for the hot-LZ check and engine flight for transit. |
| `lambs_wp_fnc_taskCamp` | nkenny | Camp scenery: optionally splits off a 1 to 2 man patrol subgroup, seats men in nearby static gunners and building positions (teleport optional), the rest walk to spots around the centre and freeze in idle animations with ANIM and PATH disabled, woken by Hit, FiredNear or Suppressed via the `taskCampReset` event; adds SENTRY then HOLD, GUARD or SAD waypoints. | Cheap, one-shot (`findBuildings`, `nearestObjects` 50 m, one `CBA_fnc_waitUntilAndExecute` per unit). | `!local _group` at start; wake-up EHs `targetEvent` to the unit so they survive migration; the waypoint statements guard on `local this`. | 2 | rewrite | Freezing men with `disableAI "ANIM"/"PATH"` fights the soldier machine and the exit hands the group to engine GUARD or SAD; keep the signature and the look, drive it through `unitOrder` with an idle posture. |
| `lambs_wp_fnc_taskCQB` | nkenny | Room clearing: every cycle finds the nearest uncleared house (per-side cleared list stored on the building), sends ready men to its next building position at assault speed, others suppress the building from outside; a known enemy within 25 m of the building is rushed. | Moderate: scheduled `sleep _cycle` loop (21 s) plus a 1 Hz `waitUntil {sleep 1; simulationEnabled}` poll, `nearestObjects` 50 m per cycle, `buildingPos` scans. | `!local _group` at start only; loop continues on the old owner after migration with no effect. | 2 | rewrite | Target choice is fair (`findNearestEnemy` uses engine knowledge) but the unstick teleports a man 3.5 m when no player is within 50 m, which hides a teleport from players (R5); keep the signature, drop the teleport, run on `unitOrder`; the real CQB tactic comes in milestone 7. |
| `lambs_wp_fnc_taskCreep` | nkenny | Stalk: every cycle `findClosestTarget` picks the nearest enemy (players only by default), stance and combat mode scale with distance and forest cover, men `doMove` onto it and switch to RED and STEALTH under 40 m. | Cheap per cycle but a scheduled `sleep` loop (30 s, ×4 when idle) with a 1 Hz sim poll; `selectBestPlaces` and `allUnits` scan per cycle. | `!local _group` at start only. | 2 | rewrite | `findClosestTarget` scans `allUnits` and `playableUnits` with no knowledge test and the task `reveal`s the target: the AI acquires a target it never detected, which breaks R1 and R4; keep the signature, feed it from the contact store or a Director area. |
| `lambs_wp_fnc_taskDefend` | nkenny, bluefield-creator | Squad defence: splits the ground into sectors weighted to the threat direction, gives every man a fighting position with a field of fire and a third of the squad a hidden reserve, counterattacks a penetration, relays out when the threat turns, falls back a line after 34% losses, calls artillery on a threat outside the perimeter. | Moderate: PFH every 8 s with `pictureGet`, `pictureContacts`, `doGroupStaticFind`, `doUGL` at night, `unitState` per man; `findPositions` per man only on (re)layout. | `!local _group` at start; the PFH ends on cancel, wipe-out, or waypoint count change; no owner check, so the old owner keeps issuing `unitOrder`s after migration. | 2 | keep | Already the model for the new core; the artillery call uses the picture's `threatPos` (built from `getHideFrom`), so it is sensor-based. |
| `lambs_wp_fnc_taskGarrison` | nkenny | Puts men into static gunners and building positions (indoor first, height-sorted or shuffled), each held through `unitOrder` with an outward sector, and one exit EH per man (Hit, Fired, FiredNear, Suppressed, all, or random) that releases him; adds a HOLD waypoint. | Cheap, one-shot (`findBuildings`, `nearestObjects`, `lineIntersects` per position). | `!local _group` at start; exit EHs use `remoteExecCall` to the unit's owner, so they are migration-safe. | 2 | keep | Already on the soldier machine and locality-correct; the teleport option is Zeus setup, not AI behaviour. |
| `lambs_wp_fnc_taskHunt` | nkenny | Tracker: every cycle `findClosestTarget` picks the nearest enemy and the group `move`s to a random point 25 to 300 m from it with gunlights and IR lasers forced on; at night on foot it fires a UGL flare or, if nobody has a UGL, `createVehicle`s an `F_20mm_Red` flare 200 m up. | Cheap per cycle but a scheduled `sleep` loop (70 s) with a 1 Hz sim poll and an `allUnits` scan per cycle. | `!local _group` at start only. | 2 | rewrite | Omniscient target pick (see creep) and a flare conjured from nothing both break the contract; keep the signature and the flare-if-you-have-a-UGL flavour, take the area from the contact store or the Director. |
| `lambs_wp_fnc_taskPatrol` | nkenny | Lays 2 to 15 MOVE waypoints at random points in the radius or area with timeouts, the last one loops to the first and optionally re-randomises all positions; optional teleport to one of them and `enableGroupReinforce`. | Trivial, one-shot; engine waypoints afterwards. | `!local _group` at start; the waypoint statements guard on `local this` and read broadcast group variables, so the patrol survives migration. | 2 | keep | Cheapest task in the addon and fully engine-driven. |
| `lambs_wp_fnc_taskReset` | nkenny, bluefield-creator | Runs `taskCleanup`, releases a directed move, clears every LAMBS group and unit variable, re-enables all AI features, resets animation and stance; soft mode keeps the group, hard mode moves the units into a fresh group with the same id. | Cheap, one-shot. | `!local _group` exit; hard mode creates a new group, which breaks any outside reference to the old one. | 4 | keep | Zeus' panic button; every caller in the tree uses soft mode, hard mode stays for scripts. |
| `lambs_wp_fnc_taskRush` | nkenny | Aggressor: every cycle `findClosestTarget` picks the nearest enemy; the group suppresses aircraft under 200 m, AT men ready launchers against tanks under 80 m, otherwise everyone `doMove`s to the target with AUTOCOMBAT and FSM off. | Cheap per cycle but a scheduled `sleep` loop (15 s, stretched to 60 s at range) with a 1 Hz sim poll and an `allUnits` scan per cycle. | `!local _group` at start only. | 2 | rewrite | Same omniscient target pick as hunt and creep; keep the signature, drive the charge with `tacticsBound` or `tacticsManeuver` toward a picture contact. |
| `lambs_wp_fnc_moduleArtillery` | jokoho482 | Zeus: lists sides that have artillery in range of the module, shows a side, salvo, spread and skip dialog, then `taskArtillery` on that position; 3DEN: reads the attributes and waits until a gun is in range, then fires. | Trivial, one dialog; the 3DEN path holds a `CBA_fnc_waitUntilAndExecute` open indefinitely. | Runs where the logic is local (Zeus client or server). | 4 | keep | Zeus intent to strike a Zeus-chosen position is exactly what layer 4 owns; it spends the Zeus budget from milestone 5. |
| `lambs_wp_fnc_moduleArtilleryRegister` | jokoho482 | Zeus: registers the group under the cursor; 3DEN: registers synced groups, or every group whose leader is inside the module area. | Trivial (3DEN path: `allGroups` once). | Runs where the logic is local. | 4 | keep | Straight wrapper over `taskArtilleryRegister`. |
| `lambs_wp_fnc_moduleAssault` | jokoho482 | Zeus: group under cursor picks a dynamic target, or a dropdown of all live groups picks a destination; 3DEN: synced groups; `targetEvent` `taskAssault` to the leader, passing the logic itself as a moving destination unless delete-on-startup. | Trivial, dialog and `BIS_fnc_sortBy` over `allGroups`. | Dialog on the Zeus client; the task starts on the group owner. | 4 | extend | Keep the class and dialog, but the group list includes player groups and the moving-logic destination is only valid on the owner; filter players and always pass a position. |
| `lambs_wp_fnc_moduleAttack` | bluefield-creator | Zeus: dropped on a group it offers the module position or a dynamic target and a radius, on the ground it offers the nearest non-player groups; 3DEN: synced groups with the area radius; `targetEvent` `taskAttack`. | Trivial. | Dialog on the Zeus client; the task starts on the group owner. | 4 | keep | Already filters `isPlayer (leader _x)` and passes positions only. |
| `lambs_wp_fnc_moduleCQB` | jokoho482 | Same pattern as moduleAssault for `taskCQB` with radius, cycle and delete-on-startup. | Trivial. | As moduleAssault. | 4 | extend | Same fixes as moduleAssault (player groups in the list, logic object as destination). |
| `lambs_wp_fnc_moduleCamp` | jokoho482 | Same pattern for `taskCamp` with radius, exit waypoint, teleport, patrol. | Trivial. | As moduleAssault. | 4 | extend | Filter player groups from the dropdown. |
| `lambs_wp_fnc_moduleCreep` | jokoho482 | Zeus: group under cursor only, dialog for radius, cycle, moving centre, players only; 3DEN: synced groups. | Trivial. | As moduleAssault. | 4 | extend | Keep the class; the "players only" option must go because it is an omniscient player hunt. |
| `lambs_wp_fnc_moduleDefend` | jokoho482, nkenny | Same pattern for `taskDefend` with radius, cover type, teleport, stealth, patrol. | Trivial. | As moduleAssault. | 4 | extend | Filter player groups from the dropdown. |
| `lambs_wp_fnc_moduleGarrison` | jokoho482 | Same pattern for `taskGarrison` with radius, exit condition, sort by height, teleport, patrol. | Trivial. | As moduleAssault. | 4 | extend | Filter player groups from the dropdown. |
| `lambs_wp_fnc_moduleHunt` | jokoho482 | Zeus: group under cursor only, dialog for radius, cycle, moving centre, players only, reinforcement, UGL flare; 3DEN: synced groups. | Trivial. | As moduleAssault. | 4 | extend | Drop "players only"; keep the rest. |
| `lambs_wp_fnc_modulePatrol` | jokoho482 | Same pattern for `taskPatrol` with range, waypoint count, moving waypoints, reinforcement, teleport. | Trivial. | As moduleAssault. | 4 | extend | Filter player groups from the dropdown. |
| `lambs_wp_fnc_moduleReset` | jokoho482, nkenny | Zeus: unit under cursor; 3DEN: synced groups; `targetEvent` `taskReset` soft with waypoint clear. | Trivial. | Task runs on the group owner. | 4 | keep | Nothing to change. |
| `lambs_wp_fnc_moduleRush` | jokoho482 | Zeus: group under cursor only, dialog for radius, cycle, moving centre, players only; 3DEN: synced groups. | Trivial. | As moduleAssault. | 4 | extend | Drop "players only". |
| `lambs_wp_fnc_moduleTarget` | jokoho482 | Zeus: creates a named "Dynamic Target" logic at the cursor, and if placed on a unit `attachTo`s it so the target follows that unit; adds it to `ModuleTargets`. | Trivial. | Local logic on the Zeus client; `ModuleTargets` is not broadcast, so only that Zeus sees it. | 4 | extend | A target attached to a player is a live feed of that player's exact position to every task that reads it (assault, CQB, camp), which breaks R4; keep static targets, drop the attach-to-unit. |
| `lambs_wp_fnc_setArtilleryRegister` | (no header) | ZEN context: registers every selected group (and the groups of selected crews). | Trivial. | Zeus client. | 4 | keep | Wrapper. |
| `lambs_wp_fnc_setAssault` | bluefield-creator | ZEN context: `targetEvent` `taskAssault` to the leader of each selected group with the clicked position. | Trivial. | Zeus client; task starts on the owner. | 4 | keep | Correct locality by construction. |
| `lambs_wp_fnc_setAttack` | bluefield-creator | ZEN context: `targetEvent` `taskAttack` with the clicked position. | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setCQB` | (no header) | ZEN context: `taskCQB` centred on the leader object (moving centre). | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setCamp` | (no header) | ZEN context: `taskCamp` at the leader's position. | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setCreep` | (no header) | ZEN context: `taskCreep` with defaults (moving centre, players only by function default `true`). | Trivial. | As setAssault. | 4 | extend | Inherits the omniscient players-only default from `taskCreep`. |
| `lambs_wp_fnc_setDefend` | (no header) | ZEN context: `taskDefend` at the leader's position. | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setGarrison` | (no header) | ZEN context: `taskGarrison` at the leader's position. | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setHunt` | (no header) | ZEN context: `taskHunt` with defaults. | Trivial. | As setAssault. | 4 | extend | Inherits whatever `taskHunt` becomes. |
| `lambs_wp_fnc_setPatrol` | (no header) | ZEN context: `taskPatrol` at the leader's position. | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setReset` | (no header) | ZEN context: soft `taskReset` with waypoint clear. | Trivial. | As setAssault. | 4 | keep | Correct. |
| `lambs_wp_fnc_setRush` | (no header) | ZEN context: `taskRush` with defaults. | Trivial. | As setAssault. | 4 | extend | Inherits whatever `taskRush` becomes. |
| `lambs_wp_fnc_setTarget` | (no header) | ZEN context: `createVehicleLocal` a Target logic at the clicked position, attached to the first selected object if any, adds it to the curator's editable objects. | Trivial. | Local to the Zeus client only. | 4 | extend | Same attach-to-unit concern as moduleTarget. |
| `scripts\fnc_wpAssault.sqf` (waypoint) | nkenny | Deprecated `lambs_danger_Attack` waypoint: sets `danger_tactics` and `disableGroupAI`, `group move`, calls `taskAssault` with `_useWaypoint = true`. | Trivial wrapper. | Waypoint scripts run on the group owner. | 4 | keep | Compatibility for old missions; it is only a wrapper. |
| `scripts\fnc_wpRetreat.sqf` | nkenny | Deprecated `lambs_danger_Retreat` waypoint: as wpAssault with `_retreat = true`. | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `scripts\fnc_wpGarrison.sqf` | nkenny | Deprecated waypoint: `spawn`s `taskGarrison` with the completion radius (which then `directCall`s itself). | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `scripts\fnc_wpPatrol.sqf` | nkenny | Deprecated waypoint: `taskPatrol` with the completion radius. | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `scripts\fnc_wpRush.sqf` | nkenny | Deprecated waypoint: sets `disableGroupAI` and `tactics`, `taskRush` with the completion radius. | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `scripts\fnc_wpHunt.sqf` | nkenny | Deprecated waypoint: `taskHunt` with the completion radius. | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `scripts\fnc_wpCreep.sqf` | nkenny | Deprecated waypoint: `taskCreep` with the completion radius. | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `scripts\fnc_wpCQB.sqf` | nkenny | Deprecated waypoint: `taskCQB` with the completion radius and `_useWaypoint = true`. | Trivial wrapper. | Owner. | 4 | keep | Compatibility. |
| `lambs_wp_fnc_ArtilleryScan` (defined in `settings.inc.sqf`) | (no header) | When `lambs_wp_autoAddArtillery` is on, every 120 s scans `vehicles` for `artilleryScanner > 0` not blocked by `autoAddArtilleryBlocked` and registers each. | Cheap per pass (`vehicles` and `configOf`), repeats via `CBA_fnc_waitAndExecute` forever. | The setting is global, so the scan runs on **every** machine and each one sends `RegisterArtillery` to the server. | 3 | extend | Gate it on `isServer` so 200 AI on a dedicated server plus HCs do not trigger N redundant scans. |
| `XEH_preInit` events `RegisterArtillery`, `RequestArtillery`, `FireArtillery`, `task*`, `taskCampReset` | (no header) | Server: registry add and request-to-nearest-gun dispatch; all machines: `FireArtillery` spawns `doArtillery`, each `task*` event calls or spawns its task, `taskCampReset` wakes a camped unit. | Trivial dispatch. | Registry events are server-only; task events arrive on the group owner via `targetEvent`. | 2/3 | keep | The event surface is the locality contract; `taskCampReset` goes when taskCamp is rewritten. |
| `Cfg3DEN` attribute `lambs_WP_Editor_IsArtillery` | (config) | 3DEN checkbox on a vehicle that `spawn`s a wait for the function then registers the gunner's group. | Trivial. | Runs where the object inits (server for 3DEN). | 4 | keep | Mission-maker convenience with no runtime cost. |

Cross-cutting notes:

- `lambs_main_fnc_findClosestTarget` (used by hunt, rush, creep) builds its candidate list from `allUnits`, or `switchableUnits + playableUnits` when `_onlyPlayers` is true, filtered only by side, distance, altitude and area, never by `knowsAbout` or `targets`, so those three tasks always know where the nearest enemy is.
- Teleport options (garrison, camp, defend, patrol) are Zeus or mission setup at task start, not something the AI does during play; they stay as Zeus tools but are the one place a group can appear adjacent to players if a Zeus asks for it.
- No wp task serves a player-commanded group or civilians: every task filters `!isPlayer _x`, and `findClosestTarget` excludes `civilian`.

## 3. Zeus-facing surface (compatibility contract)

### Waypoint classes

`CfgWaypoints >> LAMBS_DangerAI` (3DEN, marked deprecated) and `ZEN_WaypointTypes` (ZEN,
type SCRIPTED) both expose the same classes; the waypoint script receives `[group, position]`
on the group owner.

| Class | 3DEN | ZEN | Script | Ends in |
|---|---|---|---|---|
| `lambs_danger_Attack` | yes | yes | `scripts\fnc_wpAssault.sqf` | `lambs_wp_fnc_taskAssault` |
| `lambs_danger_Retreat` | yes | yes | `scripts\fnc_wpRetreat.sqf` | `lambs_wp_fnc_taskAssault` (retreat) |
| `lambs_danger_Garrison` | yes | yes | `scripts\fnc_wpGarrison.sqf` | `lambs_wp_fnc_taskGarrison` |
| `lambs_danger_Patrol` | yes | yes | `scripts\fnc_wpPatrol.sqf` | `lambs_wp_fnc_taskPatrol` |
| `lambs_danger_Rush` | yes | yes | `scripts\fnc_wpRush.sqf` | `lambs_wp_fnc_taskRush` |
| `lambs_danger_Hunt` | yes | yes | `scripts\fnc_wpHunt.sqf` | `lambs_wp_fnc_taskHunt` |
| `lambs_danger_Creep` | yes | yes | `scripts\fnc_wpCreep.sqf` | `lambs_wp_fnc_taskCreep` |
| `lambs_danger_CQB` | yes | yes | `scripts\fnc_wpCQB.sqf` | `lambs_wp_fnc_taskCQB` |
| `lambs_danger_Artillery` (3DEN) / `lambs_danger_RegisterArtillery` (ZEN) | yes | yes | `functions\fnc_taskArtilleryRegister.sqf` | `lambs_wp_fnc_taskArtilleryRegister` |

The Zeus "Attack Position" path via a plain engine Seek & Destroy waypoint (`taskAttack` with
`_wpIndex`) is wired from the danger addon's directed-move code, not from a wp waypoint class.

### 3DEN modules (`modules.hpp`, base `lambs_wp_BaseModule`, all `scope = 2`, sync to `AnyBrain` and an optional `Condition` trigger)

| Class | Attributes (property names) | Function |
|---|---|---|
| `lambs_wp_TaskArtillery` | `lambs_wp_Side` (0 west, 1 east, 2 indep), `lambs_wp_MainSalvo`, `lambs_wp_Spread`, `lambs_wp_SkipCheckRounds` | `lambs_wp_fnc_moduleArtillery` |
| `lambs_wp_TaskArtilleryRegister` | area (default 100 m) | `lambs_wp_fnc_moduleArtilleryRegister` |
| `lambs_wp_TaskAssault` | `lambs_wp_IsRetreat`, `lambs_wp_DeleteOnStartUp`, `lambs_wp_DistanceThreshold`, `lambs_wp_CycleTime` | `lambs_wp_fnc_moduleAssault` |
| `lambs_wp_TaskCamp` | area (50 m), `lambs_wp_ExitWP` (-1 random, 0 hold, 1 guard, 2 SAD), `lambs_wp_Teleport`, `lambs_wp_Patrol` | `lambs_wp_fnc_moduleCamp` |
| `lambs_wp_TaskCQB` | area (50 m), `lambs_wp_CycleTime`, `lambs_wp_DeleteOnStartUp` | `lambs_wp_fnc_moduleCQB` |
| `lambs_wp_TaskGarrison` | area (50 m), `lambs_wp_ExitConditions` (-2 random, -1 all, 0 none, 1 hit, 2 fired, 3 firedNear, 4 suppressed), `lambs_wp_SortByHeight`, `lambs_wp_Teleport`, `lambs_wp_Patrol` | `lambs_wp_fnc_moduleGarrison` |
| `lambs_wp_TaskPatrol` | area (200 m), `lambs_wp_WaypointCount`, `lambs_wp_moveWaypoints`, `lambs_wp_enableReinforcement`, `lambs_wp_teleport` | `lambs_wp_fnc_modulePatrol` |
| `lambs_wp_TaskReset` | none | `lambs_wp_fnc_moduleReset` |
| `lambs_wp_TaskDefend` | area (75 m), `lambs_wp_useCover` (0 to 6), `lambs_wp_stealth`, `lambs_wp_Teleport`, `lambs_wp_Patrol` | `lambs_wp_fnc_moduleDefend` |
| `lambs_wp_TaskCreep` | area (1000 m), `lambs_wp_MovingCenter`, `lambs_wp_PlayersOnly`, `lambs_wp_CycleTime` | `lambs_wp_fnc_moduleCreep` |
| `lambs_wp_TaskHunt` | area (1000 m), `lambs_wp_MovingCenter`, `lambs_wp_PlayersOnly`, `lambs_wp_CycleTime`, `lambs_wp_enableReinforcement`, `lambs_wp_doUGL` (0, 1, 2) | `lambs_wp_fnc_moduleHunt` |
| `lambs_wp_TaskRush` | area (1000 m), `lambs_wp_MovingCenter`, `lambs_wp_PlayersOnly`, `lambs_wp_CycleTime` | `lambs_wp_fnc_moduleRush` |

There is no 3DEN `TaskAttack` module class; `lambs_wp_ZeusTaskAttack` handles synced objects in
its non-curator branch, but it is `scope = 1` so it is not placeable in 3DEN.

### Zeus modules (`zeusModules.hpp`, `scopeCurator = 2`, categories `Lambs_Danger_WP_Cat` and `Lambs_Danger_WP_Search_Cat`)

| Class | Function | Dialog |
|---|---|---|
| `lambs_wp_Target` | `lambs_wp_fnc_moduleTarget` | none, creates a Dynamic Target |
| `lambs_wp_ZeusTaskArtillery` | `lambs_wp_fnc_moduleArtillery` | side, salvo, spread, skip check rounds |
| `lambs_wp_ZeusTaskArtilleryRegister` | `lambs_wp_fnc_moduleArtilleryRegister` | none, group under cursor |
| `lambs_wp_ZeusTaskAssault` | `lambs_wp_fnc_moduleAssault` | group or target, retreat, threshold, cycle, delete on startup |
| `lambs_wp_ZeusTaskAttack` | `lambs_wp_fnc_moduleAttack` | group or target, radius |
| `lambs_wp_ZeusTaskCamp` | `lambs_wp_fnc_moduleCamp` | group or target, radius, exit WP, teleport, patrol |
| `lambs_wp_ZeusTaskCQB` | `lambs_wp_fnc_moduleCQB` | group or target, radius, cycle, delete on startup |
| `lambs_wp_ZeusTaskDefend` | `lambs_wp_fnc_moduleDefend` | group or target, radius, cover, teleport, stealth, patrol |
| `lambs_wp_ZeusTaskGarrison` | `lambs_wp_fnc_moduleGarrison` | group or target, radius, exit condition, sort by height, teleport, patrol |
| `lambs_wp_ZeusTaskPatrol` | `lambs_wp_fnc_modulePatrol` | group or target, range, waypoints, move waypoints, reinforcement, teleport |
| `lambs_wp_ZeusTaskReset` | `lambs_wp_fnc_moduleReset` | none, unit under cursor |
| `lambs_wp_ZeusTaskCreep` | `lambs_wp_fnc_moduleCreep` | radius, cycle, moving centre, players only |
| `lambs_wp_ZeusTaskHunt` | `lambs_wp_fnc_moduleHunt` | radius, cycle, moving centre, players only, reinforcement, UGL flare |
| `lambs_wp_ZeusTaskRush` | `lambs_wp_fnc_moduleRush` | radius, cycle, moving centre, players only |

The `danger` addon adds six more Zeus modules (`lambs_danger_SetRadio`, `DisableAI`,
`ConfigureGroupAI`, `DirectedMove`, `Diagnose`, `Posture`); see [danger.md](danger.md).

### ZEN context menu (`ZEN_CfgContext.hpp`, shown when groups or objects are selected)

| Menu | Entry | Function |
|---|---|---|
| `lambs_wp` (priority 3) | Create Target | `lambs_wp_fnc_setTarget` |
| | Register Artillery | `lambs_wp_fnc_setArtilleryRegister` |
| | Attack | `lambs_wp_fnc_setAttack` |
| | Assault | `lambs_wp_fnc_setAssault` |
| | Defend | `lambs_wp_fnc_setDefend` |
| | Camp | `lambs_wp_fnc_setCamp` |
| | CQB | `lambs_wp_fnc_setCQB` |
| | Garrison | `lambs_wp_fnc_setGarrison` |
| | Patrol | `lambs_wp_fnc_setPatrol` |
| | Reset | `lambs_wp_fnc_setReset` |
| `lambs_wp_Search` (priority 4) | Creep | `lambs_wp_fnc_setCreep` |
| | Hunt | `lambs_wp_fnc_setHunt` |
| | Rush | `lambs_wp_fnc_setRush` |

### CBA settings

| Setting | Addon | Type, default | Effect |
|---|---|---|---|
| `lambs_wp_autoAddArtillery` | wp | checkbox, false, global | Starts `lambs_wp_fnc_ArtilleryScan` (120 s repeat) on every machine when turned on. |
| `lambs_eventhandlers_ExplosionEventHandlerEnabled` | eventhandlers | checkbox, true, client-configurable | Gates `delayExplosionEH` and `explosionEH`. |
| `lambs_eventhandlers_ExplosionReactionTime` | eventhandlers | slider 0 to 25, default 9, client-configurable | Cooldown after a reaction and the length of the prone dive. |

formations and range add no settings. The `main` and `danger` settings are listed in
[main.md](main.md) and [danger.md](danger.md).

### Public script API (Public: Yes headers)

`lambs_wp_fnc_taskArtillery`, `taskArtilleryRegister`, `sideHasArtillery`, `taskCleanup`,
`taskAssault`, `taskAttack`, `taskCamp`, `taskCQB`, `taskCreep`, `taskDefend`, `taskGarrison`,
`taskHunt`, `taskPatrol`, `taskReset`, `taskRush`, and the CBA events `lambs_wp_taskAssault`,
`taskAttack`, `taskCamp`, `taskCQB`, `taskCreep`, `taskGarrison`, `taskHunt`, `taskPatrol`,
`taskReset`, `taskRush`, `taskDefend` (argument arrays identical to the functions). Outside
callers inside the mod: `lambs_danger_fnc_directedMoveSet` and `directedMoveDeleted`
(taskCleanup), `tacticsReinforce` (soft taskReset), `tacticsAssess` (sideHasArtillery),
`lambs_main_fnc_doCallArtillery` (sideHasArtillery, taskArtillery), `doGroupCommandoDeploy`
and `doGroupStaticDeploy` (taskArtilleryRegister).

## 4. Artillery today

**Registry.** `SideArtilleryHash` is created on the server in `XEH_preInit` and
`publicVariable`d after every change, so every machine can query it. Guns enter it only
through `lambs_wp_fnc_taskArtilleryRegister`: it takes a group (or a unit's group), keeps the
crewed vehicles whose config has `artilleryScanner > 0`, marks each `lambs_main_isArtilleryMRLS`
true when the gunner's turret weapon has `nameSound = "rockets"`, and sends
`lambs_wp_RegisterArtillery` to the server, which `pushBackUnique`s the gun under its side.
Callers: the Zeus and 3DEN register module, the ZEN action, the 3DEN vehicle checkbox, the
deprecated waypoint, `doGroupStaticDeploy` and `doGroupCommandoDeploy` after an AI builds a
mortar, and the optional 120 s `ArtilleryScan`.

**Availability.** `lambs_wp_fnc_sideHasArtillery [side, pos]` filters the side's list to guns
that `canFire`, are `unitReady`, `simulationEnabled`, and whose first `getArtilleryAmmo` is
`inRangeOfArtillery` for the position. A gun that is currently firing has been removed from
the list (see below), so it does not count.

**Request.** `lambs_wp_fnc_taskArtillery [side|gun, pos, caller, rounds, accuracy,
skipCheckRounds]`. With a side it sends `lambs_wp_RequestArtillery` to the server, which
applies the same filter as `sideHasArtillery`, sorts survivors by distance to the target,
takes the nearest, removes it from the hash (re-publishing), and `targetEvent`s
`lambs_wp_FireArtillery` to that gun's owner. With a gun object it skips the server and sends
`FireArtillery` straight to the gun's owner.

**Fire.** `lambs_wp_FireArtillery` spawns `lambs_wp_fnc_doArtillery` on the gun's owner. If no
position is given or the gun cannot fire or the caller is dead, it re-registers the gun and
exits. Otherwise: raises `lambs_danger_OnArtilleryCalled`, `doWatch`es the target, sets
`currentTactic = "taskArtillery"` on the gun's group, shifts the aim centre `accuracy * 0.33`
m from the target along `-direction` (a beaten zone that starts short of the target and walks
over it), doubles rounds and halves spread for anything that is not a `StaticMortar`, and for
MRLS sets salvo from the gunner's magazine (up to 20, spread ×1.5, check rounds skipped). It
sleeps a main delay of 30 to 90 s scaled by gun-to-target distance (0 when skipping check
rounds), then fires 1 to 2 check-round barrages of 1 to 2 rounds each at a randomised point
within a 90 degree cone, waiting `unitReady` after each round and sleeping `getArtilleryETA +
random 35` between barrages, then the main barrage: `_rounds` calls of `commandArtilleryFire
[target, ammo, salvo]` with the impact point stepping outward by `accuracy * 0.33` each
round, `waitUntil {unitReady}` between them. It sleeps one more check-round interval, clears
`currentTactic`, and sends `RegisterArtillery` for the gun so it goes back into the pool.
Debug markers are cleaned after 60 s.

**Who chooses the target.**

- Zeus and 3DEN `moduleArtillery`: the module's own position; a Zeus decision, so layer 4 intent, no AI knowledge involved.
- `lambs_danger_fnc_tacticsAssess` (a group leader's assessment): from the leader's `_enemies` list it picks the first infantry enemy farther than `RANGE_MID` with no friendlies within `RANGE_NEAR` of it, and calls `doCallArtillery` with `_unit getHideFrom enemy`; `getHideFrom` returns the position the unit believes the enemy is at, so this is the AI's own perceived position, not the true one.
- `lambs_wp_fnc_taskDefend`: when contacts exist, `threatPos` is outside the perimeter, the leader is not heavily suppressed and no friendlies are within 200 m of it, calls `doCallArtillery [leader, threatPos]`; `threatPos` is the recency-weighted centre of the picture's contact positions, each stored by `pictureUpdate` as `leader getHideFrom enemy`, so it is also perception-based.
- `lambs_main_fnc_doCallArtillery` itself adds nothing to targeting: it checks `sideHasArtillery [side, pos]`, sets the caller's task text, has the caller (or the group's radio man via `getShareInformationParams`) stop, go low, raise binoculars, gesture and shout `SupportRequestRGArty`, then calls `taskArtillery [side, pos, caller]`.

**Does the AI use knowledge it could not have?** In the artillery chain proper, no: every
AI-originated target is a `getHideFrom` estimate or a weighted average of them, and the Zeus
path is Zeus intent. Two caveats. First, `doArtillery` uses the requested position without
error, so the only miss model is the cone and offset scatter; a stale `getHideFrom` does
carry the AI's error, but there is no additional degradation for range, time since last
sighting, or observer quality (C-52 and C-53 add these). Second, the tasks that use
`findClosestTarget` (hunt, rush, creep) do not call artillery, so the omniscience there does
not leak into fire missions today; it would if a rewrite wired their target into
`doCallArtillery`.

**Resources.** Nothing conjures ammunition: `commandArtilleryFire` spends the gun's real
magazines, `getArtilleryAmmo` returning `""` aborts the loop, and `sideHasArtillery` drops
guns that cannot fire. A gun stays out of the pool for the whole strike, so a side with one
battery fires one mission at a time.

**Locality and cost.** Registry changes are server-only and broadcast; the strike thread
lives on the gun's owner (a headless client if the gun is there) and is one scheduled thread
per strike with long sleeps, so the CPU cost is negligible but the thread can hang on
`waitUntil {unitReady _gun}` if the gun migrates or is deleted mid-strike (a deleted gun
makes `unitReady objNull` false forever, though `canFire` re-checks between barrages stop the
outer loop). `ArtilleryScan` is the only recurring cost and it runs on every machine.

## 5. eventhandlers, formations, range

### eventhandlers

| Item | What it does | Verdict | Why |
|---|---|---|---|
| `Extended_Explosion_Eventhandlers >> CAManBase` | XEH Explosion EH on every man calling `delayExplosionEH`. | keep | The only entry point; XEH means no per-unit registration cost. |
| `lambs_eventhandlers_fnc_delayExplosionEH` (Lambda.Tiger) | Exits unless the setting is on, the unit is local, not a player, alive; delays `explosionEH` by 0.16 s + distance/343 + up to 0.5 s scaled by `(1 - skill "general")`, skipping if a reaction is already pending. | keep | Cheap, local-only, one `CBA_fnc_waitAndExecute` per explosion per nearby man; a layer 1 reflex that gains nothing from Zeus. |
| `lambs_eventhandlers_fnc_explosionEH` (nkenny) | Exits for mounted, prone, cooling-down or dead units; 50% shout; 20% chance to roll prone left or right when the blast is behind (with a timed stand-up), otherwise `setDestination` 3 m away, `doWatch` the blast, dive prone via `lambs_main_doSwitchMove` global event and `setUnitPosWeak` low stance; cooldown `ExplosionReactionTime`. | keep | Correct locality and cheap; note every reaction is a `CBA_fnc_globalEvent`, so a shelling of 200 AI is a burst of network events, which the Director's indirect-fire pacing should bound. |
| `lambs_eventhandlers_ExplosionEventHandlerEnabled` | Checkbox, default on, players may set their own value. | extend | On a dedicated server with AI on the server and HCs, a client's own value never matters, but it should be server-forced so the setting does not read as a per-player option. |
| `lambs_eventhandlers_ExplosionReactionTime` | Slider 0 to 25 s, default 9, players may set their own value. | extend | Same: make it server-authoritative. |
| `XEH_postInit` | Commented out in `CfgEventHandlers.hpp`, no file exists. | delete | Dead config block. |

### formations

| Item | What it does | Verdict | Why |
|---|---|---|---|
| `CfgFSMs >> Formation >> Drop_to_ground`, `Drop_to_ground_1` | Engine formation FSM states set to `function = "nothing"`, so AI in formation never auto-drop prone. | keep | Zero runtime cost and it is exactly what keeps the soldier machine in charge of posture. |
| `CfgFSMs >> Formation >> Search_path__Covering` | `searchPath` with parameters `{28, 2}` instead of the engine defaults. | keep | Config only; affects how followers path to cover. |
| `CfgFSMs >> Formation >> Reload` | Set to `nothing`, so formation movement is not interrupted by the reload state. | keep | Config only. |
| `CfgVehicles >> Static` | `coefInside = 1.5`, `coefSpeedInside = 1.5` (engine default 2). | keep | AI inside buildings and behind statics are slowed less, which matters for garrison and CQB. |
| `CfgVehicles >> Man` | `crouchProbabilityCombat/Engage/Hiding = 0`, `formationTime = 3`, `formationX = 4.2`, `brakeDistance = 1.5`. | keep | Config only; these apply to every man including player-side AI, but in HOSTIS there is no friendly AI, so nothing serves the player. |

### range

| Item | What it does | Verdict | Why |
|---|---|---|---|
| `CfgVehicles >> CAManBase.sensitivity = 6` | Raises the perception multiplier of every man. | keep | Layer 0 knob with no runtime cost; it changes how far the engine's own sensors detect, so it stays inside the fairness contract, but it is the one global number that tunes how good every adversary's eyes are and should become a documented Zeus-level parameter rather than a hidden config. |
