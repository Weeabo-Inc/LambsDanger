# HOSTIS research notes

What we studied before designing, what each source actually says, and the one-line
behavioural consequence we draw from it. Consequences are numbered `C-nn` so that
system notes and ADRs can cite them.

Verification status of every claim is marked:

- **[P]** read in the primary source during this research pass (paper, slides, manual text).
- **[S]** read in a secondary source (article, wiki page, published summary) that quotes or
  describes the primary; the primary was not fetched.
- **[U]** not verified in this pass. Treated as a working assumption, not a fact.

Where a source contradicts the brief, the brief wins and the ADR says why.

---

## Part A. The engine we are fighting in

### A.1 Arma 3 target knowledge (`knowsAbout`, `reveal`, `targets`, `nearTargets`)

- `knowsAbout` returns a number in the range 0 to 4 describing how well a unit's group
  knows a target; a target out of sight for more than about 120 seconds decays back to 0. **[S]**
  (Bohemia Interactive community wiki, `knowsAbout`; the wiki blocked direct fetch during this
  pass, the figures come from search excerpts of that page.)
- Knowledge is held at group level: any unit's sighting is the whole group's sighting. **[S]**
- `reveal` with an accuracy argument lets script raise that value directly, which is the
  engine's built-in cheat path. **[S]**
- `getHideFrom` returns the position at which the unit believes the target is, which
  diverges from the true position as knowledge decays. **[S]**
- AI sub-skills `spotDistance` and `spotTime` govern acquisition range and delay;
  `aimingAccuracy`, `aimingShake`, `aimingSpeed` govern shooting; `courage` and `commanding`
  govern fleeing and order latency. **[S]** (BI wiki, *AI Sub-skills*.)

Consequences:

- **C-01** The engine's own sensor model is the only legitimate source of a *target*. Our
  knowledge layer wraps it and lags it; it never bypasses it. `reveal` above accuracy 1 and
  `setSkill` for tactical compensation are banned by the fairness contract.
- **C-02** `getHideFrom` and `knowsAbout` are honest inputs: they already model decay and
  error. The group contact store consumes them as *evidence*, not as truth.
- **C-03** Engine decay to zero after roughly two minutes is wrong for us: a squad does not
  forget that a machine gun was in that treeline. Our store decays to *last known*, never to
  nothing, and search behaviour is driven from last known.

### A.2 `danger.fsm` and the danger causes

- Every AI unit runs the engine `danger.fsm`; the FSM receives `_dangerCause` (enemy
  detected, fire, hit, enemy near, explosion, dead body, scream, can fire, and so on),
  `_dangerPos`, `_dangerUntil` and `_dangerCausedBy`. LAMBS replaces this FSM with its own
  and dispatches to script from it. **[S]** (BI wiki, *FSM Danger*; confirmed in upstream
  `addons/danger/dangerFSM.fsm` and `fnc_brain.sqf` in this tree.)

Consequences:

- **C-04** The danger FSM is our layer-1 *event source*, not our layer-1 brain. Events go into
  the per-soldier machine; the machine decides. Nothing else in the mod may poll for danger.

### A.3 The scheduler and CBA per-frame handlers

- Scheduled scripts (`spawn`, `execVM`) share a 3 ms budget per frame; when it is used up the
  running script is suspended mid-execution and resumes some frames later, so `sleep`-driven
  loops fall behind unpredictably under load. **[P]** (ACE3 developer wiki, *Arma 3 Scheduler
  and our Practices*.)
- `CBA_fnc_addPerFrameHandler` runs code unscheduled at most once per frame or every *n*
  seconds; `CBA_fnc_waitAndExecute` and `CBA_fnc_waitUntilAndExecute` give unscheduled
  delays. **[P]** (CBA_A3 wiki, *Per Frame Handlers*.)

Consequences:

- **C-05** No layer may use `spawn` with `sleep` for a decision loop. Every cadence in the
  five-layer table is a CBA PFH with an explicit per-tick budget, time-sliced over groups.
