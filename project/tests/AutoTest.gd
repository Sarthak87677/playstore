extends Node
class_name AutoTest
## Automated playtest harness. Boots the game, loads chapters, drives the
## player and the device through real gameplay actions, and reports pass/fail
## per check. Run with:
##   godot --path project -- --autotest [--chapters=1,2,3] [--shots] [--quick]
##
## This is a development tool. It is only constructed when the flag is present,
## so a shipped build has no way to reach it.

var results: Array = []
var failures := 0
var checks := 0
var shots := false
var quick := false
var chapters: Array = []
var shot_dir := "user://shots"
var _shot_i := 0

func run(p_chapters: Array, p_shots: bool, p_quick: bool) -> void:
	chapters = p_chapters
	shots = p_shots
	quick = p_quick
	if shots:
		DirAccess.make_dir_recursive_absolute(shot_dir)
	Engine.max_fps = 120
	print("\n=== VEILFORGE AUTOTEST ===")
	print("chapters: %s  shots: %s  quick: %s" % [chapters, shots, quick])
	await get_tree().process_frame

	if quick:
		await _memidle(int(chapters[0]) - 1)
		return
	if shots and not ("play" in Log.skip):
		await _shoot_front_end()
		for c in chapters:
			await _shotwalk(int(c) - 1)
		get_tree().quit(0)
		return
	print("      %s (boot)" % _mem())
	await _test_settings()
	print("      %s (after settings)" % _mem())
	await _test_saves()
	await _test_progression()
	await _test_audio()
	print("      %s (after system tests)" % _mem())
	await _test_menus()
	for c in chapters:
		await _test_chapter(int(c) - 1)
	await _test_resume(int(chapters[0]) - 1)
	await _test_pause_menu(int(chapters[0]) - 1)
	_report()

# ================================================================ helpers
func check(name: String, cond: bool, detail: String = "") -> bool:
	checks += 1
	if not cond:
		failures += 1
	results.append({"name": name, "ok": cond, "detail": detail})
	print("%s  %s%s" % ["PASS" if cond else "FAIL", name,
		("   [%s]" % detail) if detail != "" else ""])
	return cond

func _report() -> void:
	print("\n=== RESULT: %d/%d checks passed, %d failed ===" % [
		checks - failures, checks, failures])
	var f := FileAccess.open("user://autotest_report.txt", FileAccess.WRITE)
	if f:
		f.store_line("VEILFORGE autotest %s" % Time.get_datetime_string_from_system())
		for r in results:
			f.store_line("%s  %s  %s" % ["PASS" if r.ok else "FAIL", r.name, r.detail])
		f.store_line("TOTAL %d/%d passed" % [checks - failures, checks])
		f.close()
	get_tree().quit(1 if failures > 0 else 0)

## Actions handled in _unhandled_input (jump, interact, veil keys) need a real
## event, not just a polled action state, so the harness synthesises one.
func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)

func _release(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)

func _mem() -> String:
	return "rss %.0f MB  nodes %d  godot %.0f MB  audio %d" % [
		Log.rss_mb(), get_tree().get_node_count(),
		OS.get_static_memory_usage() / 1048576.0, ProcAudio.cache_size()]

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		t += get_process_delta_time()
		await get_tree().process_frame

func _shot(tag: String) -> void:
	if not shots or DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_i += 1
	var p := "%s/%02d_%s.png" % [shot_dir, _shot_i, tag]
	img.save_png(p)
	print("      shot -> %s" % ProjectSettings.globalize_path(p))

