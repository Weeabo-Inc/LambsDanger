# ADR-0002: Fork identity is HOSTIS; the `lambs` script prefix stays as the compatibility surface

Status: Accepted
Date: 2026-09-12
Brief reference: §0 Your role (working name, addon prefix), §4 Compatibility, §6 Fork properly
Research reference: C-07

## Context

The brief names the fork HOSTIS with addons `hostis_main`, `hostis_core`, `hostis_agent`,
`hostis_squad`, `hostis_director`, `hostis_zeus`, `hostis_compat`, and in the same breath
requires the upstream waypoint and module surface to keep working "extended rather than
broken, so existing missions do not die". It also says the name may change and must not
block work.

The upstream surface that existing missions depend on is concrete: 220 functions in the
`lambs_main_`, `lambs_danger_`, `lambs_wp_` namespaces (at least 13 of them public
`taskX` functions called from mission scripts), the `lambs_wp_moduleTask*` Zeus module
classnames, the `lambs_danger_module*` module classnames, the waypoint type classnames in
`CfgWaypoints`, the `lambs_*` CBA setting names that servers carry in their
`cba_settings.sqf`, and group and unit variables such as `lambs_danger_disableGroupAI` that
mission makers set in init fields. A blanket rename to `hostis_` breaks all of it at once,
and re-creating every one of those as an alias in a `hostis_compat` addon doubles the
surface for no behavioural gain. It also produces a single unreviewable mechanical commit.

## Decision

1. **Mod identity is HOSTIS.** `mod.cpp` (name, folder `@hostis`), the HEMTT project name,
   the release folder, the signing authority (`hostis`, so our keys never collide with
   upstream's), the README and the docs all say HOSTIS and state prominently that it is a
   modified LAMBS Danger.fsm.
2. **The three upstream addons keep their `lambs` prefix** (`lambs_main`, `lambs_danger`,
   `lambs_wp`) and keep their public function and classname surface. They *are* the
   compatibility layer the brief calls `hostis_compat`; there is no separate alias addon.
3. **New layers are new addons with the `hostis` prefix**: `hostis_core` (knowledge),
   `hostis_agent`, `hostis_squad`, `hostis_director`, `hostis_zeus`. They `requiredAddons`
   the `lambs_*` addons. As behaviour migrates out of `lambs_danger` into a layer addon, the
   old function is kept as a thin forwarder for one release, then deleted, and the deletion
   is listed in `docs/CHANGES-FROM-UPSTREAM.md`.
4. HEMTT's project `prefix` is `hostis`, so every PBO, the bikey and the release zip are
   named `hostis_*`. The six compatibility addons keep their upstream `$PBOPREFIX$`
   (`z\lambs\addons\main` and so on) so that `\z\lambs\addons\...` paths in configs,
   stringtables and the danger FSM keep resolving. HEMTT warns `INVALID-PBOPREFIX` for
   each of them on every build; the warning is expected and documented in
   `.hemtt/project.toml`. (HEMTT's documented `ignore_pboprefix` addon option is rejected
   by 1.20.1, the version installed here, so it is not used.) New addons use
   `MAINPREFIX z`, `PREFIX hostis` from `addons/core/script_mod.hpp` and a matching
   `$PBOPREFIX$`. A `hostis_*` addon calls into the compatibility addons with the
   `LFUNC`, `LGVAR` and `LAMBS_STRING` macros from `addons/core/script_macros.hpp`,
   because `EFUNC` and `EGVAR` expand with the `hostis` prefix. Two script prefixes in
   one project is supported by HEMTT and by CBA; verified with `hemtt build` in
   milestone 1.
5. CBA setting names of new settings use `hostis_`. Existing `lambs_` settings are not
   renamed.

## Consequences

- Existing missions, Zeus module placements and server setting files keep working with no
  change. This is the whole point.
- A reader sees two prefixes in the tree. The rule is simple and documented: `lambs_` is
  the compatibility surface, `hostis_` is the architecture.
- If the owner picks a different name, only the `hostis` token in new addons and in the mod
  identity changes; nothing in the compatibility surface does.
- `tools/nodejs_tools/prepchecker.js` and the SQF validator accept both prefixes; checked in
  milestone 1 with the empty `hostis_core` scaffold (`addons/core`).

## What this overrides in upstream, and why

Nothing in code. It overrides the brief's literal addon list in one respect: there is no
`hostis_compat` and no `hostis_main`; their jobs are done by the untouched `lambs_main`,
`lambs_danger` and `lambs_wp`. The brief allowed the rename to slip; this record says why it
slips permanently for the compatibility surface.

## Rejected alternative: full rename with an alias addon

Rejected because the alias addon would have to re-declare 220 function names, every module
and waypoint classname, and every setting, and keep them in step forever; it would also
force every existing `lambs_*` group variable to be mirrored on read and write. The cost is
permanent and the benefit is cosmetic.
