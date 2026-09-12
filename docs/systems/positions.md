# Dynamic tactical position selection (layer 1)

Addon: `lambs_main` (`fnc_findPositions`, `findPositionsBuilding`, `findApproach`,
`positionReserve`, `positionRelease`) and `hostis_agent` (`positionValid`). Brief §3.4.
Research: C-09, C-20 to C-27. ADR-0010.

## Purpose

Turn a purpose and a threat picture into a scored position, at squad level, on a budget.

## The query

`[centre, radius, threats, options] call lambs_main_fnc_findPositions` returns up to `count`
results `[pos, cover, canFire, stance, score, source]`, best first.

Options (hashmap):

| Key | Meaning |
|---|---|
| `purpose` | `fight` (cover with a field of fire), `hide` (full cover, concealment), `move` (a stepping stone that gains ground) |
| `objective` | position the man is going to; drives progress and directness |
| `unit`, `group` | for reservations, blacklists and indoor checks |
| `indoorBias`, `buildingsOnly`, `minDistance`, `count` | as named |
| `directness` | `[min, max]` condition on (distance gained toward the objective) / (distance walked): `[0.5, 1]` is progress, `[-0.1, 0.1]` is a flank, `[-1, -0.3]` is retreat |
| `directnessWeight` | weight on the same value: negative with a positive minimum gives the zigzag approach |

## Generation

Candidates come from walls, rocks, fences and hides (hard cover), bushes and trees (soft),
eight terrain-dip samples, parked vehicles, and the per-building position cache. The world
queries for a 25 m cell are cached for 20 s (`lambs_main_tpsCache`), so a squad asking six
times in a fight asks the engine once. The cache is invalidated by time only in this
milestone; smoke and destruction invalidation come with the position system's own tests.

## Conditions and weights

Conditions: inside the radius, outside `minDistance`, not water, not within 20 m of a
threat, not reserved by a squadmate, not blacklisted as unreachable, directness band.
Weights: cover, progress toward the objective (move), path length, road, crowding,
indoor bias, upper floors, concealment (hide), directness. Then up to 24 rays on the best
twelve decide cover height and field of fire from the main threat.

## Validation (`hostis_agent_fnc_positionValid`)

A man already moving keeps his destination unless this cheap check fails: water, threat
clearance, somebody else's reservation, and one body-height ray from the main threat.

## Budget

At most 40 candidates and 24 rays per query; the soldier machine asks at most 12 times per
0.5 s tick across all men, each man at most every 3 s.

## Acceptance

Covered by the milestone 4 suppress-and-flank test (covered routes) and by the milestone 3
morale test (men in the beaten zone are behind something).
