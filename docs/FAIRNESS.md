# The fairness contract

Players forgive being outplayed and never forgive being cheated. This document is the
contract every layer of HOSTIS is held to, the review checklist that enforces it, and the
audit of the current tree against it. It is normative: a pull request that breaks a rule
below is rejected in review regardless of how much better the AI plays.

The difficulty of HOSTIS comes from tactics, coordination, volume of fire and positioning.
Every time a change is tempted to cheat, it must build a behaviour instead.

## 1. Rules

### R1. Targets come only from the engine's sensors

An Agent may fire at, aim at, or move against a unit only if that unit is in the Agent's
group's engine knowledge at the moment of the decision: `_unit targets [...]`,
`_unit nearTargets`, `_group knowsAbout _target > 0`, or the `_dangerCausedBy` of a
danger event the unit itself received. Script may never *create* engine knowledge of a
player with `reveal` above accuracy 1, `doTarget`, `doFire`, `commandTarget` or
`commandFire` on a unit the group has not detected.

Allowed: `reveal` at accuracy 1 or below to model a *report* ("something is over there"),
because that is what the engine offers for "suspected, not seen".

### R2. No firing through what cannot be seen through

Suppressive fire is aimed at *positions* (C-22) with the engine's own ballistics. Script
does not raise `aimingAccuracy`, does not use `doWatch` on a player behind smoke, foliage or
in darkness the unit could not see through, and does not fire scripted projectiles at a
player. Blind fire from cover is fire at a last-known area with a deliberate error.

### R3. Skill is never raised to compensate

`setSkill` and `setUnitTrait` are not called by HOSTIS for tactical reasons. Skill is the
mission maker's and the difficulty setting's business. A behaviour that only works because
the soldier shoots better is not finished.

### R4. Reports give areas, not positions

A contact report received by a group (from another group, from the Director, from Zeus)
carries a position with an error radius proportional to source quality and range. A group
that has not itself detected the player receives an *area of interest*, never a target. The
Director may know exact player positions for pacing and pressure decisions only; it may
not pass them down.

### R5. No teleporting, no adjacent spawning, no free ammunition

Units are never moved by `setPos` while within a player's potential view, never spawned
inside a player's potentially visible set, and never given magazines except through a
resupply action that took time and could have been interrupted. Reinforcements enter from
outside the players' area and travel.

Allowed: `setPos` inside a task's own setup when the Zeus explicitly asked for a teleport
(the upstream `taskGarrison`/`taskCamp` teleport flag), and building-position placement of a
unit that is already indoors and out of view, which upstream uses for garrisons.

### R6. The Director does not steer Agents

Information flows up by report and down by order. An Agent or Squad function may not read a
Director or side-level structure to find an enemy. The only Director-to-Squad data are:
objective area, posture, corridor, resource grants, and the pacing throttle.

### R7. Nothing runs on the player's side

HOSTIS never controls a player's group, a group of the players' side, or a civilian group.
The exclusion is by side, faction, group variable and unit variable; the default excludes
every side with a player in it. Behaviours that only make sense if a player might be
commanding the group are deleted, not kept behind a setting.

## 2. Review checklist

Every pull request that touches `addons/` answers these in its description:

1. Does any new call to `reveal`, `doTarget`, `doFire`, `commandTarget`, `commandFire`,
   `doWatch`, `doSuppressiveFire`, `commandSuppressiveFire` take an object the group has
   not detected? Cite the guard.
2. Does any new call to `setSkill`, `setUnitTrait`, `setPos*`, `addMagazine*`,
   `setVehicleAmmo`, `createUnit`, `createVehicle` exist? Cite the rule (R3, R5) and the
   justification.
3. Does any new read of `allPlayers`, `allUnits`, `playableUnits`, `switchableUnits` or
   `nearestObjects` with a side filter happen below the Director layer? It must not.
4. Does any Squad or Agent function read a variable written by `hostis_director_*`? It must
   not.
5. Is the behaviour explicable in one sentence to a player after it killed them? Write the
   sentence in the PR.

CI enforces the mechanical part: `tools/fairness_check.py` scans every `.sqf` and `.fsm`
under `addons/` (the debug folders excepted) for the commands in items 1 to 3 and fails on
any occurrence not listed in `tools/fairness_allow.txt`. The allow list is the ledger: one
line per file and command with the guard that makes it honest, or a `TODO milestone n`
reason for a known breach. Adding a line is a review decision, not a formality.

## 3. Audit of the current tree

Findings from reading every function in `addons/main`, `addons/danger` and `addons/wp` at
commit `b1885db` (the per-function detail with line numbers is in `docs/map/*.md`). Status:
**ok** means compliant, **fix** means it must change in the milestone named. The verdict on
the whole tree: the artillery chain, the picture, the soldier machine and every tactic the
fork wrote are honest; the breaches are upstream's player-hunting tasks and a handful of
exact-state reads that are easy to route through the picture.

### Breaches

