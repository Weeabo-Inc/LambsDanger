# ADR-0009: Explicit selectable tactics instead of a GOAP or HTN planner

Status: Accepted (records a rejected alternative)
Date: 2026-09-12
Brief reference: §3.5 Squad tactics
Research reference: C-08, C-10, C-32

## Context

F.E.A.R. planned per agent with GOAP; Killzone 2 and 3 planned per bot and per squad with
an HTN planner. Both are attractive: behaviours compose and re-plan on failure. The brief
asks for tactics that are "explicit, selectable, cancellable", each with preconditions, a
commitment period and an abort condition, interruptible by the Director and by Zeus without
leaving units broken, and explicable to a player in one sentence.

## Decision

No planner. Squad behaviour is a **prioritised list of explicit tactics** (Halo's
"first one that can run, does"), each a named function with:

- `precondition` (can it start now, given picture, cohesion, intent, posture whitelist),
- `commit` (minimum seconds before another tactic may replace it, unless aborted),
- `abort` (conditions that end it early: base of fire lapsed, leader lost, Zeus pause),
- `reset` (releases every man it ordered).

The per-soldier machine below it is likewise a prioritised list of states, not a planner.
Emergent flanking is obtained the F.E.A.R. way (nearest good position plus obstacles), not
by planning.

## Consequences

- Every tactic is readable in one file and its one-sentence explanation is in its header.
- Adding a tactic is adding a function and a row in the priority table; there is no domain
  to maintain.
- The cost is that composition is by hand: if two tactics should chain, the second is
  started by the first's completion, explicitly.

## Rejected alternative: GOAP or HTN planner

Rejected because plans are hard to explain to a Zeus watching the overlay and to a player
who just died, because a planner's failure modes (no plan found, plan thrash) are exactly
the "units left in a broken state" the brief forbids, and because SQF has no cheap way to
run a search per group per tick under the 200 AI budget. Orkin himself notes the squad layer
in F.E.A.R. was "not anything particularly formal".