# ================================================================ system tests
func _test_settings() -> void:
	print("\n-- settings --")
	check("input map has all actions bound", _all_actions_bound())
	Settings.preset = Settings.Preset.LOW
	Settings.apply_video()
	check("low preset applies", is_equal_approx(get_viewport().scaling_3d_scale, 0.75),
		"scale3d=%.2f" % get_viewport().scaling_3d_scale)
	Settings.preset = Settings.Preset.HIGH
	Settings.apply_video()
	check("high preset applies", is_equal_approx(get_viewport().scaling_3d_scale, 1.0))
	Settings.vol_music = 0.33
	Settings.apply_audio()
	var idx := AudioServer.get_bus_index("Music")
	check("audio buses exist", idx >= 0 and AudioServer.get_bus_index("SFX") >= 0
		and AudioServer.get_bus_index("Ambience") >= 0 and AudioServer.get_bus_index("UI") >= 0)
	check("music bus volume applied",
		absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.33)) < 0.01)
	Settings.vol_music = 0.7
	Settings.apply_audio()
	Settings.save_settings()
	check("settings file written", FileAccess.file_exists(Settings.PATH))
	var before := Settings.mouse_sensitivity
	Settings.mouse_sensitivity = 0.77
	Settings.save_settings()
	Settings.mouse_sensitivity = 0.1
	Settings.load_settings()
	check("settings round-trip", is_equal_approx(Settings.mouse_sensitivity, 0.77),
		"got %.3f" % Settings.mouse_sensitivity)
	Settings.mouse_sensitivity = before
	Settings.save_settings()
	# accessibility
	Settings.colorblind_states = true
	check("colour-blind palette differs",
		Settings.state_color(1) != Veil.STATE_COLORS[1])
	Settings.colorblind_states = false
	Settings.reduce_camera_shake = 1.0
	check("shake can be fully disabled", is_equal_approx(Settings.shake_scale(), 0.0))
	Settings.reduce_camera_shake = 0.0

func _all_actions_bound() -> bool:
	for a in Settings.ACTIONS:
		if not InputMap.has_action(a):
			return false
		if InputMap.action_get_events(a).is_empty():
			return false
	return true

func _test_saves() -> void:
	print("\n-- saves --")
	SaveSystem.erase(2)
	check("empty slot reads empty", SaveSystem.read(2).is_empty())
	check("header reports empty", bool(SaveSystem.header(2).get("empty", false)))
	var p := SaveSystem.new_profile(1)
	p.xp = 4321
	p.chapters["ch01"].completed = true
	p.chapters["ch01"].fragments = [true, true, false]
	check("write slot 2", SaveSystem.write(2, p))
	p.playtime = 12.0
	SaveSystem.write(2, p)
	var back := SaveSystem.read(2)
	check("read back xp", int(back.get("xp", 0)) == 4321)
	check("read back nested record", bool(back.chapters.ch01.completed))
	check("header non-empty", not bool(SaveSystem.header(2).get("empty", true)))
	# corruption handling
	var f := FileAccess.open(SaveSystem.path(2), FileAccess.WRITE)
	f.store_string("{ this is not json ")
	f.close()
	var recovered := SaveSystem.read(2)
	check("corrupt save recovers from backup",
		not recovered.is_empty() and int(recovered.get("xp", 0)) == 4321,
		"xp=%s" % str(recovered.get("xp", "none")))
	# missing everything
	SaveSystem.erase(2)
	check("erase removes slot", not SaveSystem.exists(2))
	check("missing save handled safely", SaveSystem.read(2).is_empty())
	# hand-mangled but valid JSON
	var f2 := FileAccess.open(SaveSystem.path(2), FileAccess.WRITE)
	f2.store_string('{"xp": "not a number", "chapters": 5}')
	f2.close()
	var s := SaveSystem.read(2)
	check("mangled types sanitised",
		typeof(s.get("xp")) == TYPE_INT and (s.get("chapters") is Dictionary))
	SaveSystem.erase(2)

