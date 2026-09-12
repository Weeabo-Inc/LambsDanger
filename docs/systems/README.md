# System design notes

One note per system from the brief (§3 and §4). A note is written when the system's build
starts and is complete when its acceptance test passes. Each note has the same sections:
Purpose, One-sentence explanation, Inputs, Decisions, Outputs, Settings, Debug overlay,
Acceptance test, Performance budget, Fairness review.

| Brief § | System | Note | Milestone | Status |
|---|---|---|---|---|
| 3.1 | Knowledge model | `knowledge.md` | 2 | not started |
| 3.2 | Perception honesty | [`../FAIRNESS.md`](../FAIRNESS.md) | 2 | contract written, CI check pending |
| 3.3 | Morale, suppression, cohesion | `morale.md` | 3 | not started (upstream stress and this fork's escalation exist; see map) |
| 3.4 | Dynamic tactical position selection | `positions.md` | 3 | seeded by `lambs_main_fnc_findPositions` (see ADR-0010) |
| 3.5 | Squad tactics | `tactics.md` | 4 | seeded by `lambs_danger_fnc_tactics*` (see ADR-0008) |
| 3.6 | Combined arms | `combined-arms.md` | 7 | seeded by mechanised attack, air assault, vehicle brain |
| 3.7 | Indirect fire and Director tools | `director.md` | 5 | seeded by the side board |
| 3.8 | Adaptation and memory | `adaptation.md` | 7 | not started |
| 3.9 | Legibility | `legibility.md` | 3 | not started (upstream callouts exist) |
| 3.10 | Performance | `performance.md` | every milestone | budgets in ADR-0005 |
| 4 | Zeus layer | `zeus.md` | 6 | seeded by posture module, directed move, diagnose |
