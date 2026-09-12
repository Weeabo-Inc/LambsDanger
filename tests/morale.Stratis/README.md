# Morale test (layer 1)

Checks 1 to 5 of [docs/systems/morale.md](../../docs/systems/morale.md).

Layout on Stratis, placed by `init.sqf`:

- **Player**: one BLUFOR autorifleman (Mk200) with plenty of ammunition.
- **Near squad** (`hostis_near`): six OPFOR riflemen 200 m north in the open, facing you.
- **Far squad** (`hostis_far`): six OPFOR riflemen 600 m north.

Every 5 s the RPT prints `HOSTIS TEST morale <group>: name=state ...` for both squads, the
group's cohesion, and each man's `aimingAccuracy` so check 5 can be read.

Steps:

1. Long bursts at the near squad for 20 s. Within 10 s every man in the beaten zone is
   `suppressed` or `pinned`; nobody moves sideways. If the commander tries to bound, the RPT
   says `BOUND ... waits` while nobody is covering.
2. Stop for 30 s. States ease no faster than 3 s per step and the `MORALE` lines show the
   order.
3. Kill the leader and keep firing. At least one man goes `shaken` and does not rally until
   the new leader is within 25 m.
4. Keep firing until two are down. `COHESION ... -> broken`, then `COMMANDER ... withdraw`,
   and the men run away from you into cover under smoke.
5. `aimingAccuracy` never changes in the printout.

Turn on `hostis_agent_debugMorale` and LAMBS debug functions for the change lines.