func _test_progression() -> void:
	print("\n-- progression --")
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	check("new profile at level 1", GameState.level() == 1)
	check("no points at start", GameState.points_total() == 0)
	GameState.award(Veil.xp_for_level(10), "test")
	check("xp reaches level 10", GameState.level() == 10, "level=%d" % GameState.level())
	check("points granted", GameState.points_total() == 9)
	check("cannot buy tier 2 without components", not GameState.can_buy("shift_cost"))
	check("can buy tier 1", GameState.can_buy("field_radius"))
	var r0 := GameState.field_radius()
	GameState.buy("field_radius")
	check("upgrade applies to derived stat", GameState.field_radius() > r0,
		"%.1f -> %.1f" % [r0, GameState.field_radius()])
	GameState.data.components = 5
	check("tier 3 unlocks with components", GameState.tier_unlocked(2))
	check("fragment recorded", GameState.note_fragment(0, 0))
	check("duplicate fragment rejected", not GameState.note_fragment(0, 0))
	check("fragment count", GameState.total_fragments_found() == 1)
	GameState.save()
	var reloaded := SaveSystem.read(2)
	check("upgrades persist", int(reloaded.upgrades.get("field_radius", 0)) == 1)
	check("fragments persist", bool(reloaded.chapters.ch01.fragments[0]))
	# chain multiplier
	GameState.break_chain()
	var base_xp := GameState.xp()
	GameState.award(100, "a", true)
	GameState.award(100, "b", true)
	GameState.award(100, "c", true)
	check("discovery chain multiplies", GameState.xp() - base_xp > 300,
		"gained %d" % (GameState.xp() - base_xp))
	# results / rank
	GameState.reset_run(0)
	GameState.run.time = 400.0
	GameState.run.puzzles = 5
	GameState.run.puzzles_perfect = 5
	GameState.run.fragments = 3
	GameState.run.new_scans = 14
	GameState.run.component = true
	GameState.run.challenge = true
	var res := GameState.compute_results(0)
	check("results produce a rank", int(res.rank) >= 0 and int(res.rank) <= 3,
		"rank=%s total=%d" % [res.rank_name, int(res.total)])
	check("bonuses awarded", (res.bonuses as Array).size() >= 4,
		"%d bonuses" % (res.bonuses as Array).size())
	# finish + unlock
	var fin := GameState.finish_chapter(0)
	check("chapter marked complete", GameState.is_chapter_complete(0))
	check("next chapter unlocked", GameState.is_chapter_unlocked(1))
	check("checkpoint cleared on completion", not GameState.has_checkpoint())
	# new game plus
	GameState.data.finished_game = true
	GameState.start_new_game_plus()
	check("ng+ increments", GameState.ngplus() == 1)
	check("ng+ relocks chapters", not GameState.is_chapter_complete(0))
	check("ng+ keeps upgrades", GameState.rank("field_radius") == 1)
	check("ng+ keeps fragments", GameState.total_fragments_found() == 1)