- **C-06** Anything that runs per unit runs on an event or on the cheap pass of a budgeted
  cycle; the expensive pass (position queries, ray casts) is capped per tick.

### A.4 LAMBS task locality

- The upstream wiki states verbatim: "TaskX Functions, Waypoints, and Modules must be
  executed where the AI is local, and the AI *must* stay on that client. Groups that use
  dynamic load balancing for headless clients, should switch that off for units running
  taskX modules." **[P]** (nk3nny/LambsDanger wiki, *waypoints*.)

Consequences:

- **C-07** Group ownership is pinned for the life of a task or tactic. The Director runs on
  the server and talks to groups by CBA events targeted at the group's owner; the Agent and
  Squad layers run where the group is local. Load balancers must not move a group that is
  registered with the Director. The fork ships a setting and a documented API for this.

---

## Part B. Game AI studied

### B.1 F.E.A.R. — Orkin, *Three States and a Plan*, GDC 2006 **[P]**

What the paper says:

- The character FSM has three states (Goto, Animate, UseSmartObject); everything an agent
  does is "move around and play animations". Planning (GOAP, an A* search over actions with
  costs, procedural preconditions and effects) decides *when* to switch and with what
  parameters.
- A global coordinator "periodically re-clusters A.I. into squads based on proximity". Each
  squad runs zero or one squad behaviour at a time.
- The four simple squad behaviours: **Get-to-Cover** (everyone not in valid cover moves to
  cover while one member suppresses), **Advance-Cover** (move to valid cover closer to the
  threat while one suppresses), **Orderly-Advance** (single file, each covers the one ahead,
  last man faces rear), **Search** (pairs covering each other sweep rooms).
- Simple squad behaviours run in four steps: find agents to fill required slots, send orders,
  monitor each tick, succeed or fail. Agents may refuse an order because a higher-priority
  goal (fleeing a grenade) wins. The squad behaviour then fails cleanly.
- "We actually did not have any complex squad behaviors at all in F.E.A.R." Flanking and
  pincers were side effects of moving to the nearest valid cover around obstacles.
- The squad layer does not analyse the map for cover; each agent's own sensors keep a list
  of valid cover nearby and the squad only picks among what agents already know, making sure
  two agents are not sent to the same node.
- Dialogue: "Vocalizing intentions can sometimes even be enough, without any actual
  implementation of the associated squad behavior." Lines are chosen *after* the squad
  behaviour has decided. Prefer a two-party exchange over an announcement. Use dialogue to
  explain a *lack* of action ("I've got nowhere to go!").

Consequences:

- **C-08** Squad tactics are slot-filling behaviours with a monitor and a clean fail path.
  Slots are filled from units that are *able* right now; a unit may veto (survive beats
  advance) and the tactic fails rather than dragging a panicking man forward.
- **C-09** The squad layer never computes cover; it asks the position system on behalf of
  members and reserves the result so two men do not take one wall.
- **C-10** Flanks emerge from "closest good position that is not the one you are in" plus
  obstacles. The explicit suppress-and-flank tactic exists because the brief demands it be
  *visibly* true, but it is built on the same primitive, not on a scripted arc.
- **C-11** Barks are emitted from the decision, after it is made, as an exchange between two
  men where possible; there is a bark for "no better position" so stillness reads as a choice.

### B.2 Alien: Isolation — Director and Drone **[S]**

(Thompson, *The Perfect Organism: The AI of Alien: Isolation*, Game Developer, and the
follow-up *Revisiting the AI of Alien: Isolation*.)

What the sources say:

- Two systems: a **Director** that always knows where the player is and never passes that to
  the creature, and the **Alien** that must find the player with its own sensors. The
  Director "periodically directs the alien toward the player's vicinity".
- The Director manages a **menace gauge** that rises with proximity, line of sight and
  time close by; when it peaks the Director sends the creature away to give the player room.
