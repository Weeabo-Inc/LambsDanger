# ADR-0013: The Zeus layer sets intents and dials, never orders

Status: Accepted
Date: 2026-09-15
Brief reference: §4 Zeus layer, §1 "Zeus holds the reins. The AI operates."
Research reference: C-08, C-15, C-16

## Context

By milestone 5 a Zeus already had: the upstream task modules and ZEN actions (Attack,
Defend, Garrison, Patrol, Hunt, Rush, Creep, Camp, CQB, Artillery), the Posture module
and its intent fields, Directed Move, Diagnose, and the Director's CBA events. What was
missing was one place that answers "what is this group for", the Director's dials in the
Zeus hand, an area to keep the Director inside, a brake that works within a second, and a
way to see what every group thinks without reading the RPT.

The danger of a Zeus layer is that it becomes a remote control: a Zeus who can tell a man
where to stand will, and the AI stops operating. The brief forbids it: no Zeus action may
reach an Agent.

## Decision

`hostis_zeus` is a translation layer. Everything it offers reduces to one of four things
the lower layers already understand:

1. **An intent** on a group (`hostis_zeus_fnc_intent`): free, hold, defend, attack,
   reserve, with objective, radius, posture and escalation cap. One module, one ZEN
   action, four waypoint types (Eden and ZEN) and one function all go through it. Attack
   and defend also start the matching task; free, hold and reserve stop whatever task ran.
2. **A Director dial** (`hostis_zeus_fnc_director`): the throttle, the two budgets, an
   area of operations outside which the Director spends nothing, and the squad-layer
   pause. One module and one ZEN action.
3. **A Director request**: release a reserve toward an area, or ask for a fire mission on
   an area. Both are areas with an error, never a target; a Zeus release ignores budget and
   pacing because Zeus holds the reins.
4. **The pause** (`hostis_squad_fnc_pause`), which resets every tactic within the frame.

The overlay is read only: a label over every commander-run group with intent, escalation,
cohesion, running tactic and contact count, and a line to its threat centre, refreshed
from the server every three seconds. It shows what the AI believes, never what is true.

Rejected: a "move here" order per unit, a "target this" action, and any Zeus-visible
knob on the Agent layer. Directed Move stays as it is (a group-level waypoint with a
watchdog), and the upstream Disable AI stays as the emergency stop for a group.

## Consequences

- Test 9 of the brief (a Zeus touches nothing for 15 minutes) and test 10 (a Zeus can
  stop everything within a second) are testable through this addon alone.
- A mission maker's script API is the same four functions; there is no separate one.
- The overlay costs the server one pass over the commander's groups per curator every
  three seconds, capped at forty rows.

## What this overrides in upstream, and why

Nothing is removed. The upstream task modules remain; the intent module is the
recommended door because it also sets the box the commander improvises inside.
