# Performance (brief §3.10, ADR-0005, ADR-0014)

## Purpose

Two hundred AI on a dedicated server with headless clients, forty players, and the server
frame rate where the mission maker left it. Every layer is one per-frame handler that
visits a bounded number of members per tick; what each costs is measured on every run.

## One-sentence explanation

"The AI thinks in slices, a few squads a second, so a big fight slows every squad a little
instead of freezing the server."

## Handlers and their constants

| Layer | Handler | Tick | Per tick | Constant lives in |
|---|---|---|---|---|
| 0 knowledge | scripted ear (`hostis_core_fnc_hearing`) | per shot, 1 report per shooter per second, 2 per group per second | one `allGroups` distance pass | `fnc_hearing.sqf` |
| 0 knowledge | picture debug draw | 5 s, only with `debugPicture` | every local picture | `XEH_postInit.sqf` |
| 1 agent | soldier machine (`lambs_danger_fnc_unitCycle`) | 0.5 s | cheap pass over all, 12 expensive thinks | `fnc_unitCycle.sqf` |
| 1 agent | morale (`hostis_agent_fnc_moraleCycle`) | 2 s | 10 groups | `fnc_moraleCycle.sqf` |
| 2 squad | commander (`lambs_danger_fnc_commanderCycle`) | 1 s | 8 groups, each every 5 s; side board every 10 s | `fnc_commanderCycle.sqf` |
| 2 squad | tactic monitors | 2 s per running tactic | one tactic | `fnc_tacticStart.sqf` |
| 3 director | `hostis_director_fnc_think` | `thinkInterval` (10 s) per side, server only | one side | setting |
| 4 zeus | overlay | `overlayInterval` (3 s), curator's machine | one snapshot request, 40 rows | setting |

Everything else is an event: danger causes, FiredMan, Hit, Killed, intents, Zeus modules.
No `spawn`/`sleep` loop exists in `hostis_*`; the upstream `taskX` loops in `lambs_wp`
remain and are listed in `docs/UPSTREAM-MAP.md`.

## Measurement (ADR-0014)

`hostis_core_fnc_profile [name, code, args]` wraps each handler body and books, per
name: calls, total ms, worst ms, and calls and ms in the current window.
`hostis_core_fnc_profileReport [restart]` renders it with `diag_fps`, the engine's script
counts and the registered counts (commander groups, soldiers, pictures, HOSTIS groups on
the machine).

- Diagnose module, section **Performance**: the report for the machine owning the group.
- Setting `hostis_core_debugPerformance`: every machine logs `HOSTIS PERF <machine> ...`
  every 30 s and restarts its window, so the RPT is a series of 30 s slices.

## Targets for the load rig (`tests/load.Stratis`)

Judged on the server's `HOSTIS PERF server` lines with 200 AI, all in contact at the peak:

| Name | Target (ms/s over a slice) | Worst call |
|---|---|---|
| soldier | under 6 | under 8 ms |
| commander | under 4 | under 10 ms |
| morale | under 1 | under 3 ms |
| tactics | under 2 | under 5 ms |
| director | under 1 | under 15 ms |
| hearing | under 1 with 40 guns firing | under 1 ms |
| all HOSTIS together | under 15 ms/s, so under a quarter of the scheduler's share at 50 fps | |

Server fps should stay within 5 of the same mission with `hostis_core_hearingRange 0`,
`hostis_agent_morale` off and `lambs_danger_commander` off. A layer over target gets its
constant turned into a setting, tuned, and the before and after slices go in the commit.

## Headless clients (ADR-0007)

Layers 0 to 2 run where the group is local. A group is pinned while registered with the
commander: `hostis_pinned` (group variable, broadcast) and `ace_headless_blacklist` on its
men, cleared when the commander drops the group. ACE's headless module reads the unit
blacklist; other balancers should skip groups with `hostis_pinned`. A group moved anyway
is dropped by the old owner on its next commander tick (`!local`) and re-registered by the
new one on its next contact; the picture and the running tactic are lost, and the
performance log's registered counts show the move.

## Acceptance test (`tests/load.Stratis`)

1. Thirty squads of six, four APCs, a mortar team, on Stratis around the player, half with
   defend intents, half free (the reserve pool). `hostis_core_debugPerformance` is forced
   on. Idle for 2 minutes: `HOSTIS PERF server` shows the registered counts and every
   layer under a tenth of its target.
2. Fire on the nearest squads from 250 m and keep firing for 3 minutes: registered counts
   climb as hearing registers groups; every layer stays under target; `fps` within 5 of
   the idle value.
3. Bring a headless client: the `HOSTIS PERF headless` lines carry the groups it owns and
   the server's `commander groups` count drops accordingly; no `not local` lines from the
   Director's intents.
4. Diagnose a squad: the Performance section matches the last RPT slice.

## Fairness review

Profiling reads time and counts only. The pin variables carry no information about the
enemy.