- A behaviour tree of over 100 nodes, roughly 30 at the top level. Parts are **locked** at
  start and unlock from *player* actions (repeated locker use, flamethrower use), never from
  the player's deaths, so the "learning" is explicable.
- A job system with three priority levels: finish current task first, blend into the new
  task, or interrupt everything now.

Consequences:

- **C-12** The Director may know player positions for pacing only. It hands the Squad layer
  an *area of interest* with a radius, never a position, and the Squad layer cannot read the
  Director's map. This is the architectural rule that keeps the mod honest.
- **C-13** Pressure is a gauge, not a constant: the Director scores menace per player
  element and deliberately backs off (no reinforcement, no fire mission) when it peaks.
- **C-14** Adaptation is a small set of locked behaviours with plain-language unlock
  conditions driven by what players *did* (route used twice, mortars from the same grid),
  never by what killed them.
- **C-15** Every order carries a priority class: finish first, blend, or interrupt now. Zeus
  pause and Director abort are "interrupt now" and must leave the group in a valid state.

### B.3 Left 4 Dead — Booth, *The AI Systems of Left 4 Dead*, GDC 2009 **[P]**

What the slides say:

- Survivor **intensity** rises when injured (proportional to damage), incapacitated, pulled off
  a ledge, or when an infected dies nearby (inversely proportional to distance); it decays
  toward zero over time and does *not* decay while infected are actively engaging.
- Pacing states: **Build Up** (full threat population until intensity crosses the peak
  threshold), **Sustain Peak** (3 to 5 s after the peak), **Peak Fade** (minimal population;
  wait for a natural break before the relax period may start), **Relax** (minimal population
  for 30 to 45 s or until the team has moved on), then Build Up again.
- "Algorithm adjusts pacing, not difficulty. Amplitude (difficulty) is not changed,
  frequency (pacing) is."
- Population is "structured unpredictability": several randomised population functions
  superposed (mob every 90 to 180 s, spawned behind the team 75% of the time, outside the
  potentially visible set).
- Bot fairness: "Imperfect knowledge – simulated senses. Simulated aiming. Reaction times."
- Every action transition carries a reason string, "invaluable for realtime debug output".

Consequences:

- **C-16** The Director keeps an intensity estimate per player element with a *frozen* decay
  while they are in contact, and a four-state pacing machine with a mandatory lull. Constant
  pressure is a bug, not a difficulty setting.
- **C-17** Pacing changes *when* the Director spends (reinforcement, fire mission), never
  how well soldiers shoot.
- **C-18** Reinforcements arrive from outside the players' potentially visible area and
  usually from behind their axis of advance, on randomised intervals bounded by Zeus.
- **C-19** Every state transition in every layer records a one-line reason string; the
  curator overlay and the log show it.

### B.4 Killzone — Beij and Straatman, *Killzone's AI: Dynamic Procedural Tactics*, GDCE 2005 **[P]**; Straatman, van der Sterren, Beij, *Dynamic Tactical Position Evaluation*, AI Game Programming Wisdom 3 **[S]**

What the slides say:

- "Picking a good position is half the battle in 'fire & maneuver' combat." Positions are
  scored by a **weighted sum** of factors: outside danger zone, wall hugging, nearby cover,
  partial cover, proximity, line of fire, preferred range.
- Worked example weights for an attack position: proximity 20; line of fire to the primary
  threat 40 if partial cover, 20 otherwise; cover from secondary threats 20; inside the
  preferred fighting range 10. Sum the annotations, take the best.
- The function is configured by **personality** (which factors matter), **action** (what kind
  of position), the **current situation** (where the threats are) and the **squad**
  (additional constraints).
- **Tactical path-finding** adds A* link cost for crossing friendly lines of fire and for
  being under fire from known threats, so the route to a good position is also covered.
- **Suppression fire** is aimed at the threat's likely attack positions evaluated *from the
  threat's point of view*, not at the wall the threat hides behind and not at places the
  threat cannot reach. Positions scoring 40 or more become suppress targets, merged when they
  overlap in yaw and pitch.
