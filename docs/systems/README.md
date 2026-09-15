# System design notes

One note per system from the brief (§3 and §4). A note is written when the system's build
starts and is complete when its acceptance test passes. Each note has the same sections:
Purpose, One-sentence explanation, Inputs, Decisions, Outputs, Settings, Debug overlay,
Acceptance test, Performance budget, Fairness review.

| Brief § | System | Note | Milestone | Status |
|---|---|---|---|---|
| 3.1 | Knowledge model | [`knowledge.md`](knowledge.md) | 2 | built in `hostis_core`; acceptance test `tests/knowledge.Stratis` awaiting a run |
| 3.2 | Perception honesty | [`../FAIRNESS.md`](../FAIRNESS.md) | 2 | contract enforced by `tools/fairness_check.py` in CI; known breaches ledgered in `tools/fairness_allow.txt` |
| 3.3 | Morale, suppression, cohesion | [`morale.md`](morale.md) | 3 | built in `hostis_agent`; test `tests/morale.Stratis` awaiting a run |
| 3.4 | Dynamic tactical position selection | [`positions.md`](positions.md) | 3 | `findPositions` gained directness, a cell cache and `positionValid` |
| 3.5 | Squad tactics | [`tactics.md`](tactics.md) | 4 | lifecycle, planner, suppress and flank, hasty ambush, search in `hostis_squad`; test `tests/contact.Stratis` awaiting a run |
| 3.6 | Combined arms | `combined-arms.md` | 7 | seeded by mechanised attack, air assault, vehicle brain |
| 3.7 | Indirect fire and Director tools | [`director.md`](director.md) | 5 | built in `hostis_director`: reserves, reinforcement, counterattack, observed fire missions, counter-battery, pacing; test `tests/director.Stratis` awaiting a run |
| 3.8 | Adaptation and memory | [`director.md`](director.md) (Adaptation) | 5, 7 | route seeding built; fatal-position and collapsing-flank rules in milestone 7 |
| 3.9 | Legibility | [`legibility.md`](legibility.md) | 3 | bark vocabulary and morale tells in `hostis_agent` |
| 3.10 | Performance | `performance.md` | every milestone | budgets in ADR-0005 |
| 4 | Zeus layer | [`zeus.md`](zeus.md) | 6 | built in `hostis_zeus`: intent module, action, waypoints, Director dials, area of operations, pause, overlay; test `tests/zeus.Stratis` awaiting a run |
