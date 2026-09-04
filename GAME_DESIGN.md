# VEILFORGE: THE THREEFOLD EARTH — Game Design

## Premise

The Fracture left every location on the planet existing in three physical
versions at once:

* **Memory** — the place before the damage. Intact structures, working
  machinery, clean air, long sightlines, cold light.
* **Ruin** — the present. Collapse, rust, sand, ice plugs, hostile machines,
  heavy air, a low sun.
* **Bloom** — a future reclaimed by vegetation. Roots that bridge gaps, growth
  that has pried doors open, muffled sound, warm saturated light.

You are a survey engineer carrying the **Veilforge Device**, which projects a
movable field that shifts everything inside it between those three states. MOTE,
a survey drone, follows you and talks.

The objective is to reach and complete the ignition of the Threefold Climate
Engine before the three realities collapse into one unstable world.

## The design rule the whole game obeys

**A reality state is never a filter.** Every shift changes, at minimum, one of:
geometry that exists, collision you can stand on, whether a machine has power,
whether a hazard is present, how alert a guardian is, or what ambient sound the
place makes. If a shift would only recolour something, that object does not get
a state variant at all.

Concretely, `VeilSubject` holds up to three child subtrees. Switching states
shows one and hides the others, and **enables or disables their collision shapes
and areas** — so a Memory bridge is a surface you walk on and a Ruin bridge is
open air you fall through. The automated test suite asserts this directly: it
counts active collision shapes per state and fails a chapter if no subject's
collision differs between states.

---

## Core mechanics

### The movable field

Hold *Aim* to project a sphere at whatever you are looking at, up to the
Device's range. Pick a state, press *Shift*, and everything inside becomes that
state. The field follows your aim, so a shift you are standing inside moves with
you.

**Pinning** is the counter to that. A pinned field stays where you put it and
expires after a while. Puzzles that need you to be *outside* the shifted volume —
stepping stones you must walk across, a conduit that must stay live while you
walk to the other end — are built around pinning, and Chapter 1 teaches it with a
gap you physically cannot cross while holding the field yourself.

The finale asks for three simultaneous states, which is only possible because
you have three levers: the world's base state, one pinned field, and the field
you are aiming.

### Scan, record, imprint

Scanning an object gives you its field note (the game's main storytelling
channel) and, if it carries one **in the state it is currently in**, a
recordable **property**:

| Property    | What it does when imprinted                                |
| ----------- | ---------------------------------------------------------- |
| Conductive  | A dead conduit carries current                              |
| Buoyant     | A sinking object floats                                     |
| Rigid       | An object holds shape under load                            |
| Luminous    | An object emits light                                       |
| Growing     | A stunted vine extends to an anchor and becomes climbable   |
| Frozen      | Meltwater becomes a crossing; a long cable superconducts    |
| Resonant    | An object holds the Veilforge carrier tone                  |
| Hollow      | A beam becomes light enough to carry                        |

This is the cross-state transfer the premise promises: you record CONDUCTIVE
from a cable that is only live in Memory and imprint it onto a conduit that only
spans the gap in Ruin. Neither state alone solves it.

### Energy

One cell powers shifting, pinning, scanning, imprinting, dodging and the EMP. It
refills after a pause. Difficulty scales the cost, not the cap, so the harder
settings make you sequence actions rather than shrinking your options.

### Encounters

Guardians are damaged maintenance machines. They shock rather than injure — the
player has a shield, not blood. Options are always: **avoid** (they see in a
cone and lose you behind cover), **neutralise** (an EMP stuns; a Memory field
drops them to standby because in Memory they are docile service drones), or
**environment** (shift a mass above one and let it fall, or take the floor out
from under it). Bypassing one unseen is worth XP; being spotted breaks your
discovery chain. There are never more than three in a space.

### Traversal

Walk, sprint, crouch, jump, automatic mantle, hand-over-hand climbing with a
grip meter, swimming with an air meter, a dodge with brief invulnerability, and
a landing roll that cancels impact damage if you press crouch on touchdown.
Coyote time and jump buffering are both on, and all camera damping is
frame-rate independent.

---

## Chapters

Each chapter has one clear objective, five to seven reality puzzles, at least one
memorable set piece, optional routes, **three Memory Fragments**, **one upgrade
component**, **one bonus challenge**, checkpoints, a chapter-ending event and a
results screen with a rank.

### 1 — Glass-Rain Valley
*Atmospheric tutorial.* A survey skiff down in a valley where the Ruin sky rains
glass shards that hurt if you stand in the open. Teaches the field, state
cycling, scanning, imprinting, pinning and the EMP, each through a puzzle rather
than a wall of text: a fallen bridge that exists in Memory and as roots in
Bloom, a crate pinned under rubble that is a Ruin-only fact, a dead conduit that
needs CONDUCTIVE carried from a Memory cable, stepping stones that force the
first pin, and a service yard with two guardians.
**Challenge:** cross the valley without a single shard strike.

### 2 — The Walking Forest
A mobile timber mill that got four kilometres before the Fracture and has been
standing still ever since, with a forest grown through it. HOLLOW makes a beam
light enough to carry onto a counterweight; GROWING makes a stunted vine build
its own ladder; the mill spine is a three-run power puzzle where one run wants
Memory, one wants an imprint and one wants Bloom; the saw carriage needs both
power and a rail that only exists in Memory.
**Challenge:** reach the canopy without touching the forest floor after the lift.