- Hundreds of line-of-fire checks per decision are made affordable by a precomputed polar
  table per waypoint: 4000 waypoints in 64 KB, "pessimistic about cover", "inaccurate, but
  consistent". Up to 14 AI fought simultaneously on PS2.

Consequences:

- **C-20** Position selection is a weighted-sum score over sampled candidates with weights
  chosen per purpose (fire position, cover, overwatch, assault, rally, ambush). This is the
  core primitive; every movement order ends in a query to it.
- **C-21** Routes are scored too: a bound whose route crosses the enemy's line of fire or a
  friendly line of fire is rejected or penalised, so men move behind cover, not across it.
- **C-22** Suppression targets are *positions the enemy could fire from*, evaluated from the
  enemy's side, merged into a few aim points, and fired at by volume. Never "shoot at the
  wall", never "shoot at his exact body through it".
- **C-23** Line-of-fire checks are cached per area and per stance and accepted as pessimistic
  and slightly wrong; consistency matters more than accuracy.

### B.5 Tactical position selection as a query language — Jack, *Tactical Position Selection: An Architecture and Query Language*, Game AI Pro **[P]**

What the chapter says:

- A query is **Generation** (where candidates come from: hidespots from target around the
  agent within a radius, a grid, concentric circles, cover rails), **Conditions** (hard
  filters) and **Weights** (scored, normalised to 0..1 by clamping distances to known limits).
- Prefer conditions over weights; keep one or two weights per query; write fallback options
  (hard cover only, then soft cover only) instead of tuning a tradeoff.
- **Directness** = (distance agent→goal − distance point→goal) / distance agent→point.
  Condition `min_directness 0.5` gives progress; a band around zero gives flanking; a
  minimum directness with a negative directness weight gives zigzag cover-to-cover approach.
- `canReachBefore`: discard any point closer to the enemy than to us. Mark claimed points so
  two agents never pick the same one.
- Once moving, validate the chosen point with a cheap single-point query (conditions only)
  rather than re-running the full query; re-plan only when it fails or the behaviour changes.
- A scheduler amortises queries over frames; generation and filtering are interleaved.

Consequences:

- **C-24** Our position system is a query object: purpose, centre, radius, threat axes,
  conditions, weights, count. Fallback options are explicit in the query, not tuned in.
- **C-25** Bounds are a sequence of queries with a directness condition; flanks use the
  zero-directness band; approach under fire uses the zigzag form.
- **C-26** A man already moving re-validates his destination cheaply; he changes his mind
  only when the destination fails a condition, so movement has inertia and reads as decided.
- **C-27** Group reservations on positions are mandatory (already implemented as
  `positionReserve`/`positionRelease` in this tree).

### B.6 Killzone 3 multiplayer bots — Straatman, Verweij, Champandard, Morcus, Kuijpers, *Hierarchical AI for Multiplayer Bots in Killzone 3*, Game AI Pro **[P]**

What the chapter says:

- Three layers: **strategy** (a commander per faction), **squad**, **individual**. "The
  communication between the layers consists of orders moving downward and information
  moving up."
- Commander orders are coarse: Attack area, Defend area, Escort, Advance to regroup point.
  Squads report completion or "imminent failure—for instance, when the squad has been
  decimated during an attack". Bots report order completion and observed threats.
- The squad "bases its world state on messages received from its members", not on
  perception. The squad does not act directly; its primitive tasks send orders to members'
  command queues. New orders overwrite unless part of a sequence.
- Squads reason on a **strategic graph** (clustered areas) with an **influence map**
  (friendly and enemy presence, recent deaths, smoothed in space and time); the squad path is
  a corridor of areas and members are restricted to it, which leaves them freedom inside it
  and shrinks their search space.
- Commander assignment: objectives carry a weight and an optimal number of bots; compute the
  ideal distribution, create or remove squads, keep squads on prior objectives where possible,
  otherwise assign by distance, shed excess bots, assign free bots to the closest needy squad.
