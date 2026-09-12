# ADR-0006: HOSTIS never runs a player's side

Status: Accepted
Date: 2026-09-12
Brief reference: §0 second principle, §4 out of scope
Research reference: none; this is the brief's rule

## Context

Upstream must drive the player's own squad, friendly AI and civilians, and carries settings
and code paths for that: `disableAIPlayerGroup`, `disableAIPlayerGroupReaction`, the
share-information handler on players, callouts and gestures aimed at a player leader, and
the civilian handling in the danger brains. Every one of those is a compromise this fork
does not need, and some are dangerous here (a HOSTIS group must never obey a player).

## Decision

- HOSTIS attaches only to groups whose side is **hostile to every side that contains a
  player** at init time and at each re-evaluation (a side that gains a player is dropped).
- Exclusion API, checked in that order, each an opt-out:
  1. Unit variable `hostis_exclude` (true).
  2. Group variable `hostis_exclude` (true).
  3. Faction in the CBA setting `hostis_core_excludedFactions`.
  4. Side in the CBA setting `hostis_core_excludedSides`.
  5. Any group containing a player, `playableUnits` member or `switchableUnits` member.
  6. Civilian side, always.
- There is no opt-in for a player's side. No setting enables it.
- Upstream player-facing code (`disableAIPlayerGroup*`, callouts to a player leader,
  civilian brains) is deleted, not disabled, in milestone 2. The upstream setting names are
  kept as no-ops for one release so `cba_settings.sqf` files do not error.

## Consequences

- A mission with three AI sides where players are on one side gets HOSTIS on the other two,
  including when those two fight each other; that is intended.
- High command, `lambs_danger` player-group reactions and the share-information handler on
  players are gone. Missions that relied on LAMBS for *friendly* AI need upstream LAMBS
  alongside, which is a supported configuration: HOSTIS ignores what it does not own.
  (Verified in milestone 8: both mods loaded, no double control.)

## What this overrides in upstream, and why

The player-group and civilian support. Reason: the brief.
