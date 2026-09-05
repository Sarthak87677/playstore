extends ChapterBase
## CHAPTER 2 - THE WALKING FOREST
## A mobile timber mill that never finished walking, and a forest that grew
## through it while it stood still. Teaches carrying mass, the GROWING and
## HOLLOW properties, riding state-driven machinery, and vertical traversal.

var _noise := FastNoiseLite.new()
var _pads: Array[Vector4] = []
var _flags := {"gate": false, "lift": false, "roots": false, "spine": false,
	"carriage": false, "lock": false, "relay": false}

var _mill_gate: VeilSubject
var _lift_plate: PressurePlate
var _lift: Gate
var _carriage: MovingPlatform
var _lock: ResonanceLock
var _spine_sink: PowerPoint
var _relay_done := false
var _touched_floor_after_lift := false
var _lift_passed := false

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	var roll := n.get_noise_2d(x * 0.5, z * 0.5) * 7.0 + n.get_noise_2d(x * 1.7, z * 1.7) * 2.2
	var ridge := pow(clampf(absf(x) / 90.0, 0.0, 1.4), 2.0) * 26.0
	var y := roll + ridge + 4.0

	# A stream gully running east-west across the approach.
	var g := clampf(1.0 - absf(z - 74.0) / 10.0, 0.0, 1.0)
	y -= smoothstep(0.0, 1.0, g) * 5.0

	for pad in _pads:
		var d := Vector2(x - pad.x, z - pad.y).length()
		var w := float(pad.z)
		if d < w:
			y = lerpf(y, float(pad.w), smoothstep(w, w * 0.45, d))
	return y

func build_world() -> void:
	_noise.seed = 2202
	_noise.frequency = 0.011
	_noise.fractal_octaves = 4
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	_pads = [
		Vector4(0, 100, 13, 6.0),     # trailhead
		Vector4(0, 60, 13, 5.0),      # mill gate
		Vector4(-22, 30, 13, 4.0),    # counterweight yard
		Vector4(18, 10, 12, 4.5),     # root ladder base
		Vector4(0, -10, 15, 4.0),     # spine terrace
		Vector4(-12, -32, 13, 4.0),   # carriage bay
		Vector4(0, -56, 14, 4.0),     # canopy lock
		Vector4(0, -78, 15, 5.0),     # relay footing
	]

	SceneFlow.report(0.14, "Growing the forest floor")
	build_terrain(Vector2(300, 300), 198, Callable(self, "_h"), "forest")
	spawn_position = on_ground(0, 100, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.28, "Raising the canopy")
	_build_forest()
	await get_tree().process_frame

	SceneFlow.report(0.42, "Mill gate")
	_build_trailhead()
	_build_gate()
	await get_tree().process_frame

	SceneFlow.report(0.54, "Counterweight yard")
	_build_lift()
	await get_tree().process_frame

	SceneFlow.report(0.62, "Root ladder")
	_build_roots()
	await get_tree().process_frame

	SceneFlow.report(0.72, "Mill spine")
	_build_spine()
	await get_tree().process_frame

	SceneFlow.report(0.80, "Saw carriage")
	_build_carriage()
	await get_tree().process_frame

	SceneFlow.report(0.88, "Canopy")
	_build_lock()
	_build_relay()
	_build_undergrowth()
	await get_tree().process_frame

# ---------------------------------------------------------------- forest
func _build_forest() -> void:
	var excl: Array = []
	for p in _pads:
		excl.append(Rect2(p.x - p.z, p.y - p.z, p.z * 2.0, p.z * 2.0))
	for i in 150:
		var x := rng.randf_range(-140, 140)
		var z := rng.randf_range(-140, 140)
		var skip := false
		for r in excl:
			if (r as Rect2).grow(4.0).has_point(Vector2(x, z)):
				skip = true
				break
		if skip or terrain.slope_at(x, z) > 30.0:
			continue
		var h := rng.randf_range(9.0, 26.0)
		tree(on_ground(x, z, -0.4), h, h * 0.055, 4000 + i, "bark",
			"foliage" if rng.randf() < 0.7 else "foliage_dry", null,
			rng.randf_range(0.8, 1.3))
	# fallen trunks and stumps
	for i in 40:
		var x := rng.randf_range(-120, 120)
		var z := rng.randf_range(-120, 120)
		if terrain.slope_at(x, z) > 26.0:
			continue
		static_mesh(ProcAssets.trunk_mesh(5000 + i % 12, rng.randf_range(5.0, 13.0),
			rng.randf_range(0.4, 0.8), 0.1, 5, 7, 0.7), "bark",
			on_ground(x, z, 0.6),
			Vector3(PI * 0.5 + rng.randf_range(-0.2, 0.2), rng.randf_range(0, TAU), 0),
			Vector3.ONE, Veil.Surface.WOOD, Veil.L_WORLD, true, null, true)
	for i in 70:
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		rock(on_ground(x, z, -0.3), rng.randf_range(0.5, 2.4), 900 + i, "rock_dark")