- Regroup markers are chosen near the objective using influence values, with a penalty for
  areas already chosen by other friendly squads "which provides variation for repeated
  attacks and spreads out simultaneous attacks".

Consequences:

- **C-28** The Squad layer's picture is built from member reports, never by reading member
  sensors directly; the Director's picture is built from squad reports. Killing the man who
  reports degrades the picture above him.
- **C-29** Director orders are areas and postures with a weight and an ideal strength;
  assignment is sticky (keep a group on its objective if it still fits) and by distance
  otherwise.
- **C-30** A squad order gives a *corridor* and an objective area, leaving the route and the
  positions to the squad and the men.
- **C-31** The Director keeps an influence map of recent contact and recent deaths per side
  and uses it to pick reserve routes and rally points that friendly groups have not already
  chosen, so counterattacks come from a different direction each time.

### B.7 Halo 2 — Isla, *Handling Complexity in the Halo 2 AI*, GDC 2005 **[P, via the published proceeding]**

What the proceeding says:

- A behaviour DAG of about 50 behaviours with prioritised-list selection ("the first one
  that can run, does"), because analogue activation values did not scale.
- **Impulses** and **stimulus behaviours** are event-driven entries added to a point in the
  tree so an event (an ally dying) is decided in context of higher-priority behaviours
  rather than in an isolated handler.
- Memory is a set of **props**: beliefs about targets "gated by the actor's perception
  filter (an actor should not be able to see through walls)", so the AI can be wrong and
  therefore surprised.
- Designer **orders** define firing positions and areas; **styles** are behaviour
  whitelists ("a behavior cannot be considered unless it is explicitly allowed by the order's
  style"): a defensive style disables charging, an aggressive style disables
  self-preservation.

Consequences:

- **C-32** The per-soldier machine is a prioritised list, not a scored blend; the highest
  applicable state wins and the order is documented.
- **C-33** Zeus posture (cautious, balanced, aggressive) and ROE are implemented as behaviour
  *whitelists* applied at the Squad and Agent layers, not as number tweaks.
- **C-34** Contact records are beliefs with a source and an error; a unit's belief may be
  wrong and the mod must be able to show that it is wrong.

### B.8 WARNO and Steel Division — Eugen's cohesion model **[S]**

- WARNO replaced a single suppression bar with **Cohesion** in four states, High, Normal,
  Poor, Low, driven by losses and by time in combat; each state changes speed, reload time
  and aim time; at Low the unit takes rout tests and a routed unit refuses orders and moves
  to where it feels safest. **[S]** (WARNO community guides and Eugen's announcement
  summaries.) Unit availability in both games is a limited pool per deck. **[S]**

Consequences:

- **C-35** Per-group cohesion has readable named states and each state changes *what the
  group is allowed to do*, not how accurately it shoots. Broken groups take a rout test each
  tick and move to the safest known position as a body.
- **C-36** Reinforcement is a finite pool set by Zeus; the Director spends against it and
  changes tactics when it is empty.

### B.9 Company of Heroes — suppressed versus pinned **[S]**

- **Suppressed**: seeks cover, stays low, less accurate; **Pinned**: continued suppressive fire,
  cannot move or shoot. The purpose of suppression is "to keep the enemy held in place and
  afraid to peek out of cover, while a few soldiers move around to flank". **[S]** (Company of
  Heroes wiki and Relic community guides.)

Consequences:

- **C-37** Suppressed and pinned are distinct states with distinct tells: suppressed men fire
  blind from cover, pinned men do not fire and do not move laterally without covering fire.

### B.10 S.T.A.L.K.E.R. — A-Life offline simulation **[S]**

- NPCs beyond a switch distance from the player run in an "offline" abstract mode; they are
  simulated as records, not as bodies, and "pop back up" when the player approaches. **[S]**

Consequences:

- **C-38** Groups far from every player run an abstract behaviour (move along the corridor,
  hold, count time) with no position queries and no per-soldier machine; the full stack
  starts when a player element is within the group's engagement horizon.

### B.11 Call of Duty Modern Warfare (2019 onward) **[U]**

- No design source on the enemy AI was found in this pass; the only verified item is the
  *multiplayer* automatic callout system, which is a player feature, not enemy AI. The
  brief's observations (bark density, peek and blind fire, grenades to break a static player,
  legible reposition animations) are taken as play observations, not as documented design.

