extends Node
## Persistent user settings: video, audio, gameplay, accessibility and a full
## rebindable input map. Stored at user://settings.cfg (ConfigFile, plain text).

signal video_changed
signal audio_changed
signal accessibility_changed
signal bindings_changed

const PATH := "user://settings.cfg"
const CFG_VERSION := 3

# ---- graphics presets -------------------------------------------------------
enum Preset { LOW, MEDIUM, HIGH, CINEMATIC, CUSTOM }
const PRESET_NAMES := ["Low", "Medium", "High", "Cinematic", "Custom"]

## Per-preset renderer knobs consumed by WorldEnvironment / Weather / Vegetation.
const PRESET_DATA := [
	{   # LOW
		"scale3d": 0.75, "msaa": 0, "ssaa": 0, "shadow_size": 2048, "shadow_quality": 0,
		"sdfgi": false, "ssao": false, "ssil": false, "ssr": false, "volumetric": false,
		"fog": true, "glow": false, "dof": false, "veg_density": 0.35, "veg_dist": 55.0,
		"particles": 0.35, "lod_bias": 2.4, "decals": false, "reflection_probes": false,
	},
	{   # MEDIUM
		"scale3d": 0.85, "msaa": 1, "ssaa": 1, "shadow_size": 3072, "shadow_quality": 1,
		"sdfgi": false, "ssao": true, "ssil": false, "ssr": false, "volumetric": true,
		"fog": true, "glow": true, "dof": false, "veg_density": 0.6, "veg_dist": 85.0,
		"particles": 0.65, "lod_bias": 1.6, "decals": true, "reflection_probes": true,
	},
	{   # HIGH
		"scale3d": 1.0, "msaa": 1, "ssaa": 1, "shadow_size": 4096, "shadow_quality": 3,
		"sdfgi": true, "ssao": true, "ssil": false, "ssr": true, "volumetric": true,
		"fog": true, "glow": true, "dof": true, "veg_density": 1.0, "veg_dist": 130.0,
		"particles": 1.0, "lod_bias": 1.0, "decals": true, "reflection_probes": true,
	},
	{   # CINEMATIC
		"scale3d": 1.0, "msaa": 2, "ssaa": 1, "shadow_size": 8192, "shadow_quality": 4,
		"sdfgi": true, "ssao": true, "ssil": true, "ssr": true, "volumetric": true,
		"fog": true, "glow": true, "dof": true, "veg_density": 1.45, "veg_dist": 190.0,
		"particles": 1.4, "lod_bias": 0.7, "decals": true, "reflection_probes": true,
	},
]

# ---- video ------------------------------------------------------------------
var preset: int = Preset.HIGH
var custom: Dictionary = {}
var resolution: Vector2i = Vector2i(1920, 1080)
var window_mode: int = 0            # 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
var vsync: bool = true
var fps_limit: int = 0              # 0 = uncapped
var brightness: float = 1.0
var fov: float = 68.0
var motion_blur: float = 0.0        # 0..1 (default off; tasteful cap at 0.4 internally)
var show_fps: bool = false

# ---- audio ------------------------------------------------------------------
var vol_master: float = 0.85
var vol_music: float = 0.7
var vol_sfx: float = 0.9
var vol_ambience: float = 0.8
var vol_ui: float = 0.75

# ---- gameplay ---------------------------------------------------------------
var mouse_sensitivity: float = 0.28
var pad_sensitivity: float = 2.4
var invert_y: bool = false
var invert_x: bool = false
var vibration: bool = true
var vibration_strength: float = 0.8
var difficulty: int = Veil.Difficulty.FIELD
var hint_level: int = Veil.HintLevel.GUIDED
var aim_hold: bool = true           # true = hold to aim veil, false = toggle
var sprint_hold: bool = true
var crouch_hold: bool = true
var scan_hold: bool = true