func _build_undergrowth() -> void:
	var excl: Array = []
	for p in _pads:
		excl.append(Rect2(p.x - p.z * 0.8, p.y - p.z * 0.8, p.z * 1.6, p.z * 1.6))
	vegetation.scatter(ProcAssets.blade_cluster_mesh(11, 21, 0.85, 0.07), 6200,
		Rect2(-140, -140, 280, 280), veg_sampler(32.0, excl),
		Color(0.16, 0.26, 0.12), Color(0.34, 0.46, 0.18), Vector2(0.7, 2.0), 0.22, 21, 1.3)
	vegetation.scatter(ProcAssets.canopy_mesh(31, 0.9, 3), 900,
		Rect2(-140, -140, 280, 280), veg_sampler(24.0, excl),
		Color(0.14, 0.30, 0.12), Color(0.28, 0.52, 0.20), Vector2(0.6, 1.8), 0.10, 22, 1.6)
	vegetation.scatter(ProcAssets.blade_cluster_mesh(12, 12, 1.9, 0.10), 700,
		Rect2(-140, -140, 280, 280), veg_sampler(20.0, excl),
		Color(0.22, 0.34, 0.14), Color(0.46, 0.56, 0.22), Vector2(0.8, 1.6), 0.34, 23, 2.2)

# ---------------------------------------------------------------- trailhead
func _build_trailhead() -> void:
	var base := on_ground(0, 100)
	box(Vector3(14.0, 0.4, 10.0), "wood", base + Vector3(0, -0.1, 0),
		Vector3.ZERO, Veil.Surface.WOOD)
	static_mesh(ProcAssets.room_shell(Vector3(6.0, 3.2, 5.0), 0.3, 2.2, 2.6, true, 0),
		"wood", base + Vector3(-5.0, 1.8, -2.0), Vector3(0, 0.2, 0), Vector3.ONE,
		Veil.Surface.WOOD)
	scannable(base + Vector3(-5.0, 2.0, -2.0), "Ranger Hut",
		"A duty board, three mugs, and a boot-scraper worn concave.")
	scannable(base + Vector3(4.0, 1.4, 1.0), "Timber Marker",
		"Paint code for a felling plan that was never carried out.",
		Veil.Prop.RIGID, -1, 2.2)
	checkpoint("cp_trailhead", base + Vector3(0, 0.2, -4.0), 180.0)

	trigger(base + Vector3(0, 2, -10), Vector3(26, 8, 6), func() -> void:
		say("The mill was built to walk. It got about four kilometres and then the Fracture happened.",
			"MOTE", 5.4)
		say("It has been standing here long enough for the forest to consider it furniture.",
			"MOTE", 4.8))

