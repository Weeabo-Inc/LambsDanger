# The Zeus layer (layer 4, `hostis_zeus`)

Brief §4. ADR-0013.

## Purpose

Give a Zeus the reins without a remote control: what each group is for, how hard the
Director presses, where it may act, a brake, and a view of what every group believes.

## One-sentence explanation

"Zeus told them what to do, not how."

## Inputs

Curator actions: modules dropped in the Zeus interface, Zeus Enhanced context actions,
Zeus Enhanced and Eden waypoints, and the script API. Nothing here reads player state.

## Decisions

The layer makes none. It translates:

| Zeus does | Becomes |
|---|---|
| Intent module or action on a group | `lambs_danger_fnc_intentSet` on the group owner, plus the Attack Position or Defend task, or a task reset |
| HOSTIS Hold / Defend / Attack / Reserve waypoint | the same, at the waypoint position |
| Director module or action | `hostis_director_throttle` setting, the side's budgets, the side's area of operations, the squad pause |
| Release reserves here | `hostis_director_fnc_release` with force, on an area |
| Fire mission here | `hostis_director_fnc_fireRequest` on an area with the chosen error |
| Pause / resume | `hostis_squad_fnc_pause` |
| Overlay | a snapshot request every `overlayInterval` seconds, drawn on the curator's client |

Intents:

| Intent | The group |
|---|---|
| free | reacts to contact, then goes home |
| hold | stays on the spot and fights from it |
| defend | stays on the spot and counterattacks inside the radius |
| attack | takes the position with fire and movement, sweeps it, then stands down |
| reserve | waits for the Director to release it |

The area of operations: a centre and radius per side. While set, `spendAllowed` refuses
any Director spending on a position outside it: no reinforcement, no counterattack, no
fire mission. Reserves outside it remain in the pool. Radius 0 clears it.

## Outputs

Group intents, Director state, the squad pause flag, curator feedback lines, the overlay
labels. Every Zeus action with the debug setting on goes to the RPT as `ZEUS ...`.

## Settings (`hostis_zeus_*`)

| Setting | Default | Meaning |
|---|---|---|
| `overlayRange` | 1500 m | groups farther than this from the Zeus camera are not labelled |
| `overlayInterval` | 3 s | how often the overlay asks the server |
| `debug` | off | log every intent, dial and release |

## Debug overlay

The overlay itself: `<group> [<alive>] <intent> | <cohesion>[ PAUSED] | <tactic> <age> | <n> contacts`
above each leader, coloured routine grey, alert yellow, engaged orange, decisive red, with
a line to the group's threat centre. Toggled by the Overlay module, the ZEN action, or
`call hostis_zeus_fnc_overlay`.

## API

| Function | Use |
|---|---|
| `hostis_zeus_fnc_intent [group, mode, pos, radius, posture, cap, curatorOwner]` | the one door for intents |
| `hostis_zeus_fnc_director [side, throttle, reinforcements, fireMissions, aoPos, aoRadius, paused, curatorOwner]` | the dials, server only |
| `hostis_director_fnc_area [side, pos, radius]` | the area of operations alone |
| `hostis_zeus_fnc_overlay` | toggle the overlay on this client |
| `hostis_squad_fnc_pause [paused]` | the brake |

Events (server): `hostis_zeus_director` with the director arguments,
`hostis_director_setArea [side, pos, radius]`, `hostis_director_release [side, pos, radius, force]`.

## Acceptance test (`tests/zeus.Stratis`)

The mission makes the player a Zeus and places three OPFOR squads.

1. Drop Intent on a squad, choose Hold. Its overlay label reads `hold` within 3 s and the
   squad stays put when you fire near it. Choose Attack on the ground 300 m from another
   squad: the label reads `attack`, the squad moves on it and the RPT shows `taskAttack`.
2. Place a HOSTIS Defend waypoint with ZEN on the third squad: the label reads `defend`
   and `INTENT ... defend` appears in the RPT.
3. Drop Director with throttle 0 and a 500 m area: `Director ... throttle 0` feedback,
   then Release reserves here 800 m away: the Director's log says the area refused it, and
   with throttle back to 1 and the area cleared a reserve is released.
4. Pause the AI while a squad is mid-tactic: `TACTIC ... paused` in the RPT within one
   second and no man remains in a non-idle machine state; Resume and the squad plans again.
5. Overlay on: labels appear on all three squads and disappear with Overlay off.

## Performance budget

Events only. The overlay: one pass over the commander's groups per curator every 3 s,
at most forty rows, a few `drawIcon3D` per frame on the curator's client.

## Fairness review

Nothing here reveals, targets or fires. Every Zeus action is an area, an intent or a
dial. The overlay shows the picture, not the world.
