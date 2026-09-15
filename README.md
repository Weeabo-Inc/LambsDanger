# HOSTIS

**HOSTIS is a modified version of [LAMBS Danger.fsm](https://github.com/nk3nny/LambsDanger)**
by nkenny and the LAMBS contributors, distributed under the same GPLv2 with the two upstream
amendments (see [LICENSE](LICENSE)). It is a hard fork, not a patch set: it re-architects the
mod around one principle, *Zeus holds the reins, the AI operates*, and one constraint, *the AI
is never friendly and never commandable by players*.

What is different is listed in [docs/CHANGES-FROM-UPSTREAM.md](docs/CHANGES-FROM-UPSTREAM.md).
The design, the research behind it, the function-by-function map of upstream and the
architecture decision records are in [docs/](docs/README.md). The upstream waypoint, module
and script surface (`lambs_wp_fnc_task*`, the Zeus modules, the ZEN actions, the CBA
settings) keeps working; see [ADR-0002](docs/adr/0002-fork-identity-and-addon-naming.md).

## Requirements

- Arma 3 and [CBA_A3](https://github.com/CBATeam/CBA_A3).
- Optional: [Zeus Enhanced](https://github.com/zen-mod/ZEN) for the context-menu actions
  and waypoint types, [ACE3](https://github.com/acemod/ACE3) (medical states and the
  headless module are honoured).
- Not compatible with any mod that gives the AI knowledge the engine did not (spotting
  scripts, `reveal` loops): the fairness contract in [docs/FAIRNESS.md](docs/FAIRNESS.md)
  is the reason the AI feels fair.

## Install

Build with [HEMTT](https://hemtt.dev) (`hemtt release`) or take the release zip; load
`@hostis` on the server, every headless client and every player. Keys are in `keys/`.
CBA settings are under **HOSTIS**; the upstream LAMBS settings keep their names.

## Layers

| Layer | Addon | Does | Note |
|---|---|---|---|
| 4 Zeus | `hostis_zeus` | intents, Director dials, area of operations, pause, overlay | [zeus.md](docs/systems/zeus.md) |
| 3 Director | `hostis_director` | reserves, reinforcement, counterattack, fire missions, counter-battery, pacing, adaptation | [director.md](docs/systems/director.md) |
| 2 Squad | `hostis_squad`, `lambs_danger` commander | planned tactics with a lifecycle | [tactics.md](docs/systems/tactics.md) |
| 1 Agent | `hostis_agent`, `lambs_danger` soldier machine | positions, morale, cohesion, barks | [morale.md](docs/systems/morale.md), [positions.md](docs/systems/positions.md) |
| 0 Knowledge | `hostis_core` | the group's picture: contacts with error, reports, hearing | [knowledge.md](docs/systems/knowledge.md) |
| compat | `lambs_main`, `lambs_danger`, `lambs_wp` | the upstream surface, kept working | [UPSTREAM-MAP.md](docs/UPSTREAM-MAP.md) |

## Zeus quick start

1. Place OPFOR (or any side no player is on) groups as usual, by hand or with the
   upstream waypoint types. They fight on their own from the first contact.
2. **HOSTIS: Intent** module (or the ZEN action, or a Hold / Defend / Attack / Reserve
   waypoint) on a group: what it is for, where, how far, how careful.
3. **HOSTIS: Director** module: the throttle, the two budgets, the area of operations,
   pause. **Release reserves here** and **Fire mission here** ask the Director on an area.
4. **HOSTIS: Overlay** to watch what every group believes and is doing; **Diagnose** on a
   group for the full reasoning, the Director's log and the machine's performance.

## Tests and tuning

`tests/` holds one mission per system with numbered checks against its design note; the
RPT lines are prefixed `HOSTIS TEST`. `tests/load.Stratis` is the two-hundred-AI rig;
`hostis_core_debugPerformance` writes `HOSTIS PERF` slices from every machine
([performance.md](docs/systems/performance.md)).

The upstream README follows.

---

# LAMBS Danger FSM
<p align="center">
    <a href="https://github.com/nk3nny/LambsDanger/releases/latest">
        <img src="https://img.shields.io/badge/Version-2.6.2-blue.svg?style=flat-square" alt="Lambs Danger Version">
    </a>
    <a href="https://github.com/nk3nny/LambsDanger/issues">
        <img src="https://img.shields.io/github/issues-raw/nk3nny/LambsDanger.svg?style=flat-square&label=Issues" alt="Lambs Danger Issues">
    </a>
    <a href="https://github.com/nk3nny/LambsDanger/releases">
        <img src="https://img.shields.io/github/downloads/nk3nny/LambsDanger/total.svg?style=flat-square&label=Downloads" alt="Lambs Danger Downloads">
    </a>
    <a href="https://forums.bohemia.net/forums/topic/225402-lambs-improved-dangerfsm/">
        <img src="https://img.shields.io/badge/BIF-Thread-lightgrey.svg?style=flat-square" alt="BIF Thread">
    </a>
    <a href="https://discord.gg/NFFApYb">
        <img src="https://img.shields.io/discord/681656029758488619?color=%237289da&label=Discord&logo=discord&style=flat-square" alt="Lambs Danger Discord">
    </a>
    <a href="https://github.com/nk3nny/LambsDanger/actions?query=workflow%3AArma">
        <img src="https://img.shields.io/github/actions/workflow/status/nk3nny/LambsDanger/main.yml?branch=master&logo=github&style=flat-square" alt="Lambs Danger Build Status">
    </a>
</p>

This github contains the source code related to the LAMBS Danger FSM mod for Arma3. 

The project is open source. It was initially developed as an internal mod for use by the Norwegian gaming community nopryl.no. The mod is now distributed on [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=1858075458) and GitHub. You are permitted to package and repackage this mod to fit your own needs. 

The stated goal of the mod is: 
1. Make buildings part of the AI tactical landscape
2. Improve AI feedback by creating clearly distinct AI states
3. Seamless integration with vanilla, ACE3 and modded assets

The mod requires: [Community Base Addons](https://github.com/CBATeam/CBA_A3)

Check the [Wiki](https://github.com/nk3nny/LambsDanger/wiki) for additional information. Have fun!

Ken, 
01.10.19

-- 

LAMBS Danger fsm is licensed under the GNU General Public License ([GPLv2](https://github.com/nk3nny/LambsDanger/blob/master/LICENSE)) with two amendments listed in the documentation. 
