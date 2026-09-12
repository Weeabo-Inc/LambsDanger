# ADR-0005: Every layer is a budgeted, time-sliced CBA per-frame handler

Status: Accepted
Date: 2026-09-12
Brief reference: §3.10 Performance
Research reference: C-05, C-06, C-23, C-38

## Context

Scheduled scripts share 3 ms per frame; under load a `sleep` loop is suspended mid-line and
resumes whenever the scheduler gets back to it, so sleep-driven decision loops are exactly
what falls apart at 200 AI. Upstream `taskX` functions are `spawn`ed loops with `sleep`.
This fork already replaced the unit-level loops with one PFH (`unitCycle`, twice a second,
budgeted expensive pass) and the commander with one PFH time-sliced over groups (8 groups per
second, each every 5 s).

## Decision

- One CBA per-frame handler per layer per machine. No `spawn`/`sleep` decision loops
  anywhere in `hostis_*`. Remaining upstream `taskX` loops are migrated in milestone 6.
- Each handler is **time-sliced**: it holds a ring of registered groups (or units) and
  advances a bounded number per tick so that every member is visited at the layer's cadence.
- Each handler has an **explicit per-tick budget** in two currencies: number of members
  visited and number of expensive queries issued (position queries, `lineIntersectsSurfaces`
  batches, `nearestObjects`). Budgets are CBA settings with defaults chosen against the 200
  AI target.
- **Level of detail** by distance: a group with no player element inside its engagement
  horizon (setting, default 1200 m) runs the abstract behaviour only (hold, move along
  corridor, timers) and issues no queries and no per-soldier machine.
- Anything that can be an event is an event: danger FSM causes, `FiredNear`, `Hit`,
  `Killed`, `Suppressed`, Zeus module placement, intent change. Polling is for the cheap
  pass only.
- Every performance-affecting PR reports `diag_` numbers before and after on the milestone
  10 test mission.

## Consequences

- Cadences in the layer table are *targets*, and under load they stretch uniformly instead
  of one group starving. That is the desired failure mode.
- A `hostis_core_fnc_budget` helper exposes remaining budget so an expensive call can decline
  and retry next tick rather than blow the frame.
- The overlay shows per-layer tick cost and backlog.

## What this overrides in upstream, and why

The `spawn`/`sleep` structure of `fnc_taskAssault`, `taskCQB`, `taskCamp`, `taskGarrison`,
`taskPatrol`, `taskRush`, `taskHunt`, `taskCreep` and `doArtillery`. They keep their public
signatures and are re-implemented on the handlers.
