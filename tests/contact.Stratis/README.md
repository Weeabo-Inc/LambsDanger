# Contact test (layer 2, brief test 1)

Checks 1 to 5 of [docs/systems/tactics.md](../../docs/systems/tactics.md).

Layout on Stratis, placed by `init.sqf`:

- **Player**: one BLUFOR rifleman.
- **Near squad** (`hostis_near`): six OPFOR men including an autorifleman, 300 m north in the
  open, aggressive posture, free intent.
- **Far squad** (`hostis_far`): six OPFOR men 700 m north with a radio.

Every 5 s the RPT prints `HOSTIS TEST tactic <group>: <tactic> since <s>` with the
manoeuvre and base of fire counts when suppress and flank is running, and the last three
`tacticLog` lines.

Steps:

1. Fire at the near squad. Within 10 s: `MORALE` lines, men prone or in cover, return
   fire, a `KNOWLEDGE ... reports` line.
2. Within 45 s: `TACTIC ... start suppressAndFlank`, a `flank point` marker on the map, at
   least two men moving toward it on a covered route while the leader and gunner fire.
3. Shoot only at the runners and leave the base of fire alone, then shoot only at the base
   of fire: `BOUND ... waits` appears when the base stops firing and the runners hold.
4. Go behind the hangar for 60 s: `TACTIC ... start search`, a `last known` marker, pairs to
   three points around it, nobody on top of you.
5. Restart and kill the leader first: the far squad's `reported` contact is later or lost;
   the near squad reaches `strained` cohesion.

Turn on `hostis_squad_debug`, `hostis_agent_debugMorale` and LAMBS debug functions.
