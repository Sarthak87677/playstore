extends ChapterBase
## CHAPTER 6 - TEMPEST ARCHIPELAGO
## Four islands, one crossing. Every link between them exists in a different
## reality, the sea level moves with the storm, and lightning is a real threat
## that the bonus challenge asks you to avoid entirely.

var _noise := FastNoiseLite.new()
var _flags := {"causeway": false, "lighthouse": false, "bridge": false,
	"cable": false, "shelf": false, "eye": false}

var _sea: WaterVolume
var _storm := 0.0
var _storm_cycle := 62.0
var _struck := false
var _eye_done := false
var _lighthouse_lit := false
var _links: Array = []

const ISLANDS := [
	Vector3(0, 0, 96),      # landfall
	Vector3(-52, 0, 34),    # lighthouse island
	Vector3(46, 0, -14),    # cable station
	Vector3(-30, 0, -66),   # shelf island
	Vector3(0, 0, -116),    # storm eye
]

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	# Sea floor, with an island cone raised at each anchor point.
	var y := -14.0 + n.get_noise_2d(x * 0.25, z * 0.25) * 3.0
	for i in ISLANDS.size():
		var c: Vector3 = ISLANDS[i]
		var d := Vector2(x - c.x, z - c.z).length()
		var r: float = [30.0, 26.0, 28.0, 26.0, 32.0][i]
		if d < r:
			var k := smoothstep(r, 0.0, d)
			var peak: float = [9.0, 15.0, 11.0, 12.0, 8.0][i]
			# Break the cone with noise, then flatten a building pad on top so
			# structures are not perched on a curve.
			var shore := n.get_noise_2d(x * 0.9, z * 0.9) * 3.4 * (1.0 - k)
			var h := lerpf(-12.0, peak, pow(k, 1.35)) + shore
			var flat := smoothstep(14.0, 7.0, d)
			h = lerpf(h, peak, flat)
			y = maxf(y, h)
	# A shallow bar between landfall and the lighthouse (the causeway route).
	var bar := clampf(1.0 - Vector2(x + 26.0, z - 66.0).length() / 34.0, 0.0, 1.0)
	y = maxf(y, lerpf(-14.0, -1.4, smoothstep(0.0, 1.0, bar)))
	return y

func build_world() -> void:
	_noise.seed = 6606
	_noise.frequency = 0.013
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	SceneFlow.report(0.12, "Raising the archipelago")
	build_terrain(Vector2(320, 320), 234, Callable(self, "_h"), "islands",
		Veil.Surface.SAND)
	spawn_position = on_ground(0, 100, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.24, "Filling the sea")
	_sea = WaterVolume.new()
	add_child(_sea)
	_sea.build(Vector2(320, 320), 40.0, -2.0,
		Color(0.16, 0.44, 0.50, 0.55), Color(0.01, 0.07, 0.14, 0.96))
	await get_tree().process_frame

	SceneFlow.report(0.34, "Dressing the shores")
	_build_shores()
	await get_tree().process_frame

	SceneFlow.report(0.46, "Landfall")
	_build_landfall()
	_build_causeway()
	await get_tree().process_frame

	SceneFlow.report(0.58, "Lighthouse")
	_build_lighthouse()
	await get_tree().process_frame

	SceneFlow.report(0.68, "Cable station")
	_build_cable()
	await get_tree().process_frame

	SceneFlow.report(0.80, "Shelf island")
	_build_shelf()
	await get_tree().process_frame

	SceneFlow.report(0.90, "Storm eye")
	_build_eye()
	_build_dressing()
	await get_tree().process_frame

# ---------------------------------------------------------------- shores
func _build_shores() -> void:
	for i in 140:
		var x := rng.randf_range(-150, 150)
		var z := rng.randf_range(-150, 150)
		var y := terrain.height_at(x, z)
		if y < -3.0 or y > 16.0:
			continue
		rock(Vector3(x, y - 0.4, z), rng.randf_range(0.7, 3.6), 1800 + i,
			"rock_wet" if y < 1.5 else "rock")
	# Wrecked hulls and mooring posts on the tide line.
	for i in 16:
		var a := rng.randf_range(0, TAU)
		var c: Vector3 = ISLANDS[rng.randi_range(0, ISLANDS.size() - 1)]
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(20.0, 30.0)
		var y := terrain.height_at(p.x, p.z)
		if y < -6.0 or y > 4.0:
			continue
		static_mesh(ProcAssets.trunk_mesh(6100 + i, rng.randf_range(6.0, 12.0),
			rng.randf_range(0.7, 1.3), 0.08, 5, 8, 0.75), "metal_rust",
			Vector3(p.x, y + 0.6, p.z),
			Vector3(PI * 0.5 + rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), 0),
			Vector3.ONE, Veil.Surface.METAL)

