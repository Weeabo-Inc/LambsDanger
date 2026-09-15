# ADR-0014: Profiling is built in; per-tick budgets stay constants until the load rig says otherwise

Status: Accepted
Date: 2026-09-15
Brief reference: §3.10 Performance, §6 (test in MP early)
Research reference: C-05, C-06, C-38

## Context

ADR-0005 made every layer a time-sliced per-frame handler and said its budgets would be
CBA settings chosen against a 200 AI target, that a `hostis_core_fnc_budget` helper would
let expensive calls decline, and that every performance change would report `diag_`
numbers before and after. Milestones 2 to 7 shipped the handlers with their budgets as
constants (8 commander groups a second, 12 soldier thinks a tick, 10 morale groups a tick,
one Director think per side per 10 s) and no measurement of what any of them costs. The
user runs the in-game loop and could not run it during milestones 6 to 8, so no number
exists yet to tune against.

## Decision

- **Every handler is measured, always.** `hostis_core_fnc_profile [name, code, args]`
  wraps the body of each layer's handler (commander, soldier, morale, director, tactics,
  the scripted ear, the picture debug draw) and books calls, total, worst and a sliding
  window per name. The cost is two `diag_tickTime` reads per call, so it stays on in
  production.
- **The numbers are readable in two places:** the Diagnose module's new Performance
  section on the group's owner, and `HOSTIS PERF` lines in every machine's RPT every 30 s
  while `hostis_core_debugPerformance` is on.
- **`tests/load.Stratis` is the standing rig** ADR-0005 and ADR-0007 referred to: two
  hundred AI in thirty groups with vehicles and a mortar, against one player, logging the
  performance slices. Its README states the targets a run is judged against.
- **Budgets remain constants** in the handler files until a load run shows a layer over
  its target; a setting for a number nobody has measured is a knob with no scale. The
  first run that shows a layer over target turns that layer's constant into a setting, and
  the change reports the before and after slices in its commit message per ADR-0005.
- **No `hostis_core_fnc_budget` helper.** The expensive calls (`findPositions`, the sweep,
  `nearestObjects` in the tasks) are already bounded per tick by their callers' constants;
  a cross-layer budget would add bookkeeping to every call for a saving nobody has
  measured. Rejected for now, revisit with numbers.

## Consequences

- A performance regression is visible from the RPT of any run, not only from a profiler
  build.
- Tuning has a method: run the load mission, read the slices, change one constant, run
  again, commit with both slices.
- ADR-0005's "budgets are CBA settings" and "budget helper" are amended by this record;
  its handler structure, level of detail rule and reporting rule stand.

## What this overrides in upstream, and why

Nothing in upstream; upstream has no profiling. This amends this fork's own ADR-0005.
