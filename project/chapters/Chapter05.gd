extends ChapterBase
## CHAPTER 5 - THE BURIED SUN
## Desert ruins built around a reactor that was already here. A descending
## chapter: the surface teaches the heat rules, the shaft applies them, and the
## first containment ring is stabilised at the bottom.

var _noise := FastNoiseLite.new()
var _pads: Array[Vector4] = []
var _flags := {"gantry": false, "sand": false, "coolant": false, "descent": false,
	"mirrors": false, "ring": false, "vent": false}

var _core_heat := 0.0
var _heat_rate := 0.0
var _peak_heat := 0.0
var _ring_active := false
var _ring_done := false
var _coolant_valves: Array = []
var _ring_lock: ResonanceLock
var _heat_label_target := 0.0
var _vent_open := false

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	# Dune field falling into a sink-shaft at the north end.
	var dunes := n.get_noise_2d(x * 0.30, z * 0.30) * 9.0 \
		+ n.get_noise_2d(x * 0.9, z * 0.9) * 2.6
	var y := 12.0 + dunes + clampf((z + 60.0) / 200.0, 0.0, 1.0) * 6.0

	# The sink: a wide crater centred on (0, -70) dropping to the shaft mouth.
	var d := Vector2(x, z + 70.0).length()
	if d < 58.0:
		var k := smoothstep(58.0, 8.0, d)
		y = lerpf(y, -22.0, k * k)
	for pad in _pads:
		var pd := Vector2(x - pad.x, z - pad.y).length()
		var w := float(pad.z)
		if pd < w:
			var kk := smoothstep(w, w * 0.3, pd)
			y = lerpf(y, float(pad.w), kk * kk * (3.0 - 2.0 * kk))
	return y

func build_world() -> void:
	_noise.seed = 5505
	_noise.frequency = 0.011
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	_pads = [
		Vector4(0, 104, 14, 16.0),    # camp
		Vector4(0, 66, 14, 15.0),     # buried gantry
		Vector4(-28, 30, 14, 14.0),   # sand lock
		Vector4(26, 2, 14, 13.0),     # coolant yard
		Vector4(0, -30, 16, 6.0),     # shaft head
		Vector4(0, -70, 14, -22.0),   # shaft floor
	]

	SceneFlow.report(0.12, "Laying the dune field")
	build_terrain(Vector2(300, 300), 225, Callable(self, "_h"), "desert",
		Veil.Surface.SAND)
	spawn_position = on_ground(0, 104, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.24, "Ruins and drift")
	_build_desert()
	await get_tree().process_frame

	SceneFlow.report(0.36, "Drill camp")
	_build_camp()
	_build_gantry()
	await get_tree().process_frame

	SceneFlow.report(0.48, "Sand lock")
	_build_sandlock()
	await get_tree().process_frame

	SceneFlow.report(0.58, "Coolant yard")
	_build_coolant()
	await get_tree().process_frame

	SceneFlow.report(0.70, "Sink shaft")
	_build_shaft()
	await get_tree().process_frame

	SceneFlow.report(0.84, "Containment ring")
	_build_ring()
	_build_dressing()
	await get_tree().process_frame

# ---------------------------------------------------------------- desert
func _build_desert() -> void:
	for i in 110:
		var x := rng.randf_range(-140, 140)
		var z := rng.randf_range(-140, 140)
		var skip := false
		for p in _pads:
			if Vector2(x - p.x, z - p.y).length() < p.z + 6.0:
				skip = true
				break
		if skip:
			continue
		rock(on_ground(x, z, -0.5), rng.randf_range(0.9, 4.4), 1500 + i, "rock")
	# Half-buried pylons marching toward the sink.
	for i in 22:
		var t := float(i) / 21.0
		var z := lerpf(110.0, -40.0, t)
		var x := sin(t * 4.0) * 20.0
		var h := lerpf(3.0, 12.0, t)
		static_mesh(ProcAssets.truss_mesh(h, 1.6, 1.6, maxi(2, int(h / 2.4)), 0.1),
			"metal_rust", on_ground(x, z, h * 0.4),
			Vector3(PI * 0.5, rng.randf_range(-0.3, 0.3), 0), Vector3.ONE,
			Veil.Surface.METAL)
	# Wind-carved ruin walls.
	for i in 26:
		var x := rng.randf_range(-110, 110)
		var z := rng.randf_range(-40, 120)
		box(Vector3(rng.randf_range(3.0, 9.0), rng.randf_range(2.0, 6.0), 0.8),
			"concrete_aged", on_ground(x, z, 1.4),
			Vector3(0, rng.randf_range(0, TAU), rng.randf_range(-0.08, 0.08)))