### 3 — Nacre City
A vertical harbour city, nine floors under water. A sluice valve moves the water
level of the entire district, which is simultaneously a traversal tool (walk the
underpass at low water) and a lift (float an imprinted-BUOYANT pallet up to a
ledge at high water). The Pearl Lift is a resonance lock wanting power, full
water and a version of its shaft that is not falling apart. The roof crossing
alternates which state each stone belongs to.
**Challenge:** raise the Pearl Lift using only three veil shifts.

### 4 — White Signal Observatory
A listening station above the snow line. **Storm fronts sweep through on a
cycle**, and inside a front visibility drops and guardians lose you — so the
weather is a resource. FROZEN turns meltwater into a bridge and makes a long
cable superconduct. A prism hall chains a beam through rotatable prisms to a wall
receiver, with one line blocked by rubble that only exists in Ruin. Three dish
elevations must match a blueprint you have to find and scan.
**Challenge:** realign all three dishes inside a single storm front.

### 5 — The Buried Sun
Desert ruins around something warm that was already there at nine hundred metres.
A **rising core-heat clock** starts once the dish field is powered: opening the
three coolant lines slows it, and standing inside a Memory field slows it more,
because in Memory the core remembers being cold. The descent is a spiral of
platforms where two in every three belong to a different state.
**Challenge:** stabilise the ring without core heat ever passing 70%.

### 6 — Tempest Archipelago
Four islands and one crossing. The storm cycle drives the tide, so the tidal
causeway is a timing problem. Every link between islands belongs to a different
reality: a Memory pier, a Bloom cable run, a coral causeway. The lighthouse lamp,
once lit, sweeps a salt shelf that is only solid while the beam is on it.
Lightning strikes the tallest thing standing in the open, and that can be you.
**Challenge:** reach the storm eye without being struck once.

### 7 — Archive Zero
An interior chapter, and the reveal. The building is intact in all three states,
which should not be possible. The reader arch admits you only after it has seen
all three realities from where you stand. The ledger hall's plinths each want a
specific property and a wrong imprint is spent, which is what the challenge
measures. The triptych needs **three alcoves held in three different states at
once** — base state, pinned field, aimed field.
**Challenge:** reconstruct the record without a single failed imprint.

### 8 — Convergence Core
All three realities overlap in the same volume. A causeway of alternating-state
slabs descends into the basin over a lethal drop. Three containment rings must
each be imprinted RESONANT *and* held in a different state — Memory, Ruin and
Bloom — at the same moment. When the governor releases, a ninety-second ignition
sequence runs: losing a ring costs time rather than ending the attempt, and
failing simply resets the rings so you can try again.
**Challenge:** finish without dropping below 25% shield.

---

## Progression

**Research XP** is awarded for solving puzzles, perfect solutions, first-time
scans, hidden areas, wildlife, Memory Fragments, bypassing guardians unseen,
completing chapters, no-damage chapters and bonus challenges.

An **exploration chain multiplier** builds as you make discoveries in quick
succession (up to ×2.0) and breaks when you take damage or are spotted — so it
rewards clean, curious play rather than speed.

**Levels 1–30.** Each level grants one upgrade point.

**Three branches**, fifteen nodes, forty ranks — deliberately more than the
twenty-nine points a maxed player has, so builds differ:

* **Resonance** — Field Bloom (radius), Long Throw (range), Clean Phase (cost),
  Anchor Weave (pin duration), Deep Register (property slots)
* **Mobility** — Iron Grip (climb stamina), Glide Trim (air control), Long
  Stride (sprint), Soft Landing (fall damage + roll window), Phase Step (a
  mid-air second jump paid for in energy)
* **Engineering** — Wide Discharge / Deep Discharge (EMP radius and stun), Fast
  Optics (scan speed), Cell Bloom (energy regeneration), Hard Shell (shield)

Tiers unlock with **upgrade components**, one per chapter: tier 2 at two
components, tier 3 at five. So the tree opens through exploration, not grinding.

**Bonuses:** first-discovery, perfect-puzzle, exploration chain, no-damage
chapter, hidden area, full survey, chapter mastery medals, and a New Game+
multiplier.

**Unlockables** (all earned in play, none purchasable): six visual suits, five
MOTE shells, a 24-plate concept-art gallery, per-chapter time trials unlocked by
completing a chapter, and New Game+ which keeps every upgrade, fragment and
unlock while relocking the chapters.

**Ranks** C / B / A / S from a score combining time against par, puzzles, perfect
solutions, exploration, stealth and bonuses, minus damage and deaths. A
**mastery medal** needs the challenge, all three fragments, the component and at
least an A.

---

## Difficulty and hints

Three difficulties change guardian sight range, notice speed, pulse damage and
interval, incoming damage and energy costs — they do not remove content.

Four hint levels change only how often MOTE volunteers help when you have been
stuck. Every puzzle carries three written hints of increasing directness;
pressing *Ask MOTE* always gives you the guided-level answer for whatever you are
nearest, regardless of setting. A puzzle solved after a directed hint no longer
counts as "perfect", which is the only cost.

---

## Storytelling

There is no voice acting. The story is carried by:

* **MOTE**, who comments on what you are looking at and is the only character
  who speaks to you
* **Field notes** attached to every scannable object
* **24 Memory Fragments**, each a found document — a rota, a letter, a ledger,
  a rejected proposal — readable afterwards in Field Records
* **The buildings themselves**: what people left behind, and in which state

The reveal in Archive Zero is that the Fracture was the first second of the
climate engine starting, and nobody completed the sequence. The last fragment in
the game is a field note in your own handwriting that you do not remember
writing, quoting a line from the first chapter.
