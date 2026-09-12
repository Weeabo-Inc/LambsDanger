# ADR-0010: Positions are sampled and scored at runtime; no cover-node authoring

Status: Accepted (records a rejected alternative)
Date: 2026-09-12
Brief reference: §3.4 Dynamic tactical position selection
Research reference: C-09, C-20 to C-27

## Context

Arma has no cover graph and no navmesh script can read. Terrains are tens of square
kilometres and missions are placed anywhere on them by Zeus at runtime, so hand-placed
cover nodes (F.E.A.R.'s approach) are impossible. Killzone scored positions at runtime from
a waypoint graph; Brink and Killzone 3 generated cover points dynamically with no database.
This fork already has `findPositions`: it scores fighting, hiding and stepping-stone
positions from walls, rocks, vegetation, cached building positions, terrain dips and
vehicles, bounded to 40 candidates and 24 rays.

## Decision

- Candidates are **generated** per query from: `nearestTerrainObjects` (walls, rocks,
  trees, bushes, fences), `buildingPos` of nearby buildings (cached per building), a
  terrain-dip sample on a coarse grid around the centre, vehicles, and the current position.
- They are **filtered** by conditions (not in water, not blacklisted, not reserved by a
  squadmate, not closer to the threat than to the man, inside the corridor and the area of
  operations) and **scored** by weighted criteria chosen by purpose: cover from each known
  threat axis, line of sight to the objective, concealment, distance, directness, mutual
  support, exposure to other threat axes, route exposure.
- Line-of-fire tests use `lineIntersectsSurfaces` from stance heights, batched and capped per
  query, only on the best few after cheap scoring.
- Results are **cached per area** (a coarse cell keyed on position and stance) for a bounded
  time and invalidated by smoke, destruction and vehicle movement in the cell.
- Reservations (`positionReserve`/`positionRelease`) are mandatory and expire.
- The query runs at **squad level on request**, never per unit per frame; the Agent's cheap
  pass re-validates a chosen position with conditions only (C-26).

## Consequences

- Quality depends on the terrain: open Altis fields give poor positions and the AI should
  *know* it (a bark for "no cover here", a preference to close or to withdraw).
- The system is the mod's biggest cost centre and gets its own profiler counters.

## Rejected alternative: authored cover nodes or a precomputed cover map

Rejected because Zeus places encounters anywhere at runtime, because terrains are too large
to precompute in a mod, and because destruction and smoke change cover during a fight.
