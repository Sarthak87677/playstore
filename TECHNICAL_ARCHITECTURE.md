# VEILFORGE — Technical Architecture

**Engine:** Godot 4.3 stable, Forward+ (Vulkan) renderer, GDScript.
**Target:** Windows x86-64, single executable with the PCK embedded.

## Why Godot rather than Unreal

Unreal Engine 5 was the first choice and is not usable here. The build
environment is a headless Linux container with four cores, 30 GB of free disk and
no Epic account; a UE5 source build needs an Epic-linked GitHub account, well
over 100 GB and hours of compilation, and cross-compiling a Windows shipping
build from Linux is not a supported path. Godot 4.3 is a 50 MB download, exports
a Windows executable from a Linux host as a first-class workflow, and its
Forward+ renderer provides the Vulkan feature set the brief asks for — SDFGI,
volumetric fog, SSR, SSAO/SSIL, soft shadows, glow and physical camera
attributes. This is the strongest equivalent pipeline available in this
environment, which is the fallback the brief specifies.

---

## Everything is generated

No third-party art or audio ships with the game. There is no `.png`, `.wav`,
`.fbx` or `.ttf` in the project. Instead:

### `autoload/ProcAssets.gd` — meshes, textures, materials

* **Textures** are `NoiseTexture2D` — generated on engine threads in C++, not in
  a GDScript pixel loop — with gradient ramps for albedo, `as_normal_map` for
  normals, and separate roughness and AO maps. Around 40 are built.
* **Meshes** are built from `SurfaceTool` or, where volume demands it, straight
  into packed arrays. Generators cover rocks (noise-displaced UV spheres),
  crystals, tapered bent trunks, canopies, swept tubes for roots and cables,
  room shells with a real doorway cut, panelled facades with recessed window
  bays, lattice trusses, stairs, rings, debris fields, cylinders and grass blade
  clusters.
* **Everything is cached** by parameter key, including collision shapes, so a
  chapter placing 130 rocks builds ten meshes and ten convex hulls, not 130 of
  each.
* **Where a material carries an albedo texture, its `albedo_color` is a
  near-white hue shift, not a second colour.** Tinting an already-coloured
  texture with a mid-dark colour multiplies the two and crushes the surface;
  that mistake turned the terrain near-black once and every prop near-black a
  second time before it was found in a rendered capture.

### `autoload/ProcAudio.gd` — every sound in the game

Oscillators, noise and envelopes. Around 50 named SFX built from frequency
sweeps and mixes; ten seamless ambience beds built by filtering noise and
cross-fading the tail into the head; per-surface footsteps; and four instruments
(a sine/triangle pad, a Karplus–Strong pluck, a two-operator FM bell and a
sub-bass) rendered as short pitched one-shots.

Cache keys are quantised. An earlier version keyed the pad on a continuously
varying brightness value and cached a fresh 200 KB buffer every beat.

### `autoload/AudioDirector.gd` — adaptive music

Music is **sequenced live**, not streamed: a beat clock schedules ProcAudio
one-shots across four layers — a harmonic bed that changes chord every two bars,
a low pulse that enters with tension, a melody whose density tracks intensity,
and an alarm figure that only appears under real threat. Tension comes from
guardian awareness. **Reality state changes the music**: Memory transposes up an
octave and plays bells, Ruin drops an octave and detunes the pluck, Bloom sits in
the middle and adds colour tones. Buses (Music / SFX / Ambience / UI) carry a
reverb and the master carries a limiter.

---

## Reality states

Three classes carry the central mechanic:

**`VeilSubject`** — an object that exists differently per state. Holds up to
three child subtrees; applying a state shows one, hides the others, and toggles
their `CollisionShape3D.disabled`, `Area3D.monitoring`, `RigidBody3D.freeze`,
particle emission and lights. Any variant may be `null`, which means *nothing
exists here in that state* — the floor is genuinely absent.

**`VeilField`** — the visible shell, ground ring and light. Carries a radius, a
target state, and a lifetime when pinned.

**`VeilManager`** — owns the world's base state and the list of active fields.
Re-evaluates only when a field moves, is added or removed, or the base changes,
by comparing a cached list of field centres. Answers `state_at(point)`, which the
atmosphere, weather, ambience, guardian AI, conduits and puzzle conditions all
query, so every system agrees on what reality a point is in.

**`VeilDevice`** — energy, aiming raycast, shifting, pinning, the scanner, the
property register and the EMP. Lives on the player.

---

## Chapters are code, not scene files

`core/world/ChapterBase.gd` is a construction kit: `build_terrain`,
`static_mesh`, `box`, `decor`, `rock`, `tree`, `tube`, `climb_surface`,
`veil_subject`, `variant_box`, `variant_mesh`, `scannable`, `fragment`,
`component`, `hidden_marker`, `wildlife`, `checkpoint`, `trigger`, `hazard`,
`guardian`, `prop`, `say`, `cinematic`, `finish`.