Consequences:

- **C-39** Treated as design targets from observation: a grenade is the answer to a player
  who has been static under fire for more than a set time; repositioning is preceded by a
  visible pause and a bark.

### B.12 The Last of Us Part II — search and flank **[U]**

- The GDC 2021 talks located are about melee and facial systems. The 2014 talk *The Last of
  Us: Human Enemy AI* covers search behaviour for the first game. Neither was read in this
  pass.

Consequences:

- **C-40** Search is designed from doctrine (sweep likely routes, cover exits, pairs) and from
  the F.E.A.R. Search behaviour, with the TLOU material flagged for a later reading.

---

## Part C. Doctrine studied

Primary US Army text was blocked (armypubs.army.mil refused connections during this pass);
claims are marked [S] where they come from mirrored or summarised doctrine and [P] where a
mirrored manual page was read.

### C.1 Battle drills (ATP 3-21.8 Appendix E, 2016 and 2024 editions) **[S]**

The drill list is verified: 1 React to Direct Fire Contact, 2 Conduct a Platoon/Squad
Assault, 3 Break Contact, 4 React to Ambush, 5 Knock Out a Bunker, 6 Enter and Clear a
Room, 9 React to Indirect Fire. The step sequences below are from summaries and from the
2007 FM 3-21.8 as mirrored, not from the current text.

- React to contact: return fire immediately, seek cover, the leader locates the enemy,
  reports, and decides to assault or suppress and manoeuvre. **[S]**
- Squad attack: a base-of-fire element gains fire superiority; the assault element moves on a
  covered route to the flank; supporting fire shifts, then lifts, as the assault closes;
  consolidate and reorganise on the objective. **[S]**
- Break contact: one element suppresses while the other bounds to the rear; smoke; repeat
  until contact is broken; move to a rally point. **[S]**
- React to ambush: **near** (inside hand-grenade range) the element in the kill zone assaults
  through immediately, the rest suppress; **far** the element in the kill zone returns fire
  and seeks cover, the rest flank. **[S]**
- React to indirect fire: shout "incoming", move out of the impact area on a given direction
  and distance, reform. **[S]**

Consequences:

- **C-41** React-to-contact is measured in seconds: return fire and cover on the first event,
  the leader's decision on the second tick, a report on the third.
- **C-42** The bound in suppress-and-flank continues *only while* the base of fire is
  achieving volume onto the objective; when volume lapses the bound halts in cover.
- **C-43** Supporting fire shifts, then lifts, keyed to the assault element's distance from the
  objective; a base of fire that keeps firing into the objective while friends enter it is a
  bug.
- **C-44** Break contact is bounds to the rear under fire with smoke toward a rally point the
  group chose *before* contact; a group without a rally point picks one on the first contact.
- **C-45** A group caught in a near ambush assaults through; a group in a far ambush goes to
  cover and flanks. The distance threshold is grenade range.
- **C-46** Shelling triggers a move out of the beaten zone on a direction away from the
  enemy's likely observer, then a reform; spacing doubles for a while afterwards (already in
  this tree).

### C.2 Movement techniques (FM 3-21.8, as mirrored) **[P]**

- **Bounding overwatch** is used when contact is expected, "the most secure, but slowest".
  **Successive** bounds: the rear element comes up abreast of the lead, never beyond it;
  easier to control and more secure. **Alternate** bounds: the rear element passes the lead;
  faster.

Consequences:

- **C-47** Movement into contact is successive bounds by default and alternate bounds under
  an aggressive posture; the overwatch element is set before the bounding element moves.

### C.3 Fire and movement versus fire and manoeuvre **[S]**

