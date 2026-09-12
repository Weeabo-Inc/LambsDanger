# ADR-0004: The Director may know, the Agent must perceive

Status: Accepted
Date: 2026-09-12
Brief reference: §1 (two-brain system), §3.1 last paragraph, §3.2
Research reference: C-12, C-13, C-16, C-17

## Context

Alien: Isolation's Director always knows where the player is and never tells the creature;
it nudges the creature toward an *area*. That single rule is what lets a game with an
omniscient pacing system feel fair. Left 4 Dead's Director likewise reads the players'
state to choose *when* and *from where* to spend, and changes pacing rather than
difficulty.

HOSTIS needs the same split. Pacing, reinforcement timing, counter-battery and
"reinforce from behind the players' axis" all need player positions. Targeting must not.

## Decision

- The Director (layer 3) is the only layer that may read `allPlayers`, player positions,
  player-side group positions, player indirect-fire events and player vehicle presence.
- It uses them for exactly four things: the **menace gauge** (intensity per player element,
  frozen while in contact), **pacing** (build up, sustain, fade, relax), **spending**
  (reinforcement release, fire support budget, vehicle release) and **placement** (where a
  reserve enters, which is outside the players' potentially visible set).
- Everything the Director sends down is one of: an **objective area** (position and radius,
  radius never smaller than the report error of the best contact the Director actually
  holds for that area), a **posture**, a **corridor**, a **resource grant**, or a **throttle
  value**. Never a unit, never an exact position, never a target.
- The Director's board of *enemy* contacts is built from group reports (ADR-0003). The
  Director may compare its board with reality to compute *how wrong the side is*, and that
  number is shown in the curator overlay, but the comparison never flows down.

## Consequences

- The curator overlay can show "what the Director believes" next to "what is true", which is
  the best trust-building tool the Zeus has.
- Counter-battery (test 4) is honest: the Director saw rounds land and knows where they came
  from; a mortar firing position is a reasonable thing for a side to compute.
- A Director order can be *wrong* on purpose or by accident, and the Squad layer will walk
  into an empty area; that is correct behaviour.

## What this overrides in upstream, and why

`taskRush`, `taskHunt` and `taskCreep` read player positions to send groups at them. They
are re-expressed as Director intents ("find and destroy inside this box") with the group
receiving an area. The functions stay for compatibility and forward to the intent.