func _build_dressing() -> void:
	vegetation.scatter(ProcAssets.blade_cluster_mesh(71, 18, 0.8, 0.07), 4200,
		Rect2(-150, -150, 300, 300), veg_sampler(30.0, [], 1.0, 18.0),
		Color(0.26, 0.36, 0.20), Color(0.46, 0.54, 0.26), Vector2(0.7, 1.8), 0.36, 61, 1.2)
	vegetation.scatter(ProcAssets.canopy_mesh(72, 1.1, 3), 500,
		Rect2(-150, -150, 300, 300), veg_sampler(22.0, [], 3.0, 16.0),
		Color(0.18, 0.34, 0.22), Color(0.32, 0.52, 0.30), Vector2(0.6, 1.7), 0.20, 62, 1.8)

## Shared helper: a link between two islands that only exists in one state.
func _link(id: String, a: Vector3, b: Vector3, state: int, mat: String,
		surface: int, width: float = 3.4) -> VeilSubject:
	var mid := (a + b) * 0.5
	var dir := b - a
	var len := dir.length()
	var yaw := atan2(dir.x, dir.z)
	var node := variant_box(Vector3(width, 0.5, len), mat, Vector3.ZERO,
		Vector3(0, 0, 0), surface)
	var mem: Node3D = node if state == Veil.State.MEMORY else null
	var ruin: Node3D = node if state == Veil.State.RUIN else null
	var bloom: Node3D = node if state == Veil.State.BLOOM else null
	var vs := veil_subject(id, mid, mem, ruin, bloom, len * 0.55)
	vs.rotation.y = yaw
	_links.append(vs)
	return vs

