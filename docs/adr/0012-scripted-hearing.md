# ADR-0012: Shots under 300 m are heard by script, and the shooter's origin is filed

Status: Accepted
Date: 2026-09-13
Brief reference: §3.1 knowledge model, §3.2 perception honesty
Research reference: C-58, C-62, C-63

## Context

The first in-game run of `tests/knowledge.Stratis` (2026-09-13) showed two things about the
engine's Fire danger cause:

1. It did not fire at all for a rifleman shooting unsuppressed at 150 to 200 m in the open
   in daylight. The squad heard nothing until the player was 119 m away.
2. When it did fire, its danger position was the round, not the gun: the four men reported
   the fire 929 to 937 m away in one direction while the shooter stood 119 m away in another.
   Filed as a heard contact, that sent the squad flanking and searching 500 m the wrong way.

The fairness contract (R1) said targets come only from the engine's sensors. Taken
literally, the AI is deaf beyond 120 m and cannot be told where a shot came from, which no
player would accept as fair: a rifle shot at 200 m is audible and roughly locatable.

The user's decision, in their words: "Sub 300 m it should be easy to tell where the shooter
is just from firing alone. I feel like it's fine to 'cheat' and reveal to the AI where the
origin of the fire is."

## Decision

`hostis_core` owns a scripted ear, `fnc_hearing`, on the FiredMan extended event handler:

- Every shot from a man (not throwables) is heard by every local AI group of an enemy side
  whose leader is within `hearingRange` (default 300 m). A weapon with a muzzle attachment
  is heard at `hearingSuppressed` (default 0.3) times that range.
- The hearing files a `heard` contact at the shooter's position with an error of 5 m plus a
  tenth of the distance (35 m at 300 m), confidence 0.7, activity "firing", and logs the
  round's bearing for the volume counter. At most one report per shooter per second.
- Picture only. Nothing is revealed to the engine; the group orients, watches and searches
  the area, and can suppress it, but gains no target it cannot see. `engineReveal` does not
  apply to heard contacts.
- The engine's own Fire, BulletClose and Hit causes no longer file their danger position.
  A shooter the engine names and the man knows is a `shotAt` sighting; a shooter named but
  unknown is a `heard` contact at the shooter's position with a wider error; a cause with no
  shooter only counts toward the volume of fire, with no bearing.
- `hearingRange` 0 restores engine-only hearing.

## Consequences

- FAIRNESS.md R1 gains this as its one stated exception: the position of a shooter within
  hearing range, blurred, picture only.
- The "one sentence" is "They heard the shot and know roughly where it came from."
- Cost: one `allGroups` pass per shooter per second while he fires, a distance check per
  group. Fine for a company of AI; watch it with a hundred groups.
- The knowledge test's step 1 now works from 250 m without an engine detection.

## What this overrides in upstream, and why

Upstream had no hearing of its own and trusted the engine's Fire cause, including its
position; it was wrong about where the fire came from and blind beyond the engine's short
hearing. This fork models the ear so the AI reacts to fire the way a player expects.