- Fire and movement is within the element (one part moves while the other fires); fire and
  manoeuvre is between elements (a base of fire fixes while a manoeuvre element flanks).

Consequences:

- **C-48** The Agent layer does fire and movement inside a team (buddy rushes); the Squad layer
  does fire and manoeuvre between teams. The two are different tactics with different tells.

### C.4 Defence (ATP 3-21.8 chapter 5, as mirrored) **[S]**

- Area defence variants: linear obstacle, perimeter, **reverse slope** (most of the force
  masked from enemy direct fire by the crest, the crest controlled by fire).
- An **engagement area** is entered at a prominent **target reference point** all weapons
  can engage; fires are planned through its depth.
- A local **reserve** counterattacks to restore a position.

Consequences:

- **C-49** Defend builds an engagement area on the most likely approach, assigns sectors, keeps
  a depth position and a reserve, and withdraws to depth after a threshold of losses instead
  of dying in place.
- **C-50** Counterattack is a Director tactic with a timer: a reserve retakes a lost position
  within minutes, from a direction the influence map says the attackers did not use.

### C.5 Ambush formations (MCWP 3-11.3 Appendix D; ATP 3-21.8 combat patrols) **[S]**

- **Linear**: assault and support parallel to the kill zone, flanking fire. **L-shaped**: the
  long leg parallel to the kill zone, the short leg at its end at a right angle giving
  enfilade fire. **V**: assault elements on both sides.
- The ambush is initiated by the most casualty-producing weapon; withdrawal is planned.

Consequences:

- **C-51** Hasty ambush lays an L when terrain allows: the machine gun on the short leg firing
  down the long axis, riflemen along the long leg, initiated by the machine gun, with a
  withdrawal route chosen first.

### C.6 Call for fire (ATP 3-09.30 / FM 6-30) **[S]**

- Six elements in three transmissions: observer identification and warning order; target
  location; target description, method of engagement, method of fire and control.
- **Adjust fire** when the target location is questionable; **fire for effect** when the
  observer is certain the first volley will have effect. "Shot" and "splash" calls, time of
  flight, and bracketing corrections (add/drop, left/right).

Consequences:

- **C-52** A fire mission is a sequence with real delays: an observer with eyes on, a call,
  time of flight, an adjustment round, a correction, then effect. Killing the observer or
  breaking the net between call and effect cancels the mission.
- **C-53** Fire for effect without adjustment is allowed only when the observer's contact
  confidence is high (seen, recent, close).

### C.7 Counter-battery and shoot-and-scoot **[S]**

- A mortar's lofted trajectory makes its firing position easy to compute; crews that fire and
  do not move "may have a few minutes"; integrated sensor chains have compressed this to
  about three minutes.

Consequences:

- **C-54** The Director records every player indirect-fire event by firing position; a second
  fire mission from the same grid within a window makes that grid a counter-battery target
  with a delay of a few minutes, provided the Director's own fire support budget allows it.

### C.8 Hugging (Grozny 1994 to 1995; DTIC Russian lessons learned) **[S]**

- Chechen fighters closed to "50–250 meters" of Russian positions to make Russian artillery
  and air unusable; the Russian counter was baiting with a small forward element.

Consequences:

- **C-55** When the Director knows or suspects the players have indirect fire or air, groups
  in contact are told to close to inside danger-close range rather than hold at distance.

### C.9 Report formats: SALUTE and ADDRAC **[S]**

- SALUTE: Size, Activity, Location, Unit, Time, Equipment. ADDRAC fire command: Alert,
  Direction, Description, Range, Assignment, Control.

Consequences:

- **C-56** The contact record *is* a SALUTE: strength, activity (moving, static, firing),
  location with error, unit type, time, equipment. Bark vocabulary follows ADDRAC so a player
  hears direction, description and range in that order.

### C.10 The OODA loop (Boyd) **[S]**

- Observe, Orient, Decide, Act; the side that cycles faster and less predictably gets inside
  the other's loop; orientation is the step where a misled enemy goes wrong.

