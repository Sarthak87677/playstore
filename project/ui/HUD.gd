extends CanvasLayer
class_name HUD
## Diegetic-ish heads-up display: energy cell, shield, reality state, recorded
## properties, objective, subtitles, scan readout, interaction prompt, XP
## toasts and guardian awareness. Everything respects the accessibility
## settings (subtitle size and background, colour-blind state colours,
## high-contrast markers).

var player: Player
var device: VeilDevice
var chapter: ChapterBase

# widgets
var _reticle: Control
var _energy: ProgressBar
var _energy_label: Label
var _shield: ProgressBar
var _air_box: Control
var _air: ProgressBar
var _climb_box: Control
var _climb: ProgressBar
var _state_row: HBoxContainer
var _state_labels: Array = []
var _records: HBoxContainer
var _objective: Label
var _objective_box: PanelContainer
var _subtitle: Label
var _subtitle_box: PanelContainer
var _prompt: Label
var _prompt_box: PanelContainer
var _tutorial: Label
var _tutorial_box: PanelContainer
var _scan_box: Control
var _scan_bar: ProgressBar
var _scan_name: Label
var _toasts: VBoxContainer
var _chain: Label
var _alert: Control
var _alert_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _fps: Label
var _hold_ring: Control
var _hold_value := 0.0
var _damage_flash: ColorRect
var _timer_label: Label

var _subtitle_t := 0.0
var _prompt_t := 0.0
var _visible_hud := true

func _ready() -> void:
	layer = 10
	_build()
	Settings.accessibility_changed.connect(_apply_accessibility)
	Hints.tutorial_shown.connect(_on_tutorial)
	Hints.tutorial_cleared.connect(func(_id: String) -> void: _tutorial_box.visible = false)
	Hints.objective_changed.connect(set_objective)
	Hints.hint_offered.connect(func(text: String, _lv: int) -> void:
		show_subtitle(text, "MOTE", 5.0))
	GameState.xp_awarded.connect(_on_xp)
	GameState.level_up.connect(_on_level_up)
	GameState.chain_changed.connect(_on_chain)
	GameState.unlock_earned.connect(func(kind: String, id: String, label: String) -> void:
		toast("Unlocked: %s" % label, UITheme.GOLD))
	_apply_accessibility()

func bind(p: Player, ch: ChapterBase) -> void:
	player = p
	device = p.device
	chapter = ch
	device.energy_changed.connect(_on_energy)
	device.state_selected.connect(_on_state)
	device.record_changed.connect(_on_records)
	device.scan_progress.connect(_on_scan)
	device.scan_complete.connect(_on_scan_done)
	device.message.connect(_on_message)
	p.shield_changed.connect(_on_shield)
	p.air_changed.connect(_on_air)
	p.interact_focus.connect(_on_focus)
	p.took_damage.connect(_on_damage)
	if ch:
		ch.dialogue.connect(show_subtitle)
		ch.checkpoint_saved.connect(func(id: String) -> void:
			toast("Checkpoint", UITheme.ACCENT))
	_on_energy(device.energy, device.energy_max)
	_on_shield(p.shield, p.shield_max)
	_on_state(device.selected_state)
	_on_records(device.records, 0)
	_update_xp()

