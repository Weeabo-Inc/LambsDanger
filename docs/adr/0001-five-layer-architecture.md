# ADR-0001: Five layers with report-up, order-down information flow

Status: Accepted
Date: 2026-09-12
Brief reference: §1 The architecture that makes this work
Research reference: C-12, C-28, C-29, C-30, C-32

## Context

Upstream LAMBS is one reactive stack: the danger FSM fires an event, `fnc_brain` dispatches
by unit state, `fnc_tactics` picks a group tactic, and the waypoint tasks sit beside it.
Nothing plans between events, nothing coordinates across groups, and nothing distinguishes
what a group *knows* from what the engine knows. The brief asks for a Zeus who sets intent
and an AI that operates, which needs a place for intent to live, a place for cross-group
decisions, and a place for honest knowledge.

Killzone 3 (three layers, orders down, information up), Alien: Isolation (Director and
Drone) and F.E.A.R. (squad manager over autonomous agents) all converge on the same shape.

## Decision

Five layers, each its own addon, its own tick, its own debug overlay:

| Layer | Addon | Owns | Tick |
|---|---|---|---|
| 4 Zeus | `hostis_zeus` | intent, ROE, boundaries, budgets, throttle | event |
| 3 Director | `hostis_director` | reserves, reinforcement, indirect fire, pacing, cross-group coordination | 10 to 30 s |
| 2 Squad | `hostis_squad` | base of fire vs manoeuvre, tactic selection, cohesion | 3 to 8 s |
| 1 Agent | `hostis_agent` | cover, posture, fire control, panic, reload, grenades | 0.5 to 2 s, event-driven |
| 0 Knowledge | `hostis_core` | contact store, reports, decay, comms net | continuous, cheap |

Information flows **up by report** (a function call that costs simulated time and can be
lost) and **down by order** (an area, a posture, a corridor, a grant). A layer never reads a
structure owned by a layer above it. A layer never moves a unit owned by a layer below it;
it issues an order the lower layer executes.

Concretely:

- Layer 0 owns `hostis_core_fnc_contact*` and the per-group `picture`. Layers 1 to 3 read it
  through `pictureGet`; only layer 0 writes it, from unit sensors (layer 1 reports) and
  from received reports.
- Layer 1 owns the per-soldier machine (`unitOrder`, `unitCycle`, `unitThink`, `unitEvent`)
  and the position queries it makes.
- Layer 2 owns tactics. A tactic is the only thing that calls `unitOrder` for more than one
  man at once.
- Layer 3 owns the side board, the reserve pool, the fire support budget, the menace gauge
  and the influence map. It talks to layer 2 only through `intentSet` and resource grants.
- Layer 4 owns the Zeus modules, the ZEN actions, the settings and the curator overlay. It
  talks to layer 3 through the public intent and budget API and to nothing below it.

## Consequences

- Every function header carries a `Layer:` line so a reviewer can see a cross-layer read at
  a glance.
- The fairness contract R6 is checkable mechanically: grep for `hostis_director_` reads in
  the `agent` and `squad` addons.
- Latency is a feature: a group's picture lags reality by report time, and the Director's
  picture lags the groups'. Killing the reporter widens the lag.
- Debugging needs per-layer views, because the same enemy is in four different places in
  four different pictures and all four can be "right".

## What this overrides in upstream, and why

Upstream's `fnc_brain` → `fnc_tactics` chain is kept as the layer 1 to layer 2 boundary but
loses its direct reads of `targets`/`knowsAbout` in favour of the picture (ADR-0003). The
side board added in this fork's commander work becomes the seed of layer 3 (ADR-0008).
