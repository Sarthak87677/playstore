extends Control
class_name SettingsPanel
## The full settings interface: Video, Audio, Gameplay, Accessibility and
## Controls (with live rebinding). Used by both the main menu and the pause
## menu so there is exactly one implementation.

signal closed()

var _tabs: TabContainer
var _rebinding := {"action": "", "slot": 0}
var _rebind_label: Label
var _rebind_overlay: Control
var _binding_rows: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, int(UITheme.s(90)))
	margin.add_theme_constant_override("margin_top", int(UITheme.s(52)))
	margin.add_theme_constant_override("margin_bottom", int(UITheme.s(52)))
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(UITheme.s(12)))
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_child(UITheme.title("SETTINGS", 38))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var back := UITheme.button("Back  [Esc]", 20)
	back.custom_minimum_size = Vector2(UITheme.s(180), UITheme.s(44))
	back.pressed.connect(_close)
	header.add_child(back)
	vb.add_child(header)
	vb.add_child(UITheme.hsep())

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", int(UITheme.s(19)))
	vb.add_child(_tabs)

	_tabs.add_child(_video_tab())
	_tabs.add_child(_audio_tab())
	_tabs.add_child(_gameplay_tab())
	_tabs.add_child(_access_tab())
	_tabs.add_child(_controls_tab())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", int(UITheme.s(14)))
	var reset := UITheme.button("Restore Defaults", 18)
	reset.custom_minimum_size = Vector2(UITheme.s(240), UITheme.s(42))
	reset.pressed.connect(func() -> void:
		Settings.reset_to_defaults()
		_rebuild())
	footer.add_child(reset)
	var note := UITheme.label(
		"Settings are stored locally in your user folder. The game never connects to the internet.",
		15, UITheme.TEXT_FAINT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(note)
	vb.add_child(footer)

	_rebind_overlay = Control.new()
	_rebind_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebind_overlay.visible = false
	_rebind_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rebind_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebind_overlay.add_child(dim)
	_rebind_label = UITheme.label("", 28, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_rebind_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_rebind_label.offset_left = -400
	_rebind_label.offset_right = 400
	_rebind_label.offset_top = -30
	_rebind_label.offset_bottom = 30
	_rebind_overlay.add_child(_rebind_label)

func _scroll(name_: String) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = name_
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.name = "List"
	v.add_theme_constant_override("separation", int(UITheme.s(10)))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return sc

func _list(sc: ScrollContainer) -> VBoxContainer:
	return sc.get_node("List") as VBoxContainer

# ---------------------------------------------------------------- video
const RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160)]