# ================================================================ construction
func _mkbox(child: Control, color: Color = UITheme.PANEL) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.panel(color, 5, 1, UITheme.LINE))
	pc.add_child(child)
	return pc

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- damage flash
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.1, 0.1, 0.0)
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)

	# ---- reticle
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.custom_minimum_size = Vector2(28, 28)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)
	_reticle.draw.connect(_draw_reticle)

	# ---- hold-to-use ring
	_hold_ring = Control.new()
	_hold_ring.set_anchors_preset(Control.PRESET_CENTER)
	_hold_ring.custom_minimum_size = Vector2(70, 70)
	_hold_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hold_ring)
	_hold_ring.draw.connect(_draw_hold)

	# ---- bottom-left vitals
	var vitals := VBoxContainer.new()
	vitals.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left = 34
	vitals.offset_top = -170
	vitals.offset_right = 330
	vitals.offset_bottom = -30
	vitals.add_theme_constant_override("separation", 6)
	root.add_child(vitals)

	var erow := HBoxContainer.new()
	erow.add_theme_constant_override("separation", 8)
	erow.add_child(UITheme.label("CELL", 14, UITheme.TEXT_DIM))
	_energy_label = UITheme.label("100", 14, UITheme.ACCENT)
	_energy_label.custom_minimum_size = Vector2(40, 0)
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	erow.add_child(_energy_label)
	vitals.add_child(erow)
	_energy = UITheme.bar(UITheme.ACCENT, 12)
	_energy.custom_minimum_size = Vector2(260, 12)
	vitals.add_child(_energy)

	vitals.add_child(UITheme.label("SHIELD", 14, UITheme.TEXT_DIM))
	_shield = UITheme.bar(UITheme.GOOD, 10)
	_shield.custom_minimum_size = Vector2(260, 10)
	vitals.add_child(_shield)

	_air_box = VBoxContainer.new()
	_air_box.visible = false
	_air_box.add_child(UITheme.label("AIR", 13, Color(0.6, 0.85, 1.0)))
	_air = UITheme.bar(Color(0.5, 0.8, 1.0), 8)
	_air.custom_minimum_size = Vector2(260, 8)
	_air_box.add_child(_air)
	vitals.add_child(_air_box)

	_climb_box = VBoxContainer.new()
	_climb_box.visible = false
	_climb_box.add_child(UITheme.label("GRIP", 13, UITheme.ACCENT_WARM))
	_climb = UITheme.bar(UITheme.ACCENT_WARM, 8)
	_climb.custom_minimum_size = Vector2(260, 8)
	_climb_box.add_child(_climb)
	vitals.add_child(_climb_box)

	# ---- bottom-right: state selector + records
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.offset_left = -360
	right.offset_top = -150
	right.offset_right = -30
	right.offset_bottom = -30
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	_state_row = HBoxContainer.new()
	_state_row.alignment = BoxContainer.ALIGNMENT_END
	_state_row.add_theme_constant_override("separation", 10)
	for i in 3:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel",
			UITheme.panel(Color(0.05, 0.06, 0.08, 0.8), 4, 1, UITheme.LINE))
		var l := UITheme.label("%s %s" % [Veil.state_glyph(i), Veil.STATE_SHORT[i]], 17,
			UITheme.TEXT_FAINT)
		pc.add_child(l)
		_state_labels.append({"panel": pc, "label": l})
		_state_row.add_child(pc)
	right.add_child(_state_row)

	_records = HBoxContainer.new()
	_records.alignment = BoxContainer.ALIGNMENT_END
	_records.add_theme_constant_override("separation", 8)
	right.add_child(_records)

	# ---- top-left objective
	_objective = UITheme.label("", 18, UITheme.TEXT)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(420, 0)
	_objective_box = _mkbox(_objective)
	_objective_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_objective_box.offset_left = 30
	_objective_box.offset_top = 26
	_objective_box.offset_right = 470
	root.add_child(_objective_box)

	# ---- top-right: level + timer + fps
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -300
	tr.offset_top = 26
	tr.offset_right = -30
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 4)
	root.add_child(tr)
	_level_label = UITheme.label("LV 1", 18, UITheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(_level_label)
	_xp_bar = UITheme.bar(UITheme.GOLD, 6)
	_xp_bar.custom_minimum_size = Vector2(180, 6)
	tr.add_child(_xp_bar)
	_timer_label = UITheme.label("", 16, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(_timer_label)
	_chain = UITheme.label("", 16, UITheme.ACCENT_WARM, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(_chain)
	_fps = UITheme.label("", 14, UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_RIGHT)
	tr.add_child(_fps)

	# ---- toasts (XP / pickups)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_toasts.offset_left = -330
	_toasts.offset_top = -120
	_toasts.offset_right = -30
	_toasts.offset_bottom = 120
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER
	_toasts.add_theme_constant_override("separation", 5)
	root.add_child(_toasts)

	# ---- scan readout
	_scan_box = VBoxContainer.new()
	_scan_box.set_anchors_preset(Control.PRESET_CENTER)
	_scan_box.offset_left = -160
	_scan_box.offset_top = 48
	_scan_box.offset_right = 160
	_scan_box.offset_bottom = 110
	_scan_box.visible = false
	root.add_child(_scan_box)
	_scan_name = UITheme.label("", 16, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_scan_box.add_child(_scan_name)
	_scan_bar = UITheme.bar(UITheme.ACCENT, 5)
	_scan_bar.custom_minimum_size = Vector2(300, 5)
	_scan_box.add_child(_scan_bar)

	# ---- interaction prompt
	_prompt = UITheme.label("", 18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_box = _mkbox(_prompt)
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.offset_left = -220
	_prompt_box.offset_top = -230
	_prompt_box.offset_right = 220
	_prompt_box.offset_bottom = -186
	_prompt_box.visible = false
	root.add_child(_prompt_box)

	# ---- tutorial prompt
	_tutorial = UITheme.label("", 17, UITheme.ACCENT_WARM, HORIZONTAL_ALIGNMENT_CENTER)
	_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_box = _mkbox(_tutorial, Color(0.06, 0.05, 0.03, 0.86))
	_tutorial_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tutorial_box.offset_left = -300
	_tutorial_box.offset_top = 100
	_tutorial_box.offset_right = 300
	_tutorial_box.visible = false
	root.add_child(_tutorial_box)

	# ---- subtitles
	_subtitle = UITheme.label("", 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_box = _mkbox(_subtitle, Color(0, 0, 0, 0.55))
	_subtitle_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_box.offset_left = -460
	_subtitle_box.offset_top = -140
	_subtitle_box.offset_right = 460
	_subtitle_box.offset_bottom = -66
	_subtitle_box.visible = false
	root.add_child(_subtitle_box)

	# ---- guardian awareness
	_alert = VBoxContainer.new()
	_alert.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert.offset_left = -110
	_alert.offset_top = 44
	_alert.offset_right = 110
	_alert.offset_bottom = 80
	_alert.visible = false
	root.add_child(_alert)
	_alert.add_child(UITheme.label("DETECTED", 15, UITheme.BAD, HORIZONTAL_ALIGNMENT_CENTER))
	_alert_bar = UITheme.bar(UITheme.BAD, 6)
	_alert_bar.custom_minimum_size = Vector2(220, 6)
	_alert.add_child(_alert_bar)

# ================================================================ drawing
func _draw_reticle() -> void:
	var c := _reticle
	var mid := c.size * 0.5
	var col := UITheme.TEXT
	if device:
		col = Settings.state_color(device.selected_state)
	if Settings.high_contrast_markers:
		c.draw_circle(mid, 7.0, Color(0, 0, 0, 0.55))
	var aiming := device != null and device.aiming
	var r := 8.0 if aiming else 4.0
	c.draw_arc(mid, r, 0, TAU, 24, col, 1.6, true)
	c.draw_circle(mid, 1.4, col)
	if aiming:
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI * 0.25
			var d := Vector2(cos(a), sin(a))
			c.draw_line(mid + d * (r + 3.0), mid + d * (r + 7.0), col, 1.5, true)

func _draw_hold() -> void:
	if _hold_value <= 0.001:
		return
	var mid := _hold_ring.size * 0.5
	_hold_ring.draw_arc(mid, 22.0, -PI * 0.5, -PI * 0.5 + TAU * _hold_value,
		36, UITheme.ACCENT, 3.0, true)

# ================================================================ signals
func _on_energy(v: float, m: float) -> void:
	_energy.value = clampf(v / maxf(m, 0.001), 0.0, 1.0)
	_energy_label.text = "%d" % int(round(v))
	var low := v / maxf(m, 0.001) < 0.22
	_energy_label.add_theme_color_override("font_color",
		UITheme.BAD if low else UITheme.ACCENT)

func _on_shield(v: float, m: float) -> void:
	_shield.value = clampf(v / maxf(m, 0.001), 0.0, 1.0)

func _on_air(v: float, m: float) -> void:
	_air.value = clampf(v / maxf(m, 0.001), 0.0, 1.0)
	_air_box.visible = v < m - 0.01

func _on_state(s: int) -> void:
	for i in 3:
		var sel := i == s
		var col := Settings.state_color(i) if sel else UITheme.TEXT_FAINT
		(_state_labels[i].label as Label).add_theme_color_override("font_color", col)
		(_state_labels[i].panel as PanelContainer).add_theme_stylebox_override("panel",
			UITheme.panel(Color(0.08, 0.10, 0.13, 0.9) if sel else Color(0.04, 0.05, 0.06, 0.7),
				4, 2 if sel else 1, col))
	_reticle.queue_redraw()

func _on_records(slots: Array, sel: int) -> void:
	for c in _records.get_children():
		_records.remove_child(c)
		c.queue_free()
	for i in slots.size():
		var p: int = int(slots[i].prop)
		var col: Color = Veil.PROP_COLORS[clampi(p, 0, Veil.PROP_COLORS.size() - 1)]
		var pc := PanelContainer.new()
		var selected := i == sel
		pc.add_theme_stylebox_override("panel",
			UITheme.panel(Color(0.05, 0.06, 0.08, 0.85), 4, 2 if selected else 1,
				col if selected else UITheme.LINE))
		pc.add_child(UITheme.label(Veil.prop_name(p), 15, col))
		_records.add_child(pc)

func _on_scan(f: float, target: String) -> void:
	_scan_box.visible = f > 0.001
	_scan_bar.value = f
	_scan_name.text = target

func _on_scan_done(info: Dictionary) -> void:
	var txt := String(info.name)
	if String(info.note) != "":
		txt += " - " + String(info.note)
	show_subtitle(txt, "SCAN", 5.0)
	if int(info.property) != Veil.Prop.NONE:
		toast("Property recorded: %s" % Veil.prop_name(int(info.property)),
			Veil.PROP_COLORS[int(info.property)])

func _on_message(text: String, kind: String) -> void:
	var col := UITheme.TEXT
	match kind:
		"warn": col = UITheme.ACCENT_WARM
		"good": col = UITheme.GOOD
		"record": col = UITheme.ACCENT
		"unlock": col = UITheme.GOLD
	toast(text, col)

func _on_focus(t: Interactable) -> void:
	if t == null:
		_prompt_box.visible = false
		return
	_prompt_box.visible = true
	var key := Settings.binding_text("interact")
	_prompt.text = "[%s]  %s" % [key, t.prompt]

func _on_damage(amount: float, source: String) -> void:
	if Settings.reduce_flashing:
		return
	_damage_flash.color = Color(0.85, 0.12, 0.12, clampf(amount * 0.006, 0.06, 0.34))

func _on_tutorial(id: String, text: String, action: String) -> void:
	_tutorial.text = text
	_tutorial_box.visible = true

func _on_xp(amount: int, reason: String, total: int) -> void:
	toast("+%d  %s" % [amount, reason], UITheme.GOLD)
	_update_xp()

func _on_level_up(lv: int, points: int) -> void:
	AudioDirector.play("level_up", -6.0)
	toast("LEVEL %d  -  upgrade point available" % lv, UITheme.GOLD)
	_update_xp()

func _on_chain(links: int, mult: float) -> void:
	_chain.text = "" if links <= 1 else "DISCOVERY CHAIN x%.2f" % mult

func _update_xp() -> void:
	_level_label.text = "LV %d" % GameState.level()
	_xp_bar.value = GameState.level_progress()

# ================================================================ api
func toast(text: String, color: Color = UITheme.TEXT) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		UITheme.panel(Color(0.03, 0.04, 0.05, 0.82), 4, 1, color.darkened(0.3)))
	pc.add_child(UITheme.label(text, 16, color, HORIZONTAL_ALIGNMENT_RIGHT))
	pc.modulate.a = 0.0
	_toasts.add_child(pc)
	# queue_free() does not detach the child until the end of the frame, so the
	# node must be removed here or this loop never terminates.
	while _toasts.get_child_count() > 7:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var t := create_tween()
	t.tween_property(pc, "modulate:a", 1.0, 0.16)
	t.tween_interval(3.0)
	t.tween_property(pc, "modulate:a", 0.0, 0.7)
	t.tween_callback(pc.queue_free)

func show_subtitle(text: String, speaker: String = "", duration: float = 4.0) -> void:
	if not Settings.subtitles:
		return
	var prefix := ""
	if Settings.subtitle_speaker and speaker != "":
		prefix = "%s:  " % speaker
	_subtitle.text = prefix + text
	_subtitle_box.visible = true
	_subtitle_t = duration

func set_objective(text: String) -> void:
	_objective.text = text
	_objective_box.visible = text != ""

func set_hud_visible(v: bool) -> void:
	_visible_hud = v
	for c in get_children():
		if c is Control:
			(c as Control).visible = v

func _apply_accessibility() -> void:
	_subtitle.add_theme_font_size_override("font_size", Settings.subtitle_font_size())
	_subtitle_box.add_theme_stylebox_override("panel",
		UITheme.panel(Color(0, 0, 0, Settings.subtitle_background), 5, 0))
	_on_state(device.selected_state if device else 0)

# ================================================================ frame
func _process(dt: float) -> void:
	if _subtitle_t > 0.0:
		_subtitle_t -= dt
		if _subtitle_t <= 0.0:
			_subtitle_box.visible = false
	_damage_flash.color.a = maxf(0.0, _damage_flash.color.a - dt * 1.1)
	_fps.text = "%d FPS" % Engine.get_frames_per_second() if Settings.show_fps else ""

	if player:
		_climb_box.visible = player.mode == Player.Mode.CLIMB
		if _climb_box.visible:
			_climb.value = player.climb_stamina_fraction()
		var hv := player.hold_fraction()
		if not is_equal_approx(hv, _hold_value):
			_hold_value = hv
			_hold_ring.queue_redraw()

	# guardian awareness meter tracks the most alarmed guardian nearby
	var worst := 0.0
	var hostile := false
	if chapter:
		for g in chapter.guardians:
			if not is_instance_valid(g):
				continue
			var gg := g as Guardian
			if gg.state == Guardian.St.DOWN:
				continue
			worst = maxf(worst, gg.awareness_fraction())
			if gg.is_hostile():
				hostile = true
	_alert.visible = worst > 0.03
	_alert_bar.value = worst
	if chapter and GameState.run.get("active", false):
		AudioDirector.set_intensity(clampf(worst * (1.0 if hostile else 0.55), 0.05, 1.0))

	if GameState.run.get("time_trial", false):
		_timer_label.text = Veil.format_time(float(GameState.run.get("time", 0.0)))
	elif Settings.show_fps:
		_timer_label.text = Veil.format_clock(float(GameState.run.get("time", 0.0)))
	else:
		_timer_label.text = ""
	_reticle.queue_redraw()
