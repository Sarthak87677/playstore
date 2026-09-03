extends Node3D
## Gameplay host. Owns the player, camera, MOTE, HUD, pause menu and the
## currently loaded chapter, and drives death/respawn and chapter completion.

var chapter: ChapterBase
var player: Player
var cam: PlayerCamera
var mote: Mote
var hud: HUD
var pause_menu: Node
var results: Node
var _mode := "new"
var _dead := false
var _completing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

## Called by SceneFlow. Builds everything, then starts the run.
func begin(index: int, mode: String) -> void:
	_mode = mode
	GameState.reset_run(index)
	if mode == "checkpoint" and GameState.has_checkpoint() \
			and int(GameState.checkpoint().get("chapter", -1)) == index:
		GameState.restore_run_from_checkpoint()
	GameState.run["chapter"] = index
	GameState.run["time_trial"] = mode == "time_trial"
	if mode == "time_trial":
		GameState.run["time"] = 0.0

	SceneFlow.report(0.04, "Waking the device")
	await get_tree().process_frame

	cam = PlayerCamera.new()
	add_child(cam)
	player = Player.new()
	add_child(player)
	cam.set_target(player)
	mote = Mote.new()
	add_child(mote)
	if Log.skipping("mote"):
		mote.set_process(false)

	var script_path: String = String(ChapterDB.get_chapter(index).builder)
	var cs: GDScript = load(script_path)
	if cs == null:
		Log.err("Chapter builder missing: %s" % script_path)
		return
	chapter = cs.new()
	chapter.setup(index)
	add_child(chapter)

	player.bind(cam, chapter.manager if chapter.manager else null)
	await chapter.construct(player, cam, mote)

	player.bind(cam, chapter.manager)
	player.device.manager = chapter.manager
	mote.bind(player, chapter.manager)
	chapter.manager.set_player(player)

	hud = HUD.new()
	add_child(hud)
	if Log.skipping("hud"):
		hud.set_process(false)
		hud.set_hud_visible(false)
	else:
		hud.bind(player, chapter)
	mote.spoke.connect(func(t: String, s: String, d: float) -> void:
		hud.show_subtitle(t, s, d))

	pause_menu = load("res://ui/PauseMenu.gd").new()
	add_child(pause_menu)
	pause_menu.bind(self)

	results = load("res://ui/ResultsScreen.gd").new()
	add_child(results)

	# --- place the player
	var start_pos := chapter.spawn_position
	var start_yaw := chapter.spawn_yaw
	if mode == "checkpoint" and GameState.has_checkpoint():
		var cp: Dictionary = GameState.checkpoint()
		if int(cp.get("chapter", -1)) == index and cp.has("pos"):
			var p: Array = cp.pos
			start_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
			start_yaw = float(cp.get("yaw", 0.0))
			chapter.manager.set_base_state(int(cp.get("base_state", chapter.manager.base_state)))
			chapter.load_flags(cp.get("flags", {}))
			chapter.active_checkpoint = {"id": cp.get("id", ""), "pos": start_pos, "yaw": start_yaw}
	player.global_position = start_pos
	player.rotation.y = start_yaw
	player.set_spawn(start_pos, start_yaw)
	cam.yaw = rad_to_deg(start_yaw) + 180.0
	mote.global_position = start_pos + Vector3(-0.9, 2.0, -0.6)

	player.died.connect(_on_death)
	chapter.chapter_complete.connect(_on_chapter_complete)

	SceneFlow.report(1.0, "Ready")
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.begin_run()
	chapter.begin_play(mode)
	Log.info("Chapter %d started (%s), %d veil subjects" % [
		index + 1, mode, chapter.manager.subject_count()])

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("codex") and not SceneFlow.is_paused():
		open_codex()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("mote_hint") and not SceneFlow.is_paused():
		if mote:
			mote.ping_hint()
		var line := Hints.request_hint()
		hud.show_subtitle(line, "MOTE", 5.0)
		Hints.did("mote")

func toggle_pause() -> void:
	if _completing or _dead:
		return
	var want := not SceneFlow.is_paused()
	SceneFlow.set_paused(want)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if want else Input.MOUSE_MODE_CAPTURED
	if pause_menu:
		pause_menu.set_open(want)
	if want:
		AudioDirector.play_ui("ui_click", -12.0)

func open_codex() -> void:
	SceneFlow.set_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_menu:
		pause_menu.set_open(true, "codex")
	Hints.did("codex")

func resume() -> void:
	SceneFlow.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if pause_menu:
		pause_menu.set_open(false)

# ================================================================ death
func _on_death() -> void:
	if _dead:
		return
	_dead = true
	player.set_input_enabled(false)
	AudioDirector.set_intensity(0.0)
	await get_tree().create_timer(1.6).timeout
	await SceneFlow.fade_to_black(0.6)
	respawn()
	await SceneFlow.fade_from_black(0.8)

func respawn() -> void:
	var pos := chapter.spawn_position
	var yaw := chapter.spawn_yaw
	if not chapter.active_checkpoint.is_empty():
		pos = chapter.active_checkpoint.pos
		yaw = float(chapter.active_checkpoint.yaw)
	for g in chapter.guardians:
		if is_instance_valid(g) and (g as Guardian).state != Guardian.St.DOWN:
			(g as Guardian).state = Guardian.St.PATROL
			(g as Guardian).awareness = 0.0
	player.revive_at(pos, yaw)
	player.set_input_enabled(true)
	mote.global_position = pos + Vector3(-0.9, 2.0, -0.6)
	_dead = false
	hud.toast("Restored from checkpoint", UITheme.ACCENT)

# ================================================================ completion
func _on_chapter_complete() -> void:
	if _completing:
		return
	_completing = true
	player.set_input_enabled(false)
	player.device.set_aiming(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioDirector.set_intensity(0.0)
	await get_tree().create_timer(1.0).timeout
	var idx: int = int(GameState.run.get("chapter", 0))
	if GameState.run.get("time_trial", false):
		var t := float(GameState.run.get("time", 0.0))
		var best := GameState.record_time_trial(idx, t)
		GameState.end_run()
		results.show_time_trial(idx, t, best)
	else:
		var res := GameState.finish_chapter(idx)
		results.show_results(res)
	hud.set_hud_visible(false)

func advance_after_results() -> void:
	var idx: int = int(GameState.run.get("chapter", 0))
	if idx + 1 < ChapterDB.COUNT and not GameState.run.get("time_trial", false):
		await SceneFlow.start_chapter(idx + 1, "new")
	else:
		await SceneFlow.goto_menu()

func quit_to_menu() -> void:
	await SceneFlow.quit_to_menu()
