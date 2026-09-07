extends Control
class_name HowToPlay
## The controls, on one card, in the order a new player needs them.
##
## Shown once at the start of a new game and reachable from the pause menu
## afterwards. Every key is read from the live input map, so it stays correct
## when bindings are remapped.
##
## Three things this has to get right, because all three were wrong once:
##  * It pauses the game, so it MUST process while paused. As a plain child of
##    the pausable Game node it stopped receiving input the moment it appeared,
##    and no key or click could dismiss it.
##  * Its text has to wrap. Fixed-width labels ran the opening paragraph off
##    the right-hand edge of the window, where the player cannot read it.
##  * It has to fit vertically at every UI scale. The card is therefore a
##    centred panel of capped width whose key list scrolls if it ever grows
##    taller than the space available, so the dismiss button is always on
##    screen.

signal closed()

const MAX_WIDTH := 1180.0
const EDGE := 30.0

const GROUPS := [
	["Getting around", [
		["Move", ["move_forward", "move_left", "move_back", "move_right"]],
		["Look", []],
		["Sprint", ["sprint"]],
		["Jump, and mantle onto ledges", ["jump"]],
		["Crouch, or roll just after landing", ["crouch"]],
	]],
	["Looking at things", [
		["Interact, pick up, read", ["interact"]],
		["Scan an object to record what it is", ["scan"]],
		["Ask MOTE what to do next", ["mote_hint"]],
	]],
	["The Veilforge Device", [
		["Aim the veil field", ["veil_aim"]],
		["Choose Memory, Ruin or Bloom", ["veil_prev", "veil_next"]],
		["Shift everything inside the field", ["veil_shift"]],
		["Pin the field so you can walk out of it", ["veil_pin"]],
		["Imprint a recorded property onto something", ["imprint"]],
		["EMP pulse to stun a guardian", ["emp"]],
	]],
	["Menus", [
		["Upgrades, records and objectives", ["codex"]],
		["Pause", ["pause"]],
	]],
]

var _card: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _grid: GridContainer

func _ready() -> void:
	# The card pauses the game; without this it cannot be dismissed.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dim rather than blank. Seeing the world behind the card is what tells the
	# player the game is waiting for them rather than still loading.
	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.023, 0.030, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	# A CenterContainer sizes its child to that child's minimum, so capping the
	# card's minimum width is what caps the card.
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel",
		UITheme.panel(Color(0.038, 0.046, 0.058, 0.97), 10, 1, UITheme.LINE))
	centre.add_child(_card)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	_card.add_child(pad)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	pad.add_child(_body)

	_body.add_child(UITheme.label("HOW TO PLAY", 30, UITheme.TEXT))
	_body.add_child(_wrapped(
		"You are a survey engineer. The Veilforge Device shifts whatever is inside "
		+ "its field between three versions of the same place: Memory (before the "
		+ "damage), Ruin (now) and Bloom (overgrown). A bridge that is gone in Ruin "
		+ "is still standing in Memory - so shift it, and walk across.",
		16, UITheme.TEXT_DIM))
	_body.add_child(_wrapped(
		"Follow the gold diamond. It points at your current objective.",
		16, UITheme.GOLD))
	_body.add_child(UITheme.hsep())

	# The key list scrolls, so a large UI scale cannot push the dismiss button
	# off the bottom of the screen.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)

	# Two columns, not four: four overflowed the window and took the dismiss
	# button off the edge with them.
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 44)
	_grid.add_theme_constant_override("v_separation", 20)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	for g in GROUPS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(col)
		col.add_child(UITheme.label(String(g[0]), 19, UITheme.ACCENT))
		for entry in (g[1] as Array):
			col.add_child(_row(String(entry[0]), entry[1] as Array))

	_body.add_child(UITheme.hsep())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(foot)
	var start := UITheme.button("Got it - start playing", 22)
	start.custom_minimum_size = Vector2(UITheme.s(300), UITheme.s(46))
	start.pressed.connect(_dismiss)
	foot.add_child(start)
	_body.add_child(UITheme.label(
		"or press Enter, Space or Escape.  Prompts retire once you have used an "
		+ "action a few times; Settings has difficulty, hint level and every binding.",
		14, UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER))

	start.call_deferred("grab_focus")
	call_deferred("_fit")
	get_viewport().size_changed.connect(_fit)

## Size the card to the window: as wide as it wants up to a readable maximum,
## and no taller than the space it has. Done after the tree has settled so the
## real minimum sizes are known.
func _fit() -> void:
	if not is_inside_tree() or _card == null:
		return
	var vp := get_viewport_rect().size
	_card.custom_minimum_size.x = minf(MAX_WIDTH * Settings.ui_scale, vp.x - EDGE * 2.0)

	# Everything in the card that is not the scrolling list, measured exactly
	# rather than guessed, so the list gets precisely the leftover height.
	var sep := float(_body.get_theme_constant("separation"))
	var fixed := 0.0
	for c in _body.get_children():
		if c == _scroll:
			continue
		fixed += (c as Control).get_combined_minimum_size().y + sep
	var chrome := _card.get_theme_stylebox("panel").get_minimum_size().y + 36.0
	var room := vp.y - EDGE * 2.0 - chrome - fixed
	var want := _grid.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(want, 0.0, maxf(120.0, room))

func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := UITheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Without this a wrapping label still reports its unwrapped width as its
	# minimum, which is how the opening paragraph ran off the screen.
	l.custom_minimum_size.x = UITheme.s(360)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _row(label: String, actions: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var keys := "Mouse" if actions.is_empty() else ""
	if not actions.is_empty():
		var parts: Array = []
		for a in actions:
			parts.append(Settings.binding_text(String(a)))
		keys = " / ".join(PackedStringArray(parts))
	# No clip_text: a truncated binding is worse than a wide column, because the
	# player cannot tell which key the game actually means.
	var k := UITheme.label(keys, 15, UITheme.GOLD)
	k.custom_minimum_size = Vector2(UITheme.s(150), 0)
	h.add_child(k)
	var d := UITheme.label(label, 15, UITheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = UITheme.s(200)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(d)
	return h

func _dismiss() -> void:
	closed.emit()

## Anything reasonable closes it. A player who cannot find the one key that
## works will conclude the game has frozen -- which is exactly what happened.
func _unhandled_input(e: InputEvent) -> void:
	var go := false
	if e is InputEventKey and (e as InputEventKey).pressed and not e.is_echo():
		go = true
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		go = true
	elif e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed:
		go = true
	elif e is InputEventAction and (e as InputEventAction).pressed:
		# Synthesised actions, which is how the harness drives the game and how a
		# remapped binding can arrive.
		go = true
	if go:
		get_viewport().set_input_as_handled()
		_dismiss()
