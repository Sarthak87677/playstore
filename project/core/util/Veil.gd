extends RefCounted
class_name Veil
## Global constants, enums and shared vocabulary for VEILFORGE.
## Pure data + static helpers; never instantiated at runtime.

# ---------------------------------------------------------------- reality states
enum State { MEMORY = 0, RUIN = 1, BLOOM = 2 }

const STATE_COUNT := 3
const STATE_NAMES := ["Memory", "Ruin", "Bloom"]
const STATE_SHORT := ["MEM", "RUI", "BLM"]

## Base hues. Colour-blind safe variants are supplied by Settings.
const STATE_COLORS := [
	Color(0.55, 0.78, 1.00),   # Memory  - cold cyan/blue
	Color(1.00, 0.58, 0.28),   # Ruin    - amber/rust
	Color(0.44, 0.94, 0.55),   # Bloom   - vivid green
]
## High-contrast / deuteranopia-friendly alternates (blue / white / magenta).
const STATE_COLORS_CB := [
	Color(0.40, 0.68, 1.00),
	Color(0.98, 0.98, 0.92),
	Color(0.92, 0.42, 0.95),
]
## Distinct glyphs so state is readable without colour at all.
const STATE_GLYPHS := ["◆", "▲", "●"]  # diamond, triangle, circle

# ---------------------------------------------------------------- physics layers
const L_WORLD := 1 << 0
const L_PLAYER := 1 << 1
const L_PROP := 1 << 2
const L_GUARDIAN := 1 << 3
const L_TRIGGER := 1 << 4
const L_HAZARD := 1 << 5
const L_WATER := 1 << 6
const L_CLIMB := 1 << 7
const L_INTERACT := 1 << 8

# ---------------------------------------------------------------- recordable properties
enum Prop { NONE, CONDUCTIVE, BUOYANT, RIGID, LUMINOUS, GROWING, FROZEN, RESONANT, HOLLOW }

const PROP_NAMES := [
	"None", "Conductive", "Buoyant", "Rigid", "Luminous", "Growing", "Frozen", "Resonant", "Hollow"
]
const PROP_DESC := [
	"",
	"Carries a live current across its length.",
	"Displaces more than it weighs; rises through water.",
	"Holds its shape under load without deforming.",
	"Emits steady light without an external source.",
	"Extends toward anchor points over time.",
	"Locked in a solid lattice; will not flow or bend.",
	"Answers the Veilforge carrier tone and holds the note.",
	"Contains a sealed void; can be filled or vented.",
]
const PROP_COLORS := [
	Color(0.5, 0.5, 0.5),
	Color(1.00, 0.85, 0.35),
	Color(0.40, 0.80, 1.00),
	Color(0.80, 0.80, 0.86),
	Color(1.00, 0.95, 0.70),
	Color(0.50, 0.95, 0.45),
	Color(0.72, 0.92, 1.00),
	Color(0.85, 0.55, 1.00),
	Color(0.65, 0.62, 0.58),
]

# ---------------------------------------------------------------- surfaces (footsteps / decals)
enum Surface { STONE, METAL, GLASS, WATER, SNOW, SAND, FOLIAGE, WOOD, RESIN }
const SURFACE_NAMES := ["stone", "metal", "glass", "water", "snow", "sand", "foliage", "wood", "resin"]

# ---------------------------------------------------------------- upgrades
enum Branch { RESONANCE, MOBILITY, ENGINEERING }
const BRANCH_NAMES := ["Resonance", "Mobility", "Engineering"]
const BRANCH_DESC := [
	"Widen the veil field, spend less energy, hold states longer.",
	"Climb further, steer harder in air, recover faster from falls.",
	"Sharper EMP, faster scanning, quicker cell regeneration.",
]
const BRANCH_COLORS := [Color(0.55, 0.78, 1.0), Color(0.45, 0.95, 0.62), Color(1.0, 0.72, 0.32)]

# ---------------------------------------------------------------- difficulty
enum Difficulty { EXPLORER, FIELD, ENGINEER }
const DIFFICULTY_NAMES := ["Explorer", "Field Agent", "Chief Engineer"]
const DIFFICULTY_DESC := [
	"Story-focused. Guardians are slow to notice you, hazards forgive mistakes.",
	"The intended balance of exploration, puzzles and tension.",
	"Guardians are alert and relentless. Energy is scarce. Hazards bite.",
]

# ---------------------------------------------------------------- hint levels
enum HintLevel { OFF, SUBTLE, GUIDED, DIRECTED }
const HINT_NAMES := ["Off", "Subtle", "Guided", "Directed"]

# ---------------------------------------------------------------- ranks
const RANK_NAMES := ["C", "B", "A", "S"]
const RANK_COLORS := [
	Color(0.68, 0.70, 0.72), Color(0.62, 0.84, 1.0),
	Color(1.0, 0.84, 0.40), Color(1.0, 0.55, 0.85)
]

# ---------------------------------------------------------------- progression
const MAX_LEVEL := 30

## Cumulative XP required to *reach* a given level (index 0 unused).
static func xp_for_level(lv: int) -> int:
	if lv <= 1:
		return 0
	# Smooth quadratic-ish curve: level 30 lands near 60k.
	var n := float(lv - 1)
	return int(round(120.0 * n + 62.0 * n * n))

static func level_for_xp(xp: int) -> int:
	var lv := 1
	while lv < MAX_LEVEL and xp >= xp_for_level(lv + 1):
		lv += 1
	return lv

# ---------------------------------------------------------------- helpers
static func state_name(s: int) -> String:
	return STATE_NAMES[clampi(s, 0, 2)]

static func state_color(s: int, colorblind: bool = false) -> Color:
	var i := clampi(s, 0, 2)
	return STATE_COLORS_CB[i] if colorblind else STATE_COLORS[i]

static func state_glyph(s: int) -> String:
	return STATE_GLYPHS[clampi(s, 0, 2)]

static func prop_name(p: int) -> String:
	return PROP_NAMES[clampi(p, 0, PROP_NAMES.size() - 1)]

static func format_time(sec: float) -> String:
	var t := maxf(0.0, sec)
	var m := int(t) / 60
	var s := int(t) % 60
	var cs := int((t - floorf(t)) * 100.0)
	return "%02d:%02d.%02d" % [m, s, cs]

static func format_clock(sec: float) -> String:
	var t := int(maxf(0.0, sec))
	var h := t / 3600
	var m := (t % 3600) / 60
	var s := t % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]
