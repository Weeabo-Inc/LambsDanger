# HOSTIS documentation

HOSTIS is a hard fork of [LAMBS Danger.fsm](https://github.com/nk3nny/LambsDanger) built
around one principle: **Zeus holds the reins, the AI operates**, and one constraint: the AI
is never friendly and never commandable by players.

| Document | What it is |
|---|---|
| [RESEARCH.md](RESEARCH.md) | Game AI and doctrine studied, with the behavioural consequence drawn from each (`C-nn`) |
| [UPSTREAM-MAP.md](UPSTREAM-MAP.md) | Every function in the tree: what it does, what it costs, keep / rewrite / delete |
| [FAIRNESS.md](FAIRNESS.md) | The perception honesty contract, the review checklist, the audit of the current tree |
| [CHANGES-FROM-UPSTREAM.md](CHANGES-FROM-UPSTREAM.md) | What this fork has changed relative to upstream, by area |
| [adr/](adr/README.md) | Architecture decision records, including rejected options |
| [systems/](systems/README.md) | One design note per system, written when the system is built |

## Milestones

1. Research and map. `RESEARCH.md`, `UPSTREAM-MAP.md`, ADRs, fork identity, building. No behaviour changes.
2. Layer 0 and the fairness contract. Contact store, reports, comms net, overlay, CI fairness check.
3. Layer 1. Agent behaviour, position selection, suppression response, morale states, barks.
4. Layer 2. Squad tactics: suppress-and-flank, react to contact, break contact first. **Playable here.**
5. Layer 3. Director: reserves, reinforcement, indirect fire, menace pacing.
6. Layer 4. Zeus modules, overlay, budgets, throttle, mission-maker API.
7. Combined arms, CQB, adaptation.
8. Performance pass, compatibility pass, documentation, release.

## Layers

| Layer | Addon | Tick |
|---|---|---|
| 4 Zeus | `hostis_zeus` | event |
| 3 Director | `hostis_director` | 10 to 30 s |
| 2 Squad | `hostis_squad` | 3 to 8 s |
| 1 Agent | `hostis_agent` | 0.5 to 2 s, event-driven |
| 0 Knowledge | `hostis_core` | continuous, cheap |
| compat | `lambs_main`, `lambs_danger`, `lambs_wp` | the upstream surface, kept working |

Information flows up by report and down by order. See [ADR-0001](adr/0001-five-layer-architecture.md).
