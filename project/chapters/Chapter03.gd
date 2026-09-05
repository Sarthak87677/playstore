extends ChapterBase
## CHAPTER 3 - NACRE CITY
## A vertical harbour city with nine floors underwater and four still drawing
## power. Water level and power routing are the two levers, and almost every
## route depends on both.

var _noise := FastNoiseLite.new()
var _pads: Array[Vector4] = []
var _flags := {"sluice": false, "raft": false, "pumps": false, "tram": false,
	"lift": false, "roofs": false, "spire": false}

var _water: WaterVolume
var _sluice_valve: ValveWheel
var _lift_lock: ResonanceLock
var _pearl_lift: Gate
var _pump_sink: PowerPoint
var _spire_done := false
var _shifts_at_lift_start := 0
var _lift_shift_budget_ok := true

const WATER_LEVELS := [-2.0, 1.5, 5.0, 8.5]

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	# The city sits in a shallow basin that drops toward the harbour (south).
	var basin := -6.0 + clampf((absf(x) - 30.0) / 60.0, 0.0, 1.0) * 16.0
	var slope := clampf((z + 40.0) / 150.0, 0.0, 1.0) * 8.0
	var y := basin + slope + n.get_noise_2d(x * 0.4, z * 0.4) * 1.6

	# Canal channels running north-south.
	for cx in [-34.0, 34.0]:
		var c := clampf(1.0 - absf(x - cx) / 9.0, 0.0, 1.0)
		y -= smoothstep(0.0, 1.0, c) * 7.0
	for pad in _pads:
		var d := Vector2(x - pad.x, z - pad.y).length()
		var w := float(pad.z)
		if d < w:
			var k := smoothstep(w, w * 0.3, d)
			y = lerpf(y, float(pad.w), k * k * (3.0 - 2.0 * k))
	return y

func build_world() -> void:
	_noise.seed = 3303
	_noise.frequency = 0.012
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	_pads = [
		Vector4(0, 96, 15, 4.0),      # harbour steps
		Vector4(0, 62, 14, 1.0),      # flooded underpass
		Vector4(-26, 34, 14, 0.5),    # raft basin
		Vector4(24, 16, 14, 3.0),     # pumping station
		Vector4(0, -6, 16, 2.0),      # tram plaza
		Vector4(-22, -34, 14, 2.0),   # pearl lift base
		Vector4(14, -60, 15, 2.0),    # rooftops footing
		Vector4(0, -86, 16, 3.0),     # spire base
	]

	SceneFlow.report(0.12, "Laying the basin")
	build_terrain(Vector2(300, 300), 225, Callable(self, "_h"), "city")
	spawn_position = on_ground(0, 96, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.24, "Raising the district")
	_build_city()
	await get_tree().process_frame

	SceneFlow.report(0.38, "Flooding the low floors")
	_build_water()
	_build_sluice()
	await get_tree().process_frame

	SceneFlow.report(0.50, "Raft basin")
	_build_raft()
	await get_tree().process_frame

	SceneFlow.report(0.60, "Pumping station")
	_build_pumps()
	await get_tree().process_frame

	SceneFlow.report(0.70, "Tram plaza")
	_build_tram()
	await get_tree().process_frame

	SceneFlow.report(0.80, "Pearl Lift")
	_build_lift()
	await get_tree().process_frame

	SceneFlow.report(0.88, "Rooftops and spire")
	_build_roofs()
	_build_spire()
	_build_dressing()
	await get_tree().process_frame

