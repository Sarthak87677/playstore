extends Node
## Tutorial prompts and MOTE's contextual hint system.
##
## A tutorial prompt shows until the player demonstrably performs the action the
## required number of times, then is marked learned for that profile and never
## shown again (unless "always show prompts" is on in accessibility settings).

signal tutorial_shown(id: String, text: String, action: String)
signal tutorial_cleared(id: String)
signal hint_offered(text: String, level: int)
signal objective_changed(text: String)

const TUTORIALS := {
	"move":     {"text": "Move with %s / %s / %s / %s", "actions": ["move_forward", "move_left", "move_back", "move_right"], "count": 40},
	"look":     {"text": "Look around with the mouse or right stick", "actions": [], "count": 1},
	"sprint":   {"text": "Hold %s to sprint", "actions": ["sprint"], "count": 3},
	"jump":     {"text": "Press %s to jump. Hold toward a ledge to mantle", "actions": ["jump"], "count": 4},
	"crouch":   {"text": "Hold %s to crouch. Press it just after landing to roll", "actions": ["crouch"], "count": 3},
	"climb":    {"text": "Approach marked handholds and press %s to climb", "actions": ["interact"], "count": 2},
	"interact": {"text": "Press %s to interact", "actions": ["interact"], "count": 3},
	"scan":     {"text": "Hold %s to scan. Scanning records a property you can carry", "actions": ["scan"], "count": 3},
	"veil_aim": {"text": "Hold %s to project the veil field", "actions": ["veil_aim"], "count": 3},
	"veil_shift": {"text": "With the field placed, press %s to shift everything inside it", "actions": ["veil_shift"], "count": 4},
	"veil_cycle": {"text": "Use %s / %s to choose Memory, Ruin or Bloom", "actions": ["veil_prev", "veil_next"], "count": 4},
	"veil_pin": {"text": "Press %s to pin the field in place and walk away from it", "actions": ["veil_pin"], "count": 2},
	"imprint":  {"text": "Press %s to imprint a recorded property onto a compatible object", "actions": ["imprint"], "count": 2},
	"emp":      {"text": "Press %s to fire an EMP pulse and stun nearby guardians", "actions": ["emp"], "count": 2},
	"dodge":    {"text": "Press %s to dodge", "actions": ["dodge"], "count": 2},
	"mote":     {"text": "Press %s to ask MOTE for a hint", "actions": ["mote_hint"], "count": 1},
	"codex":    {"text": "Press %s for upgrades, collectibles and objectives", "actions": ["codex"], "count": 1},
	"energy":   {"text": "Veil actions drain the cell. It refills when you stop using it", "actions": [], "count": 1},
	"water":    {"text": "You cannot breathe underwater forever. Watch the air gauge", "actions": [], "count": 1},
	"guardian": {"text": "Guardians see in a cone. Break line of sight, or stun them", "actions": [], "count": 1},
}

var _active: Dictionary = {}      # id -> {progress:int, shown_at:float}
var _current: String = ""
var objective: String = ""

# Hint context is registered by whatever the player is currently near.
var _context_stack: Array = []    # [{ "id":..., "lines":[subtle, guided, directed], "priority":int }]
var _last_hint_time := 0.0
var _idle_timer := 0.0
var _last_progress_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func learned() -> Dictionary:
	if not (GameState.data.get("tutorials") is Dictionary):
		GameState.data["tutorials"] = {}
	return GameState.data["tutorials"]

func is_learned(id: String) -> bool:
	if Settings.always_show_prompts:
		return false
	return bool(learned().get(id, false))

func reset_tutorials() -> void:
	GameState.data["tutorials"] = {}
	_active.clear()

## Ask for a tutorial prompt. No-op if already learned or already showing.
func request(id: String) -> void:
	if not TUTORIALS.has(id) or is_learned(id) or _active.has(id):
		return
	var t: Dictionary = TUTORIALS[id]
	_active[id] = {"progress": 0}
	_current = id
	tutorial_shown.emit(id, format_text(id), _first_action(id))

