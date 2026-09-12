# ADR-0011: Every tactic declares preconditions, commitment, abort, and a reset path

Status: Accepted
Date: 2026-09-12
Brief reference: §3.5 last paragraph, §4 Throttle (hard pause), §5 test 9
Research reference: C-08, C-15, C-19

## Context

Upstream learned the hard way that tasks need `taskReset`. This fork already has every
tactic reset release the soldier machine's men, one planner at a time per group, and a
tactic cooldown. Zeus needs a brake "that works within a second" and the Director needs to
interrupt without leaving units broken.

## Decision

A tactic is a hashmap-described object registered in `hostis_squad`:

```
name, layer, priority,
precondition: code -> bool,
start:        code -> plan (orders issued, slots filled)
monitor:      code (each squad tick) -> "running" | "done" | "failed"
abort:        code -> bool (checked each tick before monitor)
commit:       seconds
reset:        code (release every ordered man, clear group state)
explain:      the one-sentence player explanation
```

- Exactly one tactic runs per group. Starting a new one always calls the old one's `reset`.
- `reset` is idempotent and safe to call on a dead or foreign group.
- Interrupt classes (C-15): `finish` (let the tactic reach `done`), `blend` (abort at the
  next safe point, meaning after the current bound), `now` (reset within one tick). Zeus
  pause and Zeus intent change are `now`; Director re-tasking is `blend` by default.
- Every transition writes a reason string to the group's tactic log (bounded ring) shown in
  the overlay and the diagnose report.
- The group-wide `hostis_squad_fnc_reset` is the public equivalent of upstream `taskReset`
  and calls the running tactic's `reset`, releases the men, clears the picture's derived
  values, and leaves the contact store intact (knowledge survives an order change).

## Consequences

- Test 9 (Zeus touches nothing for 15 minutes) and the hard pause are testable as
  "no unit remains in a non-idle machine state one tick after reset".
- Tactics that cannot describe their abort condition are not merged.

## What this overrides in upstream, and why

The implicit lifecycle of `fnc_tactics*` (a group variable flag and a timer). The flag
stays for compatibility; the object carries the truth.
