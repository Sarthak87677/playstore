# VEILFORGE — Controls

Every binding below is remappable in **Settings → Controls**. Each action has two
slots, so you can keep a keyboard binding and a controller binding side by side.
Click a binding, press any key, mouse button, stick direction or pad button, and
it is saved immediately. `Esc` cancels a rebind; *Reset All Bindings* restores
the defaults on this page.

Controller support is generic (any XInput-style pad). The right stick always
controls the camera; its sensitivity is separate from the mouse.

---

## Movement

| Action              | Keyboard / Mouse       | Controller        |
| ------------------- | ---------------------- | ----------------- |
| Move                | `W` `A` `S` `D` / arrows | Left stick      |
| Look                | Mouse                  | Right stick       |
| Sprint              | `Shift` *(hold)*       | L3                |
| Crouch              | `Ctrl` or `C` *(hold)* | B                 |
| Jump / Mantle       | `Space`                | A                 |
| Dodge               | `Alt`                  | LB                |
| Recentre camera     | `V`                    | D-Down            |

**Mantling** is automatic: jump toward a ledge between 0.55 m and 1.85 m and you
will pull yourself up.

**Climbing**: approach a surface with visible handholds and press *Interact* to
grab it. Move with the stick or `WASD`. Grip drains while you climb — the HUD
shows a **GRIP** bar. `Space` pushes off; *Crouch* drops.

**Rolling**: press *Crouch* within a fraction of a second of landing to roll.
A roll cancels all impact damage and keeps your momentum. The window widens with
the **Soft Landing** upgrade.

**Swimming**: entering deep water switches to swim mode. `Space` rises,
*Crouch* dives. An **AIR** bar appears when your head is under; it refills at
the surface.

---

## The Veilforge Device

| Action                 | Keyboard / Mouse            | Controller |
| ---------------------- | --------------------------- | ---------- |
| Aim veil field         | Right mouse *(hold)*        | LT         |
| Shift reality          | Left mouse                  | RT         |
| Previous state         | Wheel down / `1`            | D-Left     |
| Next state             | Wheel up / `2`              | D-Right    |
| Pin field in place     | `F`                         | R3         |
| Scan                   | `Q` *(hold)*                | Y          |
| Imprint property       | `R`                         | D-Up       |
| EMP pulse              | `G` / middle mouse          | RB         |

**Aiming** projects the field to whatever you are looking at, up to the Device's
range. The shell shows the state it will impose; the ground ring shows coverage.

**Shifting** commits: everything inside the field becomes the selected state.
This changes geometry, collision, materials, hazards, machine behaviour and
ambient sound — not just the colour.

**Pinning** leaves the field where it is so you can walk out of it. Pinned fields
expire (the shell flickers for the last three seconds). Only one pin at a time.
Press *Pin* again to release it early.

**Scanning** identifies an object, adds its field note to the record, and — if
the object carries one *in the state it is currently in* — records a **property**
you can carry. You hold three properties by default; **Deep Register** raises
that.

**Imprinting** applies your selected recorded property to a compatible object
you are standing next to. The property is consumed. A wrong target refuses and
wastes nothing except the attempt; a wrong *property* is spent.

**EMP** stuns nearby guardians for several seconds and trips some machinery.

Every Device action draws on the energy cell (**CELL** on the HUD). The cell
refills on its own after a short pause.

---

## Interaction and interface

| Action                   | Keyboard / Mouse | Controller |
| ------------------------ | ---------------- | ---------- |
| Interact                 | `E`              | X          |
| Ask MOTE for a hint      | `H`              | D-Down     |
| Codex / Upgrades         | `Tab`            | Back       |
| Pause                    | `Esc`            | Start      |

Some interactions are **hold** rather than press — a ring fills around the
reticle while you hold.

**Asking MOTE** always answers, whatever your hint level is set to, and always
refers to whatever you are nearest. It is never required.

---

## Hold vs toggle

Settings → Gameplay has independent hold/toggle switches for **Aim Field**,
**Sprint**, **Crouch** and **Scan**. With hold off, the action toggles on a
single press.

---

## Accessibility

Settings → Accessibility covers:

* **Subtitles** — on/off, four sizes, adjustable background opacity, speaker
  names on/off
* **Colour-blind state indicators** — switches Memory / Ruin / Bloom from
  cyan / amber / green to blue / white / magenta. Distinct glyphs (◆ ▲ ●) are
  shown next to every state readout regardless of this setting, so state is
  never carried by colour alone
* **High-contrast interaction markers** — adds a dark backing behind the reticle
  and interaction prompts
* **Reduce camera shake** — 0 to 1, where 1 removes camera shake entirely
* **Reduce flashing effects** — suppresses lightning flashes, damage flashes and
  screen strobes
* **Interface scale** — 0.8 to 1.6
* **Always show control prompts** — tutorial prompts normally retire once you
  have used an action a few times; this keeps them permanently

Settings → Gameplay also has **Difficulty** (Explorer / Field Agent / Chief
Engineer) and **Puzzle Hints** (Off / Subtle / Guided / Directed), both of which
can be changed at any time, including mid-chapter.

---

## HUD reference

| Element                 | Meaning                                               |
| ----------------------- | ----------------------------------------------------- |
| **CELL** (blue bar)     | Device energy. Turns red below 22%.                   |
| **SHIELD** (green bar)  | Damage you can absorb. Regenerates after a pause.     |
| **AIR** (appears in water) | Breath remaining.                                  |
| **GRIP** (appears while climbing) | Climbing stamina.                           |
| Bottom-right chips      | The three states; the selected one is highlighted.    |
| Property chips          | Recorded properties; the outlined one is selected.    |
| Top-left panel          | Current objective.                                    |
| Top-right              | Player level and XP progress.                          |
| Centre-top bar          | Guardian awareness — it fills as one notices you.     |