| Where | What it does | Rule | Fix |
|---|---|---|---|
| `main/fnc_findClosestTarget.sqf:24,33-40` | Scanned `allUnits` or `switchableUnits + playableUnits` (default players only) by side and distance, no knowledge check, returned the nearest by exact position | R1, R4 | **done, milestone 2**: deleted; `taskHunt`, `taskRush`, `taskCreep` take the best contact from the group's own picture (`hostis_core_fnc_contactNearest`) |
| `wp/fnc_taskCreep.sqf` | `reveal`ed the target found above | R1 | **done, milestone 2** |
| `wp/fnc_taskHunt.sqf` | `createVehicle`s an `F_20mm_Red` flare 200 m up when nobody has a UGL | R5 | milestone 2: flare only from a real UGL round |
| `wp/fnc_taskCQB.sqf` | Teleports a stuck man 3.5 m when no player is within 50 m | R5 | milestone 4: on `unitOrder`, no teleport |
| `main/UnitAction/fnc_doUGL.sqf:92` | `addMagazine (currentMagazine _unit)` nets one free magazine | R5 | milestone 3: load the flare on the muzzle directly |
| `danger/scripts/lambs_danger.fsm:475` | Re-queues `getPosASL _dangerCausedBy` as an enemy-detected cause under 35 m | R1 | milestone 3: `getHideFrom` |
| `danger/fnc_brainEngage.sqf:55,62,79,85` | Reads `speed`, `distance2D`, `vehicle`, `isIndoor` of the real target object | R1 | milestone 3: read the picture record |
| `danger/fnc_tacticsAssess.sqf:91-224` | Exact `distance2D`, `getPos`, `eyePos`, `nearestObjects` around real enemies drive plan branches | R1 | milestone 4: folded into the commander, which reads the picture only |
| `danger/fnc_brainVehicle.sqf:76,208,225,289,302` | Exact distance and `eyePos` of `_dangerCausedBy` in crew decisions | R1 | milestone 3 (LOS booleans may stay; distances go through the picture) |
| `danger/fnc_contact.sqf:50` | `setFormDir (_unit getDir _enemy)`, an exact bearing | R1 | milestone 3: bearing to `getHideFrom` |
| `danger/fnc_pictureUpdate.sqf:59`, `fnc_pictureContacts.sqf:26` | `alive` filter on contacts, instant death knowledge | R1 | **done, milestone 2**: deaths enter through `hostis_core_fnc_contactDeath` from the DeadBody causes |
| `danger/fnc_tacticsReinforce.sqf:83-91` | Claims nearby empty vehicles into the group (`addVehicle`) | R5 | milestone 5: vehicle release is a Director grant |
| `wp/fnc_moduleTarget.sqf`, `ZEN/fnc_setTarget.sqf` | A Dynamic Target `attachTo` a unit feeds that unit's exact position to assault, CQB and camp | R4 | milestone 6: static targets only |
| `danger/XEH_preInit.sqf:47` | Shared the reporter's own `targetKnowledge` estimate verbatim to other groups | R4 | **done, milestone 2**: the reinforce position is jittered by the reporter's error plus 2% of the distance |
| `main/fnc_doShareInformation.sqf` | Engine `reveal` to nearby friendly leaders | R4 | **done, milestone 2**: files the sighting and calls `hostis_core_fnc_netSend`; `reveal` only at accuracy 1 behind `hostis_core_engineReveal` (off) |

### Compliant today

| Where | What it does | Rule |
|---|---|---|
| `danger/fnc_pictureUpdate.sqf:37-39` | Every sighting passes through the leader's `getHideFrom`; an unknown enemy yields `[0,0,0]` and is skipped | R1, R4 |
| `danger/fnc_contact.sqf:25`, `fnc_brainForced.sqf:35`, `fnc_tacticsManeuver.sqf:281`, `main/GroupAction/fnc_doGroupBound.sqf:88`, `main/fnc_getThreat.sqf:59`, `main/UnitAction/fnc_doSurvive.sqf` | `targets` and `nearTargets` of the unit itself | R1 |
| Every `findNearestEnemy` and `getHideFrom` read in `main` (doAssault, doFleeing, doGroupStaticDeploy, doVehicleAssault, doVehicleRotate, doVehicleJink) | Engine knowledge, error-adjusted | R1 |
| `wp/fnc_taskArtillery`, `doArtillery`, `sideHasArtillery`, `main/fnc_doCallArtillery`, `taskDefend` artillery call, `tacticsAssess` artillery call | Targets are `getHideFrom` or the picture's threat centre; ammunition is real; a gun is out of the pool while firing | R1, R5 (budget comes in milestone 5) |
| `main/fnc_applyStress.sqf:34-37` | `setSkill "aimingAccuracy"` only ever lowers below the recorded base | R3 (removed anyway in milestone 3 because the brief wants behavioural consequences) |
| `danger/fnc_brainVehicle.sqf`, `commanderContingency` | `setSuppression 0.94` on dismount, a handicap | R3 |
| `main/UnitAction/fnc_doCheckBody.sqf` | Resupply from a real corpse through engine `rearm` and weapon holder actions | R5 |
| `wp/fnc_taskGarrison`, `taskCamp`, `taskDefend`, `taskPatrol` teleport flags | `setPos` at task start when the Zeus asked for it | R5 by exception |
| `danger/fnc_commanderSide.sqf` | Clusters the groups' own threat centres; never reads `allPlayers` | R6 |
| `main/UnitAction/fnc_doAssaultMemory.sqf` | Assault on a remembered position | R1 |
| All of `wp` and `danger` | Every task filters `!isPlayer`; nothing commands a player's group | R7 (the dead guards are deleted in milestone 2) |

## 4. The one-sentence rule

For every behaviour that can kill a player, the system note carries the sentence a player
would be told afterwards. Examples of acceptable sentences:

- "They put a machine gun on you and sent a team round your left while you were pinned."
- "You fired the mortar twice from the same spot, so their guns hit that spot."
- "You went through the same gap twice, so they were waiting at it the third time."

An unacceptable sentence is any that contains "somehow", "always knew" or "through the wall".
