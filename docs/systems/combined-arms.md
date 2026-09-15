# Combined arms (brief §3.6, milestone 7)

## Purpose

Vehicles, aircraft and guns are part of the same picture and the same decisions as the
men on foot. This note covers what milestone 7 added on top of the upstream vehicle brain
and the `wp` mechanised and air tasks: platform-aware hearing, the hug rule, illumination
at night, and two fairness repairs in the close-quarters and vehicle code.

## One-sentence explanation

"They heard your tank a kilometre off, saw your helicopter, and closed in on you before your
mortars could open up."

## Inputs

- The scripted ear (`hostis_core_fnc_hearing`, ADR-0012): the FiredMan event for every
  shot, with the shooter's platform.
- The Director's artillery log and the new `hostis_director_enemyAir` event.
- The squad planner's context (`tacticContext`): `hug` and `night`.

## Decisions

- **Platform-aware hearing.** A shot from a mounted gun is heard further than a rifle:
  aircraft ×4, tanks ×3, other vehicles ×1.5 on `hostis_core_hearingRange`. The error and
  confidence rules are unchanged. An aircraft's gun also raises `hostis_director_enemyAir`
  on the server, once per aircraft per 30 s; the Director marks every hostile side as having
  seen air.
- **Hug rule (C-55).** See [director.md](director.md#hugging-c-55): with enemy air or
  artillery inside 10 minutes, the planner prefers `bound`, `assault` and `suppressAndFlank`
  by +30 priority.
- **Illumination at night.** When the planner starts `suppress`, `assault`, `bound`,
  `suppressAndFlank` or `search` and the sun is down, a grenadier of the group fires an
  illumination round at the threat centre 2 s later, at most once per minute per group,
  through `lambs_main_fnc_doUGL`. No launcher or no round means no flare (FAIRNESS.md R5).
  `taskHunt` no longer conjures a flare with `createVehicle` when nobody carries one.
- **Close quarters without teleporting.** `taskCQB` used to `setVehiclePosition` a man
  stuck indoors when no player was within 50 m. He now gives that room up and takes the
  next one. The last R5 teleport outside the Zeus-requested task options is gone.
- **The vehicle brain reads its own picture.** `brainVehicle` measured the exact distance to
  what shot at the vehicle; it now measures to `getHideFrom`, the crew's last known
  position (FAIRNESS.md R1).

## Outputs

Heard contacts at the platform's range; `airSeen` and `hug` in the side state; the
`hostis_director_hug_<side>` public variable; `DIRECTOR: hugging ...` log lines; the
`TACTIC ...: illuminates the threat` debug line.

## Settings

`hostis_director_hugging` (default on), `hostis_director_adaptation` (default on); the
hearing multipliers are constants in `fnc_hearing.sqf`.

## Debug overlay

The Director report (Diagnose module on the server) prints `hugging: the enemy has indirect
fire or air` while the flag is up. The picture overlay shows heard contacts as before.

## Acceptance test (`tests/arms.Stratis`)

1. Fire the armed helicopter's gun 1 km from the squads: within 10 s each squad's picture
   has `heard unknown` near the aircraft, and the report shows `hugging`.
2. With the flag up, engage a squad from 250 m: its next planned tactic is `bound`,
   `assault` or `suppressAndFlank`, not `suppress` or `defendPosition`.
3. At night (the mission starts at 23:00), that tactic is followed within 3 s by an
   illumination round from a grenadier over your position; the group without a grenadier
   fires none.
4. Order the CQB squad into the village and watch a man stuck in a house: he walks out or
   changes room, never appears outside.
5. Shoot at the APC from 400 m and stay hidden: it turns and suppresses where it last saw
   you, not where you are.

## Performance budget

Hearing adds one `vehicle` and up to two `isKindOf` per shot before the group walk. The
adaptation rules are one hashmap sweep per think each. Nothing new runs per frame.

## Fairness review

R1: the vehicle brain now reads `getHideFrom`. R5: the CQB teleport and the conjured
flare are removed, `fairness_allow.txt` lost both TODO rows. The hug flag is a side-wide
boolean carrying no position.
