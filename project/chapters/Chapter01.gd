extends ChapterBase
## CHAPTER 1 - GLASS-RAIN VALLEY
## Atmospheric tutorial. Teaches movement, mantling, scanning, the veil field,
## state cycling, pinning, imprinting and the EMP, each through a puzzle rather
## than a text wall. Ends with the valley relay coming back online.

var _device_taken := false
var _bridge: VeilSubject
var _door_gate: Gate
var _plate: PressurePlate
var _crate: PhysicsProp
var _lock: ResonanceLock
var _pin_platform: VeilSubject
var _relay_powered := false
var _shard_hits_at_start := 0
var _flags := {"bridge": false, "door": false, "plate": false, "conduit": false,
	"pin": false, "relay": false}

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	var valley: float = pow(minf(absf(x) / 62.0, 1.6), 2.0) * 30.0
	var rise: float = -z * 0.055
	var detail: float = n.get_noise_2d(x * 0.6, z * 0.6) * 3.2 \
		+ n.get_noise_2d(x * 2.4, z * 2.4) * 0.9
	var y: float = valley + rise + detail

	# The fissure the first bridge crosses.
	var fis: float = clampf(1.0 - absf(z - 18.0) / 9.0, 0.0, 1.0)
	var fis_x: float = clampf(1.0 - maxf(0.0, absf(x) - 34.0) / 10.0, 0.0, 1.0)
	y -= smoothstep(0.0, 1.0, fis) * fis_x * 22.0

	# Flat pads where structures sit.
	for pad in _pads:
		var d: float = Vector2(x - pad.x, z - pad.y).length()
		var w: float = float(pad.z)
		if d < w:
			var k: float = smoothstep(w, w * 0.45, d)
			y = lerpf(y, float(pad.w), k)
	return y

var _noise := FastNoiseLite.new()
var _pads: Array[Vector4] = []

func build_world() -> void:
	_noise.seed = 1101
	_noise.frequency = 0.010
	_noise.fractal_octaves = 4
	manager.base_state = Veil.State.RUIN
	spawn_position = Vector3(0, 0, 64)
	spawn_yaw = PI

	# x, z, radius, height
	_pads = [
		Vector4(0, 62, 12, 3.0),      # landing site
		Vector4(0, 34, 10, 2.2),      # approach
		Vector4(0, 4, 12, -0.4),      # bridge far side
		Vector4(-26, -2, 11, 1.4),    # sealed door yard
		Vector4(20, -8, 11, 0.9),     # plate court
		Vector4(0, -26, 13, 0.2),     # conduit terrace
		Vector4(-16, -46, 12, 2.6),   # pinned platform gap
		Vector4(12, -58, 14, 1.2),    # guardian yard
		Vector4(0, -80, 14, 3.4),     # relay base
	]

	SceneFlow.report(0.16, "Cutting the valley")
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(Vector2(280, 280), 130, Callable(self, "_h"),
		ProcAssets.mat("rock"), Veil.Surface.STONE)
	spawn_position = on_ground(0, 64, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.30, "Scattering glass")
	_build_scenery()
	await get_tree().process_frame

	SceneFlow.report(0.42, "Landing site")
	_build_start()
	await get_tree().process_frame

	SceneFlow.report(0.52, "Fissure crossing")
	_build_bridge()
	await get_tree().process_frame

	SceneFlow.report(0.60, "Sealed yard")
	_build_door()
	_build_plate()
	await get_tree().process_frame

	SceneFlow.report(0.70, "Power terrace")
	_build_conduit()
	await get_tree().process_frame

	SceneFlow.report(0.76, "Pinned span")
	_build_pin_gap()
	await get_tree().process_frame

	SceneFlow.report(0.82, "Guardian yard")
	_build_guardian_yard()
	await get_tree().process_frame

	SceneFlow.report(0.86, "Relay tower")
	_build_relay()
	_build_vegetation()
	await get_tree().process_frame

