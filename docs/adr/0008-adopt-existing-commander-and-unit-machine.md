# ADR-0008: The existing commander, picture and soldier machine are the seed of layers 0 to 3

Status: Accepted
Date: 2026-09-12
Brief reference: §7 Milestones
Research reference: ADR-0001 mapping

## Context

Before this brief was written, this repository already received about forty commits of
behaviour on top of upstream: a per-group combat picture, a group commander with intent
and escalation, a side board, a per-soldier state machine with one movement issuer, a
tactical position system, deliberate and mechanised attack, air assault, contingencies
(succession, crew replacement, shelling, strays, near ambush), casualty drill, fire
discipline and a diagnose report. None of it has a design note and all of it lives inside
`lambs_danger` and `lambs_main`.

The brief's milestone 1 says "no behaviour changes". The choice is to throw that work away
and start the layers clean, or to adopt it as the seed and migrate it into the layers.

## Decision

Adopt it. The mapping:

| Existing | Becomes | Layer |
|---|---|---|
| `fnc_pictureGet` / `pictureUpdate` / `pictureContacts` | `hostis_core` contact store (ADR-0003), rewritten to the record format | 0 |
| `fnc_unitOrder` / `unitCycle` / `unitThink` / `unitEvent` / `unitState` / `unitRegister` / `unitRelease` | `hostis_agent` soldier machine, moved as is | 1 |
| `main/fnc_findPositions` / `findPositionsBuilding` / `findApproach` / `positionReserve` / `positionRelease` | `hostis_agent` position query (ADR-0010), extended to the query-object form | 1 |
| `fnc_tactics*` (assault, bound, flank, suppress, withdraw, hold, hide, garrison, CQB, maneuver, reinforce) | `hostis_squad` tactics with the lifecycle of ADR-0011 | 2 |
| `fnc_commanderGroup` / `commanderContingency` / `commanderEscalation` / `intentGet` / `intentSet` | `hostis_squad` group planner; intent API becomes the layer 3 to 2 interface | 2 |
| `fnc_commanderSide` | `hostis_director` side board, extended with menace, pacing, reserves, fire support, influence map | 3 |
| `ZeusModules/*`, `ZEN/*`, `directedMove*`, `modulePosture` | `hostis_zeus` | 4 |
| `wp/taskAttack`, `taskAttackAir`, `taskDefend` (rewritten) | stay in `lambs_wp` as the compatibility surface, forwarding to intents | 4 |

Migration is one function group per PR, each a move plus the minimum change to fit the
layer's interface, each with before and after profiler numbers, so that history stays
readable.

## Consequences

- Milestone 1 stays behaviour-free: this ADR and the map are the deliverable; moves start
  in milestone 2.
- Each moved function gets its missing design note in `docs/systems/` at the time of the
  move.
- Author lines keep `nkenny` where the code descends from upstream and `bluefield-creator`
  for fork work.

## What this overrides in upstream, and why

Nothing further; it records that the fork's pre-brief work is kept.
