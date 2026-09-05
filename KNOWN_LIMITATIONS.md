# Known Limitations

This is an honest list of where VEILFORGE falls short, what was verified and
what was not, and what a follow-up pass would fix first.

---

## 1. Visual fidelity is stylised-realistic, not photoreal

The brief asked for a hyperrealistic look. What is here is a **physically based,
fully procedural** look: real PBR materials, dynamic global illumination (SDFGI),
volumetric fog, screen-space reflections and ambient occlusion, soft shadows,
weather, wind-reactive vegetation and physical camera exposure — but every mesh
and texture is generated from noise and mathematics at runtime.

Photorealism is a function of authored assets: scanned materials, high-poly
sculpts, hand-placed detail, rigged and motion-captured characters. None of that
can be produced in this environment, and none of it can be legally obtained and
redistributed without a licence. Rather than ship placeholder cubes or a small
number of purchased assets, the game commits to a coherent procedural art
direction and applies it consistently across all eight chapters.

The most visible consequences:

* **Surface detail is noise-derived.** It reads correctly at gameplay distance
  and holds up in silhouette, but it does not have the specific character of a
  photographed material up close.
* **The player character and guardians are procedurally assembled solids,
  procedurally animated.** The locomotion cycle counter-rotates the hips against
  the shoulders, swings the arms opposite the legs, leans into acceleration and
  tracks the camera with the head — it reads well in third person at normal
  camera distance. It is not motion-captured, and there is no facial animation.
* **Buildings are parametric.** Facades have real recessed window bays and roof
  furniture, but a city block does not have the irregularity a level artist
  would give it.

## 2. The Windows executable was built but not executed on Windows

The build machine is a headless Linux container. The Windows export was produced
with Godot's official 4.3 Windows export template and verified as a
**PE32+ GUI executable for MS Windows, x86-64, 84.8 MB, with the PCK embedded**.
Wine is not available in this environment, so the `.exe` itself has not been
launched.

What *was* verified is the packaged content: an equivalent Linux export was
produced from the same project with the same `all_resources` export filter, and
the full automated playtest was run **against that packaged binary** rather than
against the source tree — 372/372 checks passing, with no missing-resource
errors. That proves the export pipeline packages every material, shader, scene
and script correctly; it does not prove the Windows binary launches on Windows.

If it does not start on a given machine, the most likely cause is a GPU without
Vulkan support. Run `VEILFORGE.exe --rendering-method gl_compatibility`.

## 3. Audio was generated and inspected, but never heard

The container has no sound card; Godot falls back to its silent driver. Audio was
verified structurally: buffers are generated with the expected sample counts and
loop points, per-state shift sounds differ byte-for-byte, bus volumes respond to
the settings, and the adaptive music sequencer runs on its beat clock. **Nobody
has listened to it.** Mix balance, whether the procedural music is pleasant over
a two-hour session, and whether any sound is harsh are unverified.

## 4. Performance is estimated, not measured on target hardware

The only GPU here is `llvmpipe`, a software Vulkan rasteriser, which is orders of
magnitude slower than any real GPU and tells you nothing about frame rate. The
60 FPS at 1080p target is based on the workload shape — triangle counts,
draw-call counts, MultiMesh use, preset-gated effects — and on Godot 4.3's
typical Forward+ cost, not on a measurement.

What *was* measured: chapter build time (1.7–4.6 s headless), node counts
(970–1300 per chapter), and steady-state memory (170–235 MB, flat over a full
playthrough with no growth).

The graphics presets exist precisely because this is unverified: Low disables
SDFGI, SSR and volumetric fog and renders 3D at 75%.

## 5. Playtest coverage is mechanical, not human

The automated harness plays the game for real — it moves, jumps, aims, shifts,
scans, imprints, dies, respawns, stuns guardians, solves every puzzle and
finishes every chapter — and it caught several severe bugs (see QA_REPORT.md).
But it is not a player. It does not tell you:

* whether the puzzles are **fun**, or fairly clued
* whether the difficulty curve across eight chapters is right
* whether the 90–180 minute target is accurate (par times are designed, not
  observed)
* whether any chapter has a route the designer did not intend

The harness solves puzzles through their API as well as by playing, so a puzzle
whose *intended physical solution* is subtly impossible would still be reported
as solvable. Human playtesting is the largest single gap in this project.

## 6. Chapter scope is even, which makes it slightly repetitive

Every chapter follows the same shape: arrive, learn the local rule, five to seven
puzzles, one set piece, a guardian encounter, a finale. That consistency was
deliberate — it is what made eight complete chapters achievable — but a longer
schedule would break the pattern more often, as Archive Zero does by dropping
traversal almost entirely.

## 7. Smaller known issues

* **Guardian navigation is a steering behaviour, not a navmesh.** Guardians
  raycast ahead and sidestep obstacles. They handle the open spaces they patrol
  correctly, but they can be out-manoeuvred around complex geometry, and they do
  not path around a building to reach you.
* **A few teardown-time renderer warnings.** Changing scene between chapters
  prints a small number of `Parameter "m" is null` messages from Godot's dummy
  renderer during headless teardown. They occur after the frame is done and have
  no gameplay or visual effect; they do not appear in a rendered run.
* **Water is a single plane per volume.** It looks correct from above and below
  and reacts to depth, but there is no shoreline geometry blending, so the
  waterline against a steep slope is a hard edge.
* **The concept-art gallery is procedurally drawn**, not painted. Each of the 24
  plates is deterministic and distinct, but they are compositions of shapes
  rather than illustrations.
* **No cloud layer.** Skies are a procedural gradient with a sun disc; weather is
  carried by particles and fog rather than by clouds.
* **Controller vibration fires, but no pad has ever felt it.** Haptics are
  triggered on damage, death, hard and soft landings, the dodge, a reality
  shift, an imprint and the EMP, all routed through one helper so the on/off
  switch and the strength slider reach the pad (reduced camera shake damps
  them too). The scaling is covered by the test suite, but the container has
  no controller, so the actual feel is unverified.
* **One save format version.** The loader has a migration path and a version
  field, but there has only ever been version 1, so migration is untested by
  anything other than its own unit check.

## 8. What is explicitly *not* a limitation

These were verified and hold:

* The game is fully offline. A full playthrough under `strace` opens **zero**
  internet sockets and makes **zero** `connect()` calls.
* All three reality states change real gameplay state — geometry, collision,
  power, hazards and AI — and the test suite fails a chapter if collision does
  not differ between states.
* All eight chapters are completable without developer commands.
* Saves survive corruption, truncation and hand-editing.
* The test harness is excluded from release exports and cannot be reached from a
  shipped build.