func _build_dressing() -> void:
	var excl: Array = []
	for p in _pads:
		excl.append(Rect2(p.x - p.z * 0.8, p.y - p.z * 0.8, p.z * 1.6, p.z * 1.6))
	vegetation.scatter(ProcAssets.blade_cluster_mesh(61, 12, 0.7, 0.06), 2400,
		Rect2(-140, -140, 280, 280), veg_sampler(30.0, excl, 2.0),
		Color(0.44, 0.40, 0.20), Color(0.62, 0.56, 0.28), Vector2(0.6, 1.6), 0.30, 51, 1.0)

# ---------------------------------------------------------------- camp
func _build_camp() -> void:
	var base := on_ground(0, 104)
	box(Vector3(18.0, 0.4, 14.0), "concrete_aged", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	static_mesh(ProcAssets.room_shell(Vector3(7.0, 3.0, 6.0), 0.3, 2.2, 2.6, true, 1),
		"metal_rust", base + Vector3(-5.0, 1.7, -2.0), Vector3(0, 0.15, 0), Vector3.ONE,
		Veil.Surface.METAL)
	for i in 4:
		decor(ProcAssets.cylinder_mesh(0.6, 1.6, 12), "metal_rust",
			base + Vector3(4.0 + float(i) * 1.6, 0.8, 3.0))
	scannable(base + Vector3(-5.0, 1.8, -2.0), "Drill Foreman's Office",
		"A desk, a fan still turning, and a wall of core samples in date order.",
		Veil.Prop.RIGID, -1, 2.6)
	checkpoint("cp_camp", base + Vector3(0, 0.3, -5.0), 180.0)
	trigger(base + Vector3(0, 3, -9.0), Vector3(24, 8, 6), func() -> void:
		say("They dug for water and found something warm at nine hundred metres.",
			"MOTE", 5.0)
		say("Then they built a city around the hole so they could keep looking at it.",
			"MOTE", 4.6))

# ---------------------------------------------------------------- buried gantry
func _build_gantry() -> void:
	var base := on_ground(0, 66)
	# A service gantry buried to the handrails in Ruin, clear in Memory,
	# and overgrown into a ramp in Bloom.
	var mem := variant_group([
		variant_box(Vector3(5.0, 0.4, 24.0), "metal", Vector3(0, 3.0, -6.0),
			Vector3.ZERO, Veil.Surface.METAL),
		variant_box(Vector3(0.2, 1.0, 24.0), "metal_rust", Vector3(-2.4, 3.6, -6.0),
			Vector3.ZERO, Veil.Surface.METAL),
		variant_box(Vector3(0.2, 1.0, 24.0), "metal_rust", Vector3(2.4, 3.6, -6.0),
			Vector3.ZERO, Veil.Surface.METAL)])
	var ruin := variant_mesh(ProcAssets.debris_mesh(770, 20, 6.0, 1.6), "sand",
		Vector3(0, 1.0, -6.0), Vector3.ZERO, Veil.Surface.SAND, false)
	var bpts := PackedVector3Array()
	for i in 8:
		var t := float(i) / 7.0
		bpts.append(Vector3(sin(t * 3.0) * 2.0, 1.0 + t * 3.0, 6.0 - t * 24.0))
	var bloom := variant_mesh(ProcAssets.tube_mesh("ch5gantry", bpts,
		PackedFloat32Array([1.1, 1.1, 1.1, 1.1, 1.1, 1.1, 1.1, 1.1]), 9, 0.3),
		"bark", Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD)
	var subj := veil_subject("gantry", base, mem, ruin, bloom, 14.0)

	box(Vector3(9.0, 6.0, 4.0), "concrete_aged", base + Vector3(0, 3.0, 8.0))
	box(Vector3(9.0, 6.0, 4.0), "concrete_aged", base + Vector3(0, 3.0, -20.0))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch5_gantry"
	pz.title = "Buried Gantry"
	pz.hint_subtle = "The walkway is still here. Most of it is under the sand."
	pz.hint_guided = "Sand is a Ruin-state fact. Memory has a clear deck; Bloom has a root ramp."
	pz.hint_directed = "Pin a Memory field over the gantry and walk the deck to the far tower."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	subj.state_applied.connect(func(s: int) -> void:
		if s != Veil.State.RUIN and not pz.is_solved:
			_flags.gantry = true
			pz.mark_solved())
	fragment(0, base + Vector3(3.5, 3.6, -19.0))

# ---------------------------------------------------------------- sand lock
func _build_sandlock() -> void:
	var base := on_ground(-28, 30)
	static_mesh(ProcAssets.room_shell(Vector3(18.0, 6.0, 14.0), 0.6, 3.6, 3.8, true, 1),
		"concrete_aged", base + Vector3(0, 3.2, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	# A chamber that fills with sand under a Ruin sky. Shifting drains it.
	var sand_ruin := variant_group([
		variant_box(Vector3(17.0, 3.4, 13.0), "sand", Vector3(0, 1.7, 0),
			Vector3.ZERO, Veil.Surface.SAND)])
	var subj := veil_subject("sand_fill", base, null, sand_ruin, null, 10.0)

	var gate := Gate.new()
	gate.size = Vector3(3.6, 3.8, 0.4)
	gate.open_offset = Vector3(0, 3.9, 0)
	gate.position = base + Vector3(0, 2.0, -7.2)
	add_child(gate)

	var plate := PressurePlate.new()
	plate.required_mass = 70.0
	plate.position = base + Vector3(0, 0.2, 2.0)
	add_child(plate)
	plate.pressed.connect(func() -> void: gate.open())
	plate.released.connect(func() -> void: gate.close())

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch5_sand"
	pz.title = "Sand Lock"
	pz.hint_subtle = "You cannot stand on the plate, because the plate is under two metres of sand."
	pz.hint_guided = "The sand only exists in one version of this room."
	pz.hint_directed = "Shift the chamber to Memory or Bloom to clear the sand, then stand on the plate to hold the inner door."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	plate.pressed.connect(func() -> void:
		_flags.sand = true
		if not pz.is_solved:
			pz.mark_solved())

	scannable(base + Vector3(6.0, 1.8, 4.0), "Sand-Scoured Idol",
		"Older than the drill camp by a long way. Its face is worn off and its posture is not.")
	hidden_marker(base + Vector3(-6.0, 1.0, -5.0))
	checkpoint("cp_sand", base + Vector3(0, 0.4, -9.0), 180.0)

# ---------------------------------------------------------------- coolant
func _build_coolant() -> void:
	var base := on_ground(26, 2)
	box(Vector3(26.0, 0.6, 20.0), "concrete", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 3:
		decor(ProcAssets.cylinder_mesh(1.4, 6.0, 16), "metal_rust",
			base + Vector3(-7.0 + float(i) * 7.0, 3.0, -6.0))
		var v := ValveWheel.new()
		v.label = "Coolant Line %d" % (i + 1)
		v.stops = 3
		v.start_step = 0
		v.position = base + Vector3(-7.0 + float(i) * 7.0, 0.2, -1.0)
		add_child(v)
		_coolant_valves.append(v)
		v.turned.connect(func(_s: int, _t: int) -> void: _recompute_cooling())

	# Hot steam vents while the lines are shut.
	for i in 3:
		var h := hazard(base + Vector3(-7.0 + float(i) * 7.0, 1.4, -3.0),
			Vector3(3.0, 3.0, 3.0), Tuning.HAZ_STEAM_DPS, "steam")
		h.set_meta("coolant_index", i)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch5_coolant"
	pz.title = "Coolant Yard"
	pz.hint_subtle = "Three lines, and the core does not care which order you open them."
	pz.hint_guided = "Open all three before you go down. Heat rises while you descend."
	pz.hint_directed = "Turn each coolant wheel to its top stop. The steam stops when the line is flowing."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_coolant_puzzle = pz

	guardian(base + Vector3(-10.0, 0.4, 6.0), [
		base + Vector3(-10, 0.4, 6), base + Vector3(9, 0.4, 6),
		base + Vector3(9, 0.4, -7)])
	scannable(base + Vector3(11.0, 1.8, 4.0), "Coolant Manifest",
		"Twelve lines listed. Three are ticked. The rest are crossed out in the same pen.",
		Veil.Prop.CONDUCTIVE, -1, 2.6)
	component(base + Vector3(-11.0, 1.0, -8.0))
	checkpoint("cp_coolant", base + Vector3(0, 0.4, 7.0), 180.0)

var _coolant_puzzle: PuzzleBase

func cooling_level() -> float:
	if _coolant_valves.is_empty():
		return 0.0
	var t := 0.0
	for v in _coolant_valves:
		t += (v as ValveWheel).fraction()
	return t / float(_coolant_valves.size())

func _recompute_cooling() -> void:
	var lvl := cooling_level()
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.has_meta("coolant_index"):
			var i := int(h.get_meta("coolant_index"))
			var open := (_coolant_valves[i] as ValveWheel).fraction() > 0.9
			(h as Area3D).set_deferred("monitorable", not open)
			(h as Node).set_meta("dps", 0.0 if open else Tuning.HAZ_STEAM_DPS)
	if lvl >= 0.99 and _coolant_puzzle and not _coolant_puzzle.is_solved:
		_flags.coolant = true
		_coolant_puzzle.mark_solved()
		say("All three lines flowing. The core will still climb, just slower.",
			"MOTE", 4.4)

# ---------------------------------------------------------------- shaft
func _build_shaft() -> void:
	var head := on_ground(0, -30)
	box(Vector3(26.0, 0.8, 20.0), "concrete", head + Vector3(0, -0.3, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	static_mesh(ProcAssets.truss_mesh(26.0, 4.0, 4.0, 10, 0.2), "metal_rust",
		head + Vector3(0, 13.0, -6.0), Vector3(PI * 0.5, 0, 0), Vector3.ONE,
		Veil.Surface.METAL)

	# A descending spiral of platforms into the sink. Alternating states force
	# the player to keep shifting while falling behind a rising heat clock.
	var floor_y := -22.0
	var steps := 12
	for i in steps:
		var a := float(i) * 0.9
		var r := lerpf(26.0, 7.0, float(i) / float(steps - 1))
		var y := lerpf(head.y - 3.0, floor_y + 2.0, float(i) / float(steps - 1))
		var p := Vector3(cos(a) * r, y, -70.0 + sin(a) * r)
		match i % 3:
			0:
				box(Vector3(6.0, 0.5, 6.0), "concrete_aged", p, Vector3.ZERO,
					Veil.Surface.STONE)
			1:
				var mem := variant_box(Vector3(6.0, 0.5, 6.0), "metal",
					Vector3.ZERO, Vector3.ZERO, Veil.Surface.METAL)
				veil_subject("shaft_m_%d" % i, p, mem, null, null, 4.0)
			_:
				var bloom := variant_box(Vector3(6.0, 0.5, 6.0), "resin",
					Vector3.ZERO, Vector3.ZERO, Veil.Surface.RESIN)
				veil_subject("shaft_b_%d" % i, p, null, null, bloom, 4.0)

	hazard(Vector3(0, floor_y - 8.0, -70.0), Vector3(70, 6, 70), 0.0,
		"the shaft floor", true)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch5_descent"
	pz.title = "Sink Shaft"
	pz.hint_subtle = "Two of every three platforms are not there yet."
	pz.hint_guided = "Metal steps are Memory. Resin steps are Bloom. Concrete is always there."
	pz.hint_directed = "Aim ahead and shift as you go: Memory for the metal steps, Bloom for the resin ones. Do not stop on a concrete step for long, the heat is climbing."
	pz.position = Vector3(0, head.y, -46.0)
	add_child(pz)
	pz.register_hints()
	trigger(Vector3(0, floor_y + 2.0, -70.0), Vector3(20, 6, 20), func() -> void:
		_flags.descent = true
		if not pz.is_solved:
			pz.mark_solved())
	checkpoint("cp_shaft", Vector3(0, floor_y + 2.6, -62.0), 180.0)
	fragment(1, Vector3(cos(3.6) * 20.0, head.y - 8.0, -70.0 + sin(3.6) * 20.0))

# ---------------------------------------------------------------- ring
func _build_ring() -> void:
	var base := Vector3(0, -22.0, -70.0)
	box(Vector3(40.0, 0.8, 40.0), "metal_dark", base + Vector3(0, -0.4, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	for i in 4:
		decor(ProcAssets.ring_mesh(12.0 - float(i) * 1.4, 0.5, 34, 10),
			"brass" if i % 2 == 0 else "metal_dark", base + Vector3(0, 3.0 + float(i) * 2.6, 0))
	var sun := decor(ProcAssets.sphere_mesh(4.4, 14, 20),
		ProcAssets.additive(Color(1.0, 0.62, 0.22), 2.2, false), base + Vector3(0, 9.0, 0))
	var sun_light := OmniLight3D.new()
	sun_light.light_color = Color(1.0, 0.68, 0.3)
	sun_light.light_energy = 4.0
	sun_light.omni_range = 40.0
	sun_light.position = base + Vector3(0, 9.0, 0)
	add_child(sun_light)

	# Three mirror plinths must each hold a different property at once.
	_ring_lock = ResonanceLock.new()
	_ring_lock.position = base + Vector3(0, 0.4, 14.0)
	add_child(_ring_lock)
	var wants := [Veil.Prop.FROZEN, Veil.Prop.CONDUCTIVE, Veil.Prop.LUMINOUS]
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.6
		var p := base + Vector3(cos(a) * 10.0, 0.4, sin(a) * 10.0)
		box(Vector3(1.4, 1.2, 1.4), "metal_dark", p + Vector3(0, 0.6, 0),
			Vector3.ZERO, Veil.Surface.METAL)
		var im := Imprintable.new()
		im.label = ["Damper Plinth", "Bus Plinth", "Beacon Plinth"][i]
		im.accepted = [wants[i]]
		im.hold_seconds = 120.0
		im.position = p + Vector3(0, 1.3, 0)
		add_child(im)
		var want: int = wants[i]
		_ring_lock.add_condition(func() -> bool: return im.current == want,
			Veil.prop_name(want))
	_ring_lock.hint_subtle = "The ring wants three different things held at the same time."
	_ring_lock.hint_guided = "Frozen, Conductive and Luminous. All three are available on the way down."
	_ring_lock.hint_directed = "Record Frozen from the shaft ice, Conductive from the coolant manifest, Luminous from the core glow, then imprint one into each plinth."
	_ring_lock.register_hints()
	_ring_lock.solved.connect(func(_p: bool) -> void:
		_flags.ring = true
		_finish_ring(base))

	var sc := scannable(base + Vector3(0, 6.0, 0), "The Buried Sun",
		"It is not a reactor. It is older, and it has been on the whole time.",
		Veil.Prop.LUMINOUS, -1, 6.0)
	sc.xp_bonus = 160
	var sc2 := scannable(base + Vector3(-13.0, 1.6, -6.0), "Shaft Ice",
		"Frost, twenty-two metres below a desert, a stone's throw from something incandescent.",
		Veil.Prop.FROZEN, -1, 2.8)
	sc2.xp_bonus = 90
	fragment(2, base + Vector3(13.0, 0.8, -8.0))
	_ring_active = true

func _finish_ring(base: Vector3) -> void:
	if _ring_done:
		return
	_ring_done = true
	AudioDirector.play("machine_start", -1.0)
	SceneFlow.flash(Color(1.0, 0.8, 0.5, 0.34), 0.8)
	set_objective("First containment ring stabilised.")
	if _peak_heat <= 0.70:
		GameState.complete_challenge()
		say("Never went past seventy percent. The engineers who built this would be furious and impressed.",
			"MOTE", 4.6)
	await cinematic(
		[base + Vector3(-24, 6, 26), base + Vector3(10, 14, 12), base + Vector3(0, 26, -22)],
		[base + Vector3(0, 8, 0), base + Vector3(0, 9, 0), base + Vector3(0, 6, 0)],
		9.5,
		[["Ring one is holding. There are four more and they are not here.",
			"MOTE"],
		 ["This thing is a component. Somebody built the climate engine around parts they found.",
			"MOTE"],
		 ["The other rings are out at sea, in the storm belt. I hope you like weather.", "MOTE"]])
	finish()

# ---------------------------------------------------------------- heat clock
func _process(dt: float) -> void:
	if not GameState.run.get("active", false) or _ring_done:
		return
	if not _ring_active and player.global_position.y > -6.0:
		# Above ground: heat bleeds off.
		_core_heat = maxf(0.0, _core_heat - dt * 0.02)
	else:
		var cool := cooling_level()
		_heat_rate = lerpf(0.030, 0.008, cool)
		# Standing in a Memory field slows the core: it remembers being cold.
		if manager.state_at(player.global_position) == Veil.State.MEMORY:
			_heat_rate *= 0.35
		_core_heat = clampf(_core_heat + dt * _heat_rate, 0.0, 1.0)
	_peak_heat = maxf(_peak_heat, _core_heat)
	if _core_heat > 0.85:
		player.apply_damage(Tuning.HAZ_HEAT_DPS * dt * (_core_heat - 0.85) * 6.0, "core heat")
	if atmosphere:
		var env := atmosphere.environment
		if env:
			env.adjustment_saturation = lerpf(1.0, 0.72, _core_heat)
			env.glow_intensity = lerpf(0.4, 0.9, _core_heat)

func core_heat() -> float:
	return _core_heat

# ---------------------------------------------------------------- hooks
func on_begin(mode: String) -> void:
	player.device.unlock_all()
	if mode != "checkpoint":
		say("Forty-four degrees in the shade and there is no shade. Core temperature is the one that matters.",
			"MOTE", 5.2)
	set_objective(String(info.objective))
	weather.set_intensity(0.6)
	_recompute_cooling()

func ambience_profiles() -> Array:
	return ["sand", "wind", "machine"]

func ambience_volumes() -> Array:
	return [0.40, 0.26, 0.18]

func on_state_changed(s: int) -> void:
	weather.set_intensity([0.25, 0.75, 0.4][clampi(s, 0, 2)])
	AudioDirector.fade_ambience(2, [0.34, 0.16, 0.10][clampi(s, 0, 2)], 1.4)

func save_flags() -> Dictionary:
	var f := _flags.duplicate()
	var steps: Array = []
	for v in _coolant_valves:
		steps.append((v as ValveWheel).step)
	f["coolant_steps"] = steps
	f["heat"] = _core_heat
	return f

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	if flags.has("coolant_steps"):
		var steps: Array = flags.coolant_steps
		for i in mini(steps.size(), _coolant_valves.size()):
			(_coolant_valves[i] as ValveWheel).set_step(int(steps[i]))
		_recompute_cooling()
	_core_heat = clampf(float(flags.get("heat", 0.0)), 0.0, 0.6)

func shot_spots() -> Array:
	return [
		{"name": "dunes", "pos": on_ground(30, 80, 14.0), "look": on_ground(0, 40, 8.0)},
		{"name": "sink", "pos": Vector3(40, 8, -34), "look": Vector3(0, -14, -70)},
		{"name": "core", "pos": Vector3(22, -12, -50), "look": Vector3(0, -13, -70)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "Drill foreman's badge, laminated, edges chewed. On the back, in marker: 'DAY 1: water. DAY 400: not water. DAY 401: told them. DAY 402: told to keep digging.'"
		1: return "A sand-scoured idol, palm-sized, carved from something that is not local stone. Whoever made it had seen the object at the bottom of this shaft, and they carved it holding its own light."
		2: return "Coolant manifest, twelve lines, three ticked. Below the list, in a shaking hand: 'It does not need cooling. It is being polite. When it stops being polite there will be no manifest and no us.'"
	return ""
