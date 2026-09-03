extends CanvasLayer
class_name ResultsScreen
## Chapter results: score breakdown, rank medal, bonuses, records and the
## follow-on options (continue, replay, time trial, menu).

var _root: Control
var _list: VBoxContainer
var _buttons: HBoxContainer

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = UITheme.BG_SOLID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(UITheme.s(140)))
	margin.add_theme_constant_override("margin_right", int(UITheme.s(140)))
	margin.add_theme_constant_override("margin_top", int(UITheme.s(60)))
	margin.add_theme_constant_override("margin_bottom", int(UITheme.s(60)))
	_root.add_child(margin)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", int(UITheme.s(8)))
	margin.add_child(_list)

func _clear() -> void:
	for c in _list.get_children():
		c.queue_free()

func _line(label: String, value: String, color: Color = UITheme.TEXT,
		size: int = 19) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UITheme.label(label, size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UITheme.label(value, size, color, HORIZONTAL_ALIGNMENT_RIGHT))
	return h

func show_results(res: Dictionary) -> void:
	_clear()
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.play("level_up", -8.0)

	_list.add_child(UITheme.label("CHAPTER COMPLETE", 20, UITheme.ACCENT))
	_list.add_child(UITheme.title(String(res.title), 44))
	_list.add_child(UITheme.hsep())
	_list.add_child(UITheme.spacer(6))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UITheme.s(30)))
	var rank_box := VBoxContainer.new()
	rank_box.add_child(UITheme.label("RANK", 16, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var rl := UITheme.label(String(res.rank_name), 76,
		Veil.RANK_COLORS[int(res.rank)], HORIZONTAL_ALIGNMENT_CENTER)
	rank_box.add_child(rl)
	rank_box.custom_minimum_size = Vector2(UITheme.s(180), 0)
	head.add_child(rank_box)

	var stat := VBoxContainer.new()
	stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat.add_theme_constant_override("separation", int(UITheme.s(3)))
	stat.add_child(_line("Time", "%s   (par %s)" % [
		Veil.format_time(float(res.time)), Veil.format_time(float(res.par))]))
	stat.add_child(_line("Puzzles solved", "%d / %d" % [int(res.puzzles), int(res.puzzles_total)]))
	stat.add_child(_line("New specimens scanned", "%d / %d" % [int(res.scans), int(res.scan_par)]))
	stat.add_child(_line("Memory Fragments", "%d / 3" % int(res.fragments)))
	stat.add_child(_line("Hidden areas", "%d" % int(res.hidden)))
	stat.add_child(_line("Deaths", "%d" % int(res.deaths),
		UITheme.BAD if int(res.deaths) > 0 else UITheme.TEXT))
	head.add_child(stat)
	_list.add_child(head)

	_list.add_child(UITheme.spacer(10))
	_list.add_child(UITheme.hsep())
	_list.add_child(_line("Time score", "%d" % int(res.time_score), UITheme.TEXT_DIM, 18))
	_list.add_child(_line("Puzzle score", "%d" % int(res.puzzle_score), UITheme.TEXT_DIM, 18))
	_list.add_child(_line("Exploration score", "%d" % int(res.explore_score), UITheme.TEXT_DIM, 18))
	_list.add_child(_line("Stealth score", "%d" % int(res.stealth_score), UITheme.TEXT_DIM, 18))
	for b in res.bonuses:
		_list.add_child(_line("Bonus: %s" % String(b.label), "+%d" % int(b.value),
			UITheme.GOLD, 18))
	if int(res.damage_penalty) > 0:
		_list.add_child(_line("Damage penalty", "-%d" % int(res.damage_penalty), UITheme.BAD, 18))
	_list.add_child(UITheme.hsep())
	_list.add_child(_line("TOTAL", "%d" % int(res.total), UITheme.TEXT, 30))
	if bool(res.new_best):
		_list.add_child(UITheme.label("New personal best.", 17, UITheme.GOOD))
	_list.add_child(_line("Research XP earned", "+%d" % int(res.xp_gained), UITheme.GOLD, 20))
	_list.add_child(_line("Player level", "%d   (%d unspent points)" % [
		GameState.level(), GameState.points_free()], UITheme.GOLD, 20))
	if bool(res.mastery):
		_list.add_child(UITheme.label("CHAPTER MASTERY MEDAL EARNED", 22, UITheme.GOLD))

	_list.add_child(UITheme.spacer(16))
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", int(UITheme.s(14)))
	_list.add_child(_buttons)

	var idx := int(res.chapter)
	if idx + 1 < ChapterDB.COUNT:
		_add_button("Continue to %s" % ChapterDB.title(idx + 1), func() -> void:
			_root.visible = false
			SceneFlow.start_chapter(idx + 1, "new"))
	else:
		_add_button("Finish", func() -> void:
			_root.visible = false
			SceneFlow.goto_menu())
	_add_button("Replay Chapter", func() -> void:
		_root.visible = false
		SceneFlow.start_chapter(idx, "new"))
	_add_button("Time Trial", func() -> void:
		_root.visible = false
		SceneFlow.start_chapter(idx, "time_trial"))
	_add_button("Main Menu", func() -> void:
		_root.visible = false
		SceneFlow.goto_menu())
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()

func show_time_trial(idx: int, t: float, is_best: bool) -> void:
	_clear()
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.play("puzzle_solved", -6.0)
	_list.add_child(UITheme.label("TIME TRIAL", 20, UITheme.ACCENT_WARM))
	_list.add_child(UITheme.title(ChapterDB.title(idx), 44))
	_list.add_child(UITheme.hsep())
	_list.add_child(UITheme.spacer(10))
	_list.add_child(UITheme.label(Veil.format_time(t), 72, UITheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER))
	var best := float(GameState.chapter_record(idx).get("time_trial_best", 0.0))
	_list.add_child(UITheme.label(
		"New best time." if is_best else "Best: %s" % Veil.format_time(best),
		20, UITheme.GOOD if is_best else UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_list.add_child(UITheme.spacer(20))
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", int(UITheme.s(14)))
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_child(_buttons)
	_add_button("Run Again", func() -> void:
		_root.visible = false
		SceneFlow.start_chapter(idx, "time_trial"))
	_add_button("Main Menu", func() -> void:
		_root.visible = false
		SceneFlow.goto_menu())
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()

func _add_button(text: String, cb: Callable) -> void:
	var b := UITheme.button(text, 20)
	b.custom_minimum_size = Vector2(UITheme.s(250), UITheme.s(48))
	b.pressed.connect(cb)
	_buttons.add_child(b)
