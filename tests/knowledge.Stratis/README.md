# Knowledge test (layer 0)

Checks 1 to 5 of [docs/systems/knowledge.md](../../docs/systems/knowledge.md).

Layout on Stratis, placed by `init.sqf` at mission start:

- **Player**: one BLUFOR rifleman on the airfield apron.
- **Near squad** (`hostis_near`): four OPFOR riflemen 250 m north-east, in the open, facing
  the player, with a radio backpack on the leader so its reports reach the far squad.
- **Far squad** (`hostis_far`): four OPFOR riflemen 700 m north behind the hangar line, with
  no line of sight to the player, with a radio backpack on the leader.

Every 10 s the RPT gets `HOSTIS TEST picture <group>` followed by the group's
`pictureReport` lines, plus `HOSTIS TEST knowsAbout` with both leaders' engine knowledge of
the player.

Steps:

1. Fire one shot in the air, then stand still. Expect within 10 s: the near squad's report
   shows a `seen` or `shotAt` infantry contact with error under 50 m; the threat centre line
   is within 60 m of your true position (the RPT prints the true distance).
2. Within 30 s: the far squad's report shows a `reported` contact (chain 1) with a wider
   error, and its `knowsAbout` of you stays below 1 while `hostis_core_engineReveal` is off.
3. Walk 150 m into the hangars out of sight and wait 3 minutes. The near squad's contact is
   still listed; its confidence falls toward 0.1 and its error grows. It must still be
   listed at 5 minutes.
4. Restart. Kill the near squad leader with the first shot. The far squad's `reported`
   contact must arrive at least three times later than in step 2, or not at all; the near
   squad's Net line shows `LEADERLESS`.
5. Restart with `hostis_core_engineReveal` on. After the far squad's report arrives, its
   leader's `knowsAbout` of you must be exactly 1. If it is higher, keep the setting off
   and note it in ADR-0003.

The mission needs CBA and HOSTIS only. HOSTIS group AI runs on OPFOR; the player is BLUFOR
and untouched (ADR-0006).