# ---- accessibility ----------------------------------------------------------
var subtitles: bool = true
var subtitle_size: int = 1          # 0 small 1 medium 2 large 3 huge
var subtitle_background: float = 0.55
var subtitle_speaker: bool = true
var colorblind_states: bool = false
var high_contrast_markers: bool = false
var reduce_camera_shake: float = 0.0    # 0 = full shake, 1 = none
var reduce_flashing: bool = false
var ui_scale: float = 1.0
var always_show_prompts: bool = false

# ---- input ------------------------------------------------------------------
var bindings: Dictionary = {}       # action -> Array[Dictionary] serialised events

const ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "sprint", "crouch", "dodge",
	"interact", "scan", "imprint", "emp",
	"veil_aim", "veil_shift", "veil_pin", "veil_prev", "veil_next",
	"mote_hint", "pause", "codex", "photo_reset",
]
const ACTION_LABELS := {
	"move_forward": "Move Forward", "move_back": "Move Back",
	"move_left": "Move Left", "move_right": "Move Right",
	"jump": "Jump / Mantle", "sprint": "Sprint", "crouch": "Crouch / Roll",
	"dodge": "Dodge", "interact": "Interact", "scan": "Scan",
	"imprint": "Imprint Property", "emp": "EMP Pulse",
	"veil_aim": "Aim Veil Field", "veil_shift": "Shift Reality",
	"veil_pin": "Pin Field", "veil_prev": "Previous State", "veil_next": "Next State",
	"mote_hint": "Ask MOTE", "pause": "Pause", "codex": "Codex / Upgrades",
	"photo_reset": "Recentre Camera",
}

var _defaults: Dictionary = {}
var _loaded_ok := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_default_bindings()
	load_settings()
	apply_all()

# =============================================================== input defaults
func _key(kc: int) -> Dictionary:
	return {"type": "key", "code": kc}

func _mb(b: int) -> Dictionary:
	return {"type": "mouse", "button": b}

func _jb(b: int) -> Dictionary:
	return {"type": "joy_button", "button": b}

func _ja(axis: int, dir: float) -> Dictionary:
	return {"type": "joy_axis", "axis": axis, "dir": dir}

