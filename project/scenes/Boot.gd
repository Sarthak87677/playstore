extends Node
## Studio splash, then the main menu. Also warms the procedural asset caches so
## the first chapter load is not the first time textures and audio are built.

var _layer: CanvasLayer
var _logo: Control
var _title: Label
var _byline: Label
var _t := 0.0
var _skipped := false

func _ready() -> void:
	Log.info("Boot: %s" % ProjectSettings.get_setting("application/config/name"))
	var args := OS.get_cmdline_user_args()
	if "--autotest" in args:
		_start_autotest(args)
		return
	_build()
	_run()

## Development-only entry point. Never reachable without the command-line flag,
## so shipped builds expose no debug tooling to players.
func _start_autotest(args: PackedStringArray) -> void:
	var chapters: Array = [1]
	var shots := "--shots" in args
	var quick := "--quick" in args
	for a in args:
		if a.begins_with("--chapters="):
			chapters = []
			for part in a.substr(11).split(","):
				if String(part).strip_edges() != "":
					chapters.append(int(part))
	var t: AutoTest = load("res://tests/AutoTest.gd").new()
	# Parented to an autoload so changing scenes does not free the harness.
	SceneFlow.add_child(t)
	t.run(chapters, shots, quick)

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = UITheme.BG_SOLID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)

	_logo = Control.new()
	_logo.set_anchors_preset(Control.PRESET_CENTER)
	_logo.custom_minimum_size = Vector2(320, 320)
	_logo.offset_left = -160
	_logo.offset_top = -200
	_logo.offset_right = 160
	_logo.offset_bottom = 120
	_layer.add_child(_logo)
	_logo.draw.connect(_draw_logo)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -500
	v.offset_right = 500
	v.offset_top = 110
	v.offset_bottom = 240
	v.add_theme_constant_override("separation", 10)
	_layer.add_child(v)

	_title = UITheme.label("THREEFOLD WORKS", 30, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.modulate.a = 0.0
	v.add_child(_title)
	_byline = UITheme.label("an original offline single-player game", 16,
		UITheme.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	_byline.modulate.a = 0.0
	v.add_child(_byline)

	var skip := UITheme.label("press any key to skip", 14, UITheme.TEXT_FAINT,
		HORIZONTAL_ALIGNMENT_CENTER)
	skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip.offset_left = -300
	skip.offset_right = 300
	skip.offset_top = -70
	skip.offset_bottom = -40
	_layer.add_child(skip)

func _draw_logo() -> void:
	var mid := _logo.size * 0.5
	var r := 92.0
	var a := _t * 0.6
	for i in 3:
		var col: Color = Veil.STATE_COLORS[i]
		col.a = clampf(_t * 1.2 - float(i) * 0.25, 0.0, 0.9)
		var off := Vector2(cos(a + TAU * float(i) / 3.0), sin(a + TAU * float(i) / 3.0)) * 16.0
		var pts := PackedVector2Array()
		var n := 3 + i
		for k in n + 1:
			var ang := TAU * float(k) / float(n) - PI * 0.5 + a * (0.4 + 0.2 * i)
			pts.append(mid + off + Vector2(cos(ang), sin(ang)) * (r - i * 12.0))
		_logo.draw_polyline(pts, col, 2.6, true)
	_logo.draw_circle(mid, 5.0, Color(0.92, 0.96, 1.0, clampf(_t - 0.4, 0.0, 1.0)))

func _process(dt: float) -> void:
	if _logo == null or not is_instance_valid(_logo):
		return
	_t += dt
	_logo.queue_redraw()
	_title.modulate.a = clampf((_t - 0.7) * 1.4, 0.0, 1.0)
	_byline.modulate.a = clampf((_t - 1.2) * 1.2, 0.0, 1.0)

func _unhandled_input(e: InputEvent) -> void:
	if _skipped:
		return
	if (e is InputEventKey and (e as InputEventKey).pressed) \
			or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
			or (e is InputEventJoypadButton and (e as InputEventJoypadButton).pressed):
		_skipped = true

func _run() -> void:
	# Warm the procedural caches while the splash plays.
	await get_tree().process_frame
	_warm()
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) < 2600 and not _skipped:
		await get_tree().process_frame
	var t := create_tween()
	t.tween_property(_layer, "offset", Vector2(0, -40), 0.4)
	await SceneFlow.fade_to_black(0.45)
	_layer.queue_free()
	await SceneFlow.goto_menu(false)

func _warm() -> void:
	# Materials and their noise textures generate on engine threads; touching
	# them here means the first chapter does not pay for all of them at once.
	for m in ["rock", "cliff", "concrete", "metal", "metal_rust", "metal_dark",
			"glass", "wood", "bark", "foliage", "grass", "dirt", "sand", "snow",
			"water", "ice", "tile", "nacre", "moss", "brass", "resin"]:
		ProcAssets.mat(m)
	for s in ["ui_click", "ui_hover", "ui_back", "ui_confirm", "ui_deny",
			"shift_memory", "shift_ruin", "shift_bloom", "scan_start", "scan_done",
			"collect", "checkpoint", "jump", "land_soft"]:
		ProcAudio.sfx(s)
	ProcAudio.ambience("wind")
	Log.info("Warm-up complete: %d audio buffers cached" % ProcAudio.cache_size())
