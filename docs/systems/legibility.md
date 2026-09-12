# Legibility (layer 1)

Addon: `hostis_agent`. Brief §3.9. Research: C-11, C-19, C-39, C-56. F.E.A.R.'s lesson: the
line is chosen after the decision, and it is what sells the decision.

## Purpose

Let a player hear and see what the enemy is doing and about to do, from the enemy's own
mouths and bodies, with no cheating narration.

## Barks (`hostis_agent_fnc_bark`)

A vocabulary in `addons/agent/XEH_preInit.sqf`: key, radio-protocol sentence, behaviour,
priority (1 to 3), per-man cooldown, per-group cooldown, audible range. All sentences are
the engine's own radio protocol (`CfgVoice`, through `lambs_main_fnc_doCallout`), so nothing
needs a licence and every faction voice works.

| Key | Fired by | Meaning to the player |
|---|---|---|
| contact | first contact (upstream) | they know something is there |
| underFire | a man goes suppressed | your fire is landing |
| takeCover | a man goes pinned | he has stopped moving |
| coverMe | a pinned man refuses an order; a bound waits for covering fire | they want to move and cannot |
| suppress | base of fire starts (upstream) | a machine gun is about to open on you |
| moving | a bound goes (upstream "Advance") | somebody is running |
| flank | flank tactic (upstream) | somebody is going round |
| fallBack | break contact (upstream) | they are leaving |
| rally | a shaken man or a broken group recovers | the leader is pulling them together |
| panic | shaken or broken | they are close to breaking |
| manDown | a loss is noticed (upstream) | you hit somebody |
| grenade | grenade thrown (upstream) | get out |

Rules: a group says one key at most once per its cooldown; a man says it once per his; a
priority 3 bark cuts a lower one short. `barkGroupCooldown` scales all cooldowns. Text
subtitles are not provided: the engine audio is the channel.

## Visual tells

Already in the tree and kept: peek and duck rhythm in cover, the pause before a bound, the
sprint without shooting, prone on arrival, smoke in the direction of movement, doubled
spacing after shelling. Added in milestone 3: morale stances (suppressed low, pinned and
shaken prone, broken running to cover), and the bound that visibly stops when the covering
team stops firing.

## Debug

The Zeus Diagnose report and the RPT show state changes with reasons (`MORALE`, `COHESION`,
`BOUND ... waits`, `UNIT ... refuses`).

## Acceptance

Covered by `tests/morale.Stratis` (the lines and stances are the read-out of that test) and
by milestone 4's suppress-and-flank test (test 1 of the brief).