# ---------------------------------------------------------------- landfall
func _build_landfall() -> void:
	var base := on_ground(0, 96)
	box(Vector3(16.0, 0.5, 12.0), "concrete_aged", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	static_mesh(ProcAssets.room_shell(Vector3(7.0, 3.2, 6.0), 0.3, 2.2, 2.6, true, 1),
		"metal_rust", base + Vector3(-5.0, 1.8, -2.0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.METAL)
	scannable(base + Vector3(-5.0, 2.0, -2.0), "Harbour Office",
		"A tide table pinned to the wall. Every figure after the Fracture is crossed out.",
		Veil.Prop.RIGID, -1, 2.6)
	checkpoint("cp_landfall", base + Vector3(0, 0.3, -4.0), 180.0)
	trigger(base + Vector3(0, 3, -8.0), Vector3(22, 8, 6), func() -> void:
		say("Four islands. Every link between them belongs to a different version of this sea.",
			"MOTE", 5.2)
		say("And the lightning is real in all three. Try not to be the highest thing standing.",
			"MOTE", 4.8))

func _build_causeway() -> void:
	# Between landfall and the lighthouse the sea bed is shallow: at low tide
	# you simply walk. The tide is driven by the storm cycle.
	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch6_causeway"
	pz.title = "Tidal Causeway"
	pz.hint_subtle = "The bar is under a metre and a half of water. Sometimes."
	pz.hint_guided = "The sea drops when the storm front passes. Watch the water, not the sky."
	pz.hint_directed = "Wait for the storm to peak - the sea falls with it - then run the bar to the lighthouse island."
	pz.position = Vector3(-26, 0, 66)
	add_child(pz)
	pz.register_hints()
	trigger(ISLANDS[1] + Vector3(0, 4, 22.0), Vector3(24, 10, 8), func() -> void:
		_flags.causeway = true
		if not pz.is_solved:
			pz.mark_solved())

# ---------------------------------------------------------------- lighthouse
func _build_lighthouse() -> void:
	var base := on_ground(ISLANDS[1].x, ISLANDS[1].z)
	box(Vector3(16.0, 0.6, 16.0), "concrete_aged", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 7:
		decor(ProcAssets.cylinder_mesh(3.0 - float(i) * 0.22, 3.4, 18),
			"concrete" if i % 2 == 0 else "nacre", base + Vector3(0, 1.7 + float(i) * 3.3, 0))
	var body := box(Vector3(5.0, 24.0, 5.0), "concrete", base + Vector3(0, 12.0, 0))
	body.visible = false
	var lamp := decor(ProcAssets.sphere_mesh(1.6, 12, 16),
		ProcAssets.additive(Color(1.0, 0.9, 0.6), 0.3, false), base + Vector3(0, 25.0, 0))
	var lamp_light := SpotLight3D.new()
	lamp_light.light_color = Color(1.0, 0.92, 0.7)
	lamp_light.light_energy = 0.0
	lamp_light.spot_range = 90.0
	lamp_light.spot_angle = 22.0
	lamp_light.position = base + Vector3(0, 25.0, 0)
	lamp_light.rotation_degrees = Vector3(-6, 0, 0)
	add_child(lamp_light)

	var climb := climb_surface(Vector3(2.0, 22.0, 0.6), base + Vector3(0, 12.0, 2.9))
	# Power the lamp: the lighthouse generator only turns over in Memory.
	var gen_mem := variant_mesh(ProcAssets.cylinder_mesh(1.2, 2.4, 14), "brass",
		Vector3.ZERO, Vector3.ZERO, Veil.Surface.METAL)
	veil_subject("lighthouse_gen", base + Vector3(5.0, 1.2, 4.0), gen_mem, null, null, 3.0)
	var im := Imprintable.new()
	im.label = "Lamp Feed"
	im.accepted = [Veil.Prop.CONDUCTIVE, Veil.Prop.LUMINOUS]
	im.position = base + Vector3(0, 1.4, 3.0)
	add_child(im)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch6_lighthouse"
	pz.title = "Lighthouse Lamp"
	pz.hint_subtle = "The lamp is intact and the feed is dead."
	pz.hint_guided = "The generator still runs in Memory. Carry what it makes to the feed."
	pz.hint_directed = "Shift the generator to Memory, scan it for Conductive, then imprint the lamp feed at the tower base."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	im.imprinted.connect(func(_p: int) -> void:
		_lighthouse_lit = true
		_flags.lighthouse = true
		(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 4.0
		var t := create_tween()
		t.tween_property(lamp_light, "light_energy", 8.0, 1.2)
		AudioDirector.play_3d("power_on", get_tree().current_scene,
			lamp_light.global_position, -2.0)
		if not pz.is_solved:
			pz.mark_solved()
			say("Lamp is lit. It sweeps the shelf every nine seconds - that is your window.",
				"MOTE", 4.8))
	var sc := scannable(base + Vector3(5.0, 1.6, 4.0), "Lighthouse Generator",
		"Hand-cranked, then diesel, then something the engineers here never wrote down.",
		Veil.Prop.CONDUCTIVE, Veil.State.MEMORY, 3.0)
	sc.xp_bonus = 90
	fragment(0, base + Vector3(-6.0, 1.0, -5.0))
	checkpoint("cp_lighthouse", base + Vector3(0, 0.4, -6.0), 180.0)

	# Link 1: lighthouse -> cable station, a Memory-state pier.
	_link("link_pier", base + Vector3(8.0, 1.0, -6.0),
		ISLANDS[2] + Vector3(-8.0, 1.0, 8.0), Veil.State.MEMORY, "metal",
		Veil.Surface.METAL, 3.6)

	var pz2 := PuzzleBase.new()
	pz2.puzzle_id = "ch6_bridge"
	pz2.title = "Memory Pier"
	pz2.hint_subtle = "There is nothing between here and the cable station."
	pz2.hint_guided = "There was a pier. It is still a pier, in Memory."
	pz2.hint_directed = "Pin a Memory field over the gap toward the cable station and walk the pier before the pin lapses."
	pz2.position = base
	add_child(pz2)
	pz2.register_hints()
	trigger(ISLANDS[2] + Vector3(-6.0, 4.0, 8.0), Vector3(12, 8, 8), func() -> void:
		_flags.bridge = true
		if not pz2.is_solved:
			pz2.mark_solved())

# ---------------------------------------------------------------- cable
func _build_cable() -> void:
	var base := on_ground(ISLANDS[2].x, ISLANDS[2].z)
	box(Vector3(20.0, 0.6, 18.0), "concrete", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	static_mesh(ProcAssets.room_shell(Vector3(12.0, 4.6, 10.0), 0.5, 3.0, 3.2, true, 1),
		"concrete_aged", base + Vector3(0, 2.5, -1.0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	static_mesh(ProcAssets.truss_mesh(18.0, 2.4, 2.4, 8, 0.14), "metal_rust",
		base + Vector3(0, 9.5, 6.0), Vector3(PI * 0.5, 0, 0), Vector3.ONE,
		Veil.Surface.METAL)

	# A cable car to the shelf island. It needs power and a taut cable; the
	# cable is only taut in Bloom, where growth has pulled it straight.
	var car := MovingPlatform.new()
	car.points = [base + Vector3(0, 10.0, 4.0),
		ISLANDS[3] + Vector3(0, 12.0, 8.0)]
	car.speed = 5.0
	car.wait_time = 3.0
	car.size = Vector3(3.4, 0.3, 3.4)
	car.loop_mode = false
	car.auto_run = false
	add_child(car)

	var cable_bloom := variant_mesh(ProcAssets.tube_mesh("ch6cable",
		PackedVector3Array([Vector3(0, 11.0, 4.0),
			(ISLANDS[3] - ISLANDS[2]) * 0.5 + Vector3(0, 9.0, 6.0),
			ISLANDS[3] - ISLANDS[2] + Vector3(0, 13.0, 8.0)]),
		PackedFloat32Array([0.3, 0.34, 0.3]), 8, 0.4), "bark",
		Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD, false)
	var cable := veil_subject("cable_run", base, null, null, cable_bloom, 60.0)

	var src := PowerPoint.new()
	src.point_id = "ch6_src"
	src.is_source = true
	src.position = base + Vector3(-7.0, 0, 6.0)
	add_child(src); power.register(src)
	var sink := PowerPoint.new()
	sink.point_id = "ch6_car"
	sink.is_sink = true
	sink.position = base + Vector3(5.0, 0, 4.0)
	add_child(sink); power.register(sink)
	var c1 := Conduit.new(); add_child(c1)
	c1.build(src.position + Vector3(0, 1.8, 0), sink.position + Vector3(0, 1.8, 0),
		[Veil.State.MEMORY], manager, true, 0.4)
	power.link("ch6_src", "ch6_car", Callable(c1, "is_conductive"), true, c1)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch6_cable"
	pz.title = "Cable Station"
	pz.hint_subtle = "The car has a motor and no line."
	pz.hint_guided = "Growth has pulled a line straight across that gap. It is not there in Ruin."
	pz.hint_directed = "Power the motor with a Memory field on the conduit, pin a Bloom field on the cable run so the line exists, then ride the car."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	var check := func() -> void:
		var ok: bool = power.is_powered("ch6_car") and cable.current_state == Veil.State.BLOOM
		if ok and not car.running:
			car.start()
			AudioDirector.play_3d("machine_start", get_tree().current_scene,
				base + Vector3(0, 8, 0), -4.0)
			_flags.cable = true
			if not pz.is_solved:
				pz.mark_solved()
		elif not ok:
			car.stop()
	cable.state_applied.connect(func(_s: int) -> void: check.call())
	power.network_changed.connect(func() -> void: check.call())

	guardian(base + Vector3(7.0, 0.4, -6.0), [
		base + Vector3(7, 0.4, -6), base + Vector3(-7, 0.4, -6),
		base + Vector3(-7, 0.4, 6)])
	component(base + Vector3(0, 1.0, -6.0))
	fragment(1, base + Vector3(8.0, 1.0, 6.0))
	checkpoint("cp_cable", base + Vector3(0, 0.4, 7.0), 180.0)

# ---------------------------------------------------------------- shelf
func _build_shelf() -> void:
	var base := on_ground(ISLANDS[3].x, ISLANDS[3].z)
	box(Vector3(20.0, 0.6, 18.0), "concrete_aged", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	box(Vector3(6.0, 0.4, 6.0), "metal", base + Vector3(0, 12.0, 8.0),
		Vector3.ZERO, Veil.Surface.METAL)
	climb_surface(Vector3(2.0, 12.0, 0.6), base + Vector3(0, 6.0, 5.2))

	# A salt shelf that only bears weight when the lighthouse beam is on it.
	var shelf := box(Vector3(8.0, 0.5, 26.0), "nacre",
		base + Vector3(0, 2.0, -16.0), Vector3.ZERO, Veil.Surface.STONE)
	shelf.collision_layer = 0
	shelf.visible = false
	var glow := decor(ProcAssets.box_mesh(Vector3(8.2, 0.1, 26.2)),
		ProcAssets.additive(Color(0.8, 0.9, 1.0), 1.2),
		base + Vector3(0, 2.3, -16.0))
	glow.visible = false

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch6_shelf"
	pz.title = "Salt Shelf"
	pz.hint_subtle = "The shelf is only solid when it is lit."
	pz.hint_guided = "The lighthouse sweeps this island. Cross while the beam is on you."
	pz.hint_directed = "Light the lighthouse lamp first, then cross the shelf during a sweep. It takes about four seconds to walk."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_shelf_body = shelf
	_shelf_glow = glow
	trigger(base + Vector3(0, 3.0, -30.0), Vector3(14, 8, 6), func() -> void:
		_flags.shelf = true
		if not pz.is_solved:
			pz.mark_solved())
	fragment(2, base + Vector3(-7.0, 1.0, 5.0))
	hidden_marker(base + Vector3(7.0, 12.6, 8.0))
	checkpoint("cp_shelf", base + Vector3(0, 0.4, 6.0), 180.0)

var _shelf_body: StaticBody3D
var _shelf_glow: MeshInstance3D
var _sweep := 0.0

# ---------------------------------------------------------------- eye
func _build_eye() -> void:
	var base := on_ground(ISLANDS[4].x, ISLANDS[4].z)
	box(Vector3(26.0, 0.8, 26.0), "metal_dark", base + Vector3(0, -0.3, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	for i in 5:
		decor(ProcAssets.ring_mesh(9.0 - float(i) * 1.4, 0.4, 30, 8),
			"brass" if i % 2 == 0 else "metal_dark", base + Vector3(0, 2.0 + float(i) * 2.4, 0))
	decor(ProcAssets.crystal_mesh(661, 7.0, 1.6, 6),
		ProcAssets.additive(Color(0.6, 0.85, 1.0), 1.6, false), base + Vector3(0, 13.0, 0))

	var it := Interactable.new()
	it.prompt = "Take the storm-eye reading"
	it.hold_time = 1.6
	it.one_shot = true
	it.position = base + Vector3(0, 1.2, 0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 3.2
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(base))

	# Link 4: shelf -> eye, a Bloom-state coral causeway.
	_link("link_coral", ISLANDS[3] + Vector3(0, 1.0, -30.0),
		base + Vector3(0, 1.0, 16.0), Veil.State.BLOOM, "resin",
		Veil.Surface.RESIN, 4.0)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch6_eye"
	pz.title = "Storm Eye"
	pz.hint_subtle = "One more gap."
	pz.hint_guided = "Coral has bridged it, in the version of this sea that is still growing."
	pz.hint_directed = "Pin a Bloom field over the last gap and cross the coral causeway to the eye platform."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 2.0, 8.0), Vector3(18, 6, 6), func() -> void:
		if not pz.is_solved:
			pz.mark_solved())
	scannable(base + Vector3(8.0, 1.4, -6.0), "Migration Chart",
		"Bird routes, redrawn every year. The last three years are the same route, and it is a circle.")

func _finale(base: Vector3) -> void:
	if _eye_done:
		return
	_eye_done = true
	_flags.eye = true
	AudioDirector.play("power_on", -2.0)
	SceneFlow.flash(Color(0.7, 0.9, 1.0, 0.3), 0.8)
	set_objective("Storm-eye reading taken.")
	if not _struck:
		GameState.complete_challenge()
		say("Not struck once. The storm noticed and chose not to mention it.", "MOTE", 3.6)
	await cinematic(
		[base + Vector3(-28, 12, 26), base + Vector3(10, 20, 8), base + Vector3(0, 32, -22)],
		[base + Vector3(0, 8, 0), base + Vector3(0, 12, 0), base + Vector3(0, 2, -70)],
		9.5,
		[["The storm is not weather. It is the three realities grinding against each other.",
			"MOTE"],
		 ["And it is centred on a building that does not appear on any chart I have.",
			"MOTE"],
		 ["Archive Zero. Whoever started this wrote it down there. Let's go and read it.",
			"MOTE"]])
	finish()

# ---------------------------------------------------------------- storm
func _process(dt: float) -> void:
	if not GameState.run.get("active", false):
		return
	_storm = fposmod(_storm + dt / _storm_cycle, 1.0)
	var front := pow(sin(_storm * PI), 2.0)
	weather.set_intensity(0.3 + front * 0.7)
	# The sea falls as the front passes: that is the causeway window.
	var want := lerpf(-0.6, -3.4, front)
	if absf(_sea.target_level - want) > 0.25:
		_sea.set_level(want, 1.4)

	# Lighthouse sweep drives the salt shelf.
	if _lighthouse_lit and _shelf_body:
		_sweep = fposmod(_sweep + dt / 9.0, 1.0)
		var lit := _sweep < 0.55
		if lit != _shelf_body.visible:
			_shelf_body.visible = lit
			_shelf_glow.visible = lit
			_shelf_body.collision_layer = Veil.L_WORLD if lit else 0
			AudioDirector.play_3d("switch", get_tree().current_scene,
				_shelf_body.global_position, -16.0, 1.2 if lit else 0.8)

func on_state_changed(s: int) -> void:
	AudioDirector.fade_ambience(0, [0.24, 0.52, 0.34][clampi(s, 0, 2)], 1.4)

# ---------------------------------------------------------------- hooks
func on_begin(mode: String) -> void:
	player.device.unlock_all()
	if mode != "checkpoint":
		say("Storm belt. Fronts every minute or so, and the sea moves with them.",
			"MOTE", 5.0)
	set_objective(String(info.objective))
	weather.set_intensity(0.6)
	weather.lightning_struck.connect(_on_lightning)

func _on_lightning(pos: Vector3) -> void:
	if player == null or not player.is_alive():
		return
	var d := player.global_position.distance_to(pos)
	# You are only hit when you are the tallest thing in the open.
	if d > 18.0:
		return
	var space := get_world_3d().direct_space_state
	var from := player.global_position + Vector3(0, 2.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 30, 0))
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [player.get_rid()]
	if not space.intersect_ray(q).is_empty():
		return
	_struck = true
	player.apply_damage(Tuning.HAZ_ELECTRIC * Tuning.dmg_scale(GameState.difficulty()),
		"lightning")
	AudioDirector.play("electric", -3.0)

func ambience_profiles() -> Array:
	return ["storm", "water", "wind_high"]

func ambience_volumes() -> Array:
	return [0.44, 0.34, 0.20]

func save_flags() -> Dictionary:
	var f := _flags.duplicate()
	f["lamp"] = _lighthouse_lit
	return f

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	_lighthouse_lit = bool(flags.get("lamp", false))

func shot_spots() -> Array:
	return [
		{"name": "landfall", "pos": on_ground(24, 108, 12.0), "look": ISLANDS[1] + Vector3(0, 8, 0)},
		{"name": "lighthouse", "pos": ISLANDS[1] + Vector3(28, 22, 26),
			"look": ISLANDS[1] + Vector3(0, 14, 0)},
		{"name": "eye", "pos": ISLANDS[4] + Vector3(30, 18, 30),
			"look": ISLANDS[4] + Vector3(0, 6, 0)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "Lighthouse ledger. 'Kept the lamp for nineteen years for ships. Kept it eleven more for nobody. Tonight something answered the sweep. I am going to keep keeping it.'"
		1: return "A salt-glass bead, formed where lightning hit wet sand. Threaded on a cord with eleven others, one per strike survived. The twelfth space on the cord is empty."
		2: return "A migration chart, three years of routes overlaid. The birds used to leave. Now they fly a closed circle around the storm eye, and they have got very good at it."
	return ""
