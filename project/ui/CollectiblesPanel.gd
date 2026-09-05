extends Control
class_name CollectiblesPanel
## Collectibles and records: per-chapter fragments, components, challenges,
## medals, best times and ranks, plus the readable fragment texts.

signal closed()

var _detail: VBoxContainer
var _selected := 0

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
	margin.add_theme_constant_override("margin_left", int(UITheme.s(70)))
	margin.add_theme_constant_override("margin_right", int(UITheme.s(70)))
	margin.add_theme_constant_override("margin_top", int(UITheme.s(46)))
	margin.add_theme_constant_override("margin_bottom", int(UITheme.s(46)))
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(UITheme.s(10)))
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_child(UITheme.title("FIELD RECORDS", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	header.add_child(UITheme.label("Completion  %.1f%%" % GameState.completion_percent(),
		20, UITheme.GOLD))
	var back := UITheme.button("Back", 19)
	back.custom_minimum_size = Vector2(UITheme.s(150), UITheme.s(42))
	back.pressed.connect(func() -> void:
		AudioDirector.play_ui("ui_back", -12.0); closed.emit())
	header.add_child(back)
	vb.add_child(header)
	vb.add_child(UITheme.hsep())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", int(UITheme.s(20)))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)

	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(UITheme.s(420), 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(UITheme.s(6)))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(list)
	body.add_child(left)

	for i in ChapterDB.COUNT:
		list.add_child(_chapter_button(i))

	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", int(UITheme.s(8)))
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	body.add_child(right)
	_show_chapter(0)

	var totals := UITheme.label(_totals_text(), 16, UITheme.TEXT_DIM)
	vb.add_child(UITheme.hsep())
	vb.add_child(totals)

func _totals_text() -> String:
	var t: Dictionary = GameState.data.get("totals", {})
	return "Fragments %d/24   Components %d/8   Puzzles solved %d   Scans %d   Hidden areas %d   Wildlife %d   Deaths %d" % [
		GameState.total_fragments_found(), GameState.components(),
		int(t.get("puzzles", 0)), int(t.get("scans", 0)), int(t.get("hidden", 0)),
		int(t.get("wildlife", 0)), int(t.get("deaths", 0))]

func _chapter_button(i: int) -> Button:
	var ch := ChapterDB.get_chapter(i)
	var rec := GameState.chapter_record(i)
	var frags := 0
	for f in rec.get("fragments", []):
		if bool(f): frags += 1
	var rank := int(rec.get("rank", -1))
	var visited := GameState.is_chapter_unlocked(i)
	var label := "%d. %s" % [i + 1, ch.title if visited else "- locked -"]
	if visited:
		label += "    %d/3 ◆" % frags
		if bool(rec.get("component", false)): label += "  ⬢"
		if bool(rec.get("challenge", false)): label += "  ★"
		if rank >= 0: label += "   %s" % Veil.RANK_NAMES[rank]
	var b := UITheme.button(label, 17)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not visited
	b.pressed.connect(func() -> void: _show_chapter(i))
	return b

func _show_chapter(i: int) -> void:
	_selected = i
	for c in _detail.get_children():
		c.queue_free()
	var ch := ChapterDB.get_chapter(i)
	var rec := GameState.chapter_record(i)
	if not GameState.is_chapter_unlocked(i):
		_detail.add_child(UITheme.label("This chapter has not been reached yet.", 20, UITheme.TEXT_DIM))
		return
	_detail.add_child(UITheme.title(ch.title, 28))
	_detail.add_child(UITheme.label(ch.subtitle, 17, UITheme.TEXT_DIM))
	_detail.add_child(UITheme.spacer(8))

	var stats := "Status: %s" % ("Complete" if bool(rec.get("completed", false)) else "In progress")
	if float(rec.get("best_time", 0.0)) > 0.0:
		stats += "     Best time: %s" % Veil.format_time(float(rec.best_time))
	if int(rec.get("best_score", 0)) > 0:
		stats += "     Best score: %d" % int(rec.best_score)
	if int(rec.get("rank", -1)) >= 0:
		stats += "     Rank: %s" % Veil.RANK_NAMES[int(rec.rank)]
	if float(rec.get("time_trial_best", 0.0)) > 0.0:
		stats += "     Time trial: %s" % Veil.format_time(float(rec.time_trial_best))
	_detail.add_child(UITheme.label(stats, 16, UITheme.TEXT))

	var medals := HBoxContainer.new()
	medals.add_theme_constant_override("separation", int(UITheme.s(16)))
	medals.add_child(_medal("Mastery", bool(rec.get("mastery", false))))
	medals.add_child(_medal("No Damage", bool(rec.get("no_damage", false))))
	medals.add_child(_medal("Challenge", bool(rec.get("challenge", false))))
	medals.add_child(_medal("Component", bool(rec.get("component", false))))
	_detail.add_child(medals)

	_detail.add_child(UITheme.spacer(10))
	_detail.add_child(UITheme.label("BONUS CHALLENGE", 18, UITheme.ACCENT_WARM))
	_detail.add_child(_wrap(String(ch.challenge), 16))
	_detail.add_child(UITheme.spacer(10))
	_detail.add_child(UITheme.label("MEMORY FRAGMENTS", 18, UITheme.ACCENT))

	var texts := _fragment_texts(i)
	for k in 3:
		var found: bool = bool((rec.fragments as Array)[k])
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel",
			UITheme.panel(UITheme.PANEL, 4, 1,
				UITheme.ACCENT.darkened(0.5) if found else UITheme.TEXT_FAINT.darkened(0.5)))
		var v := VBoxContainer.new()
		pc.add_child(v)
		v.add_child(UITheme.label(
			"◆ %s" % String(ch.fragments[k]) if found else "◇ Not yet recovered",
			17, UITheme.ACCENT if found else UITheme.TEXT_FAINT))
		if found:
			v.add_child(_wrap(String(texts[k]), 15))
		_detail.add_child(pc)

func _medal(label: String, earned: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UITheme.label("◈" if earned else "◇", 26,
		UITheme.GOLD if earned else UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.label(label, 13,
		UITheme.TEXT if earned else UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER))
	return v

func _wrap(text: String, size: int) -> Label:
	var l := UITheme.label(text, size, UITheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(UITheme.s(560), 0)
	return l

## Fragment prose lives with the chapter scripts; pull it without building a level.
func _fragment_texts(i: int) -> Array:
	var path: String = String(ChapterDB.get_chapter(i).builder)
	var cs: GDScript = load(path)
	if cs == null:
		return ["", "", ""]
	var inst = cs.new()
	inst.setup(i)
	var out: Array = []
	for k in 3:
		out.append(String(inst.fragment_text(k)))
	inst.free()
	return out

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("codex"):
		closed.emit()
		get_viewport().set_input_as_handled()
