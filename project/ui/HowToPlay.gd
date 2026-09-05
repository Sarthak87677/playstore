extends Control
class_name HowToPlay
## The controls, on one card, in the order a new player needs them.
##
## Shown once at the start of a new game and reachable from the pause menu
## afterwards. Every key is read from the live input map, so it stays correct
## when bindings are remapped.

signal closed()

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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG_SOLID
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 46)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(UITheme.label("HOW TO PLAY", 30, UITheme.TEXT))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	var back := UITheme.button("Got it", 20)
	back.pressed.connect(func() -> void: closed.emit())
	head.add_child(back)

	root.add_child(UITheme.label(
		"You are a survey engineer. The Veilforge Device shifts whatever is inside "
		+ "its field between three versions of the same place: Memory (before the "
		+ "damage), Ruin (now) and Bloom (overgrown). A bridge that is gone in Ruin "
		+ "is still standing in Memory - so shift it, and walk across.",
		16, UITheme.TEXT_FAINT))
	root.add_child(UITheme.label(
		"Follow the marker. The gold diamond points at your current objective.",
		16, UITheme.GOLD))
	root.add_child(UITheme.hsep())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 34)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	for gi in GROUPS.size():
		var g: Array = GROUPS[gi]
		if gi == 2:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(10, 0)
			cols.add_child(spacer)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
		col.add_child(UITheme.label(String(g[0]), 19, UITheme.ACCENT))
		for entry in (g[1] as Array):
			col.add_child(_row(String(entry[0]), entry[1] as Array))

	root.add_child(UITheme.label(
		"Prompts retire once you have used an action a few times. "
		+ "Settings has difficulty, hint level, and every binding.",
		14, UITheme.TEXT_FAINT))

func _row(label: String, actions: Array) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var keys := "Mouse" if actions.is_empty() else ""
	if not actions.is_empty():
		var parts: Array = []
		for a in actions:
			parts.append(Settings.binding_text(String(a)))
		keys = " / ".join(PackedStringArray(parts))
	var k := UITheme.label(keys, 15, UITheme.GOLD)
	k.custom_minimum_size = Vector2(150, 0)
	h.add_child(k)
	h.add_child(UITheme.label(label, 15, UITheme.TEXT))
	return h

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or e.is_action_pressed("interact"):
		closed.emit()
		get_viewport().set_input_as_handled()
