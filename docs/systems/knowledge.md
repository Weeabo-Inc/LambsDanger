# Knowledge model (layer 0)

Addon: `hostis_core`. Brief §3.1 and §3.2. Research: C-01, C-02, C-03, C-28, C-34, C-56,
C-57, C-61. ADRs: 0003, 0004, 0007.

## Purpose

Give every group its own, honest, lagging picture of the enemy, built only from what its
men have sensed and what other groups have told it, so that every layer above decides from
the picture and never from the engine's truth.

## One-sentence explanation

"They only know where you are because one of them saw you, heard you, or was told by
someone who did, and that knowledge is late, rough and fades."

## The store

One hashmap per group, created by `hostis_core_fnc_pictureGet`, held in the group variable
`lambs_danger_picture` (the name is kept while six upstream readers still open it
directly; it moves to `hostis_core_picture` when those readers move to `hostis_agent`).
Keys the upstream code already reads (`contacts`, `threatPos`, `threatDir`, `lastContact`,
`losses`, `maxCount`, `morale`, `lastTactic`, `lastResult`, `withdrawTime`) keep their
meaning. New keys: `lastReport`, `pictureAge`, `swept`, `sweepCursor`, `lastReportOut`,
`reports`, `netQuality`, `leaderUnit`, `leaderLostTime`, `id`.

### The contact record

An array, so that upstream readers that index `select 0..3` keep working:

| Index | Macro | Content |
|---|---|---|
| 0 | `CONTACT_OBJECT` | engine object for a `seen` or `shotAt` record; `objNull` for anything reported |
| 1 | `CONTACT_POS` | believed position ATL |
| 2 | `CONTACT_TIME` | time of the last evidence |
| 3 | `CONTACT_KNOWS` | engine `knowsAbout` at the last direct evidence, 0 for reports |
| 4 | `CONTACT_ERROR` | error radius in metres at the last evidence |
| 5 | `CONTACT_CONF` | confidence 0..1 at the last evidence |
| 6 | `CONTACT_SOURCE` | `seen`, `shotAt`, `heard`, `reported`, `suspected` |
| 7 | `CONTACT_FIRST` | time the record was created |
| 8 | `CONTACT_STRENGTH` | estimated men at this contact |
| 9 | `CONTACT_TYPE` | `infantry`, `vehicle`, `armour`, `air`, `static`, `unknown` |
| 10 | `CONTACT_HEADING` | last believed heading, -1 unknown |
| 11 | `CONTACT_ACTIVITY` | `moving`, `static`, `firing`, `dead`, `unknown` |
| 12 | `CONTACT_DEAD` | true once a body or a kill was seen or reported |
| 13 | `CONTACT_REF` | the object a report was about; never a target, only for `reveal` at 1 |
| 14 | `CONTACT_CHAIN` | 0 own evidence, 1 told by a witness, 2 told by someone who was told |

Confidence and error are stored at evidence time. Readers get *effective* values through
`contactsGet`, which copies the record and applies:

- confidence = max(floor, stored × 0.5^(age / halfLife))
- error = min(cap, stored + growth × age), growth reduced to a fifth for a `static` contact

So a record never disappears while it is younger than `contactMaxAge` (default 600 s); it
becomes "last known" with a wide circle and a low confidence, which is what search is for.

## Evidence

| Source | Who writes it | Position | Error at write |
|---|---|---|---|
| `seen` | the sensor sweep, from `targets [true, range]` of the leader and a rotating pair of other men | `observer getHideFrom enemy` | `targetKnowledge select 5` (engine error margin), at least 1 m |
| `shotAt` | the danger FSM on Fire, Hit, BulletClose with a known shooter (milestone 3) | as above | as above |
| `heard` | the danger FSM on Scream and Explosion without a known object (milestone 3) | the danger position | 25 m plus 20% of the distance |
| `reported` | the net event from another group | the sender's believed position | sender's error plus 30 m (radio) or 60 m (shouted), plus 2% of the distance between the groups |
| `suspected` | Director areas of interest (milestone 5) | area centre | area radius |

Deaths enter only from the DeadBody danger causes (C-61): `contactDeath` marks the record
dead by object or by body position. A dead enemy is otherwise still a live contact until
someone sees the body or the kill; that is intended.

Fairness: the sweep is the only place in the mod that calls `targets`, `knowsAbout`,
`getHideFrom` or `targetKnowledge` for the purpose of knowing where an enemy is. The
store's error is never smaller than the engine's own.

## The net

`netSend` sends a group's fresh contacts (updated within 20 s, confidence at least 0.4,
chain below 2) to friendly groups in range. `netParams` decides how:

- range: the side's radio setting (`lambs_main_radioWest/East/Guer`, plus the backpack
  radio bonus) when a radio man is present, otherwise shouting range (`lambs_main_radioShout`)
- delay: `reportDelay` plus distance / `reportSpeed`
- loss: `reportLossChance`, tripled when the group lost its leader in the last two minutes,
  doubled when the sender is suppressed
- quality: reports from a leaderless group carry half confidence

The report travels as a CBA target event to the receiving group's owner, so the model
holds across headless clients. The receiver files each record as `reported` with the added
error, and optionally `reveal`s the referenced object at accuracy 1 so the engine AI looks
the right way (`engineReveal`, **off by default** until the acceptance test confirms that
`reveal [x, 1]` does not inherit the side's higher knowledge, which the wiki text leaves
ambiguous).

