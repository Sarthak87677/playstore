extends Control
class_name ExtrasPanel
## Extras: concept-art gallery, unlocked suits and MOTE skins, statistics and
## New Game+. All content is earned in play; nothing here is purchasable.

signal closed()

var _tabs: TabContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not GameState.has_profile():
		var newest := SaveSystem.newest_slot()
		if newest >= 0:
			GameState.load_slot(newest)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(UITheme.s(80)))
	margin.add_theme_constant_override("margin_right", int(UITheme.s(80)))
	margin.add_theme_constant_override("margin_top", int(UITheme.s(48)))
	margin.add_theme_constant_override("margin_bottom", int(UITheme.s(48)))
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UITheme.s(10)))
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(UITheme.title("EXTRAS", 36))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := UITheme.button("Back", 19)
	back.custom_minimum_size = Vector2(UITheme.s(150), UITheme.s(42))
	back.pressed.connect(func() -> void:
		AudioDirector.play_ui("ui_back", -12.0); closed.emit())
	head.add_child(back)
	v.add_child(head)
	v.add_child(UITheme.hsep())
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", int(UITheme.s(19)))
	v.add_child(_tabs)
	_tabs.add_child(_gallery_tab())
	_tabs.add_child(_unlocks_tab())
	_tabs.add_child(_stats_tab())

func _gallery_tab() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = "Gallery"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(UITheme.s(10)))
	sc.add_child(v)
	var owned: Array = GameState.data.get("gallery", [])
	v.add_child(UITheme.label(
		"%d of 24 plates recovered. Plates unlock with Memory Fragments and chapter completions."
			% owned.size(), 16, UITheme.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", int(UITheme.s(12)))
	grid.add_theme_constant_override("v_separation", int(UITheme.s(12)))
	v.add_child(grid)
	for i in 24:
		var cell := VBoxContainer.new()
		var art := ConceptArt.new()
		art.piece = i
		art.unlocked = ("art_%02d" % (i + 1)) in owned
		cell.add_child(art)
		cell.add_child(UITheme.label(
			"%02d  %s" % [i + 1, art.subject()] if art.unlocked else "%02d  - locked -" % (i + 1),
			14, UITheme.TEXT_DIM if art.unlocked else UITheme.TEXT_FAINT))
		grid.add_child(cell)
	return sc

func _unlocks_tab() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = "Suits & MOTE"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(UITheme.s(8)))
	sc.add_child(v)

	v.add_child(UITheme.label("SUITS", 24, UITheme.ACCENT))
	for id in GameState.SUITS.keys():
		var s: Dictionary = GameState.SUITS[id]
		var have := GameState.has_unlock("suit", String(id))
		v.add_child(_unlock_row(String(s.name), String(s.desc), String(s.how), have,
			String(GameState.data.get("current_suit", "field")) == String(id),
			func() -> void: GameState.set_suit(String(id)), Color(s.accent)))
	v.add_child(UITheme.spacer(14))
	v.add_child(UITheme.label("MOTE SHELLS", 24, UITheme.ACCENT))
	for id in GameState.MOTE_SKINS.keys():
		var m: Dictionary = GameState.MOTE_SKINS[id]
		var have := GameState.has_unlock("mote", String(id))
		v.add_child(_unlock_row(String(m.name), "", String(m.how), have,
			String(GameState.data.get("current_mote_skin", "standard")) == String(id),
			func() -> void: GameState.set_mote_skin(String(id)), Color(m.light)))

	v.add_child(UITheme.spacer(18))
	v.add_child(UITheme.label("NEW GAME+", 24, UITheme.GOLD))
	var ng_ok := bool(GameState.data.get("finished_game", false)) or GameState.ngplus() > 0
	v.add_child(UITheme.label(
		"Replay all eight chapters keeping every upgrade, fragment and unlock. Guardians are more alert and scoring rewards the extra difficulty."
			if ng_ok else "Finish the game once to unlock New Game+.", 16, UITheme.TEXT_DIM))
	var ng := UITheme.button("Begin New Game+ (currently NG+%d)" % GameState.ngplus(), 19)
	ng.custom_minimum_size = Vector2(UITheme.s(420), UITheme.s(46))
	ng.disabled = not ng_ok
	ng.pressed.connect(func() -> void:
		GameState.start_new_game_plus()
		SceneFlow.start_chapter(0, "new"))
	v.add_child(ng)
	return sc

func _unlock_row(title: String, desc: String, how: String, have: bool, equipped: bool,
		on_equip: Callable, accent: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		UITheme.panel(UITheme.PANEL, 4, 1, accent.darkened(0.5) if have else UITheme.LINE))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UITheme.s(14)))
	pc.add_child(h)
	var swatch := ColorRect.new()
	swatch.color = accent if have else Color(0.15, 0.16, 0.18)
	swatch.custom_minimum_size = Vector2(UITheme.s(46), UITheme.s(46))
	h.add_child(swatch)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UITheme.label(title, 19, UITheme.TEXT if have else UITheme.TEXT_FAINT))
	if desc != "" and have:
		v.add_child(UITheme.label(desc, 15, UITheme.TEXT_DIM))
	v.add_child(UITheme.label(how, 14, UITheme.TEXT_FAINT))
	h.add_child(v)
	var b := UITheme.button("Equipped" if equipped else "Equip", 16)
	b.custom_minimum_size = Vector2(UITheme.s(140), UITheme.s(38))
	b.disabled = not have or equipped
	b.pressed.connect(func() -> void:
		on_equip.call()
		AudioDirector.play_ui("ui_confirm", -12.0)
		_refresh())
	h.add_child(b)
	return pc

func _stats_tab() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = "Statistics"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(UITheme.s(5)))
	sc.add_child(v)
	var t: Dictionary = GameState.data.get("totals", {})
	var rows := [
		["Player level", "%d / %d" % [GameState.level(), Veil.MAX_LEVEL]],
		["Research XP", "%d" % GameState.xp()],
		["Upgrade points spent", "%d / %d" % [GameState.points_spent(), GameState.points_total()]],
		["Upgrade components", "%d / 8" % GameState.components()],
		["Chapters completed", "%d / 8" % GameState.chapters_completed()],
		["Bonus challenges cleared", "%d / 8" % GameState.challenges_done()],
		["S ranks", "%d / 8" % GameState.s_ranks()],
		["Memory Fragments", "%d / 24" % GameState.total_fragments_found()],
		["Puzzles solved", "%d" % int(t.get("puzzles", 0))],
		["Objects scanned", "%d" % int(t.get("scans", 0))],
		["Hidden areas found", "%d" % int(t.get("hidden", 0))],
		["Wildlife recorded", "%d" % int(t.get("wildlife", 0))],
		["Guardians bypassed unseen", "%d" % int(t.get("bypassed", 0))],
		["Deaths", "%d" % int(t.get("deaths", 0))],
		["Total play time", Veil.format_clock(float(GameState.data.get("playtime", 0.0)))],
		["New Game+ cycles", "%d" % GameState.ngplus()],
		["Overall completion", "%.1f%%" % GameState.completion_percent()],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var l := UITheme.label(String(r[0]), 18, UITheme.TEXT_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UITheme.label(String(r[1]), 18, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(h)
	return sc

func _refresh() -> void:
	var idx := _tabs.current_tab
	for c in get_children():
		c.queue_free()
	_build()
	await get_tree().process_frame
	if _tabs:
		_tabs.current_tab = idx

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
