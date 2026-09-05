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
=== RESULT: 353/353 checks passed, 0 failed ===
```

### Packaged build

The same suite was then run **against an exported, packaged binary** — same
project, same `all_resources` export filter, PCK embedded — rather than against
the source tree, to prove the export packages every resource:

```
./build/verify/VEILFORGE_verify.x86_64 --headless -- --autotest --chapters=1,2,3,4,5,6,7,8
=== RESULT: 353/353 checks passed, 0 failed ===
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
| Front end: splash, main menu, chapter select, settings panel, every button connected, panel layout non-degenerate | 16 | pass |
| Per chapter (×8): build, contents, physics, movement, device, state switching, collision difference, scan/imprint, checkpoints, damage/death/respawn, guardians, puzzles, completion, rank | 30–34 each, 265 total | pass |
| Close and resume: checkpoint written to disk, profile dropped and reloaded, XP preserved, resumed at the checkpoint, erased slot, no-slot Continue | 10 | pass |
| Pause menu: pause stops the game, menu opens, buttons connected, Upgrades / Records / Settings panels open with live controls, resume | 10 | pass |

---

## 3. Per-chapter measurements

Measured headless on the 4-core container. `nodes` is the live SceneTree node
count with the chapter, player, MOTE and HUD present.

| # | Chapter | Load | Nodes | RSS | Veil subjects | Puzzles | Fragments | Component |
| - | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | Glass-Rain Valley | 4.59 s | 970 | 188 MB | 6 | 6 | 3 | 1 |
| 2 | The Walking Forest | 2.24 s | 1320 | 214 MB | 5 | 7 | 3 | 1 |
| 3 | Nacre City | 2.02 s | 828 | 221 MB | 7 | 7 | 3 | 1 |
| 4 | White Signal Observatory | 1.74 s | 983 | 234 MB | 3 | 6 | 3 | 1 |
| 5 | The Buried Sun | 1.81 s | 906 | 248 MB | 10 | 5 | 3 | 1 |
| 6 | Tempest Archipelago | 1.63 s | 450 | 256 MB | 4 | 6 | 3 | 1 |
| 7 | Archive Zero | 1.48 s | 560 | 261 MB | 6 | 6 | 3 | 1 |
| 8 | Convergence Core | 1.91 s | 632 | 273 MB | 9 | 6 | 3 | 1 |

Chapter 1 is slower because it pays for the first-run procedural texture and
audio generation, which every later chapter then reuses from cache. RSS rises
across a session because the procedural caches accumulate; it is bounded, and
within a single chapter it is flat (measured at 170–175 MB, unchanged over a
full play sequence).

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

The single `AF_NETLINK` socket is a kernel device-enumeration call made by the C
library during audio device probing. **The game opens no network sockets and
makes no outbound connections.** There is no telemetry, no update check, no
account system and no analytics.

---

## 5. Bugs found and fixed during testing

Every item below was found by the automated harness or the rendered capture pass
and is fixed in the current build.

| Severity | Bug | How it was found |
| --- | --- | --- |
| **Critical** | The terrain heightfield's triangles were wound counter-clockwise, so Godot back-face culled the entire ground. Every prop appeared to float in an empty sky. | Rendered capture pass — invisible in headless testing, since no check looks at pixels |
| **Critical** | `HUD.toast()` trimmed old toasts with `while get_child_count() > 7: get_child(0).queue_free()`. `queue_free()` does not detach the child until end of frame, so the loop never terminated and flooded the SceneTree deletion queue — 14 GB RSS in ~2 minutes, then an OOM kill. This would have frozen the shipped game the first time eight notifications appeared. | Full-chapter test dying with SIGKILL; located by bisecting with RSS sampling |
| **Critical** | Every full-screen panel used `set_anchors_preset(PRESET_FULL_RECT)`, which keeps the existing offsets by default. Panels parented to a Control therefore stayed 0×0: Settings, Upgrades, Field Records, Chapter Select, the results screen and the HUD's own containers all collapsed — backgrounds absent, content clipped to nothing. 59 call sites across 10 files, now `set_anchors_and_offsets_preset`. | Rendered front-end capture pass — headless checks asserted the buttons existed and were connected, which they were; nothing looked at the rectangle they occupied |
| High | The main menu and the pause menu drew their own button list on top of any sub-panel they opened, so Settings and Upgrades appeared behind the menu. The menu list is now hidden while a panel is open. | Rendered front-end capture pass |
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
| No unavoidable crashes or progression blockers | Pass | 353/353 with no crash in eight full chapter runs, twice (source and packaged) |
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

See [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) for the full list.