func _build_default_bindings() -> void:
	_defaults = {
		"move_forward": [_key(KEY_W), _key(KEY_UP), _ja(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back":    [_key(KEY_S), _key(KEY_DOWN), _ja(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left":    [_key(KEY_A), _key(KEY_LEFT), _ja(JOY_AXIS_LEFT_X, -1.0)],
		"move_right":   [_key(KEY_D), _key(KEY_RIGHT), _ja(JOY_AXIS_LEFT_X, 1.0)],
		"jump":         [_key(KEY_SPACE), _jb(JOY_BUTTON_A)],
		"sprint":       [_key(KEY_SHIFT), _jb(JOY_BUTTON_LEFT_STICK)],
		"crouch":       [_key(KEY_CTRL), _key(KEY_C), _jb(JOY_BUTTON_B)],
		"dodge":        [_key(KEY_ALT), _jb(JOY_BUTTON_LEFT_SHOULDER)],
		"interact":     [_key(KEY_E), _jb(JOY_BUTTON_X)],
		"scan":         [_key(KEY_Q), _jb(JOY_BUTTON_Y)],
		"imprint":      [_key(KEY_R), _jb(JOY_BUTTON_DPAD_UP)],
		"emp":          [_key(KEY_G), _mb(MOUSE_BUTTON_MIDDLE), _jb(JOY_BUTTON_RIGHT_SHOULDER)],
		"veil_aim":     [_mb(MOUSE_BUTTON_RIGHT), _ja(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"veil_shift":   [_mb(MOUSE_BUTTON_LEFT), _ja(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"veil_pin":     [_key(KEY_F), _jb(JOY_BUTTON_RIGHT_STICK)],
		"veil_prev":    [_mb(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_1), _jb(JOY_BUTTON_DPAD_LEFT)],
		"veil_next":    [_mb(MOUSE_BUTTON_WHEEL_UP), _key(KEY_2), _jb(JOY_BUTTON_DPAD_RIGHT)],
		"mote_hint":    [_key(KEY_H), _jb(JOY_BUTTON_DPAD_DOWN)],
		"pause":        [_key(KEY_ESCAPE), _jb(JOY_BUTTON_START)],
		"codex":        [_key(KEY_TAB), _jb(JOY_BUTTON_BACK)],
		"photo_reset":  [_key(KEY_V), _jb(JOY_BUTTON_DPAD_DOWN)],
	}
	bindings = _defaults.duplicate(true)

func _event_from_dict(d: Dictionary) -> InputEvent:
	match String(d.get("type", "")):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d.code)
			return e
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.button)
			return m
		"joy_button":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d.button)
			return j
		"joy_axis":
			var a := InputEventJoypadMotion.new()
			a.axis = int(d.axis)
			a.axis_value = float(d.dir)
			return a
	return null

func event_display_name(d: Dictionary) -> String:
	match String(d.get("type", "")):
		"key":
			# Physical-to-label mapping needs a real display server.
			if DisplayServer.get_name() == "headless":
				return OS.get_keycode_string(int(d.code))
			return OS.get_keycode_string(
				DisplayServer.keyboard_get_keycode_from_physical(int(d.code)))
		"mouse":
			match int(d.button):
				MOUSE_BUTTON_LEFT: return "Mouse Left"
				MOUSE_BUTTON_RIGHT: return "Mouse Right"
				MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
				MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
				MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
				_: return "Mouse %d" % int(d.button)
		"joy_button":
			const NAMES := {
				0: "Pad A", 1: "Pad B", 2: "Pad X", 3: "Pad Y", 4: "Pad Back",
				5: "Pad Guide", 6: "Pad Start", 7: "L3", 8: "R3",
				9: "LB", 10: "RB", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"}
			return NAMES.get(int(d.button), "Pad %d" % int(d.button))
		"joy_axis":
			var ax := int(d.axis)
			var pos: bool = float(d.dir) > 0.0
			match ax:
				JOY_AXIS_LEFT_X: return "Stick Right" if pos else "Stick Left"
				JOY_AXIS_LEFT_Y: return "Stick Down" if pos else "Stick Up"
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
				_: return "Axis %d%s" % [ax, "+" if pos else "-"]
	return "?"

func binding_text(action: String, kb_only: bool = false) -> String:
	var list: Array = bindings.get(action, [])
	for d in list:
		if kb_only and String(d.get("type", "")) not in ["key", "mouse"]:
			continue
		return event_display_name(d)
	return "--"

func apply_bindings() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.32)
		InputMap.action_erase_events(a)
		for d in bindings.get(a, []):
			var ev := _event_from_dict(d)
			if ev:
				InputMap.action_add_event(a, ev)
	bindings_changed.emit()

func rebind(action: String, ev: InputEvent, slot: int) -> bool:
	var d: Dictionary = {}
	if ev is InputEventKey:
		d = _key((ev as InputEventKey).physical_keycode)
	elif ev is InputEventMouseButton:
		d = _mb((ev as InputEventMouseButton).button_index)
	elif ev is InputEventJoypadButton:
		d = _jb((ev as InputEventJoypadButton).button_index)
	elif ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		if absf(m.axis_value) < 0.6:
			return false
		d = _ja(m.axis, signf(m.axis_value))
	else:
		return false
	var list: Array = bindings.get(action, []).duplicate()
	while list.size() <= slot:
		list.append(null)
	list[slot] = d
	bindings[action] = list.filter(func(x): return x != null)
	apply_bindings()
	save_settings()
	return true

func reset_bindings() -> void:
	bindings = _defaults.duplicate(true)
	apply_bindings()
	save_settings()

# ================================================================ apply
func preset_data() -> Dictionary:
	if preset == Preset.CUSTOM:
		var base: Dictionary = PRESET_DATA[Preset.HIGH].duplicate()
		base.merge(custom, true)
		return base
	return PRESET_DATA[clampi(preset, 0, 3)]

func apply_all() -> void:
	apply_bindings()
	apply_video()
	apply_audio()
	accessibility_changed.emit()

func apply_video() -> void:
	var w := get_window()
	if w == null:
		return
	match window_mode:
		0:
			w.mode = Window.MODE_WINDOWED
			w.borderless = false
			var scr := DisplayServer.screen_get_size()
			var target := Vector2i(mini(resolution.x, scr.x), mini(resolution.y, scr.y))
			if target.x > 0 and target.y > 0:
				w.size = target
				w.move_to_center()
		1:
			w.borderless = true
			w.mode = Window.MODE_FULLSCREEN
		2:
			w.borderless = false
			w.mode = Window.MODE_EXCLUSIVE_FULLSCREEN

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit

	var d := preset_data()
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(d.scale3d)
		vp.msaa_3d = int(d.msaa) as Viewport.MSAA
		vp.screen_space_aa = int(d.ssaa) as Viewport.ScreenSpaceAA
		vp.use_debanding = true
	RenderingServer.directional_shadow_atlas_set_size(int(d.shadow_size), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		int(d.shadow_quality) as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		int(d.shadow_quality) as RenderingServer.ShadowQuality)
	video_changed.emit()

func apply_audio() -> void:
	_set_bus("Master", vol_master)
	_set_bus("Music", vol_music)
	_set_bus("SFX", vol_sfx)
	_set_bus("Ambience", vol_ambience)
	_set_bus("UI", vol_ui)
	audio_changed.emit()

func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var vol := clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, vol <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.0001)))