# ---------------------------------------------------------------- city fabric
func _tower(pos: Vector3, w: float, h: float, d: float, seed_v: int,
		mat_name: String = "nacre") -> StaticBody3D:
	var body := static_mesh(ProcAssets.facade_mesh(w, h, d,
		maxi(2, int(w / 2.6)), maxi(3, int(h / 3.2)), 0.22, seed_v),
		mat_name, pos + Vector3(0, h * 0.5, 0),
		Vector3(0, rng.randf_range(-0.05, 0.05), 0), Vector3.ONE,
		Veil.Surface.STONE)
	# Roof lip and a service box, so the skyline is not just extruded slabs.
	decor(ProcAssets.box_mesh(Vector3(w + 0.6, 0.4, d + 0.6)), "concrete_aged",
		pos + Vector3(0, h + 0.2, 0))
	if rng.randf() < 0.6:
		decor(ProcAssets.box_mesh(Vector3(w * 0.35, 1.6, d * 0.35)), "metal_dark",
			pos + Vector3(rng.randf_range(-w * 0.2, w * 0.2), h + 1.0,
				rng.randf_range(-d * 0.2, d * 0.2)))
	return body

func _build_city() -> void:
	# A grid of towers with the harbour end lower and more broken.
	for i in 46:
		var x := rng.randf_range(-120, 120)
		var z := rng.randf_range(-120, 120)
		var skip := false
		for p in _pads:
			if Vector2(x - p.x, z - p.y).length() < p.z + 8.0:
				skip = true
				break
		if skip:
			continue
		var far := clampf((z + 120.0) / 240.0, 0.0, 1.0)
		var h := lerpf(30.0, 9.0, far) * rng.randf_range(0.6, 1.3)
		_tower(on_ground(x, z, -0.5), rng.randf_range(7.0, 15.0), h,
			rng.randf_range(7.0, 15.0), 6000 + i,
			"nacre" if rng.randf() < 0.55 else "concrete_aged")
	# Fallen slabs and mooring bollards.
	for i in 60:
		var x := rng.randf_range(-120, 120)
		var z := rng.randf_range(-120, 120)
		static_mesh(ProcAssets.debris_mesh(300 + i % 14, 8, 2.6, 1.3), "concrete_aged",
			on_ground(x, z, 0.2), Vector3(0, rng.randf_range(0, TAU), 0),
			Vector3.ONE, Veil.Surface.STONE, Veil.L_WORLD, false)
	for i in 24:
		var x := rng.randf_range(-40, 40)
		var z := rng.randf_range(60, 110)
		decor(ProcAssets.cylinder_mesh(0.4, 1.0, 10), "metal_rust",
			on_ground(x, z, 0.5))

func _build_dressing() -> void:
	var excl: Array = []
	for p in _pads:
		excl.append(Rect2(p.x - p.z * 0.8, p.y - p.z * 0.8, p.z * 1.6, p.z * 1.6))
	vegetation.scatter(ProcAssets.blade_cluster_mesh(41, 15, 0.5, 0.05), 3000,
		Rect2(-130, -130, 260, 260), veg_sampler(28.0, excl, 2.0),
		Color(0.24, 0.34, 0.22), Color(0.40, 0.52, 0.30), Vector2(0.6, 1.5), 0.18, 31, 0.9)
	vegetation.scatter(ProcAssets.canopy_mesh(42, 0.7, 3), 700,
		Rect2(-130, -130, 260, 260), veg_sampler(22.0, excl, 3.0),
		Color(0.20, 0.36, 0.28), Color(0.34, 0.56, 0.40), Vector2(0.5, 1.6), 0.10, 32, 1.4)

# ---------------------------------------------------------------- water
func _build_water() -> void:
	_water = WaterVolume.new()
	add_child(_water)
	_water.position = Vector3(0, 0, 0)
	_water.build(Vector2(300, 300), 30.0, WATER_LEVELS[1],
		Color(0.24, 0.50, 0.52, 0.50), Color(0.02, 0.10, 0.17, 0.95))

func _set_water(step: int) -> void:
	var y: float = WATER_LEVELS[clampi(step, 0, WATER_LEVELS.size() - 1)]
	_water.set_level(y, 2.6)
	AudioDirector.play_3d("machine_start", get_tree().current_scene,
		player.global_position, -14.0, 0.8)

