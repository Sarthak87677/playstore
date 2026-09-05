# VEILFORGE — QA Report

**Build tested:** commit on `claude/veilforge-threefold-earth-00i6e8`
**Engine:** Godot 4.3 stable, Forward+ (Vulkan)
**Test host:** headless Ubuntu 24.04 container, 4 cores, 15 GB RAM, `llvmpipe`
software Vulkan (Mesa 25.2.8). No physical GPU, no sound card, no Windows host.

---

## 1. What was tested and how

Testing is done by `project/tests/AutoTest.gd`, a harness that **plays the
actual game** rather than exercising functions in isolation. Invoked with
`--autotest`, it:

* boots the real game through the real splash and menu flow,
* loads each chapter through the real loading path,
* presses movement keys and synthesises input events for actions handled in
  `_unhandled_input` (jump, interact, veil actions),
* aims and fires the Veilforge Device and checks the world agrees about the
  resulting state,
* walks every `VeilSubject` in the chapter through every state it declares,
* asserts that **collision** differs between states, not just appearance,
* scans an object, stores the property, and imprints it on a valid target,
* damages the player, kills the player, and confirms respawn at a checkpoint,
* stuns and disables a guardian,
* solves every puzzle and confirms each reports solved,
* completes the chapter and checks the record, rank and next-chapter unlock,
* opens the main menu, chapter select, pause menu, Settings, Upgrades and
  Field Records, asserts every control is actually connected to a handler,
  and asserts each panel occupies a non-degenerate rectangle.

It prints one PASS/FAIL line per check, exits non-zero on any failure, and
writes `user://autotest_report.txt`.

**Reproduce:**

```
godot --headless --path project -- --autotest --chapters=1,2,3,4,5,6,7,8
```

---

## 2. Results

### Source tree

```
=== RESULT: 369/369 checks passed, 0 failed ===
```

### Packaged build

The same suite was then run **against an exported, packaged binary** — same
project, same `all_resources` export filter, PCK embedded — rather than against
the source tree, to prove the export packages every resource:

```
./build/verify/VEILFORGE_verify.x86_64 --headless -- --autotest --chapters=1,2,3,4,5,6,7,8
=== RESULT: 369/369 checks passed, 0 failed ===
```

No missing-resource, failed-load or shader-compile errors in the packaged run.

### Coverage by area

| Area | Checks | Result |
| --- | --- | --- |
| Settings: input map, graphics presets, audio buses, persistence round-trip, colour-blind palette, shake disable | 9 | pass |
| Saves: write, read back, corrupt-recovers-from-backup, erase, missing data, hand-mangled types | 10 | pass |
| Progression: XP curve, levels, upgrade gating and tiers, derived stats, chain multiplier, results scoring, ranks, mastery, NG+ | 23 | pass |
| Procedural audio: buffer generation, loop points, per-state difference, bus response, cache bounds | 5 | pass |
| Procedural assets: materials, mesh geometry, collision shapes, caching | 5 | pass |
| Front end: splash, main menu, and the New Game, Chapter Select, Settings, Extras, Credits and Exit panels — every control connected, every panel a non-degenerate rectangle | 21 | pass |
| Per chapter (×8): build, contents, physics, movement, device, state switching, collision difference, scan/imprint, checkpoints, damage/death/respawn, scoring after a death, guardians, puzzles, completion, rank | 31–35 each, 273 total | pass |
| Close and resume: checkpoint written to disk, profile dropped and reloaded, XP preserved, resumed at the checkpoint, erased slot, no-slot Continue | 10 | pass |
| Pause menu: pause stops the game, menu opens, buttons connected, Upgrades / Records / Settings open with live controls and real geometry, resume | 13 | pass |

---

## 3. Per-chapter measurements

Measured headless on the 4-core container. `nodes` is the live SceneTree node
count with the chapter, player, MOTE and HUD present.

| # | Chapter | Load | Nodes | RSS | Veil subjects | Puzzles | Fragments | Component |
| - | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | Glass-Rain Valley | 3.82 s | 970 | 199 MB | 6 | 6 | 3 | 1 |
| 2 | The Walking Forest | 2.20 s | 1320 | 218 MB | 5 | 7 | 3 | 1 |
| 3 | Nacre City | 2.03 s | 828 | 226 MB | 7 | 7 | 3 | 1 |
| 4 | White Signal Observatory | 1.64 s | 983 | 240 MB | 3 | 6 | 3 | 1 |
| 5 | The Buried Sun | 1.72 s | 906 | 251 MB | 10 | 5 | 3 | 1 |
| 6 | Tempest Archipelago | 1.66 s | 450 | 261 MB | 4 | 6 | 3 | 1 |
| 7 | Archive Zero | 1.44 s | 560 | 266 MB | 6 | 6 | 3 | 1 |
| 8 | Convergence Core | 1.85 s | 632 | 280 MB | 9 | 6 | 3 | 1 |

