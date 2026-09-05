extends Control
## Main menu with a live 3D backdrop that cycles the three reality states.
## Hosts New Game, Continue, three save slots, chapter select, extras,
## settings, credits and exit confirmation.

var _bg_world: Node3D
var _bg_cam: Camera3D
var _bg_atmo: Atmosphere
var _state := Veil.State.MEMORY
var _state_t := 0.0
var _menu: VBoxContainer
var _panel: Control
var _sub: Control = null
var _slot_note: Label
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_ui()
	AudioDirector.start_menu_music()

# ================================================================ backdrop
func _build_backdrop() -> void:
	_bg_world = Node3D.new()
	add_child(_bg_world)
	_bg_atmo = Atmosphere.new()
	_bg_world.add_child(_bg_atmo)
	# Menu-only palettes. These are deliberately darker and less foggy than the
	# in-game ones: the backdrop is seen against a title and a button column, so
	# it has to sit back and keep its silhouettes rather than fill the frame with
	# a bright horizon.
	_bg_atmo.setup([
		Atmosphere.palette(Color(0.05, 0.10, 0.21), Color(0.24, 0.36, 0.54),
			Color(0.22, 0.31, 0.45), Color(1.0, 0.97, 0.92), 1.7, 0.0035, 0.020,
			{"glow": 0.75, "sun_pitch": -14.0, "sun_yaw": 140.0, "sky_energy": 0.42,
			 "contrast": 1.16, "ambient": 0.5, "fog_aerial": 0.07, "fog_begin": 34.0}),
		Atmosphere.palette(Color(0.035, 0.040, 0.052), Color(0.155, 0.160, 0.190),
			Color(0.135, 0.145, 0.175), Color(0.92, 0.86, 0.80), 0.9, 0.0090, 0.034,
			{"glow": 0.40, "saturation": 0.80, "sun_pitch": -9.0, "sun_yaw": 120.0,
			 "sky_energy": 0.36, "contrast": 1.18, "ambient": 0.42,
			 "fog_aerial": 0.09, "fog_begin": 30.0}),
		Atmosphere.palette(Color(0.035, 0.105, 0.085), Color(0.20, 0.37, 0.27),
			Color(0.18, 0.33, 0.25), Color(1.0, 0.98, 0.88), 1.5, 0.0045, 0.026,
			{"glow": 0.70, "saturation": 1.14, "sun_pitch": -18.0, "sun_yaw": 160.0,
			 "sky_energy": 0.40, "contrast": 1.14, "ambient": 0.48,
			 "fog_aerial": 0.07, "fog_begin": 32.0}),
	], _state)

	_bg_cam = Camera3D.new()
	_bg_cam.fov = 52.0
	_bg_cam.position = Vector3(0, 6.5, 22)
	_bg_world.add_child(_bg_cam)
	_bg_cam.look_at(Vector3(0, 3.0, 0), Vector3.UP)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260101
	# a small procedural vista: ridge, monoliths, drifting shards
	for i in 26:
		var a := rng.randf_range(-PI, PI)
		var d := rng.randf_range(14.0, 46.0)
		var p := Vector3(cos(a) * d, -2.0 + rng.randf_range(0.0, 2.0), sin(a) * d - 8.0)
		var m := MeshInstance3D.new()
		m.mesh = ProcAssets.rock_mesh(i + 500, rng.randf_range(1.6, 5.4), 0.42, 10, 14, 0.7)
		m.material_override = ProcAssets.mat("rock")
		m.position = p
		_bg_world.add_child(m)
	for i in 7:
		var m := MeshInstance3D.new()
		var h := rng.randf_range(8.0, 17.0)
		m.mesh = ProcAssets.trunk_mesh(i + 900, h, rng.randf_range(0.6, 1.2), 0.1, 6, 7, 0.6)
		m.material_override = ProcAssets.mat("concrete_aged")
		m.position = Vector3(rng.randf_range(-24, 24), -2.0, rng.randf_range(-30, -6))
		_bg_world.add_child(m)
	for i in 40:
		var m := MeshInstance3D.new()
		m.mesh = ProcAssets.crystal_mesh(i + 60, rng.randf_range(0.4, 1.3), 0.16, 5)
		m.material_override = ProcAssets.additive(
			Veil.STATE_COLORS[i % 3], 1.6)
		m.position = Vector3(rng.randf_range(-20, 20), rng.randf_range(0.5, 14.0),
			rng.randf_range(-20, 8))
		m.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), 0)
		m.set_meta("drift", rng.randf_range(0.2, 0.7))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bg_world.add_child(m)

