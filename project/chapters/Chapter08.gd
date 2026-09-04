extends ChapterBase
## CHAPTER 8 - CONVERGENCE CORE
## The finale. The three realities overlap here rather than replacing one
## another, so the veil field stops being a switch and becomes a scalpel: the
## last sequence asks the player to hold three states in three places while a
## countdown runs.

var _noise := FastNoiseLite.new()
var _flags := {"approach": false, "ring_a": false, "ring_b": false, "ring_c": false,
	"governor": false, "sequence": false, "engine": false}

var _rings: Array = []
var _governor_lock: ResonanceLock
var _sequence_running := false
var _sequence_time := 0.0
var _sequence_len := 90.0
var _engine_done := false
var _min_shield := 1.0
var _overlap := 0.0
var _core_light: OmniLight3D
var _core_mesh: MeshInstance3D

const CORE := Vector3(0, 0, -96)

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	# A shattered basin around the engine: concentric terraces stepping down.
	var d := Vector2(x - CORE.x, z - CORE.z).length()
	var terrace: float = -floor(clampf(d / 26.0, 0.0, 4.0)) * 5.0
	var y: float = 18.0 + terrace + n.get_noise_2d(x * 0.4, z * 0.4) * 3.4
	if d < 24.0:
		y = lerpf(y, -4.0, smoothstep(24.0, 6.0, d))
	var edge := clampf((Vector2(x, z).length() - 130.0) / 26.0, 0.0, 1.0)
	y -= edge * 60.0
	return y

func build_world() -> void:
	_noise.seed = 8808
	_noise.frequency = 0.012
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	SceneFlow.report(0.12, "Fracturing the basin")
	build_terrain(Vector2(320, 320), 152, Callable(self, "_h"), "core",
		Veil.Surface.METAL)
	spawn_position = on_ground(0, 112, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.26, "Overlapping the realities")
	_build_basin()
	await get_tree().process_frame

	SceneFlow.report(0.40, "Approach causeway")
	_build_approach()
	await get_tree().process_frame

	SceneFlow.report(0.56, "Containment rings")
	_build_rings()
	await get_tree().process_frame

	SceneFlow.report(0.72, "Phase governor")
	_build_governor()
	await get_tree().process_frame

	SceneFlow.report(0.86, "The engine")
	_build_engine()
	_build_dressing()
	await get_tree().process_frame

# ---------------------------------------------------------------- basin
func _build_basin() -> void:
	# Fragments of all three worlds coexisting: forest, city and glass, mixed.
	for i in 90:
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(34.0, 128.0)
		var x := CORE.x + cos(a) * d
		var z := CORE.z + sin(a) * d
		if absf(x) > 140.0 or absf(z) > 150.0:
			continue
		var y := terrain.height_at(x, z)
		if y < -30.0:
			continue
		match i % 4:
			0:
				rock(Vector3(x, y - 0.4, z), rng.randf_range(1.0, 4.0), 2100 + i, "rock_dark")
			1:
				tree(Vector3(x, y - 0.4, z), rng.randf_range(8.0, 18.0),
					rng.randf_range(0.5, 0.9), 7000 + i, "bark", "foliage_bloom")
			2:
				static_mesh(ProcAssets.facade_mesh(rng.randf_range(5.0, 10.0),
					rng.randf_range(8.0, 20.0), rng.randf_range(5.0, 10.0), 3, 5, 0.2, i),
					"nacre", Vector3(x, y + 6.0, z),
					Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(0, TAU),
						rng.randf_range(-0.14, 0.14)), Vector3.ONE, Veil.Surface.STONE)
			_:
				static_mesh(ProcAssets.crystal_mesh(500 + i, rng.randf_range(2.0, 7.0),
					rng.randf_range(0.4, 1.2), 6), "glass_broken", Vector3(x, y - 0.3, z),
					Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0, TAU), 0),
					Vector3.ONE, Veil.Surface.GLASS)
	# Floating shards above the basin: three-state debris that never landed.
	for i in 40:
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(20.0, 90.0)
		var p := CORE + Vector3(cos(a) * d, rng.randf_range(12.0, 46.0), sin(a) * d)
		var m := decor(ProcAssets.rock_mesh(2400 + i % 8, rng.randf_range(1.2, 4.0),
			0.4, 10, 14, 0.7), "rock_dark", p,
			Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), 0))
		m.set_meta("float_phase", rng.randf_range(0, TAU))
		_floaters.append(m)

