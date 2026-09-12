# ADR-0007: Groups are pinned to their owner while registered; the Director lives on the server

Status: Accepted
Date: 2026-09-12
Brief reference: §2 (upstream locality warning), §3.10 Performance, §6 (test in MP early)
Research reference: C-07

## Context

Upstream's task modules must run where the group is local and the group must stay there;
dynamic load balancers that move groups between headless clients break them. The five-layer
design makes this worse: the Director must see every group on the side, but the Agent and
Squad layers must run where the units are simulated.

## Decision

- **Layers 0 to 2 run where the group is local.** Their state lives in group and unit
  variables that are *not* broadcast (local `setVariable`), except the few summary values
  the Director needs (escalation level, cohesion state, current tactic, picture age), which
  are published on a 5 s cadence with `setVariable ... true` and a rate limit.
- **Layer 3 runs on the server only.** It never touches a unit. It sends intents and grants
  with `CBA_fnc_targetEvent` to the group's owner, addressed by group; the receiving machine
  applies them if the group is local and drops them otherwise (a stale owner). Reports up
  travel with `CBA_fnc_serverEvent`.
- **Layer 4 runs on the curator's machine** for UI and forwards to the server with events.
- **Pinning.** When a group registers with a layer, `hostis_core_fnc_pin` sets the group
  variable `hostis_pinned` (broadcast). The mod ships an integration note and a setting
  `hostis_core_respectPin` for load balancers; the reference implementation for
  `ace_headless` and `werthles` is to skip groups with that variable. If a pinned group
  changes locality anyway, the old owner releases the machine's men on the `Local` event
  handler and the new owner re-registers from the broadcast summary; the picture is lost,
  which is acceptable and logged.
- Every layer 0 to 2 function begins `if (!local _group) exitWith {}` (already the pattern
  in this fork's commander).

## Consequences

- Testing must be on a dedicated server with at least one headless client from milestone 2
  onward; the milestone 10 test mission is the standing rig.
- Network traffic is bounded: one summary per group per 5 s plus events.

## What this overrides in upstream, and why

Nothing; it formalises upstream's warning and adds the pin so load balancers can cooperate.