# ================================================================ ui
func _build_ui() -> void:
	# A solid column behind the menu, then a soft falloff, so the text stays
	# readable whatever the live backdrop is doing.
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	scrim.offset_right = 560
	scrim.color = Color(0.012, 0.016, 0.022, 0.93)
	add_child(scrim)
	var fade := TextureRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	fade.offset_left = 560
	fade.offset_right = 900
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.012, 0.016, 0.022, 0.93),
		Color(0.012, 0.016, 0.022, 0.0)])
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(1, 0)
	fade.texture = grad
	add_child(fade)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	v.offset_left = UITheme.s(84)
	v.offset_top = UITheme.s(92)
	v.offset_right = UITheme.s(560)
	v.add_theme_constant_override("separation", int(UITheme.s(8)))
	add_child(v)
	_menu = v

	var t := UITheme.title("VEILFORGE", 62)
	v.add_child(t)
	v.add_child(UITheme.label("THE THREEFOLD EARTH", 24, UITheme.ACCENT))
	v.add_child(UITheme.spacer(6))
	v.add_child(UITheme.hsep())
	v.add_child(UITheme.spacer(14))

	var has_save := SaveSystem.any_save_exists()
	var cont := UITheme.button("Continue", 24)
	cont.disabled = not has_save
	cont.pressed.connect(_continue)
	v.add_child(cont)

	var ng := UITheme.button("New Game", 24)
	ng.pressed.connect(func() -> void: _open("newgame"))
	v.add_child(ng)

	var cs := UITheme.button("Chapter Select", 24)
	cs.disabled = not has_save
	cs.pressed.connect(func() -> void: _open("chapters"))
	v.add_child(cs)

	var ex := UITheme.button("Extras", 24)
	ex.pressed.connect(func() -> void: _open("extras"))
	v.add_child(ex)

	var st := UITheme.button("Settings", 24)
	st.pressed.connect(func() -> void: _open("settings"))
	v.add_child(st)

	var cr := UITheme.button("Credits", 24)
	cr.pressed.connect(func() -> void: _open("credits"))
	v.add_child(cr)

	var q := UITheme.button("Exit", 24)
	q.pressed.connect(func() -> void: _open("quit"))
	v.add_child(q)

	v.add_child(UITheme.spacer(16))
	_slot_note = UITheme.label(_save_summary(), 15, UITheme.TEXT_FAINT)
	_slot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_slot_note)

	var version := UITheme.label("v%s   -   fully offline, no accounts, no telemetry" % \
		ProjectSettings.get_setting("application/config/version", "1.0.0"),
		14, UITheme.TEXT_FAINT)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = UITheme.s(84)
	version.offset_top = -UITheme.s(46)
	add_child(version)

	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	cont.grab_focus() if has_save else ng.grab_focus()

func _save_summary() -> String:
	var parts: Array = []
	for i in SaveSystem.SLOTS:
		var h := SaveSystem.header(i)
		if h.get("empty", true):
			parts.append("Slot %d: empty" % (i + 1))
		else:
			parts.append("Slot %d: %s, level %d, %.0f%%" % [
				i + 1, h.chapter_title, int(h.level), float(h.completion)])
	return "  |  ".join(parts)