var _floaters: Array = []

func _build_dressing() -> void:
	vegetation.scatter(ProcAssets.blade_cluster_mesh(81, 5, 0.8, 0.07), 3000,
		Rect2(-140, -150, 280, 300), veg_sampler(30.0, [], -6.0, 26.0),
		Color(0.22, 0.32, 0.20), Color(0.44, 0.58, 0.30), Vector2(0.6, 1.8), 0.28, 71, 1.2)

# ---------------------------------------------------------------- approach
func _build_approach() -> void:
	var base := on_ground(0, 112)
	box(Vector3(22.0, 0.6, 16.0), "metal_dark", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	scannable(base + Vector3(0, 1.6, 4.0), "Commissioning Plate",
		"THREEFOLD CLIMATE ENGINE. Phase 1 of 1. There was never going to be a second attempt.",
		Veil.Prop.RIGID, -1, 3.0)
	checkpoint("cp_approach", base + Vector3(0, 0.4, -5.0), 180.0)
	trigger(base + Vector3(0, 3, -9.0), Vector3(20, 8, 6), func() -> void:
		say("Here it is. All three realities in the same volume of air, and none of them winning.",
			"MOTE", 5.4)
		say("Your field will still work. It just has to fight for it.", "MOTE", 4.2))

	# A causeway of alternating-state slabs down the terraces.
	var steps := 14
	for i in steps:
		var t := float(i) / float(steps - 1)
		var z := lerpf(100.0, -46.0, t)
		var x := sin(t * 6.0) * 14.0
		var y := terrain.height_at(x, z) + 1.2
		var p := Vector3(x, y, z)
		match i % 3:
			0:
				box(Vector3(7.0, 0.5, 8.0), "metal_dark", p, Vector3.ZERO,
					Veil.Surface.METAL)
			1:
				var mem := variant_box(Vector3(7.0, 0.5, 8.0), "nacre",
					Vector3.ZERO, Vector3.ZERO, Veil.Surface.STONE)
				veil_subject("cw_m_%d" % i, p, mem, null, null, 5.0)
			_:
				var bloom := variant_box(Vector3(7.0, 0.5, 8.0), "bark",
					Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD)
				veil_subject("cw_b_%d" % i, p, null, null, bloom, 5.0)

	hazard(Vector3(0, -34.0, -20.0), Vector3(200, 8, 200), 0.0, "the basin", true)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch8_approach"
	pz.title = "Convergence Causeway"
	pz.hint_subtle = "Two of every three slabs belong to somebody else's world."
	pz.hint_guided = "Nacre slabs are Memory. Root slabs are Bloom. Metal is always there."
	pz.hint_directed = "Shift as you descend - Memory for the pale slabs, Bloom for the root ones. The drop is lethal, so land each one."
	pz.position = Vector3(0, 20.0, 40.0)
	add_child(pz)
	pz.register_hints()
	trigger(Vector3(sin(6.0) * 14.0, terrain.height_at(sin(6.0) * 14.0, -46.0) + 2.0, -46.0),
		Vector3(16, 8, 10), func() -> void:
			_flags.approach = true
			if not pz.is_solved:
				pz.mark_solved())
	checkpoint("cp_causeway", Vector3(sin(6.0) * 14.0,
		terrain.height_at(sin(6.0) * 14.0, -46.0) + 1.6, -48.0), 180.0)
	fragment(0, Vector3(sin(3.0) * 14.0, terrain.height_at(sin(3.0) * 14.0, -10.0) + 2.4, -10.0))

# ---------------------------------------------------------------- rings
func _build_rings() -> void:
	# Three containment rings at 120 degrees. Each must be brought up in a
	# different state, and each has a different way of getting there.
	var want := [Veil.State.MEMORY, Veil.State.RUIN, Veil.State.BLOOM]
	var names := ["Ring Alpha", "Ring Beta", "Ring Gamma"]
	var keys := ["ring_a", "ring_b", "ring_c"]
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		var p := CORE + Vector3(cos(a) * 30.0, 0, sin(a) * 30.0)
		p.y = terrain.height_at(p.x, p.z) + 0.4
		box(Vector3(16.0, 0.8, 16.0), "metal_dark", p + Vector3(0, -0.4, 0),
			Vector3.ZERO, Veil.Surface.METAL)
		for k in 3:
			decor(ProcAssets.ring_mesh(5.0 - float(k) * 0.9, 0.35, 26, 8),
				"brass" if k % 2 == 0 else "metal_dark", p + Vector3(0, 1.6 + float(k) * 1.8, 0))
		var pip := decor(ProcAssets.sphere_mesh(0.6, 10, 14),
			ProcAssets.emissive(Color(0.3, 0.3, 0.35), 0.4), p + Vector3(0, 7.4, 0))

		var im := Imprintable.new()
		im.label = names[i]
		im.accepted = [Veil.Prop.RESONANT]
		im.hold_seconds = 0.0
		im.position = p + Vector3(0, 1.2, 0)
		add_child(im)

		var idx := i
		var ring := {"pos": p, "pip": pip, "imprint": im, "want": want[i],
			"key": keys[i], "online": false}
		_rings.append(ring)

		var pz := PuzzleBase.new()
		pz.puzzle_id = "ch8_%s" % keys[i]
		pz.title = names[i]
		pz.hint_subtle = "The ring needs a tone and a reality, and it will not say which reality."
		pz.hint_guided = "Imprint Resonant on the ring, then hold it in the state its pip is showing you."
		pz.hint_directed = "Record Resonant from the carrier crystal at the core edge, imprint this ring, then field the ring into %s." % Veil.state_name(want[i])
		pz.position = p
		add_child(pz)
		pz.register_hints()
		ring["puzzle"] = pz
		scannable(p + Vector3(6.0, 1.6, 0), "%s Plate" % names[i],
			"Commissioned, tested once, and then left holding its breath for eleven years.")

	var sc := scannable(CORE + Vector3(0, 3.0, 14.0), "Carrier Crystal",
		"It rings at exactly the Veilforge tone. That is not a coincidence; it is a specification.",
		Veil.Prop.RESONANT, -1, 4.0)
	sc.xp_bonus = 140
	decor(ProcAssets.crystal_mesh(881, 5.0, 1.2, 6),
		ProcAssets.additive(Color(0.8, 0.6, 1.0), 2.0, false), CORE + Vector3(0, 2.0, 14.0))
	fragment(1, CORE + Vector3(-16.0, terrain.height_at(CORE.x - 16.0, CORE.z) + 1.0, 8.0))

func _check_rings() -> void:
	var online := 0
	for r in _rings:
		var im: Imprintable = r.imprint
		var state := manager.state_at((r.pos as Vector3) + Vector3(0, 2.0, 0))
		var ok: bool = im.current == Veil.Prop.RESONANT and state == int(r.want)
		if ok != bool(r.online):
			r.online = ok
			var mat := (r.pip as MeshInstance3D).material_override as StandardMaterial3D
			var c: Color = Settings.state_color(int(r.want)) if ok else Color(0.3, 0.3, 0.35)
			mat.albedo_color = c
			mat.emission = c
			mat.emission_energy_multiplier = 4.0 if ok else 0.4
			if ok:
				AudioDirector.play_3d("power_on", get_tree().current_scene,
					r.pos as Vector3, -4.0)
				_flags[String(r.key)] = true
				var pz: PuzzleBase = r.puzzle
				if not pz.is_solved:
					pz.mark_solved()
		# The pip always previews the state the ring wants.
		if not ok:
			var mat2 := (r.pip as MeshInstance3D).material_override as StandardMaterial3D
			var pulse: float = 0.4 + 0.5 * (sin(float(Time.get_ticks_msec()) * 0.004) * 0.5 + 0.5)
			mat2.emission = Settings.state_color(int(r.want)) * pulse
		if bool(r.online):
			online += 1
	if _governor_lock:
		_rings_online = online

var _rings_online := 0

# ---------------------------------------------------------------- governor
func _build_governor() -> void:
	var p := CORE + Vector3(0, 0, 18.0)
	p.y = terrain.height_at(p.x, p.z) + 0.4
	box(Vector3(14.0, 0.8, 12.0), "metal_dark", p + Vector3(0, -0.4, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	_governor_lock = ResonanceLock.new()
	_governor_lock.position = p
	add_child(_governor_lock)
	_governor_lock.add_condition(func() -> bool: return _rings_online >= 1, "Ring Alpha")
	_governor_lock.add_condition(func() -> bool: return _rings_online >= 2, "Ring Beta")
	_governor_lock.add_condition(func() -> bool: return _rings_online >= 3, "Ring Gamma")
	_governor_lock.hint_subtle = "The governor counts rings, and it can count to three."
	_governor_lock.hint_guided = "All three rings have to be online at the same moment."
	_governor_lock.hint_directed = "Imprint Resonant on all three rings first - that part sticks. Then set the base state for one ring, pin a field on the second and hold the aimed field on the third."
	_governor_lock.register_hints()
	_governor_lock.solved.connect(func(_p: bool) -> void:
		_flags.governor = true
		_start_sequence())
	checkpoint("cp_governor", p + Vector3(0, 0.4, 6.0), 180.0)
	fragment(2, p + Vector3(6.0, 0.8, 4.0))
	component(p + Vector3(-6.0, 0.8, 4.0))

# ---------------------------------------------------------------- engine
func _build_engine() -> void:
	var p := CORE
	p.y = terrain.height_at(p.x, p.z)
	box(Vector3(28.0, 1.0, 28.0), "metal_dark", p + Vector3(0, -0.5, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	for i in 6:
		decor(ProcAssets.ring_mesh(11.0 - float(i) * 1.4, 0.5, 34, 10),
			"brass" if i % 2 == 0 else "metal_dark", p + Vector3(0, 2.0 + float(i) * 3.0, 0))
	_core_mesh = decor(ProcAssets.sphere_mesh(5.0, 16, 22),
		ProcAssets.additive(Color(0.7, 0.8, 1.0), 1.2, false), p + Vector3(0, 12.0, 0))
	_core_light = OmniLight3D.new()
	_core_light.light_color = Color(0.7, 0.8, 1.0)
	_core_light.light_energy = 2.0
	_core_light.omni_range = 60.0
	_core_light.position = p + Vector3(0, 12.0, 0)
	add_child(_core_light)

	var it := Interactable.new()
	it.prompt = "Complete the ignition sequence"
	it.hold_time = 2.2
	it.one_shot = true
	it.enabled = false
	it.position = p + Vector3(0, 1.4, 6.0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 3.6
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(p))
	_engine_interact = it

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch8_sequence"
	pz.title = "Ignition Sequence"
	pz.hint_subtle = "Once the governor releases, the clock is the puzzle."
	pz.hint_guided = "Keep all three rings online while the sequence runs, then finish at the core."
	pz.hint_directed = "The rings hold their imprint, so you only have to keep their states. Park the base state on one, pin the second, aim the third, and walk to the core."
	pz.position = p
	add_child(pz)
	pz.register_hints()
	_sequence_puzzle = pz

var _engine_interact: Interactable
var _sequence_puzzle: PuzzleBase

func _start_sequence() -> void:
	if _sequence_running:
		return
	_sequence_running = true
	_sequence_time = _sequence_len
	AudioDirector.play("machine_start", 0.0)
	AudioDirector.set_intensity(0.85)
	set_objective("Hold all three rings and reach the core before the overlap closes.")
	say("Governor released. Ninety seconds of overlap. Keep the rings and get to the core.",
		"MOTE", 5.0)

func _process(dt: float) -> void:
	if not GameState.run.get("active", false):
		return
	_check_rings()
	_min_shield = minf(_min_shield, player.shield / maxf(player.shield_max, 1.0))
	for m in _floaters:
		if is_instance_valid(m):
			var ph := float((m as Node3D).get_meta("float_phase", 0.0))
			(m as Node3D).position.y += sin(ph + float(Time.get_ticks_msec()) * 0.0006) * dt * 0.4
			(m as Node3D).rotation.y += dt * 0.09

	# The overlap: all three realities bleed together near the core.
	var d := player.global_position.distance_to(CORE)
	_overlap = clampf(1.0 - d / 60.0, 0.0, 1.0)
	if atmosphere and atmosphere.environment:
		var env := atmosphere.environment
		env.glow_intensity = lerpf(0.4, 1.0, _overlap)
		env.adjustment_saturation = lerpf(1.0, 1.28, _overlap)
	if _core_light:
		_core_light.light_energy = 2.0 + float(_rings_online) * 2.2 \
			+ sin(float(Time.get_ticks_msec()) * 0.003) * 0.4

	if _sequence_running and not _engine_done:
		_sequence_time -= dt
		if _rings_online < 3:
			# Losing a ring costs time rather than ending the run outright.
			_sequence_time -= dt * 1.6
		if _sequence_time <= 0.0:
			_sequence_running = false
			say("Overlap closed. The governor will let you try again - go and reset the rings.",
				"MOTE", 5.0)
			for r in _rings:
				(r.imprint as Imprintable).clear_imprint()
			if _governor_lock:
				_governor_lock.reset_puzzle()
		elif _rings_online >= 3 and d < 12.0 and _engine_interact:
			_engine_interact.enabled = true
			if not _sequence_puzzle.is_solved:
				_flags.sequence = true
				_sequence_puzzle.mark_solved()

func sequence_remaining() -> float:
	return maxf(0.0, _sequence_time) if _sequence_running else 0.0

func _finale(p: Vector3) -> void:
	if _engine_done:
		return
	_engine_done = true
	_flags.engine = true
	_sequence_running = false
	AudioDirector.play("level_up", 0.0)
	SceneFlow.flash(Color(1.0, 1.0, 1.0, 0.5), 1.6)
	set_objective("The engine is running.")
	if _min_shield >= 0.25:
		GameState.complete_challenge()
		say("Never dropped below a quarter shield. Unbroken.", "MOTE", 3.6)
	# The core opens out and all three skies resolve into one.
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_core_mesh, "scale", Vector3.ONE * 2.2, 6.0)
	t.tween_property(_core_light, "light_energy", 14.0, 6.0)
	atmosphere.day_length = 90.0
	await cinematic(
		[p + Vector3(-30, 10, 34), p + Vector3(12, 24, 16), p + Vector3(0, 44, -30),
			p + Vector3(0, 70, -70)],
		[p + Vector3(0, 10, 0), p + Vector3(0, 12, 0), p + Vector3(0, 10, 0),
			p + Vector3(0, 0, 0)],
		16.0,
		[["Ignition. All three states are being held and averaged, exactly as designed.",
			"MOTE"],
		 ["Memory is giving back the coastlines. Bloom is giving back the forests. Ruin is being asked, politely, to stop.",
			"MOTE"],
		 ["It will take about four hundred years. Somebody will have to keep it running.",
			"MOTE"],
		 ["I have logged your name against the maintenance schedule. I hope that is all right.",
			"MOTE"]])
	finish()

# ---------------------------------------------------------------- hooks
func on_begin(mode: String) -> void:
	player.device.unlock_all()
	_min_shield = 1.0
	if mode != "checkpoint":
		say("Convergence Core. Three skies, one basin, and a machine somebody left switched half on.",
			"MOTE", 5.4)
	set_objective(String(info.objective))
	weather.set_intensity(0.8)

func ambience_profiles() -> Array:
	return ["machine", "wind", "storm"]

func ambience_volumes() -> Array:
	return [0.34, 0.26, 0.22]

func on_state_changed(s: int) -> void:
	AudioDirector.fade_ambience(0, [0.24, 0.40, 0.30][clampi(s, 0, 2)], 1.4)

func save_flags() -> Dictionary:
	return _flags.duplicate()

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])

func shot_spots() -> Array:
	return [
		{"name": "basin", "pos": Vector3(40, 40, 40), "look": CORE + Vector3(0, 10, 0)},
		{"name": "rings", "pos": CORE + Vector3(34, 16, 34), "look": CORE + Vector3(0, 8, 0)},
		{"name": "core", "pos": CORE + Vector3(0, 8, 26), "look": CORE + Vector3(0, 12, 0)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "Engine commissioning plate, cast rather than printed, because whoever ordered it expected it to outlast printing. 'THREEFOLD CLIMATE ENGINE - PHASE 1 OF 1 - IF YOU ARE READING THIS AT GROUND LEVEL, SOMETHING HAS GONE WRONG AND YOU ARE THE FIX.'"
		1: return "A MOTE prototype casing, cracked, serial number 001. Inside, hand-scratched: 'unit is more stubborn than expected. recommend keeping the stubbornness.' Your MOTE goes quiet for a moment when you pick it up."
		2: return "Your own field note, in your own handwriting, dated four days before you set out. You do not remember writing it. It says: 'if the bridge is out, trust what the bridge used to be' - and underneath, 'the valley will make sense in about an hour.'"
	return ""