# ---------------------------------------------------------------- scenery
func _build_scenery() -> void:
	# Boulders and glass shelves along the valley walls.
	for i in 130:
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		if absf(x) < 16.0 and z > -90.0 and z < 70.0:
			continue
		if terrain.slope_at(x, z) > 34.0:
			continue
		rock(on_ground(x, z, -0.3), rng.randf_range(0.8, 4.2), 700 + i)
	for i in 46:
		var x := rng.randf_range(-110, 110)
		var z := rng.randf_range(-120, 110)
		if absf(x) < 22.0:
			continue
		var m := ProcAssets.crystal_mesh(200 + i, rng.randf_range(1.6, 5.5),
			rng.randf_range(0.3, 0.9), 5)
		static_mesh(m, "glass_broken", on_ground(x, z, -0.4),
			Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2)),
			Vector3.ONE, Veil.Surface.GLASS)
	# Fallen survey poles.
	for i in 16:
		var x := rng.randf_range(-60, 60)
		var z := rng.randf_range(-100, 60)
		decor(ProcAssets.cylinder_mesh(0.09, rng.randf_range(2.0, 4.5), 8),
			"metal_rust", on_ground(x, z, 0.6),
			Vector3(rng.randf_range(1.1, 1.6), rng.randf_range(0, TAU), 0))

func _build_vegetation() -> void:
	var excl: Array = []
	for p in _pads:
		excl.append(Rect2(p.x - p.z * 0.8, p.y - p.z * 0.8, p.z * 1.6, p.z * 1.6))
	vegetation.scatter(ProcAssets.blade_cluster_mesh(1, 6, 0.55, 0.05), 5200,
		Rect2(-130, -130, 260, 260), veg_sampler(30.0, excl),
		Color(0.24, 0.30, 0.18), Color(0.42, 0.46, 0.24), Vector2(0.7, 1.7), 0.20, 11, 0.9)
	vegetation.scatter(ProcAssets.blade_cluster_mesh(2, 4, 1.15, 0.08), 1100,
		Rect2(-130, -130, 260, 260), veg_sampler(24.0, excl),
		Color(0.30, 0.34, 0.20), Color(0.52, 0.54, 0.28), Vector2(0.7, 1.5), 0.30, 12, 1.6)

