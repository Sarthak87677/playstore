extends CanvasLayer
class_name PauseMenu
## In-game pause: resume, upgrades, field records, settings, restart from the
## last checkpoint, and quit to the main menu (with confirmation).

var game: Node
var _root: Control
var _menu: VBoxContainer
var _panel_holder: Control
var _open := false
var _sub: Control = null
var _confirm: Control

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_build()

func bind(g: Node) -> void:
	game = g

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = UITheme.s(90)
	left.offset_top = UITheme.s(120)
	left.offset_right = UITheme.s(460)
	left.add_theme_constant_override("separation", int(UITheme.s(10)))
	_root.add_child(left)
	_menu = left

	left.add_child(UITheme.title("PAUSED", 40))
	var sub := UITheme.label("", 17, UITheme.TEXT_DIM)
	sub.name = "Sub"
	left.add_child(sub)
	left.add_child(UITheme.spacer(14))

	var items := [
		["Resume", func() -> void: game.resume()],
		["Upgrades", func() -> void: _open_panel("upgrades")],
		["Field Records", func() -> void: _open_panel("records")],
		["Settings", func() -> void: _open_panel("settings")],
		["Save Game", func() -> void: _save_now()],
		["Restart from Checkpoint", func() -> void: _restart()],
		["Quit to Main Menu", func() -> void: _ask_quit()],
	]
	for it in items:
		var b := UITheme.button(String(it[0]), 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(it[1] as Callable)
		left.add_child(b)

	_panel_holder = Control.new()
	_panel_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_panel_holder)

	_confirm = _build_confirm()
	_root.add_child(_confirm)

func _build_confirm() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.panel(UITheme.PANEL_HI, 6, 1, UITheme.ACCENT))
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -UITheme.s(280)
	pc.offset_right = UITheme.s(280)
	pc.offset_top = -UITheme.s(110)
	pc.offset_bottom = UITheme.s(110)
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UITheme.s(14)))
	pc.add_child(v)
	v.add_child(UITheme.label("Quit to the main menu?", 24, UITheme.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.label(
		"Progress is saved at checkpoints. Anything since the last checkpoint is lost.",
		16, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UITheme.s(14)))
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UITheme.button("Quit", 20)
	yes.custom_minimum_size = Vector2(UITheme.s(180), UITheme.s(44))
	yes.pressed.connect(func() -> void:
		_confirm.visible = false
		game.quit_to_menu())
	var no := UITheme.button("Stay", 20)
	no.custom_minimum_size = Vector2(UITheme.s(180), UITheme.s(44))
	no.pressed.connect(func() -> void: _confirm.visible = false)
	h.add_child(yes)
	h.add_child(no)
	v.add_child(h)
	return c

func set_open(v: bool, panel: String = "") -> void:
	_open = v
	_root.visible = v
	_close_panel()
	if v:
		var idx: int = int(GameState.run.get("chapter", 0))
		var sub := _menu.get_node("Sub") as Label
		sub.text = "%s  -  %s   |   Level %d   |   %s played" % [
			"Chapter %d" % (idx + 1), ChapterDB.title(idx), GameState.level(),
			Veil.format_clock(float(GameState.data.get("playtime", 0.0)))]
		if panel != "":
			_open_panel(panel)
		else:
			for c in _menu.get_children():
				if c is Button:
					(c as Button).grab_focus()
					break

func _open_panel(which: String) -> void:
	_close_panel()
	match which:
		"settings":
			_sub = SettingsPanel.new()
		"upgrades":
			_sub = UpgradePanel.new()
		"records":
			_sub = CollectiblesPanel.new()
		"codex":
			_sub = UpgradePanel.new()
	if _sub == null:
		return
	_panel_holder.add_child(_sub)
	_sub.connect("closed", Callable(self, "_close_panel"))

func _close_panel() -> void:
	if _sub != null and is_instance_valid(_sub):
		_sub.queue_free()
	_sub = null

func _save_now() -> void:
	if GameState.save():
		AudioDirector.play_ui("ui_confirm", -10.0)
	else:
		AudioDirector.play_ui("ui_deny", -10.0)

func _restart() -> void:
	if not GameState.has_checkpoint():
		AudioDirector.play_ui("ui_deny", -10.0)
		return
	SceneFlow.set_paused(false)
	SceneFlow.restart_from_checkpoint()

func _ask_quit() -> void:
	_confirm.visible = true

func _unhandled_input(e: InputEvent) -> void:
	if not _open:
		return
	if e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
		if _confirm.visible:
			_confirm.visible = false
		elif _sub != null:
			_close_panel()
		else:
			game.resume()
		get_viewport().set_input_as_handled()
