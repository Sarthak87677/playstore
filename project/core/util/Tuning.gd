extends RefCounted
class_name Tuning
## Central gameplay tuning. Every magic number that a designer would want to
## reach for lives here so balance passes touch exactly one file.

# ------------------------------------------------------------------ locomotion
const WALK_SPEED := 4.1
const SPRINT_SPEED := 7.4
const CROUCH_SPEED := 2.0
const AIR_CONTROL := 0.34
const ACCEL_GROUND := 14.0
const ACCEL_AIR := 4.2
const FRICTION := 13.0
const JUMP_VELOCITY := 7.2
const GRAVITY := 22.0
const TERMINAL_VELOCITY := 42.0
const COYOTE_TIME := 0.14
const JUMP_BUFFER := 0.16
const MANTLE_MAX_HEIGHT := 1.85
const MANTLE_MIN_HEIGHT := 0.55
const MANTLE_DURATION := 0.42
const CLIMB_SPEED := 2.6
const CLIMB_STAMINA := 9.0
const STEP_HEIGHT := 0.42
const SLOPE_LIMIT_DEG := 48.0
const CROUCH_HEIGHT := 1.05
const STAND_HEIGHT := 1.82
const LAND_SOFT := 6.0     # below this impact speed: no penalty
const LAND_HARD := 13.0    # above this: damage + stumble
const LAND_FATAL := 26.0
const ROLL_WINDOW := 0.22  # press crouch within this of landing to roll

# ------------------------------------------------------------------ camera
const CAM_DIST := 3.45
const CAM_DIST_AIM := 2.05
const CAM_HEIGHT := 1.62
const CAM_SHOULDER := 0.55
const CAM_FOV := 68.0
const CAM_FOV_SPRINT := 76.0
const CAM_FOV_AIM := 56.0
const CAM_PITCH_MIN := -62.0
const CAM_PITCH_MAX := 68.0
const CAM_LAG := 12.0
const CAM_ROT_LAG := 18.0

# ------------------------------------------------------------------ veil device
const FIELD_RADIUS_BASE := 6.0
const FIELD_RADIUS_PER_UP := 2.0
const FIELD_RANGE_BASE := 18.0
const FIELD_RANGE_PER_UP := 5.0
const ENERGY_MAX := 100.0
const ENERGY_REGEN := 11.0
const ENERGY_REGEN_PER_UP := 4.0
const ENERGY_REGEN_DELAY := 0.9
const SHIFT_COST := 14.0
const SHIFT_COST_REDUCTION_PER_UP := 2.6
const FIELD_HOLD_DRAIN := 5.5
const PIN_COST := 22.0
const PIN_DURATION_BASE := 12.0
const PIN_DURATION_PER_UP := 6.0
const SCAN_TIME := 1.15
const SCAN_TIME_PER_UP := -0.22
const SCAN_RANGE := 26.0
const IMPRINT_COST := 18.0
const RECORD_SLOTS := 3

# ------------------------------------------------------------------ combat / survival
const SHIELD_MAX := 100.0
const SHIELD_REGEN := 7.0
const SHIELD_REGEN_DELAY := 4.2
const EMP_COST := 26.0
const EMP_RADIUS_BASE := 5.5
const EMP_RADIUS_PER_UP := 1.6
const EMP_STUN_BASE := 4.0
const EMP_STUN_PER_UP := 1.4
const DODGE_COST := 8.0
const DODGE_DISTANCE := 4.2
const DODGE_DURATION := 0.34
const DODGE_IFRAMES := 0.24
const DODGE_COOLDOWN := 0.65

# ------------------------------------------------------------------ guardians
const GUARD_VIEW_DIST := [16.0, 22.0, 28.0]      # per difficulty
const GUARD_VIEW_ANGLE := [55.0, 66.0, 78.0]
const GUARD_NOTICE_TIME := [2.2, 1.35, 0.85]
const GUARD_PATROL_SPEED := 2.3
const GUARD_CHASE_SPEED := 5.1
const GUARD_PULSE_DAMAGE := [10.0, 17.0, 26.0]
const GUARD_PULSE_INTERVAL := [3.0, 2.1, 1.5]
const GUARD_SEARCH_TIME := 9.0
const GUARD_HEALTH := 100.0

# ------------------------------------------------------------------ xp awards
const XP_PUZZLE := 220
const XP_PUZZLE_PERFECT := 120
const XP_FRAGMENT := 300
const XP_SCAN_NEW := 45
const XP_HIDDEN_AREA := 260
const XP_WILDLIFE := 180
const XP_CHAPTER := 900
const XP_CHALLENGE := 700
const XP_NO_DAMAGE := 550
const XP_GHOST_BONUS := 40         # per guardian bypassed unseen
const XP_FIRST_DISCOVERY := 90
const XP_CHAIN_STEP := 0.12        # exploration chain multiplier per link
const XP_CHAIN_MAX := 2.0
const CHAIN_WINDOW := 26.0         # seconds to keep a discovery chain alive

# ------------------------------------------------------------------ hazards
const HAZ_SHARD_DAMAGE := 12.0
const HAZ_STEAM_DPS := 18.0
const HAZ_COLD_DPS := 6.0
const HAZ_HEAT_DPS := 9.0
const HAZ_ELECTRIC := 26.0
const DROWN_TIME := 22.0
const DROWN_DPS := 14.0

# ------------------------------------------------------------------ difficulty scaling
static func dmg_scale(diff: int) -> float:
	return [0.55, 1.0, 1.45][clampi(diff, 0, 2)]

static func energy_scale(diff: int) -> float:
	return [1.35, 1.0, 0.78][clampi(diff, 0, 2)]
