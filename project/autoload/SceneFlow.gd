extends Node
## Scene transitions, loading screen and the pause contract.
##
## Chapters are built procedurally, which takes a moment, so loads run through a
## dedicated screen with a real progress bar driven by the chapter builder.

signal load_progress(fraction: float, label: String)
signal scene_ready(scene: Node)
signal pause_toggled(paused: bool)

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Game.tscn"

var _layer: CanvasLayer
var _fade: ColorRect
var _load_root: Control
var _load_bar: ProgressBar
var _load_label: Label
var _load_title: Label
var _load_tip: Label
var _busy := false
var current_kind := "boot"      # boot | menu | game

const TIPS := [
	"A pinned field keeps working while you walk away from it.",
	"Scanning is not just for XP. A recorded property can be imprinted elsewhere.",
	"Guardians track sound as well as sight. Bloom-state undergrowth muffles both.",
	"Memory-state floors sometimes exist where Ruin has only open air.",
	"Roll on landing to keep your momentum and take no impact damage.",
	"If a route looks impossible, it probably exists in a different state.",
	"Bloom roots grow toward anchor points. Give them something to reach for.",
	"Water level, power routing and vegetation are all shift-dependent.",
	"You can hold three recorded properties. Deep Register raises that.",
	"Every chapter hides three Memory Fragments and one upgrade component.",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

	_load_root = Control.new()
	_load_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_root.visible = false
	_load_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_load_root)

	var bg := ColorRect.new()
	bg.color = Color(0.020, 0.024, 0.031, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_root.add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(720, 0)
	vb.offset_left = -360
	vb.offset_top = -110
	vb.offset_right = 360
	vb.offset_bottom = 110
	vb.add_theme_constant_override("separation", 14)
	_load_root.add_child(vb)

	_load_title = Label.new()
	_load_title.add_theme_font_size_override("font_size", 42)
	_load_title.add_theme_color_override("font_color", Color(0.86, 0.90, 0.95))
	_load_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_load_title)

	_load_label = Label.new()
	_load_label.add_theme_font_size_override("font_size", 18)
	_load_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.70))
	_load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_load_label)

	_load_bar = ProgressBar.new()
	_load_bar.custom_minimum_size = Vector2(0, 8)
	_load_bar.show_percentage = false
	_load_bar.max_value = 1.0
	_load_bar.step = 0.001
	vb.add_child(_load_bar)

	_load_tip = Label.new()
	_load_tip.add_theme_font_size_override("font_size", 16)
	_load_tip.add_theme_color_override("font_color", Color(0.45, 0.52, 0.60))
	_load_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_tip.custom_minimum_size = Vector2(0, 48)
	vb.add_child(_load_tip)

func report(fraction: float, label: String) -> void:
	if _load_bar:
		_load_bar.value = clampf(fraction, 0.0, 1.0)
	if _load_label:
		_load_label.text = label
	load_progress.emit(fraction, label)

# ================================================================ fades
func fade_to_black(time: float = 0.45) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color", Color(0, 0, 0, 1), time)
	await t.finished

func fade_from_black(time: float = 0.6) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color", Color(0, 0, 0, 0), time)
	await t.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func flash(color: Color = Color(1, 1, 1, 0.85), time: float = 0.3) -> void:
	if Settings.reduce_flashing:
		return
	_fade.color = color
	var t := create_tween()
	t.tween_property(_fade, "color", Color(color.r, color.g, color.b, 0.0), time)

# ================================================================ transitions
func show_loading(title: String) -> void:
	_load_title.text = title
	_load_tip.text = TIPS[randi() % TIPS.size()]
	_load_bar.value = 0.0
	_load_label.text = "Preparing"
	_load_root.visible = true

func hide_loading() -> void:
	_load_root.visible = false

func goto_menu(fade: bool = true) -> void:
	if _busy:
		return
	_busy = true
	set_paused(false)
	if fade:
		await fade_to_black(0.4)
	AudioDirector.stop_all()
	Hints.clear_contexts()
	get_tree().change_scene_to_file(MENU_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame
	current_kind = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.start_menu_music()
	_busy = false
	await fade_from_black(0.6)

## Enter a chapter. `mode` is "new", "checkpoint" or "time_trial".
func start_chapter(index: int, mode: String = "new") -> void:
	if _busy:
		return
	_busy = true
	set_paused(false)
	await fade_to_black(0.4)
	AudioDirector.stop_all()
	Hints.clear_contexts()
	show_loading(ChapterDB.title(index))
	await get_tree().process_frame

	get_tree().change_scene_to_file(GAME_SCENE)
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("begin"):
		Log.err("Game scene failed to load")
		hide_loading()
		_busy = false
		await goto_menu(false)
		return
	current_kind = "game"
	await scene.begin(index, mode)
	hide_loading()
	_busy = false
	scene_ready.emit(scene)
	await fade_from_black(0.8)

func restart_from_checkpoint() -> void:
	var idx: int = int(GameState.run.get("chapter", 0))
	await start_chapter(idx, "checkpoint")

func quit_to_menu() -> void:
	GameState.end_run()
	GameState.save()
	await goto_menu()

# ================================================================ pause
func set_paused(v: bool) -> void:
	get_tree().paused = v
	GameState.run["paused"] = v
	pause_toggled.emit(v)

func is_paused() -> bool:
	return get_tree().paused

func request_quit() -> void:
	GameState.save()
	Log.info("Clean shutdown requested.")
	await fade_to_black(0.35)
	get_tree().quit()