func subtitle_font_size() -> int:
	return [20, 26, 34, 44][clampi(subtitle_size, 0, 3)]

func state_color(s: int) -> Color:
	return Veil.state_color(s, colorblind_states)

func shake_scale() -> float:
	return clampf(1.0 - reduce_camera_shake, 0.0, 1.0)

# ================================================================ persistence
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", CFG_VERSION)
	for section_key in _schema().keys():
		for k in _schema()[section_key]:
			cfg.set_value(section_key, k, get(k))
	cfg.set_value("input", "bindings", JSON.stringify(bindings))
	var e := cfg.save(PATH)
	if e != OK:
		Log.warn("Could not save settings (%d)" % e)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		Log.info("No settings file; using defaults.")
		_loaded_ok = false
		return
	for section_key in _schema().keys():
		for k in _schema()[section_key]:
			if cfg.has_section_key(section_key, k):
				var v: Variant = cfg.get_value(section_key, k)
				var cur: Variant = get(k)
				# Type-guard: never let a hand-edited file inject a wrong type.
				if typeof(v) == typeof(cur):
					set(k, v)
				elif typeof(cur) == TYPE_FLOAT and typeof(v) == TYPE_INT:
					set(k, float(v))
				elif typeof(cur) == TYPE_INT and typeof(v) == TYPE_FLOAT:
					set(k, int(v))
	if cfg.has_section_key("input", "bindings"):
		var parsed: Variant = JSON.parse_string(String(cfg.get_value("input", "bindings", "")))
		if parsed is Dictionary:
			var merged: Dictionary = _defaults.duplicate(true)
			for a in (parsed as Dictionary).keys():
				if a in ACTIONS and (parsed[a] is Array):
					merged[a] = parsed[a]
			bindings = merged
	_clamp_ranges()
	_loaded_ok = true
	Log.info("Settings loaded.")

