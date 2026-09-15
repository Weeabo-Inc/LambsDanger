# Load test (milestone 8, the standing rig of ADR-0005, ADR-0007 and ADR-0014)

Checks 1 to 4 of [docs/systems/performance.md](../../docs/systems/performance.md).

Layout on Stratis, placed by `init.sqf` relative to the player:

- **Player**: one BLUFOR rifleman.
- **Thirty squads** (`hostis_load_<ring>_<n>`): six men each on rings at 400, 800 and
  1200 m, ten per ring. Even-numbered squads defend where they stand, odd-numbered are
  free, so the Director has fifteen reserves.
- **Four APCs** (`hostis_load_apc_<n>`): crewed, on the 800 m ring, hold intent.
- **Mortar team** (`hostis_load_mortar`): 1500 m north, registered as artillery.

Two hundred AI. `hostis_core_debugPerformance` is forced on by the mission, so every
machine writes `HOSTIS PERF <machine> ...` slices to its RPT every 30 s. The mission adds
`HOSTIS TEST player at <grid> | OPFOR alive N | groups in contact N | fps N` on the same
cadence.

Run it on the dedicated server with at least one headless client if one is available.

Steps:

1. Idle for 2 minutes. Read the `HOSTIS PERF server` block: `registered` shows the
   groups the commander holds, and every named line is far under the targets in
   performance.md (soldier under 6 ms/s, commander under 4, morale under 1, tactics under
   2, director under 1, hearing under 1).
2. Engage the 400 m ring and keep firing for 3 minutes. The registered counts climb; the
   `groups in contact` count rises past ten; every layer stays under target and `fps` stays
   within 5 of step 1.
3. With a headless client connected: the `HOSTIS PERF headless` lines show groups
   registered there and the server's `commander groups` drops by as many; no
   `is not local` text in the Director's log lines.
4. Zeus: Diagnose any squad. The Performance section matches the last RPT slice from the
   machine that owns it.

Paste the `HOSTIS PERF` blocks from steps 1 and 2 into the next session. A layer over
target becomes a setting and is tuned against these numbers.
