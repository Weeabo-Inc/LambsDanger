# Morale, suppression and cohesion (layer 1)

Addon: `hostis_agent`. Brief §3.3. Research: C-35, C-37, C-58, C-62. Confirmed decisions:
consequences are behavioural, never numeric.

## Purpose

Give every man a readable state that governs what he may do under fire, and every group a
cohesion state the squad and the Director act on, so that a player 200 m away can tell a
squad that is holding from one about to break.

## One-sentence explanation

"You put enough fire on them that they stopped moving, then their leader went down and
the rest broke; if you had let up, the leader would have rallied them."

## Per-man states (`hostis_agent_fnc_moraleState`)

| State | Enters when | What he does | Tell |
|---|---|---|---|
| steady | nothing below applies | everything | normal stance |
| suppressed | engine suppression above `suppressedLevel` (0.4), or hit in the last 5 s | head down, blind fire from cover through the soldier machine's peek and duck | crouches or goes prone, "Under fire!" |
| pinned | suppression above `pinnedSuppression` (0.8), or above 60% of it for 6 s | refuses `move`, `rush` and `assault` orders unless the order says he is covered | prone, does not shift, "Take cover!" |
| shaken | stress above `shakenStress` (0.6), or hit in the last 20 s while suppressed | refuses `assault`; recovers only with a living leader within `rallyRange` (25 m) | prone, panic line |
| broken | group cohesion broken, or stress above `brokenStress` (0.8) under fire while cut off or leaderless | breaks away from the fire through the `survive` order | runs to cover away from the threat, panic line |
| rallying | leaving shaken or broken with the leader near, for `rallyTime` (10 s) | as suppressed | leader calls "Rally up" |

Worse states arrive at once. A better state waits `stateMinTime` (3 s) so the read-out does
not flicker. Stress is the upstream per-man value (`lambs_main_fnc_getStress`), fed by fire,
hits and losses; the old `applyStress` skill write is gone.

Isolation: a man more than `isolationRange` (40 m) from his leader with nobody within 15 m.

## Group cohesion (`hostis_agent_fnc_cohesion`)

Written into the group picture as `cohesion`:

| State | When | Consequence |
|---|---|---|
| steady | | |
| strained | 40% of men pinned, shaken or broken; or group morale under 0.6; or no leader | the squad layer prefers suppress and hold over closing (milestone 4) |
| broken | half the men broken; or group morale under 0.35; or 70% bad with losses | the commander runs break contact and asks for help |
| rallying | leaving broken, for 20 s | leader calls "Rally up" |

Group morale is the upstream `getMorale` (losses, stress, leader down, courage).

## Volume of fire

- Incoming: every Fire, BulletClose and Hit danger cause logs one event with its bearing
  (`hostis_core_fnc_fireLog`); `hostis_core_fnc_fireIncoming` gives events per second, all
  round or per sector. One Fire cause per bullet seen (Suma), so this is a rounds counter.
- Outgoing: a FiredMan handler stamps every shooter; `hostis_agent_fnc_fireVolume` counts how
  many men of an element fired inside a window and their rounds per second.
- The gate: in `doGroupBound`, when fire is coming in, the moving team only goes if at least
  two men (or all of a smaller team) of the stationary team fired in the last 4 s. Otherwise
  the runners wait, a man calls for covering fire, and the log says why. Orders issued by the
  bound carry `covered = true`, which is what lets a pinned man move.

## Evidence

The danger causes now feed the picture directly: a known shooter is filed as `shotAt`, an
unknown shooter as `heard` at the fire position, a scream as `heard` infantry.

## Settings (`hostis_agent_*`)

`morale`, `suppressedLevel`, `pinnedSuppression`, `shakenStress`, `brokenStress`,
`isolationRange`, `rallyRange`, `rallyTime`, `stateMinTime`, `debugMorale`.

## Debug

`debugMorale` (or LAMBS debug functions) logs every state change with the numbers behind
it: `MORALE <name>: pinned -> shaken (suppression 0.71, stress 0.62, hit 4 s ago)`. The
morale handler runs every 2 s over the commander's groups, ten per tick.

## Acceptance test (`tests/morale.Stratis`)

Player with a machine gun at 200 m from an OPFOR squad in the open, a second squad 400 m
behind it. Every 5 s the RPT prints each man's state.

1. Fire long bursts at the near squad for 20 s: within 10 s every man in the beaten zone is
   `suppressed` or `pinned`; nobody moves laterally; the commander's bound (if any) logs
   `BOUND ... waits` while nobody covers.
2. Stop firing for 30 s: states ease to steady no faster than `stateMinTime`, and the log
   shows the order.
3. Kill the leader, keep firing: at least one man goes `shaken`; nobody rallies until the new
   leader is within 25 m of him.
4. Keep the fire on until two men are down: cohesion reaches `broken`, the commander logs
   `withdraw`, the men run away from you into cover under smoke.
5. At no point does any man's `skill "aimingAccuracy"` change (printed every 5 s).

## Performance budget

Per group per 2 s: a few variable reads per man, no world queries. The FiredMan handler is
two variable writes per shot on the shooter's machine.
