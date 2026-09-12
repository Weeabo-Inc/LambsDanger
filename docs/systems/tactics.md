# Squad tactics (layer 2)

Addon: `hostis_squad`. Brief §3.5. Research: C-08, C-10, C-30, C-41 to C-51, C-58, C-60.
ADRs 0009 (explicit tactics, no planner) and 0011 (lifecycle).

## Purpose

One place where a group's tactic is chosen, started, watched, and ended cleanly, so that
the commander, the Director and the Zeus all interrupt the same way and no man is left
under a dead order.

## One-sentence explanation

Each tactic carries its own; the planner's is: "They picked the drill that fit what they
knew about you, ran it until it worked or failed, and switched when it did."

## The lifecycle

A tactic is a registered descriptor (`hostis_squad_fnc_tacticRegister`): priority, planned,
precondition, start, monitor, abort, reset, commit, maxDuration, moving, explain.

- `tacticStart` resets whatever ran before, snapshots the group's settings, marks the group
  busy for the upstream code (`lambs_danger_isExecutingTactic`, `tacticToken`), runs the
  tactic's start and installs one 3 s monitor handler.
- `tacticMonitor` checks the abort condition, the tactic's own monitor, then the default
  judgement (bleeding, broken, enemy gone, reached, stalled) and the timeout.
- `tacticReset` is the one reset: the tactic's own reset, the flags, the monitor, the men
  (released to follow the leader, AUTOCOMBAT back), the group's settings from before, the
  picture's last tactic and result, a log line with the reason. Interrupt classes (C-15):
  `now` this frame, `blend` after the current leg (10 s at most), `finish` let the monitor
  end it.
- `pause` is the Zeus brake: every local group's tactic is reset within the frame and the
  planner stops until resumed.
- Zeus directed moves and `lambs_wp` task cleanup call `tacticReset` first.

Upstream tactics are wrapped: they are called with a very long delay so their own timer
resets never fire, and those timers are additionally guarded by the token so a stale one
cannot touch a later tactic. Their condition-based resets fire when the lifecycle clears
the busy flag and only repeat what the lifecycle already did.

## The planner (`hostis_squad_fnc_plan`)

Called from the commander's think at alert (level 1) and above engaged (level 2 and 3).
The first planned tactic, by priority, whose precondition holds and that is not on
cooldown, starts. The commander's own defence tree (hold and defend intents) still runs
first for defenders and starts `garrison`, `hide` and `suppress` by name through the same
lifecycle; the planner runs for defenders only when the enemy is inside their area.

| Priority | Tactic | Precondition (summary) | Ends |
|---|---|---|---|
| 100 | `withdraw` (break contact) | cohesion broken, morale under 0.35, or cautious under 0.5; rested; not defending | 110 m from the threat after 20 s |
| 85 | `hastyAmbush` | alert, not yet fired on, enemy known and moving, 80 to 400 m, three men or more | 10 s after springing (range 150 m, or fired upon), then the planner |
| 80 | `suppressAndFlank` | engaged, four men or more, not the support role, not broken, threat inside 400 m | manoeuvre element on the objective (hand-over to the building assault), or stalled 60 s |
| 70 | `bound` | engaged, small team inside 600 m, or aggressive and far | reached 25 m or stalled 45 s |
| 60 | `assault` | engaged, inside close range | reached or 85 s |
| 50 | `suppress` | engaged and cautious, support role, alone, far, or strained | enemy gone 20 s or 60 s |
| 40 | `search` | alert or engaged, nothing seen for 30 s, last known under 300 s old, not under fire | seen again, or settled 30 s, or `searchTime` |

Not planned, started by name: `garrison`, `hide`, `flank`. The deliberate attack
(`tacticsManeuver`) and the mechanised and air assaults stay on their own state machine
and are started by the commander directly; they join the lifecycle when they move to this
addon.

## Suppress and flank

The one behaviour the brief calls the most important.

1. Task organisation: the leader, the support gunners and the medic are the base of fire,
   never more than half the men; everyone else is the manoeuvre element, at least two.
2. The flank point is off the enemy's side by `flankOffset` (100 m, never more than 70% of
   the distance), pulled back toward our side so the route does not cross the enemy's
   front; the side whose point scores better cover wins.
3. The base holds from the nearest cover with a suppress list (known contacts, buildings
   around them, the centre) and fires by the soldier machine's peek and duck; smoke goes
   out; the leader calls "suppress".
4. The manoeuvre element bounds to the flank point through `doGroupBound` with the base of
   fire static. The bound only goes while the base is firing when fire is coming in
   (C-42); otherwise the runners wait and call for covering fire. The bound picks covered
   legs, sprints, drops prone on arrival.
5. On the flank point the element turns in on the enemy with a new bound; inside close
   range the bound hands over to the building assault, which keeps the men, and the
   tactic ends "done".

Failure: element gone, stalled 60 s, two losses, morale under 0.35, cohesion broken.

## Hasty ambush

An L across the enemy's approach at the group's own position: riflemen along the long leg
at 6 m spacing, the machine gun on the short leg 25 m to the side with better cover,
looking down the kill zone 80 m out. Weapons hold (GREEN) until the enemy is inside
`ambushRange` (150 m) or the group is fired upon; then RED, "attack", ten seconds of the
opening volley and the planner takes over.

## Search

Pairs go to the edge of the last known position's error circle, beyond it and to both
flanks, and hold facing outward; the leader takes a vantage short of it. The circle is the
picture's own error, so the search converges on where the enemy could be, not where he is.
Ends when he is seen again, when everyone has settled for 30 s, or after `searchTime`.

## React to contact

Kept from upstream and the fork: the first contact puts the leader into cover, calls the
contact, shares the report, registers the group with the commander, and the men's brains
handle cover and return fire. The commander's first think follows within 2 to 5 s and the
planner runs from then on. `tacticsAssess`'s random plan list no longer runs for a
registered group; its side jobs (statics, flares, artillery) move to the Director.

## Settings (`hostis_squad_*`)

`enabled`, `tacticCooldown` (20 s), `flankOffset` (100 m), `ambushRange` (150 m),
`searchTime` (120 s), `debug`.

## Debug

`debug` (or LAMBS debug functions) logs every start, phase, refusal and end with the
reason; the picture keeps the last ten in `tacticLog` (shown by the Diagnose module in
milestone 6). A `flank point`, `kill zone` or `last known` marker is drawn for 5 minutes.

## Acceptance test (`tests/contact.Stratis`)

Test 1 of the brief. A six-man OPFOR squad in the open, the player firing at it from
300 m with a rifle.

1. Within 10 s of the first shot: men in cover or prone, return fire, `KNOWLEDGE ...
   reports` in the RPT (report).
2. Within 45 s: `TACTIC ... start suppressAndFlank`, the leader and gunner firing from
   cover, at least two men moving on a route with cover toward a flank point marker.
3. Stop firing at the base of fire and fire only at the runners: when the base of fire
   stops shooting, the RPT shows `BOUND ... waits` and the runners stay in cover; when it
   resumes, they move again.
4. Hide behind the hangar for 60 s: `TACTIC ... start search`, pairs to three points around
   your last position, none of them on top of you.
5. Kill the leader on the first shot in a second run: the report to the far squad is
   later or lost, and the near squad goes `strained`.

## Performance budget

One 3 s handler per running tactic; the planner runs inside the commander's 5 s think; the
context builds from the picture and the men with no world queries; suppress and flank
makes two position queries at start.