func _build_sluice() -> void:
	var base := on_ground(0, 62)
	# An underpass that is only passable at low water.
	box(Vector3(26.0, 0.6, 12.0), "concrete_aged", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	box(Vector3(26.0, 6.0, 1.0), "concrete_aged", base + Vector3(0, 3.0, -6.0))
	box(Vector3(8.0, 6.0, 12.0), "concrete_aged", base + Vector3(-13.0, 3.0, 0))
	box(Vector3(8.0, 6.0, 12.0), "concrete_aged", base + Vector3(13.0, 3.0, 0))
	box(Vector3(26.0, 1.2, 12.0), "concrete_aged", base + Vector3(0, 6.6, 0))

	_sluice_valve = ValveWheel.new()
	_sluice_valve.label = "Sluice Gate"
	_sluice_valve.stops = 4
	_sluice_valve.start_step = 1
	_sluice_valve.position = base + Vector3(9.0, 0.3, 5.0)
	add_child(_sluice_valve)
	_sluice_valve.turned.connect(func(step: int, _total: int) -> void:
		_set_water(step))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch3_sluice"
	pz.title = "Harbour Sluice"
	pz.hint_subtle = "The water is a setting, not a fact."
	pz.hint_guided = "The valve on the walkway changes the level of the whole district."
	pz.hint_directed = "Turn the sluice wheel down to its lowest stop, then walk the underpass floor."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 1.4, -8.0), Vector3(20, 4, 4), func() -> void:
		_flags.sluice = true
		if not pz.is_solved:
			pz.mark_solved())

	scannable(base + Vector3(9.0, 1.6, 5.0), "Sluice Governor",
		"Manual override. The automatic one is nine floors down and has opinions.",
		Veil.Prop.RIGID, -1, 2.6)
	checkpoint("cp_sluice", base + Vector3(0, 0.4, -9.0), 180.0)
	trigger(base + Vector3(0, 3, 10.0), Vector3(26, 8, 6), func() -> void:
		say("Nine floors under water and four still lit. Somebody is paying the bill.",
			"MOTE", 5.0))

# ---------------------------------------------------------------- raft
func _build_raft() -> void:
	var base := on_ground(-26, 34)
	box(Vector3(30.0, 0.5, 26.0), "concrete_aged", base + Vector3(0, -6.0, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	# A ledge you can only reach by floating up on the crate.
	box(Vector3(9.0, 0.6, 7.0), "concrete", base + Vector3(0, 7.2, -10.0),
		Vector3.ZERO, Veil.Surface.STONE)
	box(Vector3(9.0, 5.0, 0.6), "concrete", base + Vector3(0, 9.8, -13.2))

	var crate := prop(base + Vector3(0, -3.0, 6.0), Vector3(1.6, 1.0, 1.6),
		"Dock Pallet", 120.0, "wood")
	crate.imprint.accepted = [Veil.Prop.BUOYANT, Veil.Prop.HOLLOW, Veil.Prop.RIGID]

	# The buoyancy reference: a mooring float that only exists in Memory.
	var float_mem := variant_mesh(ProcAssets.rock_mesh(881, 0.9, 0.1, 10, 14, 0.9),
		ProcAssets.mat_variant("metal_rust", Color(1.2, 0.9, 0.7)),
		Vector3.ZERO, Vector3.ZERO, Veil.Surface.METAL)
	veil_subject("mooring_float", base + Vector3(11.0, 2.4, 4.0), float_mem, null, null, 3.0)
	var sc := scannable(base + Vector3(11.0, 2.4, 4.0), "Mooring Float",
		"Sealed air. It has been holding the same tonne up for thirty years.",
		Veil.Prop.BUOYANT, Veil.State.MEMORY, 3.0)
	sc.xp_bonus = 90

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch3_raft"
	pz.title = "Raft Basin"
	pz.hint_subtle = "The pallet sinks. The ledge is above the waterline."
	pz.hint_guided = "Make the pallet float, then raise the water under it."
	pz.hint_directed = "Scan the Memory-state mooring float for Buoyant, imprint it on the pallet, then turn the sluice up to its top stop and ride it."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 8.4, -10.0), Vector3(8, 3, 6), func() -> void:
		_flags.raft = true
		if not pz.is_solved:
			pz.mark_solved())
	fragment(0, base + Vector3(3.0, 7.8, -11.5))