func format_text(id: String) -> String:
	var t: Dictionary = TUTORIALS[id]
	var txt := String(t.text)
	var acts: Array = t.actions
	if acts.is_empty():
		return txt
	var keys: Array = []
	for a in acts:
		keys.append("[%s]" % Settings.binding_text(String(a)))
	if txt.count("%s") == keys.size():
		return txt % keys
	return txt % [keys[0]] if txt.count("%s") == 1 else txt

func _first_action(id: String) -> String:
	var acts: Array = TUTORIALS[id].actions
	return String(acts[0]) if acts.size() > 0 else ""

## Called by gameplay code whenever the player performs a trackable action.
func did(id: String, amount: int = 1) -> void:
	if not _active.has(id):
		if TUTORIALS.has(id) and not is_learned(id):
			learned()[id] = true
		return
	var st: Dictionary = _active[id]
	st.progress = int(st.progress) + amount
	if st.progress >= int(TUTORIALS[id].count):
		_active.erase(id)
		learned()[id] = true
		tutorial_cleared.emit(id)
		if _current == id:
			_current = ""

func active_prompt() -> String:
	if _current != "" and _active.has(_current):
		return format_text(_current)
	for id in _active.keys():
		return format_text(id)
	return ""

# ================================================================ objectives
func set_objective(text: String) -> void:
	if objective == text:
		return
	objective = text
	_last_progress_time = Time.get_ticks_msec() / 1000.0
	objective_changed.emit(text)

func note_progress() -> void:
	_last_progress_time = Time.get_ticks_msec() / 1000.0
	_idle_timer = 0.0

# ================================================================ contextual hints
func push_context(id: String, lines: Array, priority: int = 0) -> void:
	for c in _context_stack:
		if c.id == id:
			c.lines = lines
			c.priority = priority
			return
	_context_stack.append({"id": id, "lines": lines, "priority": priority})
	_context_stack.sort_custom(func(a, b): return int(a.priority) > int(b.priority))

func pop_context(id: String) -> void:
	for i in range(_context_stack.size() - 1, -1, -1):
		if _context_stack[i].id == id:
			_context_stack.remove_at(i)

func clear_contexts() -> void:
	_context_stack.clear()

func best_context() -> Dictionary:
	return _context_stack[0] if _context_stack.size() > 0 else {}

## Player pressed the hint key. Always answers, regardless of hint level.
func request_hint() -> String:
	var ctx := best_context()
	var level: int = maxi(Settings.hint_level, Veil.HintLevel.GUIDED)
	var line := ""
	if ctx.is_empty():
		line = "Nothing near you needs the device. Try the objective marker." \
			if objective == "" else "Objective: %s" % objective
	else:
		var lines: Array = ctx.lines
		var idx: int = clampi(level - 1, 0, lines.size() - 1)
		line = String(lines[idx])
	GameState.run["hint_uses"] = int(GameState.run.get("hint_uses", 0)) + 1
	_last_hint_time = Time.get_ticks_msec() / 1000.0
	hint_offered.emit(line, level)
	return line

## Automatic nudge when the player has been stuck for a while.
func _process(dt: float) -> void:
	if Settings.hint_level <= Veil.HintLevel.OFF:
		return
	if not GameState.run.get("active", false) or GameState.run.get("paused", false):
		return
	_idle_timer += dt
	var threshold: float = [999.0, 95.0, 62.0, 38.0][clampi(Settings.hint_level, 0, 3)]
	var now := Time.get_ticks_msec() / 1000.0
	if _idle_timer >= threshold and now - _last_hint_time > 30.0:
		_idle_timer = 0.0
		var ctx := best_context()
		if not ctx.is_empty():
			var lines: Array = ctx.lines
			var idx: int = clampi(Settings.hint_level - 1, 0, lines.size() - 1)
			_last_hint_time = now
			hint_offered.emit(String(lines[idx]), Settings.hint_level)