# ================================================================ panels
func _open(which: String) -> void:
	_close()
	if which != "quit" and _menu:
		_menu.visible = false
	match which:
		"settings":
			_sub = SettingsPanel.new()
			_panel.add_child(_sub)
			_sub.connect("closed", Callable(self, "_close"))
		"newgame": _sub = _slot_panel(true)
		"continue": _sub = _slot_panel(false)
		"chapters": _sub = _chapter_panel()
		"extras":
			_sub = ExtrasPanel.new()
			_panel.add_child(_sub)
			_sub.connect("closed", Callable(self, "_close"))
		"credits": _sub = _credits_panel()
		"quit": _sub = _quit_panel()

func _close() -> void:
	if _sub != null and is_instance_valid(_sub):
		_sub.queue_free()
	_sub = null
	if _menu:
		_menu.visible = true
	if _slot_note:
		_slot_note.text = _save_summary()

func _shell(title: String) -> Dictionary:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(UITheme.s(110)))
	margin.add_theme_constant_override("margin_right", int(UITheme.s(110)))
	margin.add_theme_constant_override("margin_top", int(UITheme.s(56)))
	margin.add_theme_constant_override("margin_bottom", int(UITheme.s(56)))
	root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UITheme.s(10)))
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UITheme.title(title, 36))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := UITheme.button("Back", 19)
	back.custom_minimum_size = Vector2(UITheme.s(150), UITheme.s(42))
	back.pressed.connect(_close)
	head.add_child(back)
	v.add_child(head)
	v.add_child(UITheme.hsep())
	_panel.add_child(root)
	return {"root": root, "list": v}

func _slot_panel(new_game: bool) -> Control:
	var s := _shell("SELECT SAVE SLOT" if not new_game else "NEW GAME")
	var v: VBoxContainer = s.list
	if new_game:
		v.add_child(UITheme.label("Choose a difficulty. You can change it later in Settings.",
			17, UITheme.TEXT_DIM))
		var diff_row := HBoxContainer.new()
		diff_row.add_theme_constant_override("separation", int(UITheme.s(12)))
		var chosen := {"v": Settings.difficulty}
		for d in 3:
			var b := UITheme.button(Veil.DIFFICULTY_NAMES[d], 19)
			b.custom_minimum_size = Vector2(UITheme.s(230), UITheme.s(58))
			b.toggle_mode = true
			b.button_pressed = d == Settings.difficulty
			b.tooltip_text = Veil.DIFFICULTY_DESC[d]
			b.pressed.connect(func() -> void:
				chosen.v = d
				for c in diff_row.get_children():
					(c as Button).button_pressed = (c as Button).text == Veil.DIFFICULTY_NAMES[d])
			diff_row.add_child(b)
		v.add_child(diff_row)
		v.add_child(UITheme.label(Veil.DIFFICULTY_DESC[Settings.difficulty], 15, UITheme.TEXT_FAINT))
		v.add_child(UITheme.spacer(10))
		v.set_meta("difficulty", chosen)
	for i in SaveSystem.SLOTS:
		v.add_child(_slot_row(i, new_game, v))
	return s.root