Chapter 1 is slower because it pays for the first-run procedural texture and
audio generation, which every later chapter then reuses from cache.

RSS rises across a session (199 MB after chapter 1, 280 MB after chapter 8)
because the procedural texture and audio caches accumulate and are then reused;
it is bounded, and within a single chapter it is flat — the post-play node count
is within ~25 nodes of the post-load count in every chapter, so nothing is
leaking per frame.

**"Reality states change collision" passed in all 8 chapters** — that check
enumerates each subject's active collision shapes per state and fails if no
subject's collision differs, so it is a direct assertion that shifting is a
physical change and not a repaint.

---

## 4. Offline verification

Two independent checks.

**Source scan.** No networking API appears anywhere in the project:

```
grep -rnE "HTTPRequest|HTTPClient|StreamPeerTCP|StreamPeerTLS|PacketPeerUDP|
           WebSocket|ENetConnection|MultiplayerAPI|UPNP|IP.resolve|
           OS.shell_open|TCPServer|UDPServer" --include=*.gd project/
  → no matches
```

**Syscall trace.** The packaged binary was run under `strace -f -e trace=network`
for a complete chapter playthrough (boot, splash, menu, chapter load, movement,
device use, death, respawn, guardians, puzzles, completion):

```
socket families used:  1 × AF_NETLINK
AF_INET / AF_INET6 sockets: 0
connect() to any internet address: 0
```

The single `AF_NETLINK` socket is `NETLINK_KOBJECT_UEVENT` — the kernel's local
device-hotplug channel, opened by the input/device layer to notice controllers
being plugged in. It is not an internet socket and carries no traffic off the
machine. **The game opens no network sockets and makes no outbound
connections.** There is no telemetry, no update check, no
account system and no analytics.

---

## 5. Bugs found and fixed during testing

Every item below was found by the automated harness or the rendered capture pass
and is fixed in the current build.

| Severity | Bug | How it was found |
| --- | --- | --- |
| **Critical** | The terrain heightfield's triangles were wound counter-clockwise, so Godot back-face culled the entire ground. Every prop appeared to float in an empty sky. | Rendered capture pass — invisible in headless testing, since no check looks at pixels |
| **Critical** | `HUD.toast()` trimmed old toasts with `while get_child_count() > 7: get_child(0).queue_free()`. `queue_free()` does not detach the child until end of frame, so the loop never terminated and flooded the SceneTree deletion queue — 14 GB RSS in ~2 minutes, then an OOM kill. This would have frozen the shipped game the first time eight notifications appeared. | Full-chapter test dying with SIGKILL; located by bisecting with RSS sampling |
| **Critical** | A lethal hazard deals 9999 damage so that nothing survives it, and `note_damage` recorded that verbatim. One fall into Chapter 1's fissure scored -23998, which zeroed the chapter total and pinned the rank to C however well the rest of the chapter was played — a permanent, unrecoverable penalty for an ordinary mistake the game already punishes with a death and a respawn. Only damage the shield actually absorbs is recorded now. | Reading a captured results screen: `Damage penalty -24378` against positive scores in the hundreds. The harness now scores a run, kills the player outright and scores it again; reverting the fix was confirmed to fail it (6754 -> 0, exit 1) |
| **Critical** | Every full-screen panel used `set_anchors_preset(PRESET_FULL_RECT)`, which keeps the existing offsets by default. Panels parented to a Control therefore stayed 0×0: Settings, Upgrades, Field Records, Chapter Select, the results screen and the HUD's own containers all collapsed — backgrounds absent, content clipped to nothing. 59 call sites across 10 files, now `set_anchors_and_offsets_preset`. | Rendered front-end capture pass — headless checks asserted the buttons existed and were connected, which they were; nothing looked at the rectangle they occupied. The harness now asserts panel geometry, and reintroducing the bug in one file was confirmed to fail the suite (2 failures, exit 1) |
| High | The main menu and the pause menu drew their own button list on top of any sub-panel they opened, so Settings and Upgrades appeared behind the menu. The menu list is now hidden while a panel is open. | Rendered front-end capture pass |
| High | Prop materials repeated the double-darkening the terrain shader used to have: a mid-dark `albedo_color` multiplying an already-coloured `albedo_texture`. Boulders read as near-black smears and the relay tower's rust was pure black. All 18 textured base materials now carry a hue-preserving near-white tint; the five duplicate-and-retint variants are scaled by the same factor, so every material/variant relationship is unchanged. | Rendered capture pass |
| Medium | Sun-only key lighting at these pitches dropped shadowed ground to near-black. Fill energy and ambient were raised across all three palettes. | Rendered capture pass |
| Low | Chapter 1's `bridge` capture vantage took its height from the terrain on the far side of the fissure, so the camera sat buried inside the near valley wall. | Rendered capture pass |
| **Critical** | Typed `@export var accepted: Array[int]` rejected a plain array literal at runtime. The assignment threw, aborting the rest of the chapter's build function and silently dropping a Memory Fragment. | "three memory fragments [2 found]" failing in chapter 2 |
| High | The procedural audio cache was keyed on a continuously varying brightness value, so the music sequencer allocated and cached a fresh ~200 KB buffer every beat, unbounded. | Memory bisect |
| High | Positional one-shot audio players were freed only on `finished`, which a silent fallback audio driver never emits — one leaked node per footstep. The replacement timer then captured the freed node in a lambda. | Node-count tracking, then a lambda-capture error |
| High | Terrain meshes carried no tangents, so the terrain shader's normal map had no basis and shaded the ground into black-and-white mottling. | Rendered capture pass |
| High | The terrain shader tinted an already-coloured albedo texture, darkening every ground surface twice over to near-black. | Rendered capture pass |
| High | `HeightMapShape3D` was scaled non-uniformly to fit a world-sized grid. Heights are now pre-divided by the cell size and the shape scaled uniformly. | Player falling through terrain |
| Medium | Chapters could place the player's spawn inside or under the ground. `ChapterBase` now raises any spawn that ends up below the surface. | "player does not fall through the world" failing |
| Medium | Mesh generators returned `null` for degenerate parameters; the null then reached `MeshInstance3D` and the collision builder. | Renderer errors during chapter build |
| Medium | Chapter 8 shipped without its upgrade component. | "one upgrade component [0 found]" |
| Medium | Fog, aerial perspective and auto-exposure were tuned so aggressively that distant terrain blended into the sky and the ground was crushed against a bright sky. | Rendered capture pass |
| Medium | Depth of field blurred everything past 34 m, including landmarks the player navigates by. | Rendered capture pass |
| Low | Islands in chapter 6 were smooth mathematical cones with no flat ground for structures. | Rendered capture pass |
| Low | `Settings.event_display_name` called a display-server function unavailable in headless mode. | Headless test errors |
| Low | Several materials (nacre, snow, sand) read as near-white on screen. | Rendered capture pass |