# ---------------------------------------------------------------- mill gate
func _build_gate() -> void:
	var base := on_ground(0, 60)
	box(Vector3(26.0, 0.5, 8.0), "metal_rust", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	# Gatehouse walls either side of the opening.
	box(Vector3(8.0, 7.0, 3.0), "metal_rust", base + Vector3(-8.5, 3.5, 0))
	box(Vector3(8.0, 7.0, 3.0), "metal_rust", base + Vector3(8.5, 3.5, 0))
	box(Vector3(26.0, 1.6, 3.0), "metal_rust", base + Vector3(0, 7.8, 0))

	# MEMORY: an intact shutter, closed and locked - no way through.
	var mem := variant_box(Vector3(9.0, 7.0, 0.6), "metal",
		Vector3(0, 3.5, 0), Vector3.ZERO, Veil.Surface.METAL)
	# RUIN: the shutter has jammed half-down; still blocked.
	var ruin := variant_group([
		variant_box(Vector3(9.0, 4.6, 0.6), "metal_rust",
			Vector3(0, 4.7, 0), Vector3.ZERO, Veil.Surface.METAL),
		variant_mesh(ProcAssets.debris_mesh(220, 14, 2.4, 1.1), "metal_rust",
			Vector3(0, 0.4, 0), Vector3.ZERO, Veil.Surface.METAL, false)])
	# BLOOM: a root has torn the shutter open. This is the way through.
	var pts := PackedVector3Array()
	for i in 8:
		var t := float(i) / 7.0
		pts.append(Vector3(lerpf(-9.0, 9.0, t), 1.4 + sin(t * PI) * 4.2, sin(t * 3.0) * 1.1))
	var radii := PackedFloat32Array()
	for i in 8:
		radii.append(0.85)
	var bloom := variant_group([
		variant_mesh(ProcAssets.tube_mesh("ch2gate", pts, radii, 9, 0.3), "bark",
			Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD),
		variant_box(Vector3(3.4, 3.6, 0.5), "metal_rust",
			Vector3(-6.4, 5.4, 0), Vector3(0, 0, 0.5), Veil.Surface.METAL),
		variant_box(Vector3(3.4, 3.6, 0.5), "metal_rust",
			Vector3(6.4, 5.4, 0), Vector3(0, 0, -0.5), Veil.Surface.METAL)])

	_mill_gate = veil_subject("mill_gate", base, mem, ruin, bloom, 11.0)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch2_gate"
	pz.title = "Mill Gate"
	pz.hint_subtle = "Nothing you do to a shutter will open a shutter."
	pz.hint_guided = "Something else already opened it. Not now, and not before - later."
	pz.hint_directed = "Field the gate and shift it to Bloom. The root that grew through it made the doorway."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_mill_gate.state_applied.connect(func(s: int) -> void:
		if s == Veil.State.BLOOM and not pz.is_solved:
			_flags.gate = true
			pz.mark_solved()
			say("There it is. The forest did the demolition for us.", "MOTE", 4.0))

	scannable(base + Vector3(-11.0, 2.0, 2.0), "Gate Servo",
		"Rated for ten thousand cycles. It managed four hundred.",
		Veil.Prop.RIGID, -1, 2.4)
	fragment(0, base + Vector3(-11.5, 1.0, -4.0))

# ---------------------------------------------------------------- counterweight
func _build_lift() -> void:
	var base := on_ground(-22, 30)
	box(Vector3(20.0, 0.5, 18.0), "metal_rust", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	static_mesh(ProcAssets.truss_mesh(14.0, 3.0, 3.0, 7, 0.14), "metal_rust",
		base + Vector3(0, 7.2, -6.0), Vector3(PI * 0.5, 0, 0), Vector3.ONE, Veil.Surface.METAL)

	_lift_plate = PressurePlate.new()
	_lift_plate.required_mass = 150.0
	_lift_plate.plate_size = Vector3(2.6, 0.18, 2.6)
	_lift_plate.position = base + Vector3(4.0, 0.2, 3.0)
	add_child(_lift_plate)

	_lift = Gate.new()
	_lift.size = Vector3(4.0, 0.4, 4.0)
	_lift.open_offset = Vector3(0, 9.0, 0)
	_lift.open_time = 3.0
	_lift.material_name = "metal"
	_lift.position = base + Vector3(-4.0, 0.4, -5.0)
	add_child(_lift)
	_lift_plate.pressed.connect(func() -> void:
		_lift.open()
		_flags.lift = true)
	_lift_plate.released.connect(func() -> void: _lift.close())

	# A milled beam that is far too heavy - until you hollow it out.
	var beam := prop(base + Vector3(-1.0, 1.4, 6.0), Vector3(0.9, 0.9, 4.2),
		"Mill Beam", 220.0, "wood")
	beam.imprint.accepted = [Veil.Prop.HOLLOW, Veil.Prop.RIGID, Veil.Prop.BUOYANT]
	beam.set_meta("surface", Veil.Surface.WOOD)

	# The reference: a hollow standing trunk, only hollow in Bloom.
	var hollow_bloom := variant_mesh(
		ProcAssets.trunk_mesh(611, 8.0, 1.1, 0.06, 6, 9, 0.7), "bark",
		Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD)
	veil_subject("hollow_trunk", base + Vector3(8.0, 0, -2.0), null, null, hollow_bloom, 4.0)
	var sc := scannable(base + Vector3(8.0, 2.2, -2.0), "Hollowed Bole",
		"Something large lived in here and left tidily.",
		Veil.Prop.HOLLOW, Veil.State.BLOOM, 3.0)
	sc.xp_bonus = 80

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch2_lift"
	pz.title = "Counterweight"
	pz.hint_subtle = "The beam is the right size and the wrong weight."
	pz.hint_guided = "Find something hollow, and make the beam hollow too."
	pz.hint_directed = "Shift the standing trunk to Bloom, scan it for Hollow, imprint that onto the beam, then carry it onto the plate."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_lift_plate.pressed.connect(func() -> void:
		if not pz.is_solved:
			pz.mark_solved()
			say("Beam holds. Platform is yours while the weight stays put.", "MOTE", 4.2))

	trigger(base + Vector3(-4.0, 11.0, -5.0), Vector3(6, 3, 6), func() -> void:
		_lift_passed = true
		say("From here the floor is optional. Try to keep it that way.", "MOTE", 4.0))
	checkpoint("cp_lift", base + Vector3(-4.0, 9.4, -5.0), 180.0)

# ---------------------------------------------------------------- root ladder
func _build_roots() -> void:
	var base := on_ground(18, 10)
	box(Vector3(16.0, 0.5, 14.0), "metal_rust", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	box(Vector3(3.0, 12.0, 3.0), "concrete_aged", base + Vector3(6.0, 6.0, -4.0))
	box(Vector3(7.0, 0.4, 5.0), "metal", base + Vector3(6.0, 12.2, -4.0),
		Vector3.ZERO, Veil.Surface.METAL)

	# A stunted vine. Imprinting GROWING makes it reach the platform above.
	var stub := MeshInstance3D.new()
	var spts := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.2, 1.4, -0.3),
		Vector3(-0.1, 2.6, -0.5)])
	var sradii := PackedFloat32Array([0.34, 0.28, 0.2])
	stub.mesh = ProcAssets.tube_mesh("ch2stub", spts, sradii, 8, 0.4)
	stub.material_override = ProcAssets.mat("bark")
	stub.position = base + Vector3(3.0, 0.2, -1.0)
	add_child(stub)

	var im := Imprintable.new()
	im.label = "Stunted Vine"
	im.accepted = [Veil.Prop.GROWING]
	im.position = base + Vector3(3.0, 1.2, -1.0)
	add_child(im)

	var grown := Node3D.new()
	grown.visible = false
	add_child(grown)
	var gpts := PackedVector3Array()
	for i in 10:
		var t := float(i) / 9.0
		gpts.append(base + Vector3(3.0 + sin(t * 4.0) * 1.6, 0.2 + t * 12.4,
			-1.0 - t * 3.2 + cos(t * 3.0) * 0.8))
	var gradii := PackedFloat32Array()
	for i in 10:
		gradii.append(lerpf(0.42, 0.24, float(i) / 9.0))
	var gm := MeshInstance3D.new()
	gm.mesh = ProcAssets.tube_mesh("ch2grown", gpts, gradii, 9, 0.3)
	gm.material_override = ProcAssets.mat("bark")
	grown.add_child(gm)
	var gclimb := climb_surface(Vector3(1.8, 12.4, 0.6),
		base + Vector3(3.4, 6.4, -2.6), Vector3(0, 0.3, 0), grown)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch2_roots"
	pz.title = "Stunted Vine"
	pz.hint_subtle = "It stopped growing. It did not stop wanting to."
	pz.hint_guided = "Somewhere nearby something is still extending toward an anchor."
	pz.hint_directed = "Scan a Bloom-state root for Growing, then imprint it onto the stunted vine at the base of the tower."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	im.imprinted.connect(func(_p: int) -> void:
		stub.visible = false
		grown.visible = true
		AudioDirector.play_3d("machine_start", get_tree().current_scene,
			grown.global_position, -8.0, 1.4)
		_flags.roots = true
		if not pz.is_solved:
			pz.mark_solved()
			say("It found the anchor. Climb before it decides it is finished.", "MOTE", 4.4))

	# The Growing reference lives in the Bloom canopy nearby.
	var vine_bloom := variant_mesh(
		ProcAssets.tube_mesh("ch2ref", PackedVector3Array([
			Vector3(-3, 0, 0), Vector3(-1, 3, 1), Vector3(1, 6, 0), Vector3(3, 8, -1)]),
			PackedFloat32Array([0.4, 0.34, 0.28, 0.2]), 8, 0.3), "bark",
		Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD)
	veil_subject("ref_vine", base + Vector3(-6.0, 0, 4.0), null, null, vine_bloom, 4.0)
	var sc := scannable(base + Vector3(-6.0, 3.0, 4.0), "Climbing Liana",
		"Extends about a metre a week toward anything that will take its weight.",
		Veil.Prop.GROWING, Veil.State.BLOOM, 3.2)
	sc.xp_bonus = 80
	hidden_marker(base + Vector3(6.0, 12.8, -4.0))
	fragment(1, base + Vector3(6.0, 13.0, -6.0))