Consequences:

- **C-57** The mod's job is to shorten the enemy's loop (report latency, decision cadence) and
  lengthen the player's (smoke, feints, pressure from an unexpected direction). Killing the
  leader or the radio lengthens *their* loop, which is what acceptance test 3 measures.

---

## Part D. Consolidated consequences by system

| System (brief §) | Consequences |
|---|---|
| 3.1 Knowledge model | C-01, C-02, C-03, C-28, C-34, C-56, C-57 |
| 3.2 Fairness contract | C-01, C-12, C-17, C-22 |
| 3.3 Morale, suppression, cohesion | C-35, C-37 |
| 3.4 Position selection | C-09, C-20, C-21, C-23, C-24, C-25, C-26, C-27 |
| 3.5 Squad tactics | C-08, C-10, C-30, C-41 to C-51 |
| 3.6 Combined arms | C-46, C-55 |
| 3.7 Indirect fire and Director tools | C-13, C-16, C-18, C-22, C-31, C-36, C-52 to C-55 |
| 3.8 Adaptation and memory | C-14, C-31, C-54 |
| 3.9 Legibility | C-11, C-19, C-39, C-56 |
| 3.10 Performance | C-05, C-06, C-07, C-23, C-38 |
| 4 Zeus layer | C-12, C-15, C-29, C-33, C-36 |

## Sources

- Orkin, J. *Three States and a Plan: The A.I. of F.E.A.R.* GDC 2006.
  https://www.gamedevs.org/uploads/three-states-plan-ai-of-fear.pdf
- Booth, M. *The AI Systems of Left 4 Dead.* GDC 2009.
  https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
- Beij, A., Straatman, R. *Killzone's AI: Dynamic Procedural Tactics.* GDCE 2005.
  https://www.guerrilla-games.com/media/News/Files/gdce05_killzone_ai.pdf
- Jack, M. *Tactical Position Selection: An Architecture and Query Language.* Game AI Pro.
  https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter26_Tactical_Position_Selection.pdf
- Straatman, R. et al. *Hierarchical AI for Multiplayer Bots in Killzone 3.* Game AI Pro.
  http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf
- Isla, D. *Handling Complexity in the Halo 2 AI.* GDC 2005 proceeding.
  https://www.gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai
- Thompson, T. *The Perfect Organism: The AI of Alien: Isolation.*
  https://www.gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation
- nk3nny/LambsDanger wiki, *waypoints.* https://github.com/nk3nny/LambsDanger/wiki/waypoints
- ACE3, *Arma 3 Scheduler and our Practices.*
  https://ace3.acemod.org/wiki/development/arma-3-scheduler-and-our-practices.html
- CBA_A3 wiki, *Per Frame Handlers.* https://github.com/CBATeam/CBA_A3/wiki/Per-Frame-Handlers
- Bohemia Interactive community wiki: *knowsAbout*, *AI Sub-skills*, *FSM Danger*
  (fetch refused during this pass; cited from search excerpts).
- ATP 3-21.8 *Infantry Platoon and Squad*, Appendix E battle drill list (2024) via
  infantrydrills.com; FM 3-21.8 (2007) movement chapter via globalsecurity.org mirrors.
- ATP 3-09.30 *Observed Fires* (2017), chapter 4, via published summaries; FM 6-30 chapter 4
  via globalsecurity.org.
- MCWP 3-11.3 Appendix D *Ambush Formations.*
  https://www.globalsecurity.org/military/library/policy/usmc/mcwp/3-11-3/appd.pdf
- Thomas, T. *The Battle of Grozny: Deadly Classroom for Urban Combat*, Parameters; DTIC
  ADA394517 *Russian Urban Tactics: Lessons from the Battle for Grozny.*
- Wikipedia: *Counter-battery radar*, *Shoot-and-scoot*, *OODA loop*.
- Company of Heroes wiki, *Suppression*; WARNO stress and suppression guides.