# ---------------------------------------------------------------- pumps
func _build_pumps() -> void:
	var base := on_ground(24, 16)
	box(Vector3(24.0, 0.6, 20.0), "concrete", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	static_mesh(ProcAssets.room_shell(Vector3(14.0, 6.0, 11.0), 0.5, 3.4, 3.6, true, 1),
		"concrete_aged", base + Vector3(0, 3.2, -2.0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	for i in 3:
		decor(ProcAssets.cylinder_mesh(0.9, 4.0, 14), "metal_rust",
			base + Vector3(-4.0 + float(i) * 4.0, 2.0, -4.0))

	var src := PowerPoint.new()
	src.point_id = "ch3_src"
	src.is_source = true
	src.position = base + Vector3(-9.0, 0, 7.0)
	add_child(src); power.register(src)
	var j1 := PowerPoint.new()
	j1.point_id = "ch3_j1"
	j1.position = base + Vector3(0, 0, 4.0)
	add_child(j1); power.register(j1)
	var j2 := PowerPoint.new()
	j2.point_id = "ch3_j2"
	j2.position = base + Vector3(8.0, 0, 2.0)
	add_child(j2); power.register(j2)
	_pump_sink = PowerPoint.new()
	_pump_sink.point_id = "ch3_pumps"
	_pump_sink.is_sink = true
	_pump_sink.position = base + Vector3(8.0, 0, -6.0)
	add_child(_pump_sink); power.register(_pump_sink)

	var c1 := Conduit.new(); add_child(c1)
	c1.build(src.position + Vector3(0, 1.8, 0), j1.position + Vector3(0, 1.8, 0),
		[Veil.State.MEMORY], manager, true, 0.5)
	var c2 := Conduit.new(); add_child(c2)
	c2.build(j1.position + Vector3(0, 1.8, 0), j2.position + Vector3(0, 1.8, 0),
		[], manager, true, 0.5)
	var c3 := Conduit.new(); add_child(c3)
	c3.build(j2.position + Vector3(0, 1.8, 0), _pump_sink.position + Vector3(0, 1.8, 0),
		[Veil.State.MEMORY, Veil.State.BLOOM], manager, true, 0.5)
	power.link("ch3_src", "ch3_j1", Callable(c1, "is_conductive"), true, c1)
	power.link("ch3_j1", "ch3_j2", Callable(c2, "is_conductive"), true, c2)
	power.link("ch3_j2", "ch3_pumps", Callable(c3, "is_conductive"), true, c3)

	var sc := scannable(base + Vector3(-11.0, 1.8, 9.0), "Harbour Bus Bar",
		"Salt has eaten the label. The copper underneath is immaculate.",
		Veil.Prop.CONDUCTIVE, Veil.State.MEMORY, 2.6)
	sc.xp_bonus = 70

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch3_pumps"
	pz.title = "Pumping Station"
	pz.hint_subtle = "Three runs. One of them is not a cable at all any more."
	pz.hint_guided = "Two runs come back in Memory. The middle one wants a property."
	pz.hint_directed = "Pin a Memory field over the station, scan the bus bar for Conductive and imprint the dead middle run."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_pump_sink.powered_changed.connect(func(on: bool) -> void:
		if on:
			_flags.pumps = true
			if not pz.is_solved:
				pz.mark_solved()
				say("Pumps have power. The Pearl Lift needs them and the water at full.",
					"MOTE", 4.8))

	guardian(base + Vector3(10.0, 0.4, 8.0), [
		base + Vector3(10, 0.4, 8), base + Vector3(-8, 0.4, 8),
		base + Vector3(-8, 0.4, -6)])
	checkpoint("cp_pumps", base + Vector3(0, 0.4, 8.0), 180.0)
	component(base + Vector3(0, 1.0, -6.0))

# ---------------------------------------------------------------- tram
func _build_tram() -> void:
	var base := on_ground(0, -6)
	box(Vector3(34.0, 0.6, 22.0), "tile", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for sx in [-14.0, 14.0]:
		box(Vector3(3.0, 12.0, 3.0), "nacre", base + Vector3(sx, 6.0, -9.0))

	# The tram deck exists in Memory; in Bloom a coral shelf spans the same gap.
	var mem := variant_group([
		variant_box(Vector3(5.0, 0.4, 26.0), "metal", Vector3(0, 9.0, -20.0),
			Vector3.ZERO, Veil.Surface.METAL),
		variant_box(Vector3(0.2, 1.0, 26.0), "metal_rust", Vector3(-2.4, 9.6, -20.0),
			Vector3.ZERO, Veil.Surface.METAL),
		variant_box(Vector3(0.2, 1.0, 26.0), "metal_rust", Vector3(2.4, 9.6, -20.0),
			Vector3.ZERO, Veil.Surface.METAL)])
	var bpts := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		bpts.append(Vector3(sin(t * 3.4) * 1.6, 8.2 - sin(t * PI) * 1.2, -7.0 - t * 26.0))
	var bradii := PackedFloat32Array()
	for i in 9:
		bradii.append(1.15)
	var bloom := variant_group([
		variant_mesh(ProcAssets.tube_mesh("ch3tram", bpts, bradii, 9, 0.3), "resin",
			Vector3.ZERO, Vector3.ZERO, Veil.Surface.RESIN)])
	var deck := veil_subject("tram_deck", base + Vector3(0, 0, 0), mem, null, bloom, 16.0)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch3_tram"
	pz.title = "Tram Crossing"
	pz.hint_subtle = "There were three ways across this plaza and none of them are now."
	pz.hint_guided = "The tram deck is a Memory. The coral shelf is a Bloom."
	pz.hint_directed = "Pin a Memory or Bloom field over the plaza gap and walk across the span it makes."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 10.0, -30.0), Vector3(10, 4, 5), func() -> void:
		_flags.tram = true
		if not pz.is_solved:
			pz.mark_solved())

	scannable(base + Vector3(-16.0, 1.6, 4.0), "Tram Signal Head",
		"Still cycling. Green, amber, red, for a service that has no cars and no drivers.")
	wildlife(base + Vector3(15.0, 1.0, 6.0), "Nacre Kelp Shoal",
		"They graze the tower faces and leave them polished. The city has never looked better.")
	fragment(1, base + Vector3(-14.0, 12.4, -9.0))

# ---------------------------------------------------------------- pearl lift
func _build_lift() -> void:
	var base := on_ground(-22, -34)
	box(Vector3(26.0, 0.6, 22.0), "tile", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 4:
		box(Vector3(1.4, 26.0, 1.4), "nacre",
			base + Vector3(-6.0 + float(i % 2) * 12.0, 13.0, -6.0 + float(i / 2) * 12.0))

	_pearl_lift = Gate.new()
	_pearl_lift.size = Vector3(9.0, 0.5, 9.0)
	_pearl_lift.open_offset = Vector3(0, 24.0, 0)
	_pearl_lift.open_time = 7.0
	_pearl_lift.material_name = "nacre"
	_pearl_lift.position = base + Vector3(0, 0.6, 0)
	add_child(_pearl_lift)

	_lift_lock = ResonanceLock.new()
	_lift_lock.position = base + Vector3(9.0, 0.2, 8.0)
	add_child(_lift_lock)
	_lift_lock.add_condition(func() -> bool: return power.is_powered("ch3_pumps"),
		"Pumps powered")
	_lift_lock.add_condition(func() -> bool: return _water.target_level >= WATER_LEVELS[3] - 0.1,
		"Water at full")
	_lift_lock.add_condition(func() -> bool:
		return manager.state_at(base) != Veil.State.RUIN, "Structure sound")
	_lift_lock.hint_subtle = "The lift wants three things at once."
	_lift_lock.hint_guided = "Power, water and a version of this shaft that is not falling apart."
	_lift_lock.hint_directed = "Power the pumps, turn the sluice to its top stop, then hold a Memory or Bloom field over the lift shaft."
	_lift_lock.register_hints()
	_lift_lock.solved.connect(func(_p: bool) -> void:
		_flags.lift = true
		_pearl_lift.open()
		say("Pearl Lift is rising. Twenty-four metres, and then the roofs.", "MOTE", 4.6)
		if GameState.run.get("shifts", 0) - _shifts_at_lift_start <= 3:
			GameState.complete_challenge()
			say("Three shifts. That was elegant.", "MOTE", 3.0)
		else:
			_lift_shift_budget_ok = false)

	checkpoint("cp_lift", base + Vector3(0, 0.6, 7.0), 180.0)
	trigger(base + Vector3(0, 3, 12.0), Vector3(22, 8, 6), func() -> void:
		_shifts_at_lift_start = int(GameState.run.get("shifts", 0))
		say("The Pearl Lift. It only runs when the district agrees with itself.",
			"MOTE", 4.6))

# ---------------------------------------------------------------- roofs
func _build_roofs() -> void:
	var base := on_ground(14, -60)
	base.y += 24.0
	# A rooftop crossing where each stepping stone belongs to a different state.
	var seq := [Veil.State.MEMORY, Veil.State.BLOOM, Veil.State.RUIN,
		Veil.State.MEMORY, Veil.State.BLOOM]
	for i in seq.size():
		var p := base + Vector3(sin(float(i) * 1.3) * 6.0, float(i) * 1.2, -float(i) * 7.0)
		var mem: Node3D = null
		var ruin: Node3D = null
		var bloom: Node3D = null
		var block := func(m: String, s: int) -> Node3D:
			return variant_box(Vector3(5.0, 0.5, 5.0), m, Vector3.ZERO, Vector3.ZERO, s)
		match seq[i]:
			Veil.State.MEMORY: mem = block.call("nacre", Veil.Surface.STONE)
			Veil.State.RUIN: ruin = block.call("concrete_aged", Veil.Surface.STONE)
			_: bloom = block.call("resin", Veil.Surface.RESIN)
		veil_subject("roof_%d" % i, p, mem, ruin, bloom, 3.5)

	box(Vector3(10.0, 0.6, 10.0), "nacre", base + Vector3(0, -0.3, 4.0),
		Vector3.ZERO, Veil.Surface.STONE)
	box(Vector3(12.0, 0.6, 12.0), "nacre",
		base + Vector3(sin(5.0 * 1.3) * 6.0, 6.0, -5.0 * 7.0 - 6.0),
		Vector3.ZERO, Veil.Surface.STONE)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch3_roofs"
	pz.title = "Roof Crossing"
	pz.hint_subtle = "Only some of the stones are here at any one time."
	pz.hint_guided = "The field moves with you. Change state as you go."
	pz.hint_directed = "Aim ahead, pick the state the next stone belongs to, shift, step, repeat. Pinning does not help - the stones alternate."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(sin(5.0 * 1.3) * 6.0, 1.6, -5.0 * 7.0 - 6.0),
		Vector3(10, 4, 10), func() -> void:
			_flags.roofs = true
			if not pz.is_solved:
				pz.mark_solved())
	hidden_marker(base + Vector3(-9.0, 0.6, 6.0))
	checkpoint("cp_roofs", base + Vector3(0, 0.6, 4.0), 180.0)

# ---------------------------------------------------------------- spire
func _build_spire() -> void:
	var base := on_ground(0, -86)
	base.y += 30.0
	box(Vector3(20.0, 0.8, 20.0), "nacre", base + Vector3(0, -0.4, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 5:
		decor(ProcAssets.ring_mesh(6.0 - float(i) * 0.9, 0.3, 26, 8), "nacre",
			base + Vector3(0, 2.0 + float(i) * 3.0, 0))
	decor(ProcAssets.crystal_mesh(555, 9.0, 2.0, 6), "glass", base + Vector3(0, 16.0, 0))

	var it := Interactable.new()
	it.prompt = "Read the spire beacon"
	it.hold_time = 1.4
	it.one_shot = true
	it.position = base + Vector3(0, 1.2, 0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 3.0
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(base))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch3_spire"
	pz.title = "Spire Beacon"
	pz.hint_subtle = "The beacon is above you."
	pz.hint_guided = "The roof crossing leads to the spire platform."
	pz.hint_directed = "Cross the roofs, then read the beacon on the spire deck."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 2.0, 0), Vector3(14, 5, 14), func() -> void:
		if not pz.is_solved:
			pz.mark_solved())
	fragment(2, base + Vector3(7.0, 0.8, -6.0))

func _finale(base: Vector3) -> void:
	if _spire_done:
		return
	_spire_done = true
	_flags.spire = true
	AudioDirector.play("power_on", -2.0)
	SceneFlow.flash(Color(0.7, 0.95, 1.0, 0.3), 0.7)
	set_objective("Spire beacon read.")
	await cinematic(
		[base + Vector3(-26, 12, 28), base + Vector3(8, 22, 10), base + Vector3(0, 34, -24)],
		[base + Vector3(0, 8, 0), base + Vector3(0, 14, -4), base + Vector3(0, 4, -60)],
		9.5,
		[["The beacon has been transmitting the same nine seconds since the Fracture.",
			"MOTE"],
		 ["It is not a distress call. It is a measurement, repeated, of something getting worse.",
			"MOTE"],
		 ["The source is north, in the mountains, and it is very cold there. Bring the suit.",
			"MOTE"]])
	finish()

# ---------------------------------------------------------------- hooks
func on_begin(mode: String) -> void:
	player.device.unlock_all()
	if mode != "checkpoint":
		say("Nacre City. Four floors of it are above water today. That number is not stable.",
			"MOTE", 5.2)
	set_objective(String(info.objective))
	weather.set_intensity(0.6)

func ambience_profiles() -> Array:
	return ["water", "wind", "machine"]

func ambience_volumes() -> Array:
	return [0.44, 0.24, 0.14]

func on_state_changed(s: int) -> void:
	weather.set_intensity([0.35, 0.7, 0.5][clampi(s, 0, 2)])
	AudioDirector.fade_ambience(2, [0.30, 0.12, 0.06][clampi(s, 0, 2)], 1.4)

func save_flags() -> Dictionary:
	var f := _flags.duplicate()
	f["water_step"] = _sluice_valve.step if _sluice_valve else 1
	return f

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	if flags.has("water_step") and _sluice_valve:
		_sluice_valve.set_step(int(flags.water_step))
		_set_water(int(flags.water_step))
	if bool(_flags.get("lift", false)) and _pearl_lift:
		_pearl_lift.open()

func shot_spots() -> Array:
	return [
		{"name": "harbour", "pos": on_ground(28, 82, 14.0), "look": on_ground(0, 40, 6.0)},
		{"name": "plaza", "pos": on_ground(-30, 8, 16.0), "look": on_ground(0, -20, 8.0)},
		{"name": "spire", "pos": on_ground(30, -66, 44.0), "look": on_ground(0, -86, 36.0)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "A tram token, brass, worn smooth on one face. The reverse still reads NACRE TRANSIT - ONE JOURNEY, ANY LINE. Somebody drilled a hole through it and wore it on a string."
		1: return "A photograph taken from a balcony, showing the same view you are standing in. The water in the picture is nine floors lower and there are boats on it. On the back: 'the tide went out in 1 hour. it has not come back in.'"
		2: return "The harbourmaster's key, on a float so it would not sink. Tied to it, a note: 'If the beacon is still running when you read this, the engine is still trying. Do not switch it off to make the noise stop.'"
	return ""