func _clamp_ranges() -> void:
	preset = clampi(preset, 0, 4)
	window_mode = clampi(window_mode, 0, 2)
	brightness = clampf(brightness, 0.5, 1.8)
	fov = clampf(fov, 55.0, 105.0)
	motion_blur = clampf(motion_blur, 0.0, 1.0)
	vol_master = clampf(vol_master, 0.0, 1.0)
	vol_music = clampf(vol_music, 0.0, 1.0)
	vol_sfx = clampf(vol_sfx, 0.0, 1.0)
	vol_ambience = clampf(vol_ambience, 0.0, 1.0)
	vol_ui = clampf(vol_ui, 0.0, 1.0)
	mouse_sensitivity = clampf(mouse_sensitivity, 0.02, 1.5)
	pad_sensitivity = clampf(pad_sensitivity, 0.4, 8.0)
	difficulty = clampi(difficulty, 0, 2)
	hint_level = clampi(hint_level, 0, 3)
	subtitle_size = clampi(subtitle_size, 0, 3)
	subtitle_background = clampf(subtitle_background, 0.0, 1.0)
	reduce_camera_shake = clampf(reduce_camera_shake, 0.0, 1.0)
	ui_scale = clampf(ui_scale, 0.8, 1.6)
	vibration_strength = clampf(vibration_strength, 0.0, 1.0)
	resolution.x = clampi(resolution.x, 640, 7680)
	resolution.y = clampi(resolution.y, 480, 4320)

## Controller haptics. Every rumble in the game routes through here, so the
## on/off switch and the strength slider actually reach the pad instead of
## being stored and ignored. Reduced camera shake also damps haptics, since a
## player who turns shake down is usually asking for less physical feedback.
func haptic_magnitude(base: float) -> float:
	if not vibration:
		return 0.0
	return clampf(base * vibration_strength * (1.0 - reduce_camera_shake * 0.7), 0.0, 1.0)

func rumble(weak: float, strong: float, duration: float) -> int:
	var w := haptic_magnitude(weak)
	var st := haptic_magnitude(strong)
	if w <= 0.0 and st <= 0.0:
		return 0
	var pads := Input.get_connected_joypads()
	for d in pads:
		Input.start_joy_vibration(int(d), w, st, duration)
	return pads.size()

func reset_to_defaults() -> void:
	preset = Preset.HIGH; custom = {}
	resolution = Vector2i(1920, 1080); window_mode = 0; vsync = true; fps_limit = 0
	brightness = 1.0; fov = 68.0; motion_blur = 0.0; show_fps = false
	vol_master = 0.85; vol_music = 0.7; vol_sfx = 0.9; vol_ambience = 0.8; vol_ui = 0.75
	mouse_sensitivity = 0.28; pad_sensitivity = 2.4; invert_y = false; invert_x = false
	vibration = true; vibration_strength = 0.8
	difficulty = Veil.Difficulty.FIELD; hint_level = Veil.HintLevel.GUIDED
	aim_hold = true; sprint_hold = true; crouch_hold = true; scan_hold = true
	subtitles = true; subtitle_size = 1; subtitle_background = 0.55; subtitle_speaker = true
	colorblind_states = false; high_contrast_markers = false
	reduce_camera_shake = 0.0; reduce_flashing = false; ui_scale = 1.0
	always_show_prompts = false
	reset_bindings()
	apply_all()
	save_settings()

func _schema() -> Dictionary:
	return {
		"video": ["preset", "custom", "resolution", "window_mode", "vsync", "fps_limit",
			"brightness", "fov", "motion_blur", "show_fps"],
		"audio": ["vol_master", "vol_music", "vol_sfx", "vol_ambience", "vol_ui"],
		"gameplay": ["mouse_sensitivity", "pad_sensitivity", "invert_y", "invert_x",
			"vibration", "vibration_strength", "difficulty", "hint_level",
			"aim_hold", "sprint_hold", "crouch_hold", "scan_hold"],
		"access": ["subtitles", "subtitle_size", "subtitle_background", "subtitle_speaker",
			"colorblind_states", "high_contrast_markers", "reduce_camera_shake",
			"reduce_flashing", "ui_scale", "always_show_prompts"],
	}