# ---------------------------------------------------------------- start
func _build_start() -> void:
	var base := on_ground(0, 62)
	# The survey skiff you walked away from.
	var hull := Node3D.new()
	hull.position = base + Vector3(9.0, 0.4, 5.0)
	hull.rotation.y = 0.7
	add_child(hull)
	static_mesh(ProcAssets.box_mesh(Vector3(4.2, 1.5, 8.0), 0.5), "metal_rust",
		Vector3.ZERO, Vector3(0.12, 0, 0.22), Vector3.ONE, Veil.Surface.METAL,
		Veil.L_WORLD, true, hull)
	decor(ProcAssets.box_mesh(Vector3(3.0, 1.2, 2.4)), "metal_dark",
		Vector3(0, 1.2, -1.6), Vector3.ZERO, Vector3.ONE, hull)
	decor(ProcAssets.crystal_mesh(9, 1.6, 0.5, 5), "glass_broken",
		Vector3(1.4, 1.0, 3.6), Vector3(0.4, 1.0, 0.2), Vector3.ONE, hull)

	scannable(base + Vector3(9.0, 1.6, 5.0), "Survey Skiff GR-04",
		"Impact damage on the port side. The log ends mid-sentence.", Veil.Prop.RIGID, -1, 2.6)

	# The device itself.
	var plinth := box(Vector3(1.2, 1.0, 1.2), "concrete", base + Vector3(0, 0.5, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	var dev := MeshInstance3D.new()
	dev.mesh = ProcAssets.box_mesh(Vector3(0.36, 0.20, 0.30))
	dev.material_override = ProcAssets.emissive(Color(0.5, 0.85, 1.0), 1.8)
	dev.position = base + Vector3(0, 1.15, 0)
	add_child(dev)
	var halo := decor(ProcAssets.ring_mesh(0.34, 0.03, 20, 6),
		ProcAssets.additive(Color(0.5, 0.85, 1.0), 2.6), base + Vector3(0, 1.15, 0))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.5, 0.85, 1.0)
	lamp.light_energy = 2.2
	lamp.omni_range = 9.0
	lamp.position = base + Vector3(0, 1.4, 0)
	add_child(lamp)

	var it := Interactable.new()
	it.prompt = "Take the Veilforge Device"
	it.position = base + Vector3(0, 1.1, 0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 2.2
	cs.shape = sp
	it.add_child(cs)
	it.one_shot = true
	add_child(it)
	it.used.connect(func(_by: Node) -> void:
		_on_device_taken(dev, halo, lamp))

	checkpoint("cp_start", base + Vector3(-3, 0, -2), 180.0)

	trigger(base + Vector3(0, 2, -14), Vector3(30, 8, 6), func() -> void:
		say("The relay is south, past the fissure. If the bridge is still down, we improvise.",
			"MOTE", 4.6))

func _on_device_taken(dev: Node3D, halo: Node3D, lamp: Node3D) -> void:
	if _device_taken:
		return
	_device_taken = true
	dev.queue_free()
	halo.queue_free()
	lamp.queue_free()
	player.device.unlock("field")
	AudioDirector.play("power_on", -4.0)
	SceneFlow.flash(Color(0.5, 0.85, 1.0, 0.35), 0.5)
	say_now("Veilforge core is warm. Hold the aim key to throw a field, then shift what is inside it.",
		"MOTE", 6.0)
	Hints.request("veil_aim")
	Hints.request("veil_cycle")
	set_objective("Cross the fissure and reach the valley relay.")
	GameState.award(120, "Veilforge Device recovered")

# ---------------------------------------------------------------- bridge
func _build_bridge() -> void:
	var y_near := _h(0, 27.0)
	var y_far := _h(0, 9.0)
	var mid_y := (y_near + y_far) * 0.5 + 0.6

	# Anchor piers on both sides.
	box(Vector3(7.0, 5.0, 3.0), "concrete_aged", Vector3(0, y_near - 1.0, 27.5))
	box(Vector3(7.0, 5.0, 3.0), "concrete_aged", Vector3(0, y_far - 1.0, 8.5))

	# MEMORY: intact span.
	var mem := Node3D.new()
	var deck := variant_box(Vector3(6.0, 0.5, 20.0), "concrete",
		Vector3(0, mid_y, 18.0), Vector3.ZERO, Veil.Surface.STONE)
	mem.add_child(deck)
	for side in [-1.0, 1.0]:
		mem.add_child(variant_box(Vector3(0.25, 1.1, 20.0), "metal_rust",
			Vector3(side * 2.9, mid_y + 0.8, 18.0), Vector3.ZERO, Veil.Surface.METAL))
	for i in 5:
		var z := 10.0 + float(i) * 4.0
		mem.add_child(variant_mesh(ProcAssets.truss_mesh(6.0, 1.6, 2.0, 4, 0.08),
			"metal_rust", Vector3(0, mid_y - 1.4, z), Vector3(0, PI * 0.5, 0),
			Veil.Surface.METAL, false))

	# RUIN: the span is gone; only broken stubs remain.
	var ruin := Node3D.new()
	ruin.add_child(variant_box(Vector3(6.0, 0.5, 4.0), "concrete_aged",
		Vector3(0, mid_y, 25.0), Vector3(0.06, 0, 0), Veil.Surface.STONE))
	ruin.add_child(variant_box(Vector3(6.0, 0.5, 3.0), "concrete_aged",
		Vector3(0, mid_y - 0.6, 10.0), Vector3(-0.10, 0, 0), Veil.Surface.STONE))
	ruin.add_child(variant_mesh(ProcAssets.debris_mesh(31, 22, 4.0, 1.4),
		"concrete_aged", Vector3(0, mid_y - 9.0, 18.0), Vector3.ZERO,
		Veil.Surface.STONE, false))

	# BLOOM: a thick root has grown across, lower and narrower.
	var bloom := Node3D.new()
	var pts := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		pts.append(Vector3(sin(t * 3.0) * 1.4, mid_y - 1.2 - sin(t * PI) * 1.6,
			lerpf(27.0, 9.0, t)))
	var radii := PackedFloat32Array()
	for i in 9:
		radii.append(1.05)
	bloom.add_child(variant_mesh(ProcAssets.tube_mesh("ch1bridge", pts, radii, 10, 0.3),
		"bark", Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD))
	for i in 6:
		var t := 0.1 + float(i) * 0.16
		bloom.add_child(variant_mesh(ProcAssets.canopy_mesh(300 + i, 1.9, 3),
			"foliage_bloom", Vector3(sin(t * 3.0) * 1.4 + rng.randf_range(-1.6, 1.6),
				mid_y - 0.2 - sin(t * PI) * 1.6, lerpf(26.0, 10.0, t)),
			Vector3.ZERO, Veil.Surface.FOLIAGE, false))

	_bridge = veil_subject("bridge", Vector3(0, mid_y, 18.0), mem, ruin, bloom, 11.0)

	# Falling into the fissure is fatal; the mist below sells it.
	hazard(Vector3(0, mid_y - 20.0, 18.0), Vector3(80, 8, 18), 0.0, "the fissure", true)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch1_bridge"
	pz.title = "The Fallen Span"
	pz.hint_subtle = "The piers are intact. Something used to sit on them."
	pz.hint_guided = "The bridge exists in Memory. Put the field over the gap and shift."
	pz.hint_directed = "Aim at the middle of the gap, select Memory with the state keys, then shift. Bloom works too - the roots are lower but they hold."
	pz.position = Vector3(0, mid_y, 18.0)
	add_child(pz)
	pz.register_hints()
	_bridge.state_applied.connect(func(s: int) -> void:
		if s == Veil.State.MEMORY or s == Veil.State.BLOOM:
			if not pz.is_solved:
				_flags.bridge = true
				pz.mark_solved()
				say("Span restored. It only holds while the field does.", "MOTE", 4.0))

	checkpoint("cp_bridge", Vector3(0, _h(0, 4.0) + 0.4, 4.0), 180.0)
	trigger(Vector3(0, mid_y + 2.0, 30.0), Vector3(24, 8, 8), func() -> void:
		Hints.request("veil_shift")
		say("Bridge is out. The valley remembers it, though - three ways to cross, if you look.",
			"MOTE", 5.2))

# ---------------------------------------------------------------- sealed door
func _build_door() -> void:
	var base := on_ground(-26, -2)
	# A maintenance blockhouse whose door only opens with power.
	static_mesh(ProcAssets.room_shell(Vector3(9.0, 4.2, 7.0), 0.4, 3.0, 3.0, true, 1),
		"concrete_aged", base + Vector3(0, 2.3, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	_door_gate = Gate.new()
	_door_gate.size = Vector3(3.0, 3.0, 0.3)
	_door_gate.open_offset = Vector3(0, 3.1, 0)
	_door_gate.position = base + Vector3(0, 1.7, 3.6)
	add_child(_door_gate)

	# Inside: the first Memory Fragment and a hidden alcove.
	fragment(0, base + Vector3(0, 1.0, -1.6))
	scannable(base + Vector3(-3.0, 1.4, -2.0), "Weather Board",
		"A shift roster. Somebody kept scoring out their own name and writing it back in.")

	# BLOOM roots make a climbable route onto the roof - the alternate way in.
	var mem := Node3D.new()
	mem.add_child(variant_box(Vector3(3.2, 0.4, 3.2), "concrete",
		Vector3(0, 4.6, -4.4), Vector3.ZERO, Veil.Surface.STONE))
	var bloom := Node3D.new()
	var pts := PackedVector3Array()
	for i in 7:
		var t := float(i) / 6.0
		pts.append(Vector3(-6.0 + t * 1.2, t * 5.6, -5.4 + sin(t * 2.4) * 1.1))
	var radii := PackedFloat32Array()
	for i in 7:
		radii.append(0.55)
	bloom.add_child(variant_mesh(ProcAssets.tube_mesh("ch1door", pts, radii, 8, 0.3),
		"bark", Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD))
	var climb := climb_surface(Vector3(1.6, 5.6, 0.5), base + Vector3(-5.4, 2.8, -5.4))
	bloom.add_child(climb.duplicate())
	climb.queue_free()
	bloom.add_child(variant_box(Vector3(3.4, 0.35, 3.4), "bark",
		Vector3(-5.0, 5.6, -5.0), Vector3.ZERO, Veil.Surface.WOOD))
	veil_subject("door_roof", base, mem, null, bloom, 8.0)

	# Roof hatch drops into the blockhouse.
	box(Vector3(2.0, 0.3, 2.0), "metal_rust", base + Vector3(0, 4.45, -1.0),
		Vector3.ZERO, Veil.Surface.METAL)

	var hatch := Interactable.new()
	hatch.prompt = "Open roof hatch"
	hatch.position = base + Vector3(0, 4.7, -1.0)
	var hcs := CollisionShape3D.new()
	var hsp := SphereShape3D.new()
	hsp.radius = 2.0
	hcs.shape = hsp
	hatch.add_child(hcs)
	add_child(hatch)
	hatch.used.connect(func(_b: Node) -> void:
		_door_gate.open()
		_flags.door = true
		say("Hatch released. That is one way in.", "MOTE", 3.2))

# ---------------------------------------------------------------- pressure plate
func _build_plate() -> void:
	var base := on_ground(20, -8)
	box(Vector3(16.0, 0.4, 14.0), "concrete_aged", base + Vector3(0, -0.1, 0),
		Vector3.ZERO, Veil.Surface.STONE)

	_plate = PressurePlate.new()
	_plate.required_mass = 70.0
	_plate.position = base + Vector3(4.0, 0.2, -3.0)
	add_child(_plate)

	var gate := Gate.new()
	gate.size = Vector3(4.0, 3.6, 0.4)
	gate.open_offset = Vector3(0, 3.7, 0)
	gate.position = base + Vector3(-6.5, 1.9, -6.6)
	add_child(gate)
	_plate.pressed.connect(func() -> void:
		gate.open()
		_flags.plate = true)
	_plate.released.connect(func() -> void: gate.close())

	# The crate is pinned under Ruin rubble; in Memory the rubble does not exist.
	_crate = prop(base + Vector3(-2.0, 1.2, 2.0), Vector3(1.0, 1.0, 1.0),
		"Ballast Crate", 95.0, "wood")
	var ruin_rubble := Node3D.new()
	ruin_rubble.add_child(variant_mesh(ProcAssets.debris_mesh(77, 12, 1.9, 1.2),
		"concrete_aged", Vector3.ZERO, Vector3.ZERO, Veil.Surface.STONE))
	ruin_rubble.add_child(variant_box(Vector3(3.4, 1.6, 3.4), "concrete_aged",
		Vector3(0, 0.9, 0), Vector3.ZERO, Veil.Surface.STONE))
	veil_subject("crate_rubble", base + Vector3(-2.0, 1.0, 2.0), null, ruin_rubble, null, 2.2)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch1_plate"
	pz.title = "Ballast Court"
	pz.hint_subtle = "The plate wants more weight than you carry."
	pz.hint_guided = "There is a crate under that rubble. The rubble is a Ruin-state fact."
	pz.hint_directed = "Shift the rubble pile to Memory, carry the crate onto the plate, then walk through the gate."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_plate.pressed.connect(func() -> void:
		if not pz.is_solved:
			pz.mark_solved())

	scannable(base + Vector3(-6.5, 2.0, -6.6), "Blast Shutter",
		"Rated for pressure, not for time.", Veil.Prop.RIGID, -1, 2.4)
	# Behind the shutter: the hidden alcove.
	hidden_marker(base + Vector3(-6.5, 1.0, -10.5))
	scannable(base + Vector3(-8.0, 1.4, -11.5), "Field Cache",
		"Somebody left a full ration kit and a note that just says 'sorry'.")

	trigger(base + Vector3(0, 2, 6), Vector3(18, 6, 6), func() -> void:
		Hints.request("interact")
		say("Plate needs mass. You are not heavy enough, and I am considerably less so.",
			"MOTE", 4.4))

# ---------------------------------------------------------------- conduit
func _build_conduit() -> void:
	var base := on_ground(0, -26)
	box(Vector3(22.0, 0.5, 16.0), "concrete_aged", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.STONE)

	var src := PowerPoint.new()
	src.point_id = "ch1_src"
	src.is_source = true
	src.position = base + Vector3(-8.0, 0, 4.0)
	add_child(src)
	power.register(src)

	var mid := PowerPoint.new()
	mid.point_id = "ch1_mid"
	mid.position = base + Vector3(0, 0, -1.0)
	add_child(mid)
	power.register(mid)

	var sink := PowerPoint.new()
	sink.point_id = "ch1_sink"
	sink.is_sink = true
	sink.position = base + Vector3(8.0, 0, -5.0)
	add_child(sink)
	power.register(sink)

	# First run conducts in Memory. Second run is dead in every state and must
	# be given the CONDUCTIVE property by hand.
	var c1 := Conduit.new()
	add_child(c1)
	c1.build(src.position + Vector3(0, 1.8, 0), mid.position + Vector3(0, 1.8, 0),
		[Veil.State.MEMORY], manager, true, 0.5)
	var c2 := Conduit.new()
	add_child(c2)
	c2.build(mid.position + Vector3(0, 1.8, 0), sink.position + Vector3(0, 1.8, 0),
		[], manager, true, 0.5)

	power.link("ch1_src", "ch1_mid", Callable(c1, "is_conductive"), true, c1)
	power.link("ch1_mid", "ch1_sink", Callable(c2, "is_conductive"), true, c2)

	# The reference cable you scan to learn CONDUCTIVE - only live in Memory.
	var ref_mem := Node3D.new()
	var rpts := PackedVector3Array()
	for i in 6:
		var t := float(i) / 5.0
		rpts.append(Vector3(-11.0 + t * 5.0, 1.4 - sin(t * PI) * 0.4, 7.0))
	var rrad := PackedFloat32Array()
	for i in 6:
		rrad.append(0.09)
	ref_mem.add_child(variant_mesh(ProcAssets.tube_mesh("ch1ref", rpts, rrad, 6, 0.4),
		ProcAssets.emissive(Color(1.0, 0.85, 0.35), 1.6), Vector3.ZERO, Vector3.ZERO,
		Veil.Surface.METAL, false))
	veil_subject("ref_cable", base + Vector3(-8.5, 0, 7.0), ref_mem, null, null, 3.0)
	var sc := scannable(base + Vector3(-8.5, 1.6, 7.0), "Live Feeder Cable",
		"Still carrying current, in the version of this place that had current.",
		Veil.Prop.CONDUCTIVE, Veil.State.MEMORY, 2.6)
	sc.xp_bonus = 80

	var gate := Gate.new()
	gate.size = Vector3(4.4, 4.0, 0.4)
	gate.open_offset = Vector3(0, 4.1, 0)
	gate.position = base + Vector3(0, 2.1, -9.0)
	add_child(gate)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch1_conduit"
	pz.title = "Dead Run"
	pz.hint_subtle = "One of these two runs will never carry current on its own."
	pz.hint_guided = "Scan something that is conductive, then imprint that property onto the dead run."
	pz.hint_directed = "Shift the feeder cable area to Memory, hold Scan on the cable, walk to the second conduit and press Imprint."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	sink.powered_changed.connect(func(on: bool) -> void:
		if on:
			gate.open()
			_flags.conduit = true
			if not pz.is_solved:
				pz.mark_solved()
				say("Both runs live. The property carried across - that is the whole trick of this device.",
					"MOTE", 5.0)
		else:
			gate.close())

	trigger(base + Vector3(0, 2, 7), Vector3(20, 6, 5), func() -> void:
		player.device.unlock("scan")
		player.device.unlock("imprint")
		Hints.request("scan")
		Hints.request("imprint")
		say_now("Scanner and imprinter online. Record a property from one state, carry it into another.",
			"MOTE", 5.4))

	checkpoint("cp_conduit", base + Vector3(0, 0.4, -12.0), 180.0)
	fragment(1, base + Vector3(9.5, 1.2, 6.0))

# ---------------------------------------------------------------- pinned span
func _build_pin_gap() -> void:
	var base := on_ground(-16, -46)
	box(Vector3(12.0, 0.6, 8.0), "concrete_aged", base + Vector3(0, -0.2, 8.0),
		Vector3.ZERO, Veil.Surface.STONE)
	box(Vector3(12.0, 0.6, 8.0), "concrete_aged", base + Vector3(0, -0.2, -12.0),
		Vector3.ZERO, Veil.Surface.STONE)
	hazard(base + Vector3(0, -8.0, -2.0), Vector3(20, 6, 14), 0.0, "the drop", true)

	# The stepping stones only exist in Memory, and you must be OUTSIDE the
	# field while crossing - which is exactly what pinning is for.
	var mem := Node3D.new()
	for i in 4:
		mem.add_child(variant_box(Vector3(3.0, 0.4, 3.0), "concrete",
			Vector3(sin(float(i) * 1.4) * 2.2, -0.2 + float(i % 2) * 0.3,
				2.0 - float(i) * 3.4), Vector3.ZERO, Veil.Surface.STONE))
	_pin_platform = veil_subject("pin_stones", base + Vector3(0, 0, -2.0),
		mem, null, null, 7.0)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch1_pin"
	pz.title = "Held Ground"
	pz.hint_subtle = "The field follows you. That is not always what you want."
	pz.hint_guided = "You cannot stand on the stones and hold the field on them at the same time."
	pz.hint_directed = "Aim the field over the gap, select Memory, then press Pin. The field stays put while you run across."
	pz.position = base
	add_child(pz)
	pz.register_hints()

	trigger(base + Vector3(0, 2, 9.0), Vector3(14, 6, 5), func() -> void:
		player.device.unlock("pin")
		Hints.request("veil_pin")
		say_now("Pin the field. It will hold that patch of Memory without you standing in it.",
			"MOTE", 5.4))
	trigger(base + Vector3(0, 2, -13.0), Vector3(14, 6, 5), func() -> void:
		_flags.pin = true
		if not pz.is_solved:
			pz.mark_solved())
	checkpoint("cp_pin", base + Vector3(0, 0.5, -14.0), 180.0)
	fragment(2, base + Vector3(5.0, 0.8, -14.5))

# ---------------------------------------------------------------- guardians
func _build_guardian_yard() -> void:
	var base := on_ground(12, -58)
	box(Vector3(30.0, 0.5, 22.0), "concrete_aged", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 8:
		var a := TAU * float(i) / 8.0
		box(Vector3(1.4, 3.2, 1.4), "concrete", base + Vector3(cos(a) * 9.0, 1.6, sin(a) * 7.0))
	for i in 5:
		box(Vector3(4.0, 1.6, 1.2), "metal_rust",
			base + Vector3(rng.randf_range(-11, 11), 0.8, rng.randf_range(-8, 8)),
			Vector3(0, rng.randf_range(0, TAU), 0), Veil.Surface.METAL)

	var g := guardian(base + Vector3(-6, 0.2, 4), [
		base + Vector3(-8, 0.2, 6), base + Vector3(8, 0.2, 5),
		base + Vector3(9, 0.2, -6), base + Vector3(-7, 0.2, -5)])
	var g2 := guardian(base + Vector3(7, 0.2, -7), [
		base + Vector3(7, 0.2, -7), base + Vector3(-9, 0.2, -7)])

	component(base + Vector3(0, 1.0, -9.0))

	scannable(base + Vector3(-11.0, 1.6, 8.0), "Service Unit, dormant",
		"Chassis is fine. Whatever it was told to do last, it is still doing.",
		Veil.Prop.RIGID, -1, 3.0)
	wildlife(base + Vector3(13.0, 0.6, 8.0), "Glass-Moth Cluster",
		"They roost on the shards. The valley is quieter for them in Bloom.")

	trigger(base + Vector3(0, 2, 12.0), Vector3(26, 8, 5), func() -> void:
		player.device.unlock("emp")
		Hints.request("emp")
		Hints.request("guardian")
		say_now("Two service units, both past their service life. Stun them, avoid them, or drop something on them - your call.",
			"MOTE", 6.0))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch1_yard"
	pz.title = "Service Yard"
	pz.hint_subtle = "They see in a cone, and they do not see at all in Memory."
	pz.hint_guided = "Guardians go dormant inside a Memory field. Shift the yard and walk through."
	pz.hint_directed = "Aim the field at a guardian, select Memory and shift - it drops to standby. Or hit it with an EMP pulse."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 2, -12.0), Vector3(26, 8, 5), func() -> void:
		if not pz.is_solved:
			pz.mark_solved())
	checkpoint("cp_yard", base + Vector3(0, 0.4, -13.0), 180.0)

# ---------------------------------------------------------------- relay
func _build_relay() -> void:
	var base := on_ground(0, -80)
	box(Vector3(20.0, 1.0, 20.0), "concrete", base + Vector3(0, -0.3, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	static_mesh(ProcAssets.truss_mesh(18.0, 3.2, 3.2, 9, 0.16), "metal_rust",
		base + Vector3(0, 9.2, 0), Vector3(PI * 0.5, 0, 0), Vector3.ONE, Veil.Surface.METAL)
	decor(ProcAssets.ring_mesh(3.2, 0.22, 26, 8), "metal_dark", base + Vector3(0, 18.4, 0))
	decor(ProcAssets.ring_mesh(2.2, 0.16, 22, 8), "brass",
		base + Vector3(0, 18.4, 0), Vector3(0.5, 0, 0))

	# Climb the tower: handholds appear as a ladder in Memory, roots in Bloom.
	var mem := Node3D.new()
	var ladder := climb_surface(Vector3(1.4, 9.0, 0.4), Vector3(0, 5.0, 1.9))
	mem.add_child(ladder.duplicate())
	ladder.queue_free()
	mem.add_child(variant_box(Vector3(4.0, 0.3, 3.0), "metal", Vector3(0, 9.6, 0.8),
		Vector3.ZERO, Veil.Surface.METAL))
	var bloom := Node3D.new()
	var pts := PackedVector3Array()
	for i in 8:
		var t := float(i) / 7.0
		pts.append(Vector3(sin(t * 4.0) * 1.3, t * 9.6, 2.2 + cos(t * 3.0) * 0.7))
	var radii := PackedFloat32Array()
	for i in 8:
		radii.append(0.42)
	bloom.add_child(variant_mesh(ProcAssets.tube_mesh("ch1relay", pts, radii, 8, 0.3),
		"bark", Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD))
	var bclimb := climb_surface(Vector3(1.8, 9.4, 0.5), Vector3(0, 5.0, 2.4))
	bloom.add_child(bclimb.duplicate())
	bclimb.queue_free()
	bloom.add_child(variant_box(Vector3(4.2, 0.35, 3.2), "bark", Vector3(0, 9.7, 0.8),
		Vector3.ZERO, Veil.Surface.WOOD))
	veil_subject("relay_climb", base, mem, null, bloom, 10.0)

	var console := box(Vector3(1.6, 1.0, 0.8), "metal_dark",
		base + Vector3(0, 10.2, 0.6), Vector3.ZERO, Veil.Surface.METAL)
	decor(ProcAssets.box_mesh(Vector3(1.2, 0.05, 0.5)),
		ProcAssets.emissive(Color(1.0, 0.55, 0.25), 1.4),
		base + Vector3(0, 10.72, 0.85), Vector3(-0.5, 0, 0))

	var it := Interactable.new()
	it.prompt = "Bring the relay online"
	it.hold_time = 1.4
	it.one_shot = true
	it.position = base + Vector3(0, 10.4, 0.6)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 2.4
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(base))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch1_relay"
	pz.title = "Valley Relay"
	pz.hint_subtle = "There is no ladder here any more."
	pz.hint_guided = "The tower had a service ladder once, and the forest grew its own."
	pz.hint_directed = "Field the base of the tower into Memory or Bloom, then press Interact at the handholds to climb."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 11.0, 0.0), Vector3(6, 3, 6), func() -> void:
		if not pz.is_solved:
			pz.mark_solved())

	set_objective("Cross the fissure and reach the valley relay.")

func _finale(base: Vector3) -> void:
	if _relay_powered:
		return
	_relay_powered = true
	_flags.relay = true
	AudioDirector.play("machine_start", -2.0)
	SceneFlow.flash(Color(1.0, 0.9, 0.7, 0.4), 0.7)
	set_objective("Relay online.")
	# Bonus challenge: crossed the valley without a single shard strike.
	if int(GameState.run.get("shard_hits", 0)) <= _shard_hits_at_start:
		GameState.complete_challenge()
		say("Not one shard. I logged it.", "MOTE", 3.0)
	weather.set_intensity(0.15)
	await cinematic(
		[base + Vector3(-14, 14, 16), base + Vector3(6, 20, 6), base + Vector3(0, 26, -18)],
		[base + Vector3(0, 12, 0), base + Vector3(0, 16, 0), base + Vector3(0, 6, -40)],
		9.0,
		[["The relay answers. Somewhere south of here, something answered back.", "MOTE"],
		 ["Three signals. Same tower. Same second. One from a version of this valley that has not happened yet.", "MOTE"],
		 ["Whatever the Fracture did, it is still doing it. Let's go and see.", "MOTE"]])
	finish()

# ---------------------------------------------------------------- chapter hooks
func on_begin(mode: String) -> void:
	_shard_hits_at_start = int(GameState.run.get("shard_hits", 0))
	if mode == "checkpoint" and _device_taken:
		player.device.unlock_all()
	Hints.request("move")
	Hints.request("look")
	if mode != "checkpoint":
		say("Systems check. You are upright, the skiff is not, and the sky is still coming down.",
			"MOTE", 5.2)
		say("There is a device in the wreck cradle. Take it before the rain finds you.",
			"MOTE", 5.0)
		set_objective("Recover the Veilforge Device from the skiff cradle.")
	weather.set_intensity(0.85)

func ambience_profiles() -> Array:
	return ["wind", "rain_glass", "wind_high"]

func ambience_volumes() -> Array:
	return [0.42, 0.32, 0.14]

func on_state_changed(s: int) -> void:
	# Glass rain only falls in the Ruin present; Memory has clean rain, Bloom is calm.
	weather.set_intensity([0.25, 0.9, 0.35][clampi(s, 0, 2)])
	AudioDirector.fade_ambience(1, [0.08, 0.34, 0.12][clampi(s, 0, 2)], 1.4)

func save_flags() -> Dictionary:
	var f := _flags.duplicate()
	f["device"] = _device_taken
	return f

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	if bool(flags.get("device", false)):
		_device_taken = true
		player.device.unlock_all()
	if bool(_flags.get("door", false)) and _door_gate:
		_door_gate.open()

func fragment_text(idx: int) -> String:
	match idx:
		0: return "Rainfall log, entry 04. 'Third night of it. The shards are not ice and they are not glass, they are the sky's idea of both. Two of the crew have started sleeping under the skiff. I have started sleeping at all, which is new.'"
		1: return "A single bootprint pressed into set resin, with a name scratched beside it: SURVEYOR B. HALLOW. Underneath, in a different hand: 'she went south. she said the tower was singing in three keys.'"
		2: return "An unsent letter. 'If you are reading this in the valley then the relay is down and I am not there to fix it. Do not trust the bridge. Trust what the bridge used to be. That sentence will make sense to you in about an hour.'"
	return ""
