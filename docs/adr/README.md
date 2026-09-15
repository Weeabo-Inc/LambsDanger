# Architecture decision records

One file per decision, numbered, never edited after acceptance except to change the
status line (Accepted, Superseded by ADR-nnnn, Rejected). Rejected options get their own
record so the reasoning is not lost.

Template:

```
# ADR-nnnn: Title

Status: Proposed | Accepted | Rejected | Superseded by ADR-nnnn
Date: YYYY-MM-DD
Brief reference: section of the HOSTIS brief this answers
Research reference: C-nn consequences from docs/RESEARCH.md

## Context
## Decision
## Consequences
## What this overrides in upstream, and why
```

| ADR | Title | Status |
|---|---|---|
| [0001](0001-five-layer-architecture.md) | Five layers with report-up, order-down information flow | Accepted |
| [0002](0002-fork-identity-and-addon-naming.md) | Fork identity is HOSTIS; `lambs` script prefix stays as the compatibility surface | Accepted |
| [0003](0003-group-contact-store-replaces-knowsabout.md) | A group-owned contact store replaces reliance on `knowsAbout` | Accepted |
| [0004](0004-director-agent-information-boundary.md) | The Director may know, the Agent must perceive | Accepted |
| [0005](0005-cadence-and-budgets.md) | Every layer is a budgeted, time-sliced CBA per-frame handler | Accepted |
| [0006](0006-hostile-only-scope.md) | HOSTIS never runs a player's side | Accepted |
| [0007](0007-locality-and-headless-clients.md) | Groups are pinned to their owner while registered; the Director lives on the server | Accepted |
| [0008](0008-adopt-existing-commander-and-unit-machine.md) | The existing commander, picture and soldier machine are the seed of layers 0 to 3 | Accepted |
| [0009](0009-explicit-tactics-not-a-planner.md) | Explicit selectable tactics instead of a GOAP/HTN planner | Accepted |
| [0010](0010-no-hand-placed-cover-nodes.md) | Positions are sampled and scored at runtime; no cover-node authoring | Accepted |
| [0011](0011-tactic-lifecycle.md) | Every tactic declares preconditions, commitment, abort, and a reset path | Accepted |
| [0012](0012-scripted-hearing.md) | Shots under 300 m are heard by script, and the shooter's origin is filed | Accepted |
| [0013](0013-zeus-layer-is-intents-and-dials.md) | The Zeus layer sets intents and dials, never orders | Accepted |
| [0014](0014-profiling-built-in.md) | Profiling is built in; per-tick budgets stay constants until the load rig says otherwise | Accepted, amends 0005 |