# ---------------------------------------------------------------- mill spine
func _build_spine() -> void:
	var base := on_ground(0, -10)
	box(Vector3(30.0, 0.6, 24.0), "metal_rust", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	# The spine itself: a huge articulated girder running the length of the mill.
	for i in 5:
		static_mesh(ProcAssets.truss_mesh(12.0, 2.6, 2.6, 6, 0.15), "metal_rust",
			base + Vector3(0, 9.0 + sin(float(i) * 0.7) * 0.6, -14.0 + float(i) * 7.0),
			Vector3(0, 0, 0), Vector3.ONE, Veil.Surface.METAL)
	for i in 4:
		box(Vector3(1.6, 9.0, 1.6), "metal_dark",
			base + Vector3(-9.0 + float(i % 2) * 18.0, 4.5, -10.0 + float(i / 2) * 16.0))

	var src := PowerPoint.new()
	src.point_id = "ch2_src"
	src.is_source = true
	src.position = base + Vector3(-11.0, 0, 8.0)
	add_child(src)
	power.register(src)

	var j1 := PowerPoint.new()
	j1.point_id = "ch2_j1"
	j1.position = base + Vector3(-1.0, 0, 3.0)
	add_child(j1)
	power.register(j1)

	var j2 := PowerPoint.new()
	j2.point_id = "ch2_j2"
	j2.position = base + Vector3(7.0, 0, -3.0)
	add_child(j2)
	power.register(j2)

	_spine_sink = PowerPoint.new()
	_spine_sink.point_id = "ch2_spine"
	_spine_sink.is_sink = true
	_spine_sink.position = base + Vector3(11.0, 0, -9.0)
	add_child(_spine_sink)
	power.register(_spine_sink)

	# Three different reasons a run does or does not conduct.
	var c1 := Conduit.new(); add_child(c1)
	c1.build(src.position + Vector3(0, 1.8, 0), j1.position + Vector3(0, 1.8, 0),
		[Veil.State.MEMORY], manager, false, 0.6)
	var c2 := Conduit.new(); add_child(c2)
	c2.build(j1.position + Vector3(0, 1.8, 0), j2.position + Vector3(0, 1.8, 0),
		[], manager, true, 0.6)
	var c3 := Conduit.new(); add_child(c3)
	c3.build(j2.position + Vector3(0, 1.8, 0), _spine_sink.position + Vector3(0, 1.8, 0),
		[Veil.State.BLOOM], manager, false, 0.6)
	c3.conductive_states = [Veil.State.BLOOM]

	power.link("ch2_src", "ch2_j1", Callable(c1, "is_conductive"), true, c1)
	power.link("ch2_j1", "ch2_j2", Callable(c2, "is_conductive"), true, c2)
	power.link("ch2_j2", "ch2_spine", Callable(c3, "is_conductive"), true, c3)

	var sc := scannable(base + Vector3(-13.0, 1.6, 10.0), "Feeder Bus",
		"Copper, and still bright where the insulation held.",
		Veil.Prop.CONDUCTIVE, Veil.State.MEMORY, 2.6)
	sc.xp_bonus = 70

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch2_spine"
	pz.title = "Mill Spine"
	pz.hint_subtle = "Three runs, and no single state lights all three."
	pz.hint_guided = "The first wants Memory, the last wants Bloom, and the middle wants a property."
	pz.hint_directed = "Pin a Memory field on the first run, imprint Conductive on the middle run, then shift the far end to Bloom so the vine carries the last leg."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_spine_sink.powered_changed.connect(func(on: bool) -> void:
		if on and not pz.is_solved:
			_flags.spine = true
			pz.mark_solved()
			say("Spine is live. The carriage will run now - if you can make it run.",
				"MOTE", 4.6))

	checkpoint("cp_spine", base + Vector3(0, 0.4, -12.0), 180.0)
	scannable(base + Vector3(9.0, 2.4, 6.0), "Walking Leg Actuator",
		"Six of these lifted four hundred tonnes, once a minute, for nine years.",
		Veil.Prop.RIGID, -1, 3.0)
	component(base + Vector3(-13.0, 1.0, -12.0))

# ---------------------------------------------------------------- saw carriage
func _build_carriage() -> void:
	var base := on_ground(-12, -32)
	box(Vector3(24.0, 0.5, 16.0), "metal_rust", base + Vector3(0, -0.15, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	for sx in [-9.0, 9.0]:
		box(Vector3(0.5, 14.0, 0.5), "metal_dark", base + Vector3(sx, 7.0, -5.0))
		box(Vector3(0.5, 14.0, 0.5), "metal_dark", base + Vector3(sx, 7.0, 5.0))

	_carriage = MovingPlatform.new()
	_carriage.points = [base + Vector3(0, 1.0, 5.0), base + Vector3(0, 13.4, -5.0)]
	_carriage.speed = 2.6
	_carriage.wait_time = 2.2
	_carriage.size = Vector3(5.0, 0.35, 4.0)
	_carriage.loop_mode = false
	_carriage.auto_run = false
	add_child(_carriage)

	# The carriage only runs where the mill still has a working track: Memory.
	var track_mem := variant_group([
		variant_box(Vector3(0.4, 14.0, 0.4), "metal", Vector3(-9.0, 7.0, 0), Vector3(0.6, 0, 0),
			Veil.Surface.METAL),
		variant_box(Vector3(0.4, 14.0, 0.4), "metal", Vector3(9.0, 7.0, 0), Vector3(0.6, 0, 0),
			Veil.Surface.METAL)])
	var track := veil_subject("carriage_track", base + Vector3(0, 0, 0),
		track_mem, null, null, 12.0)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch2_carriage"
	pz.title = "Saw Carriage"
	pz.hint_subtle = "There is a track here, or there was."
	pz.hint_guided = "The carriage needs both power and a rail that still exists."
	pz.hint_directed = "With the spine live, pin a Memory field on the carriage bay so the rails exist, then ride the carriage up."
	pz.position = base
	add_child(pz)
	pz.register_hints()

	var check := func() -> void:
		var live: bool = power.is_powered("ch2_spine")
		var railed := track.current_state == Veil.State.MEMORY
		if live and railed:
			if not _carriage.running:
				_carriage.start()
				AudioDirector.play_3d("machine_start", get_tree().current_scene,
					base + Vector3(0, 4, 0), -3.0)
				_flags.carriage = true
				if not pz.is_solved:
					pz.mark_solved()
		else:
			_carriage.stop()
	track.state_applied.connect(func(_s: int) -> void: check.call())
	power.network_changed.connect(func() -> void: check.call())

	guardian(base + Vector3(8.0, 0.4, 6.0), [
		base + Vector3(8, 0.4, 6), base + Vector3(-8, 0.4, 6),
		base + Vector3(-8, 0.4, -4)])
	scannable(base + Vector3(-10.0, 1.6, 6.0), "Blade Housing",
		"Two metres of tooth, folded away and never asked to work again.",
		Veil.Prop.RIGID, -1, 2.6)
	wildlife(base + Vector3(11.0, 1.0, -6.0), "Bark-Weaver Colony",
		"They repair the mill faster than the mill decays. Nobody asked them to.")
	checkpoint("cp_carriage", base + Vector3(0, 13.8, -5.0), 180.0)

# ---------------------------------------------------------------- canopy lock
func _build_lock() -> void:
	var base := on_ground(0, -56)
	base.y += 13.0
	# A canopy deck the carriage delivers you onto.
	box(Vector3(22.0, 0.5, 18.0), "wood", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.WOOD)
	for i in 6:
		var a := TAU * float(i) / 6.0
		box(Vector3(0.6, 13.0, 0.6), "bark",
			base + Vector3(cos(a) * 9.0, -6.8, sin(a) * 7.0), Vector3.ZERO, Veil.Surface.WOOD)

	_lock = ResonanceLock.new()
	_lock.position = base + Vector3(0, 0.2, 0)
	add_child(_lock)

	var plinths: Array = []
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		var p := base + Vector3(cos(a) * 5.5, 0.2, sin(a) * 5.5)
		box(Vector3(1.2, 1.0, 1.2), "metal_dark", p + Vector3(0, 0.5, 0),
			Vector3.ZERO, Veil.Surface.METAL)
		var im := Imprintable.new()
		im.label = ["Rigid Socket", "Growth Socket", "Light Socket"][i]
		im.accepted = [[Veil.Prop.RIGID], [Veil.Prop.GROWING], [Veil.Prop.LUMINOUS]][i]
		im.hold_seconds = 90.0
		im.position = p + Vector3(0, 1.1, 0)
		add_child(im)
		plinths.append(im)
		var want: int = [Veil.Prop.RIGID, Veil.Prop.GROWING, Veil.Prop.LUMINOUS][i]
		_lock.add_condition(func() -> bool: return im.current == want,
			Veil.prop_name(want))

	# A luminous fungus provides the third property, in Bloom only.
	var glow := variant_mesh(ProcAssets.canopy_mesh(717, 1.4, 4),
		ProcAssets.emissive(Color(0.55, 1.0, 0.75), 1.4), Vector3.ZERO, Vector3.ZERO,
		Veil.Surface.FOLIAGE, false)
	veil_subject("glow_fungus", base + Vector3(-9.0, 0.6, 6.0), null, null, glow, 3.0)
	var sc := scannable(base + Vector3(-9.0, 1.2, 6.0), "Lantern Bracket Fungus",
		"Bright enough to read by. It is reading you back, in its way.",
		Veil.Prop.LUMINOUS, Veil.State.BLOOM, 3.0)
	sc.xp_bonus = 90

	_lock.hint_subtle = "Three sockets, three different appetites."
	_lock.hint_guided = "Each socket takes one property, and they must all be held at once."
	_lock.hint_directed = "Record Rigid, Growing and Luminous, then imprint one into each socket before the first lapses."
	_lock.register_hints()
	_lock.solved.connect(func(_p: bool) -> void:
		_flags.lock = true
		say("Three tones held. The canopy stair is open.", "MOTE", 4.0))
	fragment(2, base + Vector3(9.0, 0.8, -6.0))
	checkpoint("cp_lock", base + Vector3(0, 0.4, 7.0), 180.0)

# ---------------------------------------------------------------- relay
func _build_relay() -> void:
	var base := on_ground(0, -78)
	base.y += 16.0
	box(Vector3(16.0, 0.6, 16.0), "wood", base + Vector3(0, -0.3, 0),
		Vector3.ZERO, Veil.Surface.WOOD)
	for i in 4:
		box(Vector3(0.7, 16.0, 0.7), "bark",
			base + Vector3(-6.0 + float(i % 2) * 12.0, -8.3, -6.0 + float(i / 2) * 12.0),
			Vector3.ZERO, Veil.Surface.WOOD)
	static_mesh(ProcAssets.truss_mesh(10.0, 2.4, 2.4, 5, 0.13), "metal_rust",
		base + Vector3(0, 5.2, 0), Vector3(PI * 0.5, 0, 0), Vector3.ONE, Veil.Surface.METAL)
	decor(ProcAssets.ring_mesh(2.6, 0.2, 24, 8), "metal_dark", base + Vector3(0, 10.6, 0))

	# The stair up to the relay only exists once the lock is satisfied.
	var stair := Gate.new()
	stair.size = Vector3(3.0, 0.4, 10.0)
	stair.open_offset = Vector3(0, 0, 0)
	stair.starts_open = false
	stair.position = base + Vector3(0, 0.4, 10.0)
	add_child(stair)
	var stair_body := box(Vector3(3.2, 0.4, 12.0), "wood",
		base + Vector3(0, -3.0, 13.0), Vector3(-0.42, 0, 0), Veil.Surface.WOOD)
	stair_body.visible = false
	stair_body.collision_layer = 0
	_lock.solved.connect(func(_p: bool) -> void:
		stair_body.visible = true
		stair_body.collision_layer = Veil.L_WORLD
		AudioDirector.play_3d("door", get_tree().current_scene,
			stair_body.global_position, -4.0))

	var console := box(Vector3(1.6, 1.0, 0.8), "metal_dark",
		base + Vector3(0, 0.7, -2.0), Vector3.ZERO, Veil.Surface.METAL)
	var it := Interactable.new()
	it.prompt = "Start the mill and bring the canopy relay online"
	it.hold_time = 1.5
	it.one_shot = true
	it.position = base + Vector3(0, 1.1, -2.0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 2.6
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(base))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch2_relay"
	pz.title = "Canopy Relay"
	pz.hint_subtle = "The stair is not built yet."
	pz.hint_guided = "The resonance lock on the deck below opens the way up."
	pz.hint_directed = "Fill all three sockets on the canopy deck, then take the stair that appears."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 1.6, 0), Vector3(8, 4, 8), func() -> void:
		if not pz.is_solved:
			pz.mark_solved())

func _finale(base: Vector3) -> void:
	if _relay_done:
		return
	_relay_done = true
	_flags.relay = true
	AudioDirector.play("machine_start", -1.0)
	SceneFlow.flash(Color(0.85, 1.0, 0.75, 0.32), 0.8)
	set_objective("Canopy relay online.")
	if _lift_passed and not _touched_floor_after_lift:
		GameState.complete_challenge()
		say("Not one bootprint on the floor since the lift. Noted.", "MOTE", 3.4)
	await cinematic(
		[base + Vector3(-20, 8, 24), base + Vector3(4, 16, 8), base + Vector3(0, 30, -26)],
		[base + Vector3(0, 4, 0), base + Vector3(0, 8, -6), base + Vector3(0, -6, -40)],
		9.5,
		[["The mill is taking a step. Its first in eleven years.", "MOTE"],
		 ["The relay says the same three signals. Closer now, and one of them is under water.",
			"MOTE"],
		 ["Nacre City. Nine floors down and still drawing power. We go there next.", "MOTE"]])
	finish()

# ---------------------------------------------------------------- hooks
func on_begin(mode: String) -> void:
	player.device.unlock_all()
	if mode != "checkpoint":
		say("Trailhead. The mill is two kilometres north and it has not moved since the Fracture.",
			"MOTE", 5.0)
	set_objective(String(info.objective))
	weather.set_intensity(0.5)
	player.footstep.connect(func(_s: int) -> void:
		# The bonus challenge: stay off the forest floor after the second lift.
		if _lift_passed and not _relay_done and player.global_position.y < ground_y(
				player.global_position.x, player.global_position.z) + 1.6:
			_touched_floor_after_lift = true)

func ambience_profiles() -> Array:
	return ["forest", "wind", "machine"]

func ambience_volumes() -> Array:
	return [0.40, 0.22, 0.10]

func on_state_changed(s: int) -> void:
	weather.set_intensity([0.30, 0.5, 0.85][clampi(s, 0, 2)])
	AudioDirector.fade_ambience(0, [0.22, 0.34, 0.55][clampi(s, 0, 2)], 1.4)
	AudioDirector.fade_ambience(2, [0.24, 0.12, 0.04][clampi(s, 0, 2)], 1.4)

func save_flags() -> Dictionary:
	return _flags.duplicate()

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	if bool(_flags.get("lift", false)) and _lift:
		_lift.open()

func shot_spots() -> Array:
	return [
		{"name": "approach", "pos": on_ground(20, 84, 10.0), "look": on_ground(0, 56, 8.0)},
		{"name": "spine", "pos": on_ground(-24, 6, 14.0), "look": on_ground(0, -12, 8.0)},
		{"name": "canopy", "pos": on_ground(20, -44, 26.0), "look": on_ground(0, -62, 18.0)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "Sawyer's tally board, last column unfinished. 'DAY 3,111 - 41 stems. DAY 3,112 - 40 stems. DAY 3,113 -' and then nothing, and then, in pencil, much later and much shakier: 'the trees are walking now too. fair is fair.'"
		1: return "A brass ring, root-bound into a branch that has grown around and through it. Engraved inside: FOR B.H., WHO WENT SOUTH. The branch has held it for a decade and shows no sign of letting go."
		2: return "A canopy survey pin with a paper tag: 'Growth rate up 400% since the event. Not a mutation. The trees are the same trees. They are simply in more of a hurry, and I think they are in a hurry toward something.'"
	return ""