func _slot_row(i: int, new_game: bool, holder: VBoxContainer) -> PanelContainer:
	var h := SaveSystem.header(i)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.panel(UITheme.PANEL, 5, 1, UITheme.LINE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UITheme.s(16)))
	pc.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UITheme.label("SLOT %d" % (i + 1), 20, UITheme.ACCENT))
	if h.get("empty", true):
		info.add_child(UITheme.label("Empty", 17, UITheme.TEXT_FAINT))
	else:
		info.add_child(UITheme.label("%s  -  Chapter %d" % [
			h.chapter_title, int(h.chapter_index) + 1], 18))
		var extra := "Level %d   |   %s played   |   %d/8 chapters   |   %d/24 fragments   |   %.1f%%" % [
			int(h.level), Veil.format_clock(float(h.playtime)),
			int(h.chapters_done), int(h.fragments), float(h.completion)]
		if int(h.ngplus) > 0:
			extra += "   |   NG+%d" % int(h.ngplus)
		info.add_child(UITheme.label(extra, 15, UITheme.TEXT_DIM))
		info.add_child(UITheme.label("Difficulty: %s" % Veil.DIFFICULTY_NAMES[int(h.difficulty)],
			14, UITheme.TEXT_FAINT))
	row.add_child(info)

	if new_game:
		var b := UITheme.button("Start" if h.get("empty", true) else "Overwrite", 18)
		b.custom_minimum_size = Vector2(UITheme.s(180), UITheme.s(44))
		b.pressed.connect(func() -> void:
			var diff := Settings.difficulty
			if holder.has_meta("difficulty"):
				diff = int((holder.get_meta("difficulty") as Dictionary).v)
			GameState.start_new_game(i, diff)
			Hints.reset_tutorials()
			SceneFlow.start_chapter(0, "new"))
		row.add_child(b)
	else:
		var b := UITheme.button("Load", 18)
		b.custom_minimum_size = Vector2(UITheme.s(150), UITheme.s(44))
		b.disabled = h.get("empty", true)
		b.pressed.connect(func() -> void: _load_slot(i))
		row.add_child(b)
	if not h.get("empty", true):
		var d := UITheme.button("Erase", 18)
		d.custom_minimum_size = Vector2(UITheme.s(130), UITheme.s(44))
		d.pressed.connect(func() -> void:
			SaveSystem.erase(i)
			_close()
			_open("newgame" if new_game else "continue"))
		row.add_child(d)
	return pc

func _continue() -> void:
	var s := SaveSystem.newest_slot()
	if s < 0:
		_open("newgame")
		return
	_load_slot(s)

func _load_slot(i: int) -> void:
	if not GameState.load_slot(i):
		AudioDirector.play_ui("ui_deny", -8.0)
		return
	var idx := GameState.unlocked_chapter()
	var mode := "new"
	if GameState.has_checkpoint():
		idx = int(GameState.checkpoint().get("chapter", idx))
		mode = "checkpoint"
	SceneFlow.start_chapter(idx, mode)

func _chapter_panel() -> Control:
	var s := _shell("CHAPTER SELECT")
	var v: VBoxContainer = s.list
	if not GameState.has_profile():
		var newest := SaveSystem.newest_slot()
		if newest >= 0:
			GameState.load_slot(newest)
	if not GameState.has_profile():
		v.add_child(UITheme.label("Start a new game first.", 20, UITheme.TEXT_DIM))
		return s.root
	v.add_child(UITheme.label(
		"Replaying a chapter keeps your upgrades and collectibles. Time trials unlock once a chapter is complete.",
		16, UITheme.TEXT_DIM))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(UITheme.s(6)))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	v.add_child(sc)
	for i in ChapterDB.COUNT:
		list.add_child(_chapter_row(i))
	return s.root