---

## 6. Acceptance checklist

| Requirement | Status | Evidence |
| --- | --- | --- |
| A new player can install, launch and finish the game offline | **Partly verified** | All eight chapters complete in the packaged binary with zero network activity. The Windows `.exe` itself has not been launched — no Windows host or Wine here (see KNOWN_LIMITATIONS §2) |
| New Game, Continue, saves and chapter unlocking work | Pass | Save/load/corruption/erase checks; "next chapter unlocked" per chapter; close-and-resume test |
| Every chapter can be completed without developer commands | Pass | Each chapter completed through its own puzzle and interaction logic; `chapter completion recorded` ×8 |
| All three reality states affect actual gameplay | Pass | "all veil subjects switch cleanly" and "reality states change collision" pass in all 8 chapters |
| XP, upgrades, bonuses and collectibles persist correctly | Pass | Progression suite; "upgrades persist", "fragments persist", "xp survived the restart" |
| Controller and keyboard controls work | Pass | Every action has both a keyboard/mouse and a controller binding and is present in the input map; the harness drives the game through those actions. Physical controller hardware was not available |
| Pause, settings and accessibility options work | Pass | Pause halts the game and resumes; the pause menu opens Upgrades, Field Records and Settings with connected, correctly sized controls; preset application, audio bus levels, settings round-trip, colour-blind palette, shake disable |
| Missing save data is handled safely | Pass | "missing save handled safely", "mangled types sanitised", "corrupt save recovers from backup", "continue finds no slot to load" |
| The game can be closed and resumed correctly | Pass | Close-and-resume test: profile dropped from memory, reloaded from disk, resumed 0.3 m from the checkpoint |
| No unavoidable crashes or progression blockers | Pass | 369/369 with no crash in eight full chapter runs, twice (source and packaged) |
| No required asset missing from the packaged build | Pass | Full suite run against the packaged binary with no load errors |
| No network connection is attempted | Pass | `strace`: zero internet sockets, zero `connect()` calls |
| The distributable build matches the editable project | Pass | The ZIP is produced by exporting `project/` directly; the verification binary is the same export with the same content filter |

---

## 7. Not covered by automated testing

Stated plainly, because these are the real gaps:

* **No human has played the game.** Fun, pacing, difficulty curve, hint quality
  and whether the 90–180 minute target is accurate are all unverified.
* **No one has heard the audio.** The container has no sound device.
* **No frame-rate measurement.** The only GPU is a software rasteriser.
* **The Windows executable has not been launched on Windows.**
* The harness can solve a puzzle through its API as well as by playing it, so a
  puzzle whose intended *physical* solution was subtly impossible would still be
  reported as solvable.
* **Screens are checked, but only some frames were looked at.** The harness
  asserts that every panel is wired up and occupies a real rectangle, and the
  five front-end screens plus Chapter 1 in all three states were rendered and
  inspected by eye. The other seven chapters have one inspected frame each. A
  layout that is present and correctly sized but ugly would still pass.

See [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) for the full list.