Each `chapters/ChapterNN.gd` overrides `build_world()` and calls those helpers,
reporting progress to the loading bar and yielding between phases. A chapter is
600–750 lines of readable placement code rather than a binary scene, which is
what makes eight distinct chapters tractable — and it means the whole game is
diffable and reviewable as text.

`Terrain` builds a heightfield from a chapter-supplied height function straight
into packed vertex/normal/UV/tangent/index arrays (SurfaceTool is far too slow
for a 47k-triangle field in GDScript), plus a uniformly-scaled `HeightMapShape3D`
for collision.

---

## Rendering

`core/world/Atmosphere.gd` owns the `WorldEnvironment`, sun and fill light, and
holds **three palettes** — one per reality state — that cross-fade as the
player's local state changes. Each palette carries sky colours, sun angle,
colour and energy, fog density and depth range, volumetric density, ambient
energy, saturation, contrast and glow.

`shaders/terrain.gdshader` is a triplanar three-layer terrain: a ground layer, a
slope layer selected by surface normal, and a peak layer selected by height,
with the thresholds broken up by macro noise and a second finer octave for
close-up grain. Eight biome presets feed it the same procedural noise the object
materials use.

`shaders/wind.gdshader` drives `MultiMeshInstance3D` vegetation with a
two-frequency sway scaled by height above the root, plus a gust uniform the
weather system pushes.

`shaders/water.gdshader` does dual scrolling normal maps, depth-based colour and
opacity via the depth texture, screen-space refraction, foam at the shoreline and
vertex waves.

`Weather` runs GPU particle systems that follow the camera — glass shards, rain,
snow, sand, pollen, mist, embers, and a three-colour convergence effect — plus
lightning, wind gusts, and per-state intensity. Weather is gameplay: glass rain
only falls from the Ruin sky and only hits you when you are not under cover;
blizzards blind guardians as well as the player.

### Graphics presets

Low / Medium / High / Cinematic set 3D resolution scale, MSAA, screen-space AA,
shadow atlas size and filter quality, SDFGI, SSAO, SSIL, SSR, volumetric fog,
glow, depth of field, vegetation density and draw distance, particle count and
LOD bias. High is the 1080p/60 target; Low disables GI, reflections and
volumetrics and renders 3D at 75%.

---

## Progression and saves

`GameState` holds one dictionary — XP, upgrades, per-chapter records,
collectibles, unlocks, totals and the active checkpoint — and `SaveSystem`
serialises it verbatim to JSON.

Writes are atomic: serialise, write to `slot_N.tmp`, **re-read and re-parse the
temp file to prove it is valid**, rotate the previous save to `slot_N.bak`, then
rename. The first write also seeds the backup, so a slot always has a fallback.

Reads degrade rather than throw: unreadable primary falls back to the backup;
missing keys are filled from a fresh profile; values of the wrong type are
replaced. A hand-edited save with `"xp": "not a number"` and `"chapters": 5`
loads as a valid profile. All of this is covered by the test suite.

---

## Testing

`tests/AutoTest.gd` is a real playtest harness, not a unit-test file. Invoked
with `--autotest`, it drives the actual game: presses movement keys, synthesises
input events for actions handled in `_unhandled_input`, aims and fires the
Device, checks that `state_at` agrees, walks every `VeilSubject` through every
state it declares, verifies that **collision differs between states**, scans and
imprints, damages and kills the player and confirms respawn, stuns and disables a
guardian, solves every puzzle, completes the chapter and checks the record,
rank and unlock.

It also covers settings round-tripping, the graphics presets, audio bus levels,
save writing, backup recovery, corrupt and type-mangled saves, the XP curve,
upgrade gating, derived stats, the chain multiplier, results scoring and New
Game+.

It opens every front-end and pause-menu screen and asserts two separate things
about each: that every control is connected to a handler, and that the panel
occupies a **non-degenerate rectangle** with content of real extent inside it.
The second assertion exists because the first one passed while six screens were
rendering at 0×0 — `set_anchors_preset()` keeps the existing offsets by
default, so a full-screen panel parented to a Control collapses silently.

It is excluded from release exports and guarded at the entry point, so a shipped
build cannot reach it.

`--shots` renders each chapter from fixed vantage points in all three states.
That capture pass is how the two worst bugs in the project were found: the
terrain's triangles were wound backwards, so the entire ground was back-face
culled and every prop appeared to float in the sky.

---

## Performance notes

* Meshes, materials, textures and collision shapes are cached by parameter key
  and shared across every instance.
* Rocks and similar props draw from a small pool of base meshes varied by scale
  and rotation, so the shape cache stays warm.
* Vegetation is `MultiMeshInstance3D` with preset-driven density, visibility
  range and LOD bias.
* `VeilManager` only re-evaluates subjects when a field actually moved.
* Occlusion culling is on; positional one-shot audio players are freed by a
  timer parented to the player as well as by `finished`, because a silent
  fallback audio driver never emits it.
* Chapter load is 1.7–4.6 s headless on this four-core container, most of it in
  terrain generation and the first chapter's texture warm-up.
