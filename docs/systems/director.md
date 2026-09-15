# The Director (layer 3)

Addon: `hostis_director`. Brief §3.7, §3.8, §1 (two brains). Research: C-12, C-13, C-14,
C-16, C-17, C-18, C-29, C-31, C-36, C-50, C-52 to C-55. ADR-0004, ADR-0007.

## Purpose

One brain per side, on the server, that knows a lot and moves nobody: it spends reserves
and fire missions against a budget, paces the pressure, and hands squads areas and intents.

## One-sentence explanation

"The enemy commander saw his squad break, held his reserve until you thought it was over,
then sent it in from the side you had not covered."

## What it knows and what it may do with it (ADR-0004)

- **From its groups' reports only**: the board (clusters of reported contacts with strength,
  confidence, age, error), the influence map (friendly presence, reported enemy presence,
  deaths, per 100 m cell), which defended positions fell.
- **From the players, for pacing only**: each player element's damage, deaths, position and
  whether the side's groups are engaged near it (the menace gauge); the cells the players
  move through (routes); the firing position of a gun a player fires (counter-battery).
- **What it hands down**: an area (position plus error, filed as a `suspected` contact in the
  reserve's own picture), an intent, a task. Never a unit, never a target.

## Tick

Every `thinkInterval` (10 s) per side with HOSTIS groups: board, influence, pacing, routes,
counter-battery, fallen positions, reinforcement, counterattack, fire missions.

## Pacing (C-16, C-17)

Per player element an intensity: +2 per point of damage taken, +0.5 per death, +0.15 per
think while a HOSTIS group has a fresh contact within 200 m, decaying 0.01 per second
otherwise and not at all while engaged. States: **build up** until intensity reaches 1,
**sustain** 5 s, **fade** until intensity falls under 0.5 with nobody engaged, **relax** for
`relaxTime` divided by the `throttle`, then build up again. The Director spends on an
element (reinforcement, counterattack, fire mission, route seed) only while it is building
up. Throttle 0 stops all spending; the squad-layer pause stops everything else.

## Reserves and reinforcement (C-29, C-36)

The pool: groups with a `reserve` intent, plus (setting) idle free-intent groups not in
contact, not on a task, not directed, not released in the last 5 minutes. A group that
breaks contact leaves a request; the Director answers the oldest one per think, one
release per 45 s per side, from a reserve within `reserveRange` whose bearing to the
threat differs by more than 90 degrees from the requester's when one exists. The reserve
gets the area as a suspected contact, an attack intent, and the Attack Position task.
Each release spends one reinforcement. With none left, nobody comes, and the log says so.

## Counterattack (C-50)

A hold or defend objective counts as fallen when no defender is inside its radius and the
board reports the enemy on it (or the defenders are all dead). After `counterattackDelay`
(90 s), a reserve is released onto it from the bearing opposite the influence map's enemy
presence around it. Once per objective; forgotten after 15 minutes.

## Fire missions (C-52, C-53)

`fireRequest` is the call for fire: budget, a gun in range, an observer error under
`observerError` (80 m), no more than four active, no active mission within 150 m, pacing,
and nobody of ours within `dangerClose` (200 m). A leader's `doCallArtillery` goes through
it with the error of the contact it holds. The sequence: one adjusting round at the
reported position jittered by its error; after 35 s, the observer must be alive and still
hold a contact within 200 m of the target with error under the limit; the corrected
position gets four rounds for effect and the observer calls it; otherwise the mission is
cancelled and the log says whether the observer died or lost the target. A mission with no
observer (counter-battery, a Zeus, a script) fires for effect on the given area after its
delay.

## Counter-battery (C-54)

Every mortar or artillery vehicle fired by a player reports its position to the server. Two
firings within 60 m inside `counterBatteryWindow` (600 s) make that position a fire mission
without an observer, `counterBatteryDelay` (180 s) later, once per position per 15 minutes.

## Adaptation (C-14)

Three locked rules, each unlocked by what the players did and never by what killed them.
All three read the board and the side's own state, never a player position, and the
`adaptation` setting turns them off together.

- **Route seeding** (`routes`): a route cell the players have entered on two separate
  visits gets a reserve with a defend intent and radius 100 on it, holding fire until the
  players are close. One seed per 5 minutes, spending a reinforcement.
- **Favourite positions** (`favourites`): the board's clusters are counted per 100 m cell,
  once per visit (a gap of 2 minutes between reports on the cell is a new visit). The third
  visit, while the cell is still reported fresh, gets a fire request on its centre with a
  60 m error and no observer. One per side per 10 minutes, and each cell at most once per
  10 minutes. Sentence: "You used that spot three times, so they had the mortars ready for
  it."
- **Collapsing flank** (`flank`): two defended positions lost within 400 m of each other
  inside 10 minutes mean one side of the line is being rolled up. Instead of retaking
  either, a reserve is released to a blocking position 150 m from the nearest position
  still held, toward the breach, and gets a hold intent there once it arrives (a Zeus-style
  forced release, ignoring budget and pacing but not the area of operations). One block
  per breach per 20 minutes. Sentence: "They lost two posts on that side, so the next squad
  dug in across your path."

## Hugging (C-55)

The side hugs for 10 minutes after any of its groups hear an enemy aircraft fire (the
scripted ear raises `hostis_director_enemyAir` for a gun on an `Air` platform, once per
aircraft per 30 s) or after the enemy's artillery is logged. The flag is published as
`hostis_director_hug_<side>`; the squad planner reads it into its context as `hug` and
raises the priority of `bound`, `assault` and `suppressAndFlank` by 30, so a group in
contact closes to inside danger-close range rather than holding at distance where the guns
can be brought in. The `hugging` setting turns it off. Sentence: "Your helicopter was
overhead, so they ran straight at you instead of holding the treeline."

## API

| Function or event | Does |
|---|---|
| `hostis_director_fnc_budget [side, key, value]` / event `hostis_director_setBudget` | read or set `reinforcements`, `fireMissions` |
| `hostis_director_fnc_release [side, pos, error, reason, avoidBearing, force]` / event `hostis_director_release [side, pos, radius]` | send a reserve at an area |
| `hostis_director_fnc_counterattack [side, pos, radius, force]` / event `hostis_director_counterattack` | counterattack a position |
| `hostis_director_fnc_fireRequest [side, pos, error, reason, observer, notBefore]` / event `hostis_director_fireMission` | call for fire |
| `hostis_director_fnc_report [side]` | the reasoning as text (in the Diagnose module on the server) |
| `hostis_director_fnc_reserves [side, pos]` | the pool |

## Settings (`hostis_director_*`)

`enabled`, `thinkInterval`, `throttle`, `relaxTime`, `reinforcements`, `fireMissions`,
`reservePoolAuto`, `reserveRange`, `counterattackDelay`, `dangerClose`, `observerError`,
`counterBatteryWindow`, `counterBatteryDelay`, `hugging`, `adaptation`, `debug`.

## Acceptance test (`tests/director.Stratis`)

Brief tests 2 and 4.

1. A squad with a defend intent holds a compound; two reserve squads wait 800 m away; a
   mortar team is registered. Take the compound. Within 3 minutes of the last defender
   leaving it, the RPT shows `DIRECTOR: ... lost` then `released ... counterattack`, and the
   reserve arrives from a bearing not within 90 degrees of the one you came from.
2. While the defenders still see you, `fire mission ... adjusting round` then `correction
   ... fire for effect` with the rounds landing near your true position. Kill the observing
   squad's leader between the two: `cancelled: observer lost`.
3. Fire the player mortar twice from the same spot: `counter-battery on ... in 180 s`, then
   rounds on that spot.
4. After a heavy exchange, `pacing ... -> relax` and no release during it.

## Performance budget

One think per side per 10 s: an `allGroups` filter, one contact query per group, a small
hashmap sweep, one `allPlayers` pass. No world queries.