func _chapter_row(i: int) -> PanelContainer:
	var ch := ChapterDB.get_chapter(i)
	var rec := GameState.chapter_record(i)
	var unlocked := GameState.is_chapter_unlocked(i)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.panel(
		UITheme.PANEL if unlocked else Color(0.03, 0.035, 0.04, 0.8), 5, 1, UITheme.LINE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UITheme.s(14)))
	pc.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UITheme.label("%d.  %s" % [i + 1, ch.title if unlocked else "Locked"],
		20, UITheme.TEXT if unlocked else UITheme.TEXT_FAINT))
	if unlocked:
		info.add_child(UITheme.label(ch.subtitle, 15, UITheme.TEXT_DIM))
		var frags := 0
		for f in rec.get("fragments", []):
			if bool(f): frags += 1
		var st := "%d/3 fragments" % frags
		if bool(rec.get("component", false)): st += "   component"
		if int(rec.get("rank", -1)) >= 0: st += "   rank %s" % Veil.RANK_NAMES[int(rec.rank)]
		if float(rec.get("best_time", 0.0)) > 0.0:
			st += "   best %s" % Veil.format_time(float(rec.best_time))
		info.add_child(UITheme.label(st, 14, UITheme.TEXT_FAINT))
	else:
		info.add_child(UITheme.label("Complete the previous chapter to unlock.",
			15, UITheme.TEXT_FAINT))
	row.add_child(info)
	var play := UITheme.button("Play", 18)
	play.custom_minimum_size = Vector2(UITheme.s(130), UITheme.s(42))
	play.disabled = not unlocked
	play.pressed.connect(func() -> void: SceneFlow.start_chapter(i, "new"))
	row.add_child(play)
	var tt := UITheme.button("Time Trial", 18)
	tt.custom_minimum_size = Vector2(UITheme.s(160), UITheme.s(42))
	tt.disabled = not bool(rec.get("completed", false))
	tt.pressed.connect(func() -> void: SceneFlow.start_chapter(i, "time_trial"))
	row.add_child(tt)
	return pc

func _credits_panel() -> Control:
	var s := _shell("CREDITS")
	var v: VBoxContainer = s.list
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", int(UITheme.s(6)))
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	v.add_child(sc)
	var text := FileAccess.get_file_as_string("res://data/credits.txt")
	if text.strip_edges().is_empty():
		text = "VEILFORGE: THE THREEFOLD EARTH"
	for line in text.split("\n"):
		var l := String(line)
		if l.begins_with("# "):
			inner.add_child(UITheme.spacer(12))
			inner.add_child(UITheme.label(l.substr(2), 24, UITheme.ACCENT))
		elif l.strip_edges().is_empty():
			inner.add_child(UITheme.spacer(6))
		else:
			inner.add_child(UITheme.label(l, 17, UITheme.TEXT_DIM))
	return s.root

func _quit_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.panel(UITheme.PANEL_HI, 6, 1, UITheme.ACCENT))
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.offset_left = -UITheme.s(260)
	pc.offset_right = UITheme.s(260)
	pc.offset_top = -UITheme.s(90)
	pc.offset_bottom = UITheme.s(90)
	root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UITheme.s(16)))
	pc.add_child(v)
	v.add_child(UITheme.label("Exit VEILFORGE?", 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", int(UITheme.s(14)))
	var yes := UITheme.button("Exit", 20)
	yes.custom_minimum_size = Vector2(UITheme.s(170), UITheme.s(46))
	yes.pressed.connect(func() -> void: SceneFlow.request_quit())
	var no := UITheme.button("Cancel", 20)
	no.custom_minimum_size = Vector2(UITheme.s(170), UITheme.s(46))
	no.pressed.connect(_close)
	h.add_child(yes)
	h.add_child(no)
	v.add_child(h)
	_panel.add_child(root)
	return root

# ================================================================ frame
func _process(dt: float) -> void:
	_t += dt
	_state_t += dt
	if _state_t > 9.0:
		_state_t = 0.0
		_state = (_state + 1) % 3
		_bg_atmo.set_state(_state)
	if _bg_cam:
		var a := _t * 0.045
		_bg_cam.position = Vector3(sin(a) * 9.0, 6.0 + sin(_t * 0.14) * 1.2, 20.0 + cos(a) * 4.0)
		_bg_cam.look_at(Vector3(0, 3.0, -6.0), Vector3.UP)
	for c in _bg_world.get_children():
		if c is MeshInstance3D and c.has_meta("drift"):
			var d := float(c.get_meta("drift"))
			(c as MeshInstance3D).position.y += sin(_t * d) * dt * 0.5
			(c as MeshInstance3D).rotation.y += dt * d * 0.4

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _sub != null:
		_close()
		get_viewport().set_input_as_handled()
