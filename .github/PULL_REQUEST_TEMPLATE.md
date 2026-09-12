### When merged this pull request will:

1. *Describe what this pull request will do*
2. *Each change in a separate line*

### Fairness checklist (docs/FAIRNESS.md §2)

- [ ] No new `reveal`, `doTarget`, `doFire`, `commandTarget`, `commandFire`, `doWatch` or suppressive-fire call on an object the group has not detected (or the guard is cited below)
- [ ] No new `setSkill`, `setUnitTrait`, `setPos*`, `addMagazine*`, `setVehicleAmmo`, `createUnit` or `createVehicle` (or the rule and justification are cited below)
- [ ] No read of `allPlayers`, `allUnits`, `playableUnits`, `switchableUnits` or side-filtered `nearestObjects` below the Director layer
- [ ] No Squad or Agent function reads a `hostis_director_*` variable

### The one sentence

*What a player would be told after this behaviour killed them.*

### Performance (if this changes a handler, a loop or a world query)

*Before and after `diag_` numbers on the milestone 10 test mission.*
