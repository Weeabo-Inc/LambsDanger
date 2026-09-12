# ADR-0003: A group-owned contact store replaces reliance on `knowsAbout`

Status: Accepted
Date: 2026-09-12
Brief reference: §3.1 Knowledge model, §3.2 Perception honesty contract
Research reference: C-01, C-02, C-03, C-28, C-34, C-56

## Context

Upstream decides from engine knowledge directly: `targets`, `nearTargets`, `knowsAbout`,
`getHideFrom`, and `reveal` to share. Engine knowledge is honest but has three problems for
us. It decays to nothing after roughly two minutes, so a squad forgets a machine gun it took
casualties from. It is instantaneous and lossless inside a group and, through
`doShareInformation`, nearly so between groups, so killing the leader or the radio changes
nothing. And it carries no *source*, so the AI cannot tell "I saw him" from "someone told me
something was over there", which is exactly the difference between a target and an area.

This fork already added a per-group `picture` (`fnc_pictureGet`, `pictureUpdate`,
`pictureContacts`) storing `[enemy, hideFrom, time, knowsAbout]` with a 90 s age limit and a
derived threat centre. That is a start, not the model.

## Decision

A **contact record** per group, owned by layer 0:

```
[ id, position, error, confidence, firstSeen, lastUpdated, source,
  strength, composition, heading, activity, lastKnown ]
```

- `source` is one of `seen`, `heard`, `shotAt`, `reported`, `suspected`. `seen` and `shotAt`
  records may carry the engine object and are the only records an Agent may fire at (R1).
  `heard`, `reported` and `suspected` carry a position and an error radius only.
- `confidence` decays with time and with distance from the last observer. It decays to a
  floor, never to zero; a record at the floor is *last known* and drives search.
- `error` grows with age and with the report chain (a report of a report is worse).
- Records enter only through `contactReport` calls: from a unit's own sensors (the danger
  event, `targets`, `nearTargets` of that unit), or from another group's report over the
  comms net, which adds delay and error and may be lost.
- Reports between groups travel over a modelled net: a group without a leader or a radio
  reports late or not at all; a group out of Director range reports nothing upward.
- The Director's board is built from group reports only. It may consult real player
  positions for pacing (ADR-0004) but never writes them into any group's store.

`knowsAbout` and `getHideFrom` remain inputs (they are the engine's honest sensor state)
and are read in exactly one place, the layer 0 sensor sweep. No layer above 0 calls them.

## Consequences

- Search behaviour has something to search *for*: the last-known record with its error
  radius.
- Acceptance test 3 (kill the leader first) becomes measurable: report latency and Director
  picture age are numbers in the overlay.
- `doShareInformation` changes from `reveal` to a `contactReport` into the receiver's store
  (with `reveal` capped at accuracy 1 so the engine also treats it as a suspicion).
- Memory cost is bounded: records per group are capped and merged by proximity.

## What this overrides in upstream, and why

Upstream's `fnc_doShareInformation` (reveal to friendlies by distance) and the direct reads
of `targets`/`knowsAbout` in `fnc_tacticsAssess`, `fnc_brainEngage` and the `taskX` hunts.
Reason: they make information free and instant, which is the single biggest reason upstream
AI can feel omniscient.
