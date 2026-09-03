extends Control
class_name UpgradePanel
## Upgrade screen: three branches, rank pips, tier gating by upgrade
## components, and a live readout of what each rank actually changes.

signal closed()

var _points_label: Label
var _comp_label: Label
var _rows: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	GameState.upgrade_bought.connect(func(_id: String, _r: int) -> void: _refresh())

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(UITheme.s(70)))
	margin.add_theme_constant_override("margin_right", int(UITheme.s(70)))
	margin.add_theme_constant_override("margin_top", int(UITheme.s(46)))
	margin.add_theme_constant_override("margin_bottom", int(UITheme.s(46)))
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(UITheme.s(10)))
	margin.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(UITheme.s(24)))
	header.add_child(UITheme.title("VEILFORGE UPGRADES", 34))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	_points_label = UITheme.label("", 20, UITheme.GOLD)
	_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_points_label)
	_comp_label = UITheme.label("", 20, UITheme.ACCENT_WARM)
	_comp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_comp_label)
	var back := UITheme.button("Back", 19)
	back.custom_minimum_size = Vector2(UITheme.s(150), UITheme.s(42))
	back.pressed.connect(func() -> void:
		AudioDirector.play_ui("ui_back", -12.0); closed.emit())
	header.add_child(back)
	vb.add_child(header)
	vb.add_child(UITheme.hsep())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", int(UITheme.s(18)))
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)

	for b in 3:
		var branch := VBoxContainer.new()
		branch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch.add_theme_constant_override("separation", int(UITheme.s(8)))
		var head := UITheme.label(Veil.BRANCH_NAMES[b].to_upper(), 24, Veil.BRANCH_COLORS[b])
		branch.add_child(head)
		branch.add_child(UITheme.label(Veil.BRANCH_DESC[b], 15, UITheme.TEXT_DIM))
		branch.add_child(UITheme.hsep(1, Veil.BRANCH_COLORS[b].darkened(0.5)))
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", int(UITheme.s(8)))
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(list)
		branch.add_child(sc)
		cols.add_child(branch)

		for id in GameState.UPGRADES.keys():
			var u: Dictionary = GameState.UPGRADES[id]
			if int(u.branch) != b:
				continue
			list.add_child(_upgrade_card(String(id), u, b))

	var foot := UITheme.label(
		"Upgrade points come from player levels. Tiers unlock with upgrade components found in chapters.",
		15, UITheme.TEXT_FAINT)
	vb.add_child(foot)
	_refresh()

func _upgrade_card(id: String, u: Dictionary, branch: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		UITheme.panel(UITheme.PANEL, 5, 1, Veil.BRANCH_COLORS[branch].darkened(0.55)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UITheme.s(4)))
	pc.add_child(v)

	var top := HBoxContainer.new()
	var nm := UITheme.label(String(u.name), 19, UITheme.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	top.add_child(pips)
	v.add_child(top)

	var desc := UITheme.label(String(u.desc), 15, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UITheme.s(10)))
	var status := UITheme.label("", 15, UITheme.TEXT_FAINT)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(status)
	var buy := UITheme.button("Upgrade", 16)
	buy.custom_minimum_size = Vector2(UITheme.s(130), UITheme.s(34))
	buy.pressed.connect(func() -> void:
		if GameState.buy(id):
			_refresh())
	row.add_child(buy)
	v.add_child(row)

	_rows[id] = {"pips": pips, "status": status, "buy": buy, "card": pc, "u": u}
	return pc

func _refresh() -> void:
	_points_label.text = "Points  %d / %d" % [GameState.points_free(), GameState.points_total()]
	_comp_label.text = "Components  %d" % GameState.components()
	for id in _rows.keys():
		var r: Dictionary = _rows[id]
		var u: Dictionary = r.u
		var rank := GameState.rank(id)
		var maxr := int(u.max)
		var pips := r.pips as HBoxContainer
		for c in pips.get_children():
			c.queue_free()
		for i in maxr:
			var dot := UITheme.label("●" if i < rank else "○", 16,
				Veil.BRANCH_COLORS[int(u.branch)] if i < rank else UITheme.TEXT_FAINT)
			pips.add_child(dot)
		var buy := r.buy as Button
		var status := r.status as Label
		if rank >= maxr:
			buy.disabled = true
			buy.text = "Maxed"
			status.text = "Fully upgraded"
			status.add_theme_color_override("font_color", UITheme.GOOD)
		elif not GameState.tier_unlocked(int(u.tier)):
			buy.disabled = true
			buy.text = "Locked"
			status.text = "Needs %d upgrade components" % GameState.TIER_COMPONENTS[int(u.tier)]
			status.add_theme_color_override("font_color", UITheme.BAD)
		elif GameState.points_free() < int(u.cost):
			buy.disabled = true
			buy.text = "%d pts" % int(u.cost)
			status.text = "Not enough points"
			status.add_theme_color_override("font_color", UITheme.TEXT_FAINT)
		else:
			buy.disabled = false
			buy.text = "Upgrade (%d)" % int(u.cost)
			status.text = "Rank %d / %d" % [rank, maxr]
			status.add_theme_color_override("font_color", UITheme.TEXT_DIM)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("codex"):
		closed.emit()
		get_viewport().set_input_as_handled()