func _video_tab() -> ScrollContainer:
	var sc := _scroll("Video")
	var v := _list(sc)

	var res_names: Array = []
	var res_idx := 2
	for i in RESOLUTIONS.size():
		res_names.append("%d x %d" % [RESOLUTIONS[i].x, RESOLUTIONS[i].y])
		if RESOLUTIONS[i] == Settings.resolution:
			res_idx = i
	var res := UITheme.option(res_names, res_idx)
	res.item_selected.connect(func(i: int) -> void:
		Settings.resolution = RESOLUTIONS[i]
		Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Resolution", res, "Applies in windowed mode."))

	var wm := UITheme.option(["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"],
		Settings.window_mode)
	wm.item_selected.connect(func(i: int) -> void:
		Settings.window_mode = i; Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Display Mode", wm))

	var preset := UITheme.option(Settings.PRESET_NAMES, Settings.preset)
	preset.item_selected.connect(func(i: int) -> void:
		Settings.preset = i; Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Graphics Preset", preset,
		"Low / Medium / High / Cinematic scale shadows, GI, reflections, fog and vegetation."))

	var vs := UITheme.check(Settings.vsync)
	vs.toggled.connect(func(b: bool) -> void:
		Settings.vsync = b; Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("V-Sync", vs))

	var fps := UITheme.option(["Unlimited", "30", "60", "120", "144"],
		[0, 30, 60, 120, 144].find(Settings.fps_limit))
	fps.item_selected.connect(func(i: int) -> void:
		Settings.fps_limit = [0, 30, 60, 120, 144][i]
		Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Frame Rate Limit", fps))

	var fov := UITheme.slider(55.0, 105.0, 1.0, Settings.fov)
	fov.value_changed.connect(func(x: float) -> void:
		Settings.fov = x; Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Field of View", fov))

	var bright := UITheme.slider(0.5, 1.8, 0.01, Settings.brightness)
	bright.value_changed.connect(func(x: float) -> void:
		Settings.brightness = x; Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Brightness", bright))

	var mb := UITheme.slider(0.0, 1.0, 0.05, Settings.motion_blur)
	mb.value_changed.connect(func(x: float) -> void:
		Settings.motion_blur = x; Settings.apply_video(); Settings.save_settings())
	v.add_child(UITheme.row("Motion Blur", mb, "Off by default. Capped to a gentle amount."))

	var showfps := UITheme.check(Settings.show_fps)
	showfps.toggled.connect(func(b: bool) -> void:
		Settings.show_fps = b; Settings.save_settings())
	v.add_child(UITheme.row("Show Performance Readout", showfps))
	return sc

# ---------------------------------------------------------------- audio
func _audio_tab() -> ScrollContainer:
	var sc := _scroll("Audio")
	var v := _list(sc)
	var defs := [
		["Master Volume", "vol_master"], ["Music", "vol_music"],
		["Sound Effects", "vol_sfx"], ["Ambience", "vol_ambience"],
		["Interface", "vol_ui"]]
	for d in defs:
		var key := String(d[1])
		var s := UITheme.slider(0.0, 1.0, 0.01, float(Settings.get(key)))
		s.value_changed.connect(func(x: float) -> void:
			Settings.set(key, x); Settings.apply_audio(); Settings.save_settings())
		s.drag_ended.connect(func(_c: bool) -> void: AudioDirector.play_ui("ui_click", -14.0))
		v.add_child(UITheme.row(String(d[0]), s))
	v.add_child(UITheme.spacer(12))
	var test := UITheme.button("Test Sound", 18)
	test.custom_minimum_size = Vector2(UITheme.s(200), UITheme.s(40))
	test.pressed.connect(func() -> void: AudioDirector.play("puzzle_solved", -6.0))
	v.add_child(test)
	return sc

# ---------------------------------------------------------------- gameplay
func _gameplay_tab() -> ScrollContainer:
	var sc := _scroll("Gameplay")
	var v := _list(sc)

	var diff := UITheme.option(Veil.DIFFICULTY_NAMES, Settings.difficulty)
	diff.item_selected.connect(func(i: int) -> void:
		Settings.difficulty = i
		if GameState.has_profile():
			GameState.data.difficulty = i
			GameState.save()
		Settings.save_settings())
	v.add_child(UITheme.row("Difficulty", diff, Veil.DIFFICULTY_DESC[Settings.difficulty]))

	var hint := UITheme.option(Veil.HINT_NAMES, Settings.hint_level)
	hint.item_selected.connect(func(i: int) -> void:
		Settings.hint_level = i; Settings.save_settings())
	v.add_child(UITheme.row("Puzzle Hints", hint,
		"Off, Subtle, Guided or Directed. Asking MOTE always answers regardless."))

	var ms := UITheme.slider(0.02, 1.5, 0.01, Settings.mouse_sensitivity)
	ms.value_changed.connect(func(x: float) -> void:
		Settings.mouse_sensitivity = x; Settings.save_settings())
	v.add_child(UITheme.row("Mouse Sensitivity", ms))

	var ps := UITheme.slider(0.4, 8.0, 0.1, Settings.pad_sensitivity)
	ps.value_changed.connect(func(x: float) -> void:
		Settings.pad_sensitivity = x; Settings.save_settings())
	v.add_child(UITheme.row("Controller Sensitivity", ps))

	for d in [["Invert Vertical Look", "invert_y"], ["Invert Horizontal Look", "invert_x"],
			["Controller Vibration", "vibration"], ["Hold to Aim Field", "aim_hold"],
			["Hold to Sprint", "sprint_hold"], ["Hold to Crouch", "crouch_hold"],
			["Hold to Scan", "scan_hold"]]:
		var key := String(d[1])
		var c := UITheme.check(bool(Settings.get(key)))
		c.toggled.connect(func(b: bool) -> void:
			Settings.set(key, b); Settings.save_settings())
		v.add_child(UITheme.row(String(d[0]), c))

	var vib := UITheme.slider(0.0, 1.0, 0.05, Settings.vibration_strength)
	vib.value_changed.connect(func(x: float) -> void:
		Settings.vibration_strength = x; Settings.save_settings())
	v.add_child(UITheme.row("Vibration Strength", vib))
	return sc

# ---------------------------------------------------------------- accessibility
func _access_tab() -> ScrollContainer:
	var sc := _scroll("Accessibility")
	var v := _list(sc)

	var subs := UITheme.check(Settings.subtitles)
	subs.toggled.connect(func(b: bool) -> void:
		Settings.subtitles = b; Settings.save_settings()
		Settings.accessibility_changed.emit())
	v.add_child(UITheme.row("Subtitles", subs))

	var size := UITheme.option(["Small", "Medium", "Large", "Very Large"], Settings.subtitle_size)
	size.item_selected.connect(func(i: int) -> void:
		Settings.subtitle_size = i; Settings.save_settings()
		Settings.accessibility_changed.emit())
	v.add_child(UITheme.row("Subtitle Size", size))

	var sbg := UITheme.slider(0.0, 1.0, 0.05, Settings.subtitle_background)
	sbg.value_changed.connect(func(x: float) -> void:
		Settings.subtitle_background = x; Settings.save_settings()
		Settings.accessibility_changed.emit())
	v.add_child(UITheme.row("Subtitle Background", sbg))

	var spk := UITheme.check(Settings.subtitle_speaker)
	spk.toggled.connect(func(b: bool) -> void:
		Settings.subtitle_speaker = b; Settings.save_settings())
	v.add_child(UITheme.row("Show Speaker Names", spk))

	var cb := UITheme.check(Settings.colorblind_states)
	cb.toggled.connect(func(b: bool) -> void:
		Settings.colorblind_states = b; Settings.save_settings()
		Settings.accessibility_changed.emit())
	v.add_child(UITheme.row("Colour-Blind State Indicators", cb,
		"Switches Memory / Ruin / Bloom to blue / white / magenta. Distinct glyphs are always shown."))

	var hc := UITheme.check(Settings.high_contrast_markers)
	hc.toggled.connect(func(b: bool) -> void:
		Settings.high_contrast_markers = b; Settings.save_settings()
		Settings.accessibility_changed.emit())
	v.add_child(UITheme.row("High-Contrast Interaction Markers", hc))

	var shake := UITheme.slider(0.0, 1.0, 0.05, Settings.reduce_camera_shake)
	shake.value_changed.connect(func(x: float) -> void:
		Settings.reduce_camera_shake = x; Settings.save_settings())
	v.add_child(UITheme.row("Reduce Camera Shake", shake, "1.0 removes camera shake entirely."))

	var flash := UITheme.check(Settings.reduce_flashing)
	flash.toggled.connect(func(b: bool) -> void:
		Settings.reduce_flashing = b; Settings.save_settings())
	v.add_child(UITheme.row("Reduce Flashing Effects", flash,
		"Suppresses lightning flashes, damage flashes and screen strobes."))

	var uis := UITheme.slider(0.8, 1.6, 0.05, Settings.ui_scale)
	uis.value_changed.connect(func(x: float) -> void:
		Settings.ui_scale = x; Settings.save_settings())
	v.add_child(UITheme.row("Interface Scale", uis, "Takes effect on the next screen."))

	var always := UITheme.check(Settings.always_show_prompts)
	always.toggled.connect(func(b: bool) -> void:
		Settings.always_show_prompts = b; Settings.save_settings())
	v.add_child(UITheme.row("Always Show Control Prompts", always,
		"Normally prompts retire once you have used the action a few times."))
	return sc

# ---------------------------------------------------------------- controls
func _controls_tab() -> ScrollContainer:
	var sc := _scroll("Controls")
	var v := _list(sc)
	v.add_child(UITheme.label(
		"Click a binding, then press any key, mouse button, or controller input.",
		16, UITheme.TEXT_DIM))
	v.add_child(UITheme.hsep())
	_binding_rows.clear()
	for a in Settings.ACTIONS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(UITheme.s(12)))
		var lbl := UITheme.label(String(Settings.ACTION_LABELS.get(a, a)), 18)
		lbl.custom_minimum_size = Vector2(UITheme.s(280), 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(lbl)
		for slot in 2:
			var b := UITheme.button(_binding_text(a, slot), 16)
			b.custom_minimum_size = Vector2(UITheme.s(190), UITheme.s(38))
			b.pressed.connect(_start_rebind.bind(a, slot))
			h.add_child(b)
			_binding_rows["%s_%d" % [a, slot]] = b
		v.add_child(h)
	v.add_child(UITheme.spacer(10))
	var rb := UITheme.button("Reset All Bindings", 18)
	rb.custom_minimum_size = Vector2(UITheme.s(240), UITheme.s(40))
	rb.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh_bindings())
	v.add_child(rb)
	return sc

func _binding_text(action: String, slot: int) -> String:
	var list: Array = Settings.bindings.get(action, [])
	if slot < list.size():
		return Settings.event_display_name(list[slot])
	return "--"

func _refresh_bindings() -> void:
	for key in _binding_rows.keys():
		var parts: PackedStringArray = String(key).rsplit("_", true, 1)
		var action := parts[0]
		var slot := int(parts[1])
		(_binding_rows[key] as Button).text = _binding_text(action, slot)

func _start_rebind(action: String, slot: int) -> void:
	_rebinding = {"action": action, "slot": slot}
	_rebind_label.text = "Press an input for\n%s\n\n[Esc] cancels" % \
		String(Settings.ACTION_LABELS.get(action, action))
	_rebind_overlay.visible = true

func _input(e: InputEvent) -> void:
	if not _rebind_overlay.visible:
		return
	if e is InputEventKey and (e as InputEventKey).pressed \
			and (e as InputEventKey).physical_keycode == KEY_ESCAPE:
		_rebind_overlay.visible = false
		accept_event()
		return
	var ok := false
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		ok = true
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		ok = true
	elif e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed:
		ok = true
	elif e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.7:
		ok = true
	if not ok:
		return
	if Settings.rebind(String(_rebinding.action), e, int(_rebinding.slot)):
		AudioDirector.play_ui("ui_confirm", -12.0)
		_refresh_bindings()
		_rebind_overlay.visible = false
	accept_event()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_build()

func _close() -> void:
	AudioDirector.play_ui("ui_back", -12.0)
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if _rebind_overlay.visible:
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