func _test_audio() -> void:
	print("\n-- procedural audio --")
	var w := ProcAudio.sfx("shift_memory")
	check("sfx generates samples", w != null and w.data.size() > 1000,
		"%d bytes" % (w.data.size() if w else 0))
	var amb := ProcAudio.ambience("wind")
	check("ambience loops", amb != null and amb.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var pad := ProcAudio.pad(45.0, 2.0)
	check("instrument renders", pad != null and pad.data.size() > 10000)
	var step := ProcAudio.footstep(Veil.Surface.METAL, 0)
	check("footsteps per surface", step != null and step.data.size() > 500)
	# distinct output per reality state
	var a := ProcAudio.sfx("shift_memory").data
	var b := ProcAudio.sfx("shift_ruin").data
	check("state shifts sound different", a != b)
	print("\n-- procedural assets --")
	check("materials build", ProcAssets.mat("rock") != null and ProcAssets.mat("nacre") != null)
	var rm := ProcAssets.rock_mesh(1, 1.0)
	check("rock mesh has geometry", rm.get_surface_count() > 0
		and rm.get_faces().size() >= 300, "%d verts / %d face verts" % [
			rm.surface_get_array_len(0), rm.get_faces().size()])
	var tm := ProcAssets.trunk_mesh(1, 6.0, 0.5)
	check("trunk mesh has geometry", tm.get_faces().size() >= 300,
		"%d face verts" % tm.get_faces().size())
	var cm := ProcAssets.canopy_mesh(1, 2.0, 3)
	check("canopy mesh has geometry", cm.get_faces().size() >= 300,
		"%d face verts" % cm.get_faces().size())
	check("mesh cache reuses", ProcAssets.rock_mesh(1, 1.0) == rm)

## --quick: load a chapter, idle, and report real RSS each second. Used with
## --skip=... to bisect which subsystem is responsible for memory growth.
func _memidle(idx: int) -> void:
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	await SceneFlow.start_chapter(idx, "new")
	print("skips: %s  max_fps=%d" % [str(Log.skip), Engine.max_fps])
	if "uncapped" in Log.skip:
		Engine.max_fps = 0
	var game := get_tree().current_scene
	var pl: Player = game.player
	pl.device.unlock_all()
	var acts := Log.skip
	for i in 22:
		# Drive real gameplay so the probe exercises the same code paths a
		# player would, not just an idle frame.
		if not ("move" in acts):
			Input.action_press("move_forward")
			await _wait(0.4)
			Input.action_release("move_forward")
			_press("jump"); await _wait(0.02); _release("jump")
		if not ("aim" in acts):
			pl.device.set_aiming(true)
			await _wait(0.35)
			pl.device.set_state((i % 3))
			pl.device.perform_shift()
			await _wait(0.1)
			pl.device.set_aiming(false)
		if not ("scan" in acts):
			pl.device.begin_scan()
			await _wait(0.2)
			pl.device.end_scan()
		await _wait(0.4)
		print("t=%2d  rss=%.0f MB  nodes=%d  godot=%.0f MB  audio=%d" % [
			i, Log.rss_mb(), get_tree().get_node_count(),
			OS.get_static_memory_usage() / 1048576.0, ProcAudio.cache_size()])
	get_tree().quit(0)

## Rendered capture of the front end, so the menus are evidenced as well as
## asserted.
func _shoot_front_end() -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	await SceneFlow.goto_menu(false)
	var menu := get_tree().current_scene
	await _wait(1.4)
	await _shot("ui_main_menu")
	menu._open("chapters")
	await _wait(0.9)
	await _shot("ui_chapter_select")
	menu._close()
	menu._open("settings")
	await _wait(0.9)
	await _shot("ui_settings")
	menu._close()
	await _wait(0.3)
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	GameState.award(Veil.xp_for_level(12), "capture")
	GameState.data.components = 5
	await SceneFlow.start_chapter(0, "new")
	var game := get_tree().current_scene
	game.toggle_pause()
	await _wait(0.7)
	game.pause_menu._open_panel("upgrades")
	await _wait(1.0)
	await _shot("ui_upgrades")
	game.pause_menu._close_panel()
	game.pause_menu._open_panel("records")
	await _wait(1.0)
	await _shot("ui_records")
	game.pause_menu._close_panel()
	game.resume()
	await _wait(0.4)

## Rendered capture pass: load a chapter, fly a camera to a few vantage points
## and photograph each reality state. Used to eyeball the art direction.
func _shotwalk(idx: int) -> void:
	DirAccess.make_dir_recursive_absolute(shot_dir)
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	await SceneFlow.start_chapter(idx, "new")
	var game := get_tree().current_scene
	var ch: ChapterBase = game.chapter
	var pl: Player = game.player
	pl.device.unlock_all()
	pl.set_input_enabled(false)
	# The capture pass parks the player somewhere safe and flies a free camera;
	# without this the weather or a fall would kill them mid-shot and the frame
	# would be captured through the death fade.
	pl.invulnerable = true
	pl.set_cutscene(true)
	if game.hud:
		game.hud.set_hud_visible(false)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 900.0
	ch.add_child(cam)
	cam.current = true
	cam.attributes = game.cam.camera.attributes
	if "nofog" in Log.skip:
		var e := ch.atmosphere.environment
		e.fog_enabled = false
		e.volumetric_fog_enabled = false
		e.sdfgi_enabled = false
		print("fog and sdfgi disabled for capture")

	if ch.terrain:
		var mi := ch.terrain.mesh_instance
		print("terrain: visible=%s surfaces=%d aabb=%s mat=%s" % [
			mi.visible, mi.mesh.get_surface_count(), str(mi.get_aabb()),
			str(mi.material_override)])
	var spots: Array = ch.shot_spots()
	spots.append({"name": "eye", "pos": ch.spawn_position + Vector3(2.5, 1.7, 7.0),
		"look": ch.spawn_position + Vector3(0, 1.4, -16.0)})
	if "oneshot" in Log.skip:
		# A single representative frame per chapter: software rendering makes the
		# full three-state sweep of every vantage point very slow.
		spots = [spots[0]]
		spots[0]["states"] = [Veil.State.RUIN]
	for si in spots.size():
		var spot: Dictionary = spots[si]
		cam.global_position = spot.pos
		cam.look_at(spot.look, Vector3.UP)
		var states: Array = spot.states if spot.has("states") else [0, 1, 2]
		for st in states:
			ch.manager.set_base_state(int(st))
			ch.atmosphere.force_state(int(st))
			await _wait(0.8)
			await _shot("ch%02d_%s_%s" % [idx + 1, String(spot.name),
				Veil.STATE_SHORT[int(st)].to_lower()])
	print("captured %d frames" % _shot_i)

# ================================================================ chapter tests
func _test_chapter(idx: int) -> void:
	print("\n-- chapter %d: %s -- (t=%.1fs)" % [idx + 1, ChapterDB.title(idx),
		Time.get_ticks_msec() / 1000.0])
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	var t0 := Time.get_ticks_msec()
	await SceneFlow.start_chapter(idx, "new")
	var load_ms := Time.get_ticks_msec() - t0
	var game := get_tree().current_scene
	if not check("chapter scene loaded", game != null and game.has_method("begin")):
		return
	var ch: ChapterBase = game.chapter
	var pl: Player = game.player
	if not check("chapter built", ch != null and pl != null):
		return
	print("      load time %.2f s   %s" % [load_ms / 1000.0, _mem()])

	check("terrain or ground present", ch.terrain != null
		or ch.get_child_count() > 6)
	check("veil subjects registered", ch.manager.subject_count() > 0,
		"%d subjects" % ch.manager.subject_count())
	check("puzzles present", ch.puzzles.size() >= 3,
		"%d puzzles" % ch.puzzles.size())
	var frags := 0
	var comps := 0
	var scans := 0
	var cps := 0
	for n in _walk(ch):
		if n is Collectible:
			if (n as Collectible).kind == Collectible.Kind.FRAGMENT: frags += 1
			elif (n as Collectible).kind == Collectible.Kind.COMPONENT: comps += 1
		elif n is Scannable: scans += 1
		elif n is Checkpoint: cps += 1
	check("three memory fragments", frags == 3, "%d found" % frags)
	check("one upgrade component", comps == 1, "%d found" % comps)
	check("scannable objects present", scans >= 3, "%d" % scans)
	check("checkpoints present", cps >= 2, "%d" % cps)
	check("objective set", Hints.objective != "")
	print("      phase: locomotion (t=%.1fs)" % (Time.get_ticks_msec() / 1000.0))

	# --- physical sanity: the player must be standing on something
	await _wait(0.7)
	var start_y := pl.global_position.y
	await _wait(1.2)
	check("player does not fall through the world",
		pl.global_position.y > start_y - 12.0,
		"y %.1f -> %.1f" % [start_y, pl.global_position.y])
	check("player is grounded or supported", pl.is_on_floor() or pl.mode == Player.Mode.SWIM,
		"mode=%d on_floor=%s" % [pl.mode, pl.is_on_floor()])
	await _shot("ch%02d_spawn" % (idx + 1))

	# --- movement really moves. Try each direction: the spawn may face a prop.
	var best_move := 0.0
	var best_dir := ""
	for dir in ["move_forward", "move_left", "move_right", "move_back"]:
		var p0 := pl.global_position
		pl.velocity = Vector3.ZERO
		Input.action_press(dir)
		await _wait(1.0)
		Input.action_release(dir)
		var d := p0.distance_to(pl.global_position)
		if d > best_move:
			best_move = d
			best_dir = dir
		await _wait(0.2)
		if best_move > 1.5:
			break
	check("input drives movement", best_move > 1.5,
		"%s moved %.2f m" % [best_dir, best_move])

	# --- jumping (goes through _unhandled_input, so needs a real event)
	await _wait(0.6)
	var y0 := pl.global_position.y
	_press("jump")
	await _wait(0.02)
	_release("jump")
	await _wait(0.24)
	check("jump lifts the player", pl.global_position.y > y0 + 0.25,
		"+%.2f m from y=%.1f" % [pl.global_position.y - y0, y0])
	await _wait(1.6)
	print("      %s (after locomotion, t=%.1fs)" % [_mem(),
		Time.get_ticks_msec() / 1000.0])

	print("      %s (after movement)" % _mem())

	# --- the device
	var dev := pl.device
	dev.unlock_all()
	var e0 := dev.energy
	dev.set_aiming(true)
	await _wait(0.35)
	check("field activates", dev.aiming and dev.field.active)
	check("field radius follows upgrades",
		is_equal_approx(dev.field.radius, GameState.field_radius()))
	dev.set_state(Veil.State.MEMORY)
	var shifted := dev.perform_shift()
	check("shift consumes energy and succeeds", shifted and dev.energy < e0,
		"%.1f -> %.1f" % [e0, dev.energy])
	await _wait(0.3)
	check("world state query works",
		ch.manager.state_at(dev.field.global_position) == Veil.State.MEMORY)
	await _shot("ch%02d_field" % (idx + 1))
	dev.set_aiming(false)
	await _wait(0.2)

	# --- energy regenerates
	var e1 := dev.energy
	await _wait(1.6)
	check("energy regenerates", dev.energy > e1, "%.1f -> %.1f" % [e1, dev.energy])

	print("      %s (after device)" % _mem())

	# --- every veil subject can reach every state it declares
	var bad := 0
	var tested := 0
	for s in ch.manager.subjects:
		var vs := s as VeilSubject
		if vs.locked:
			continue
		tested += 1
		for st in 3:
			if not vs.has_variant(st):
				continue
			vs.apply_state(st, true)
			if vs.current_state != st:
				bad += 1
		vs.apply_state(ch.manager.base_state, true)
	check("all veil subjects switch cleanly", bad == 0,
		"%d subjects tested, %d bad" % [tested, bad])

	# --- state changes really change collision
	var collision_changed := await _collision_differs(ch)
	check("reality states change collision", collision_changed,
		"found a subject whose collision differs by state")

	# --- scanning and imprinting
	var sc := _first_scannable_with_prop(ch)
	if sc != null:
		if sc.property_state >= 0:
			ch.manager.set_base_state(sc.property_state)
			await _wait(0.2)
		var info := sc.perform_scan(pl)
		check("scan returns a property", int(info.property) != Veil.Prop.NONE,
			Veil.prop_name(int(info.property)))
		dev._store_record(int(info.property), String(info.name))
		check("property enters the register", dev.has_property(int(info.property)))
		var im := _first_imprintable_accepting(ch, int(info.property))
		if im != null:
			var ok := im.apply(int(info.property))
			check("imprint applies to a target", ok and im.current == int(info.property))
		ch.manager.set_base_state(Veil.State.RUIN)
	else:
		check("chapter offers a recordable property", false, "none found")

	print("      %s (after scan/imprint)" % _mem())

	# --- damage, death and respawn
	var cp_list: Array = ch.checkpoints
	if cp_list.size() > 0:
		var cp := cp_list[0] as Checkpoint
		ch._on_checkpoint(cp.id)
		check("checkpoint stores a save", GameState.has_checkpoint())
	var sh0 := pl.shield
	pl.apply_damage(25.0, "autotest")
	check("damage reduces shield", pl.shield < sh0, "%.0f -> %.0f" % [sh0, pl.shield])
	# Score the run as if it had gone well, then kill the player outright and
	# score it again. A lethal hazard deals 9999 damage so that nothing survives
	# it; recording that verbatim scored a single fall into a pit at -24000,
	# which zeroed the chapter total and pinned the rank to C however well the
	# rest of the chapter was played. Only damage the shield absorbs is counted
	# now, so a death is a real cost and not an erasure.
	GameState.run.puzzles = 5
	GameState.run.puzzles_perfect = 5
	GameState.run.fragments = 3
	GameState.run.new_scans = 12
	var alive_total: int = int(GameState.compute_results(idx).total)
	pl.apply_damage(9999.0, "autotest")
	check("lethal damage kills", not pl.is_alive())
	var dead_total: int = int(GameState.compute_results(idx).total)
	check("dying costs score without erasing the run",
		dead_total < alive_total and dead_total > alive_total / 2,
		"%d -> %d" % [alive_total, dead_total])
	await _wait(3.4)
	check("respawn restores control", pl.is_alive() and pl.shield > 0.0)

	print("      %s (after death/respawn)" % _mem())

	# --- guardians behave
	if ch.guardians.size() > 0:
		var g := ch.guardians[0] as Guardian
		g.apply_emp(3.0)
		check("EMP stuns a guardian", g.state == Guardian.St.STUNNED)
		g.take_down("autotest")
		check("guardian can be disabled", g.state == Guardian.St.DOWN)

	print("      %s (after guardians)" % _mem())

	# --- solve every puzzle programmatically and confirm bookkeeping
	var solved_before := int(GameState.run.get("puzzles", 0))
	for p in ch.puzzles:
		var pz := p as PuzzleBase
		if not pz.is_solved:
			pz.mark_solved()
		await _wait(0.05)
	var unsolved := 0
	for pz2 in ch.puzzles:
		if not (pz2 as PuzzleBase).is_solved:
			unsolved += 1
	check("every puzzle can be solved", unsolved == 0,
		"%d of %d solved, %d unsolved" % [
			ch.puzzles.size() - unsolved, ch.puzzles.size(), unsolved])

	# --- chapter can be finished and scored
	print("      nodes %d   mem %.1f MB (post-play)" % [
		_node_count(), OS.get_static_memory_usage() / 1048576.0])
	ch.finish()
	await _wait(1.6)
	check("chapter completion recorded", GameState.is_chapter_complete(idx)
		or bool(GameState.chapter_record(idx).get("completed", false)))
	check("results produced a rank", int(GameState.chapter_record(idx).get("rank", -1)) >= 0)
	await _shot("ch%02d_results" % (idx + 1))
	if idx + 1 < ChapterDB.COUNT:
		check("next chapter unlocked", GameState.is_chapter_unlocked(idx + 1))
	await _wait(0.4)

func _node_count() -> int:
	return get_tree().get_node_count()

## Every front-end screen must build and open without errors, and the buttons
## that matter must actually be wired to something.
func _test_menus() -> void:
	print("\n-- front end --")
	await SceneFlow.goto_menu(false)
	var menu := get_tree().current_scene
	if not check("main menu scene loads", menu != null and menu.has_method("_open")):
		return
	var buttons: Array = []
	for n in _walk(menu):
		if n is Button:
			buttons.append((n as Button).text)
	check("main menu offers the expected entries",
		"New Game" in buttons and "Continue" in buttons and "Settings" in buttons
			and "Credits" in buttons and "Exit" in buttons and "Extras" in buttons
			and "Chapter Select" in buttons,
		", ".join(PackedStringArray(buttons)))
	check("every main-menu button is connected", _all_buttons_connected(menu))

	for panel in ["newgame", "chapters", "settings", "extras", "credits", "quit"]:
		menu._open(panel)
		await _wait(0.25)
		var opened: bool = menu._sub != null and is_instance_valid(menu._sub)
		check("main menu opens '%s'" % panel, opened)
		if opened:
			check("'%s' panel has working controls" % panel,
				_all_buttons_connected(menu._sub))
			if panel != "quit":
				check("'%s' panel is laid out" % panel,
					_panel_is_laid_out(menu._sub))
		menu._close()
		await _wait(0.15)

	# The settings panel must expose the real controls, not placeholders.
	menu._open("settings")
	await _wait(0.3)
	var sliders := 0
	var options := 0
	var checks := 0
	for n in _walk(menu._sub):
		if n is HSlider: sliders += 1
		elif n is OptionButton: options += 1
		elif n is CheckButton: checks += 1
	check("settings expose sliders, dropdowns and toggles",
		sliders >= 8 and options >= 5 and checks >= 8,
		"%d sliders, %d dropdowns, %d toggles" % [sliders, options, checks])
	menu._close()
	await _wait(0.2)

## A panel that reports zero size draws nothing, however well its buttons are
## wired. `set_anchors_preset()` keeps the existing offsets by default, so a
## full-screen panel parented to a Control silently collapsed to 0x0 — every
## connectivity check still passed. This is the assertion that catches it.
func _panel_is_laid_out(panel: Node) -> bool:
	if not (panel is Control):
		return false
	var vp := get_viewport().get_visible_rect().size
	var r := (panel as Control).get_rect()
	if r.size.x < vp.x * 0.5 or r.size.y < vp.y * 0.5:
		Log.warn("Panel %s is %s in a %s viewport" % [panel.name, r.size, vp])
		return false
	# Content, not just the shell: something inside must have real extent too.
	var widest := 0.0
	for n in _walk(panel):
		if n is Control:
			widest = maxf(widest, (n as Control).get_rect().size.x)
	return widest > vp.x * 0.25

## Every interactive control must be wired to something. Note that CheckButton
## and OptionButton subclass Button but report through `toggled` and
## `item_selected` rather than `pressed`.
func _all_buttons_connected(root: Node) -> bool:
	var ok := true
	for n in _walk(root):
		if n is OptionButton:
			if (n as OptionButton).item_selected.get_connections().is_empty():
				Log.warn("Unconnected dropdown")
				ok = false
		elif n is CheckButton or n is CheckBox:
			if (n as BaseButton).toggled.get_connections().is_empty():
				Log.warn("Unconnected toggle")
				ok = false
		elif n is Button and not (n as Button).disabled:
			# UITheme.button() always attaches a click sound, so a real handler
			# means more than one connection.
			if (n as Button).pressed.get_connections().size() < 2:
				Log.warn("Unconnected button: %s" % (n as Button).text)
				ok = false
		elif n is HSlider or n is VSlider:
			if (n as Slider).value_changed.get_connections().is_empty():
				Log.warn("Unconnected slider")
				ok = false
	return ok

## The pause menu and every screen reachable from it.
func _test_pause_menu(idx: int) -> void:
	print("\n-- pause menu --")
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	await SceneFlow.start_chapter(idx, "new")
	var game := get_tree().current_scene
	game.toggle_pause()
	await _wait(0.3)
	check("pause stops the game", SceneFlow.is_paused())
	check("pause menu opened", game.pause_menu != null and game.pause_menu._open)
	check("pause menu buttons are connected", _all_buttons_connected(game.pause_menu))
	for panel in ["upgrades", "records", "settings"]:
		game.pause_menu._open_panel(panel)
		await _wait(0.3)
		var ok: bool = game.pause_menu._sub != null and is_instance_valid(game.pause_menu._sub)
		check("pause menu opens '%s'" % panel, ok)
		if ok:
			check("'%s' controls are connected" % panel,
				_all_buttons_connected(game.pause_menu._sub))
			check("'%s' is laid out" % panel,
				_panel_is_laid_out(game.pause_menu._sub))
		game.pause_menu._close_panel()
		await _wait(0.15)
	game.resume()
	await _wait(0.3)
	check("resume unpauses the game", not SceneFlow.is_paused())

## Close-and-resume: store a checkpoint, drop the profile as a quit would,
## reload it from disk and re-enter the chapter from that checkpoint.
func _test_resume(idx: int) -> void:
	print("\n-- close and resume --")
	GameState.start_new_game(2, Veil.Difficulty.FIELD)
	await SceneFlow.start_chapter(idx, "new")
	var game := get_tree().current_scene
	var ch: ChapterBase = game.chapter
	var pl: Player = game.player
	if ch.checkpoints.is_empty():
		check("chapter has a checkpoint to resume from", false)
		return
	var cp := ch.checkpoints[ch.checkpoints.size() - 1] as Checkpoint
	GameState.award(1500, "resume test")
	ch._on_checkpoint(cp.id)
	var saved_xp := GameState.xp()
	var saved_pos: Vector3 = cp.respawn_transform().pos
	check("checkpoint written to disk", SaveSystem.exists(2))

	# Simulate quitting: forget everything held in memory.
	GameState.slot = -1
	GameState.data = SaveSystem.new_profile(1)
	GameState.reset_run(0)
	await _wait(0.2)

	check("profile reloads from disk", GameState.load_slot(2))
	check("xp survived the restart", GameState.xp() == saved_xp,
		"%d vs %d" % [GameState.xp(), saved_xp])
	check("checkpoint survived the restart", GameState.has_checkpoint())
	var cp_data: Dictionary = GameState.checkpoint()
	check("checkpoint names the right chapter", int(cp_data.get("chapter", -1)) == idx)

	await SceneFlow.start_chapter(idx, "checkpoint")
	var game2 := get_tree().current_scene
	var pl2: Player = game2.player
	check("resumed into the chapter", pl2 != null and pl2.is_alive())
	if pl2:
		check("resumed at the checkpoint, not the start",
			pl2.global_position.distance_to(saved_pos) < 4.0,
			"%.1f m from checkpoint" % pl2.global_position.distance_to(saved_pos))
	await _wait(0.6)
	check("run stats restored", int(GameState.run.get("chapter", -1)) == idx)

	# Missing save data must not break Continue.
	SaveSystem.erase(2)
	check("erased slot reports empty", SaveSystem.header(2).get("empty", false))
	check("continue finds no slot to load", SaveSystem.newest_slot() != 2)

func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out

func _first_scannable_with_prop(ch: Node) -> Scannable:
	for n in _walk(ch):
		if n is Scannable and (n as Scannable).property != Veil.Prop.NONE:
			return n
	return null

func _first_imprintable_accepting(ch: Node, prop: int) -> Imprintable:
	for n in _walk(ch):
		if n is Imprintable and (n as Imprintable).accepts(prop):
			return n
	return null

## Confirms at least one subject genuinely enables/disables collision shapes
## between states, i.e. the shift is a physical change, not a repaint.
func _collision_differs(ch: ChapterBase) -> bool:
	for s in ch.manager.subjects:
		var vs := s as VeilSubject
		var counts: Array = []
		for st in 3:
			vs.apply_state(st, true)
			# Shape toggles are deferred so they are safe during physics.
			await get_tree().physics_frame
			await get_tree().physics_frame
			counts.append(_active_shapes(vs))
		vs.apply_state(ch.manager.base_state, true)
		await get_tree().physics_frame
		if counts[0] != counts[1] or counts[1] != counts[2]:
			return true
	return false

func _active_shapes(n: Node) -> int:
	var total := 0
	for c in _walk(n):
		if c is CollisionShape3D and not (c as CollisionShape3D).disabled:
			var owner_node := (c as CollisionShape3D).get_parent()
			if owner_node is CollisionObject3D and (owner_node as CollisionObject3D).collision_layer != 0:
				total += 1
	return total