`lambs_main_fnc_doShareInformation` keeps its signature and now files the sighting in the
sender's store and calls `netSend`; it no longer `reveal`s at `maxRevealValue`. The
`lambs_main_OnInformationShared` event still fires with the recipient list for the
upstream reinforcement handler.

Killing the leader: `pictureRefresh` notices a leader change to a dead or unconscious man
and stamps `leaderLostTime`; for `leaderlessTime` seconds the group's reports are three
times slower, three times likelier to be lost, and half as confident. Killing the radio
man removes the radio range. That is acceptance test 3's mechanism.

## API

| Function | Layer | Purpose |
|---|---|---|
| `hostis_core_fnc_pictureGet` | 0 | get or create the store |
| `hostis_core_fnc_pictureRefresh` | 0 | prune, derive threat centre, losses, leader loss; gated to once per second |
| `hostis_core_fnc_contactReport` | 0 | file one piece of evidence; merges by object, by reference, or by proximity for objectless records |
| `hostis_core_fnc_contactSweep` | 0 | the sensor sweep; the only reader of engine target knowledge |
| `hostis_core_fnc_contactsGet` | 0 | query with effective confidence and error; filters by age, confidence, source, radius, dead |
| `hostis_core_fnc_contactDeath` | 0 | mark a contact dead from a body or a witnessed kill |
| `hostis_core_fnc_contactNearest` | 0 | the best contact near a position, for the upstream hunt, rush and creep tasks |
| `hostis_core_fnc_netParams` | 0 | delay, loss, quality and range for this group's reports |
| `hostis_core_fnc_netSend` | 0 | report fresh contacts to friendly groups over the net |
| `hostis_core_fnc_pictureReport` | debug | the picture as text for the diagnose module and the log |
| `hostis_core_fnc_debugDraw` | debug | map markers of the picture for Zeus |

Upstream forwarders: `lambs_danger_fnc_pictureGet`, `pictureUpdate`, `pictureContacts`.
Callers in `lambs_*` reach the store through the `HFUNC(core,name)` macro.

## Settings (`hostis_core_*`)

| Setting | Default | Meaning |
|---|---|---|
| `contactMaxAge` | 600 s | a contact is forgotten after this |
| `confidenceHalfLife` | 45 s | confidence halves every this many seconds |
| `confidenceFloor` | 0.1 | confidence never drops below this while remembered |
| `errorGrowth` | 0.5 m/s | the circle grows this fast for a moving contact |
| `errorCap` | 300 m | and never wider than this |
| `storeCap` | 24 | records per group; the weakest objectless ones go first |
| `mergeRadius` | 20 m | objectless records of one type this close are one contact |
| `sweepRange` | 1200 m | how far the sweep asks the engine |
| `sweepUnits` | 2 | extra men, rotating, whose eyes join the leader's per sweep |
| `reportDelay` | 3 s | base delay of a report |
| `reportSpeed` | 150 m/s | plus one second per this many metres |
| `reportInterval` | 10 s | a group reports at most this often |
| `reportLossChance` | 0.1 | chance a report is lost |
| `leaderlessFactor` | 3 | delay and loss multiplier after losing the leader |
| `leaderlessTime` | 120 s | how long a group counts as leaderless |
| `engineReveal` | false | `reveal [ref, 1]` on received reports |
| `debugPicture` | false | draw the picture as map markers for the Zeus |

## Debug overlay

`debugPicture` on: every 5 s each owning machine moves one global marker per live contact
(colour by source, alpha by confidence, text `source type age error`) and one for the
threat centre, per group, capped at 8 contacts. Markers are created once and moved, not
recreated. `pictureReport` is appended to the Zeus Diagnose module's text and printed by
the acceptance test.

## Acceptance test (`tests/knowledge`)

Stratis. Player rifleman, one OPFOR squad at 250 m, one OPFOR squad at 700 m behind a hill
with no line of sight, both HOSTIS. Player fires one shot in the air.

1. Within 10 s the near squad's picture holds a `seen` or `shotAt` contact with an error
   under 50 m and its threat centre within 60 m of the player's true position.
2. Within 30 s the far squad's picture holds a `reported` contact, not a `seen` one, with a
   wider error, and no unit of the far squad has `knowsAbout player > 1` unless
   `engineReveal` is on.
3. Player hides for 3 minutes without being seen. The near squad's record stays, its
   confidence falls toward the floor and its error grows; it is never deleted before 600 s.
4. Kill the near squad leader first in a second run: the far squad's `reported` contact
   arrives at least three times later than in the first run, or not at all.
5. `engineReveal` on: after a report, `knowsAbout player` of the far leader is 1, not the near
   leader's value. If it is higher, the setting stays off and the ADR-0003 note is updated.

`tests/knowledge/init.sqf` prints both pictures to the RPT every 10 s.

## Performance budget

- Sweep: leader plus `sweepUnits` `targets` calls per group per commander think (5 s) and on
  the existing event paths. `targets` is an engine query with no ray casts.
- Refresh: O(contacts) per second per group, capped by `storeCap`.
- Net: one `allGroups` filter per group per `reportInterval`; one CBA target event per
  recipient per interval.
- No per-frame work. The debug PFH runs at 5 s and does nothing when the setting is off.
