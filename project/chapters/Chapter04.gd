extends ChapterBase
## CHAPTER 4 - WHITE SIGNAL OBSERVATORY
## A listening station above the snow line. Storm fronts sweep through on a
## cycle, cutting visibility and guardian sight alike, and the chapter's bonus
## challenge is a race against one of them.

var _noise := FastNoiseLite.new()
var _pads: Array[Vector4] = []
var _flags := {"door": false, "channel": false, "beam": false, "dishes": false,
	"generator": false, "signal": false}

var _dishes: Array = []
var _dish_target := [2, 0, 3]
var _storm_phase := 0.0
var _storm_cycle := 78.0
var _challenge_armed := false
var _challenge_start := 0.0
var _signal_done := false
var _gen_sink: PowerPoint
var _prisms: Array = []
var _receiver_lit := [false, false, false]

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	var n := _noise
	# A shoulder of mountain: high to the west, a saddle in the middle, a cirque
	# to the north where the dishes sit.
	var ridge := pow(clampf((x + 120.0) / 200.0, 0.0, 1.0), 1.6) * -34.0 + 30.0
	var north := clampf((-z + 60.0) / 180.0, 0.0, 1.0) * 14.0
	var y := ridge + north
	y += n.get_noise_2d(x * 0.35, z * 0.35) * 8.0 + n.get_noise_2d(x * 1.3, z * 1.3) * 2.4
	# A glacial channel the FROZEN puzzle spans.
	var ch := clampf(1.0 - absf(z + 12.0) / 8.0, 0.0, 1.0)
	y -= smoothstep(0.0, 1.0, ch) * clampf(1.0 - absf(x) / 40.0, 0.0, 1.0) * 12.0
	for pad in _pads:
		var d := Vector2(x - pad.x, z - pad.y).length()
		var w := float(pad.z)
		if d < w:
			var k := smoothstep(w, w * 0.3, d)
			y = lerpf(y, float(pad.w), k * k * (3.0 - 2.0 * k))
	return y

func build_world() -> void:
	_noise.seed = 4404
	_noise.frequency = 0.010
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	_pads = [
		Vector4(0, 96, 14, 22.0),     # cable-car landing
		Vector4(0, 58, 13, 20.0),     # frozen door
		Vector4(0, -12, 18, 12.0),    # glacial channel crossing
		Vector4(-28, -40, 15, 16.0),  # prism hall approach
		Vector4(22, -46, 14, 17.0),   # generator shed
		Vector4(0, -76, 20, 18.0),    # dish field
		Vector4(0, -104, 14, 20.0),   # signal room
	]

	SceneFlow.report(0.12, "Carving the cirque")
	build_terrain(Vector2(300, 300), 225, Callable(self, "_h"), "mountain",
		Veil.Surface.SNOW)
	spawn_position = on_ground(0, 96, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.26, "Setting the snow line")
	_build_mountain()
	await get_tree().process_frame

	SceneFlow.report(0.38, "Cable-car landing")
	_build_landing()
	_build_door()
	await get_tree().process_frame

	SceneFlow.report(0.50, "Glacial channel")
	_build_channel()
	await get_tree().process_frame

	SceneFlow.report(0.60, "Prism hall")
	_build_prisms()
	await get_tree().process_frame

	SceneFlow.report(0.70, "Generator shed")
	_build_generator()
	await get_tree().process_frame

	SceneFlow.report(0.82, "Dish field")
	_build_dishes()
	await get_tree().process_frame

	SceneFlow.report(0.90, "Signal room")
	_build_signal()
	_build_dressing()
	await get_tree().process_frame

# ---------------------------------------------------------------- mountain
func _build_mountain() -> void:
	for i in 120:
		var x := rng.randf_range(-140, 140)
		var z := rng.randf_range(-140, 140)
		var skip := false
		for p in _pads:
			if Vector2(x - p.x, z - p.y).length() < p.z + 5.0:
				skip = true
				break
		if skip:
			continue
		rock(on_ground(x, z, -0.4), rng.randf_range(0.9, 5.0), 1200 + i, "rock_dark")
	# Ice pinnacles and wind-scoured pillars.
	for i in 40:
		var x := rng.randf_range(-130, 130)
		var z := rng.randf_range(-130, 130)
		if terrain.slope_at(x, z) > 34.0:
			continue
		static_mesh(ProcAssets.crystal_mesh(400 + i, rng.randf_range(1.4, 4.6),
			rng.randf_range(0.3, 0.9), 6), "ice", on_ground(x, z, -0.3),
			Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0, TAU), 0),
			Vector3.ONE, Veil.Surface.GLASS)
	# Marker cairns along the route.
	for i in 18:
		var t := float(i) / 17.0
		var z := lerpf(90.0, -100.0, t)
		var x := sin(t * 5.0) * 12.0
		decor(ProcAssets.rock_mesh(3, 0.5, 0.3, 8, 10, 0.8), "rock_dark",
			on_ground(x + 9.0, z, 0.5))
		decor(ProcAssets.box_mesh(Vector3(0.16, 1.4, 0.16)),
			ProcAssets.emissive(Color(1.0, 0.5, 0.2), 1.2), on_ground(x + 9.0, z, 1.4))

func _build_dressing() -> void:
	var excl: Array = []
	for p in _pads:
		excl.append(Rect2(p.x - p.z * 0.8, p.y - p.z * 0.8, p.z * 1.6, p.z * 1.6))
	vegetation.scatter(ProcAssets.blade_cluster_mesh(51, 12, 0.35, 0.05), 2200,
		Rect2(-140, -140, 280, 280), veg_sampler(26.0, excl, -1e9, 22.0),
		Color(0.34, 0.36, 0.30), Color(0.52, 0.54, 0.46), Vector2(0.5, 1.2), 0.26, 41, 0.6)

# ---------------------------------------------------------------- landing
func _build_landing() -> void:
	var base := on_ground(0, 96)
	box(Vector3(18.0, 0.6, 14.0), "metal_rust", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.METAL)
	static_mesh(ProcAssets.truss_mesh(20.0, 3.0, 3.0, 8, 0.16), "metal_rust",
		base + Vector3(0, 9.0, 12.0), Vector3(PI * 0.5, 0, 0), Vector3.ONE,
		Veil.Surface.METAL)
	decor(ProcAssets.box_mesh(Vector3(4.0, 3.0, 6.0)), "metal_dark",
		base + Vector3(6.0, 2.0, 4.0), Vector3(0.1, 0.3, 0.05))
	scannable(base + Vector3(6.0, 2.6, 4.0), "Cable Car, derailed",
		"Eleven seats. Four of them have coats still folded on them.")
	checkpoint("cp_landing", base + Vector3(0, 0.4, -4.0), 180.0)
	trigger(base + Vector3(0, 3, -8.0), Vector3(24, 8, 6), func() -> void:
		say("Observatory is a kilometre up the ridge. Storm fronts come through about every eighty seconds.",
			"MOTE", 5.4)
		say("Inside a front you cannot see and neither can they. Use it.", "MOTE", 4.2))

# ---------------------------------------------------------------- frozen door
func _build_door() -> void:
	var base := on_ground(0, 58)
	static_mesh(ProcAssets.room_shell(Vector3(14.0, 5.0, 10.0), 0.5, 3.2, 3.4, true, 1),
		"concrete_aged", base + Vector3(0, 2.7, -2.0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	# RUIN: the doorway is a solid plug of ice. MEMORY: an open airlock.
	# BLOOM: frost-vines have cracked it open.
	var ruin := variant_box(Vector3(3.2, 3.4, 1.4), "ice",
		Vector3(0, 1.7, 3.0), Vector3.ZERO, Veil.Surface.GLASS)
	var mem := variant_group([
		variant_box(Vector3(0.5, 3.4, 1.0), "metal", Vector3(-1.6, 1.7, 3.0),
			Vector3.ZERO, Veil.Surface.METAL),
		variant_box(Vector3(0.5, 3.4, 1.0), "metal", Vector3(1.6, 1.7, 3.0),
			Vector3.ZERO, Veil.Surface.METAL)])
	var bpts := PackedVector3Array([Vector3(-3, 0.4, 3.4), Vector3(-1, 2.2, 3.2),
		Vector3(1.4, 3.4, 3.0), Vector3(3.2, 4.2, 2.6)])
	var bloom := variant_mesh(ProcAssets.tube_mesh("ch4door", bpts,
		PackedFloat32Array([0.4, 0.34, 0.3, 0.24]), 8, 0.3), "bark",
		Vector3.ZERO, Vector3.ZERO, Veil.Surface.WOOD)
	var subj := veil_subject("ice_door", base, mem, ruin, bloom, 6.0)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch4_door"
	pz.title = "Frozen Airlock"
	pz.hint_subtle = "The door is not locked. It is full."
	pz.hint_guided = "There is a version of this doorway with nothing in it."
	pz.hint_directed = "Field the doorway and shift it to Memory - the ice plug is a Ruin-state fact and simply is not there."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	subj.state_applied.connect(func(s: int) -> void:
		if s != Veil.State.RUIN and not pz.is_solved:
			_flags.door = true
			pz.mark_solved())
	fragment(0, base + Vector3(-4.0, 1.0, -4.0))
	scannable(base + Vector3(4.0, 1.6, -4.0), "Frost-Split Lens Housing",
		"The optic cracked along a single line. Somebody labelled the crack and kept using it.",
		Veil.Prop.FROZEN, Veil.State.RUIN, 2.6)
	checkpoint("cp_door", base + Vector3(0, 0.4, -6.0), 180.0)

# ---------------------------------------------------------------- channel
func _build_channel() -> void:
	var base := on_ground(0, -12)
	# A meltwater channel with a hazard at the bottom.
	hazard(Vector3(0, base.y - 6.0, -12.0), Vector3(70, 8, 14),
		Tuning.HAZ_COLD_DPS * 3.0, "the meltwater")
	var wv := WaterVolume.new()
	add_child(wv)
	wv.position = Vector3(0, 0, -12.0)
	wv.build(Vector2(70, 13), 10.0, base.y - 4.4,
		Color(0.34, 0.56, 0.62, 0.45), Color(0.06, 0.16, 0.24, 0.9))

	# A frozen crossing: imprint FROZEN onto the channel surface to walk over.
	var im := Imprintable.new()
	im.label = "Meltwater Surface"
	im.accepted = [Veil.Prop.FROZEN]
	im.position = Vector3(0, base.y - 4.0, -12.0)
	add_child(im)

	var ice_bridge := box(Vector3(9.0, 0.5, 15.0), "ice",
		Vector3(0, base.y - 4.2, -12.0), Vector3.ZERO, Veil.Surface.GLASS)
	ice_bridge.visible = false
	ice_bridge.collision_layer = 0

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch4_channel"
	pz.title = "Meltwater Channel"
	pz.hint_subtle = "The water is moving and it is very cold."
	pz.hint_guided = "Something else on this mountain is locked solid. Borrow that."
	pz.hint_directed = "Scan the ice plug or an ice pinnacle for Frozen, then imprint it onto the meltwater surface to make a crossing."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	im.imprinted.connect(func(_p: int) -> void:
		ice_bridge.visible = true
		ice_bridge.collision_layer = Veil.L_WORLD
		AudioDirector.play_3d("shift_memory", get_tree().current_scene,
			ice_bridge.global_position, -4.0, 0.7)
		_flags.channel = true
		if not pz.is_solved:
			pz.mark_solved()
			say("Solid. It will not stay solid, so do not admire it.", "MOTE", 3.6))
	im.imprint_cleared.connect(func() -> void:
		ice_bridge.visible = false
		ice_bridge.collision_layer = 0)
	im.hold_seconds = 26.0

	# There is also a Memory-state footbridge for players who prefer that route.
	var mem := variant_box(Vector3(2.6, 0.4, 16.0), "metal",
		Vector3(14.0, base.y - 1.0, -12.0), Vector3.ZERO, Veil.Surface.METAL)
	veil_subject("ch4_footbridge", Vector3(14.0, base.y, -12.0), mem, null, null, 9.0)

	checkpoint("cp_channel", Vector3(0, base.y + 0.4, -22.0), 180.0)
	wildlife(Vector3(-16.0, base.y + 0.8, -22.0), "Snow-Skater Colony",
		"They live on the wind and never touch the ground. The storm is their weather, not their problem.")

# ---------------------------------------------------------------- prisms
func _build_prisms() -> void:
	var base := on_ground(-28, -40)
	static_mesh(ProcAssets.room_shell(Vector3(24.0, 6.0, 18.0), 0.6, 4.0, 4.0, true, 1),
		"concrete_aged", base + Vector3(0, 3.2, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)

	# An emitter, two rotatable prisms, and three receivers in the walls.
	var emitter := LightPrism.new()
	emitter.emitter = true
	emitter.steps = 8
	emitter.beam_length = 30.0
	emitter.position = base + Vector3(-8.0, 0.2, 6.0)
	add_child(emitter)
	_prisms.append(emitter)
	for i in 2:
		var p := LightPrism.new()
		p.steps = 8
		p.beam_length = 26.0
		p.position = base + Vector3(-1.0 + float(i) * 7.0, 0.2, -1.0 - float(i) * 4.0)
		add_child(p)
		_prisms.append(p)

	var receivers: Array = []
	for i in 3:
		var rp := base + Vector3(-7.0 + float(i) * 7.0, 1.4, -8.0)
		var r := box(Vector3(1.2, 1.2, 0.6), "metal_dark", rp, Vector3.ZERO,
			Veil.Surface.METAL)
		r.set_meta("receiver", i)
		var lamp := decor(ProcAssets.ring_mesh(0.4, 0.06, 18, 6),
			ProcAssets.emissive(Color(0.4, 0.4, 0.45), 0.4), rp + Vector3(0, 0, 0.4))
		receivers.append({"body": r, "lamp": lamp})

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch4_beam"
	pz.title = "Prism Hall"
	pz.hint_subtle = "The beam is short. The receivers are not in line."
	pz.hint_guided = "Each prism passes the beam on. Turn them so the chain reaches a receiver."
	pz.hint_directed = "Rotate the first prism toward the second, the second toward the third, and the last toward a wall receiver. Shifting the hall to Memory removes the rubble blocking one line."
	pz.position = base
	add_child(pz)
	pz.register_hints()

	# Rubble that blocks one beam line unless the hall is in Memory.
	var rubble_ruin := variant_mesh(ProcAssets.debris_mesh(915, 10, 1.8, 1.4),
		"concrete_aged", Vector3.ZERO, Vector3.ZERO, Veil.Surface.STONE)
	veil_subject("prism_rubble", base + Vector3(3.0, 0.8, -4.0), null, rubble_ruin, null, 2.4)

	# Chain the beams: a prism lights when the previous beam hits it.
	var relight := func() -> void:
		for i in range(1, _prisms.size()):
			var prev: LightPrism = _prisms[i - 1]
			var hit := prev.hit_target()
			var lit := false
			if hit != null:
				var owner_node: Node = hit
				while owner_node != null and not (owner_node is LightPrism):
					owner_node = owner_node.get_parent()
				lit = owner_node == _prisms[i]
			(_prisms[i] as LightPrism).energise(lit)
		var last: LightPrism = _prisms[_prisms.size() - 1]
		var t := last.hit_target()
		var idx := -1
		if t != null and t.has_meta("receiver"):
			idx = int(t.get_meta("receiver"))
		for i in 3:
			var on := i == idx and last.active
			if on != _receiver_lit[i]:
				_receiver_lit[i] = on
				var mat := (receivers[i].lamp as MeshInstance3D).material_override as StandardMaterial3D
				var c := Color(1.0, 0.94, 0.7) if on else Color(0.4, 0.4, 0.45)
				mat.albedo_color = c
				mat.emission = c
				mat.emission_energy_multiplier = 3.0 if on else 0.4
				if on:
					AudioDirector.play_3d("power_on", get_tree().current_scene,
						(receivers[i].body as Node3D).global_position, -8.0)
		if idx >= 0 and last.active and not pz.is_solved:
			_flags.beam = true
			pz.mark_solved()
			say("Optical path closed. That is the dish control loop back online.",
				"MOTE", 4.2)
	for p in _prisms:
		(p as LightPrism).rotated.connect(func(_s: int) -> void: relight.call())
		(p as LightPrism).beam_hit.connect(func(_n: Node) -> void: relight.call())

	component(base + Vector3(9.0, 1.0, 6.0))
	checkpoint("cp_prisms", base + Vector3(0, 0.4, 7.0), 180.0)

# ---------------------------------------------------------------- generator
func _build_generator() -> void:
	var base := on_ground(22, -46)
	static_mesh(ProcAssets.room_shell(Vector3(16.0, 5.0, 12.0), 0.5, 3.2, 3.4, true, 0),
		"metal_rust", base + Vector3(0, 2.7, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.METAL)
	for i in 2:
		decor(ProcAssets.cylinder_mesh(1.1, 3.4, 14), "metal_dark",
			base + Vector3(-3.0 + float(i) * 6.0, 1.7, -2.0))

	var src := PowerPoint.new()
	src.point_id = "ch4_src"
	src.is_source = true
	src.position = base + Vector3(-5.0, 0, 3.0)
	add_child(src); power.register(src)
	var j := PowerPoint.new()
	j.point_id = "ch4_j"
	j.position = base + Vector3(3.0, 0, 1.0)
	add_child(j); power.register(j)
	_gen_sink = PowerPoint.new()
	_gen_sink.point_id = "ch4_dishes"
	_gen_sink.is_sink = true
	_gen_sink.position = base + Vector3(-16.0, 0, -8.0)
	add_child(_gen_sink); power.register(_gen_sink)

	# The long run to the dish field is superconducting only when FROZEN.
	var c1 := Conduit.new(); add_child(c1)
	c1.build(src.position + Vector3(0, 1.8, 0), j.position + Vector3(0, 1.8, 0),
		[Veil.State.MEMORY, Veil.State.RUIN], manager, false, 0.4)
	var c2 := Conduit.new(); add_child(c2)
	c2.build(j.position + Vector3(0, 1.8, 0), _gen_sink.position + Vector3(0, 1.8, 0),
		[], manager, true, 1.4)
	c2.imprint.accepted = [Veil.Prop.FROZEN, Veil.Prop.CONDUCTIVE]
	c2.imprint.label = "Long Run"
	var long_run_ok := func() -> bool:
		return c2.imprint != null and c2.imprint.current in [
			Veil.Prop.FROZEN, Veil.Prop.CONDUCTIVE]
	power.link("ch4_src", "ch4_j", Callable(c1, "is_conductive"), true, c1)
	power.link("ch4_j", "ch4_dishes", long_run_ok, true, c2)

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch4_generator"
	pz.title = "Long Run"
	pz.hint_subtle = "The cable to the dishes has too much resistance and too much length."
	pz.hint_guided = "Up here, cold is an advantage. Make the cable cold."
	pz.hint_directed = "Scan an ice pinnacle or the door plug for Frozen and imprint it onto the long run - a frozen line carries the load."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_gen_sink.powered_changed.connect(func(on: bool) -> void:
		if on:
			_flags.generator = true
			if not pz.is_solved:
				pz.mark_solved()
				say("Dish field has power. Storm front is inbound - if you want the record, start now.",
					"MOTE", 5.0)
			_arm_challenge())

	guardian(base + Vector3(-12.0, 0.4, 6.0), [
		base + Vector3(-12, 0.4, 6), base + Vector3(6, 0.4, 6),
		base + Vector3(6, 0.4, -8)])
	scannable(base + Vector3(4.0, 1.8, 3.0), "Night Watch Rota",
		"Two names per shift, all year. In the last month the second column is blank.")
	checkpoint("cp_generator", base + Vector3(0, 0.4, 5.0), 180.0)

# ---------------------------------------------------------------- dishes
func _build_dishes() -> void:
	var base := on_ground(0, -76)
	box(Vector3(46.0, 0.6, 30.0), "concrete", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 3:
		var p := base + Vector3(-15.0 + float(i) * 15.0, 0.2, 0)
		box(Vector3(2.4, 4.0, 2.4), "metal_dark", p + Vector3(0, 2.0, 0))
		var yoke := Node3D.new()
		yoke.position = p + Vector3(0, 4.2, 0)
		add_child(yoke)
		var dish := MeshInstance3D.new()
		dish.mesh = ProcAssets.ring_mesh(3.4, 1.4, 26, 10, PI)
		dish.material_override = ProcAssets.mat("metal")
		dish.rotation = Vector3(-0.6, 0, 0)
		yoke.add_child(dish)
		decor(ProcAssets.cylinder_mesh(0.12, 3.0, 8), "metal_rust",
			Vector3(0, 1.4, 0), Vector3.ZERO, Vector3.ONE, yoke)

		var valve := ValveWheel.new()
		valve.label = "Dish %d Elevation" % (i + 1)
		valve.stops = 4
		valve.start_step = [1, 2, 1][i]
		valve.position = p + Vector3(3.4, 0.2, 4.0)
		add_child(valve)
		var lamp := decor(ProcAssets.ring_mesh(0.34, 0.05, 16, 6),
			ProcAssets.emissive(Color(0.4, 0.4, 0.45), 0.4), p + Vector3(3.4, 1.6, 4.0))
		_dishes.append({"valve": valve, "yoke": yoke, "lamp": lamp, "index": i})
		valve.turned.connect(func(step: int, _t: int) -> void:
			var t := create_tween()
			t.tween_property(yoke, "rotation:x",
				-0.9 + float(step) * 0.35, 0.6).set_trans(Tween.TRANS_SINE)
			_check_dishes())

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch4_dishes"
	pz.title = "Dish Array"
	pz.hint_subtle = "Three dishes, four elevations each, and one correct set."
	pz.hint_guided = "The alignment is written down somewhere on this mountain. Scan the blueprint."
	pz.hint_directed = "Scan the Antenna Blueprint by the signal room for the elevations, then set the three wheels to match. They only hold when the field has power."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	pz.set_meta("dish_puzzle", true)
	_dish_puzzle = pz

	var sc := scannable(base + Vector3(0, 1.6, 12.0), "Antenna Blueprint",
		"Elevation set for the White Signal: dish one at stop three, dish two at stop one, dish three at stop four.")
	sc.xp_bonus = 120
	fragment(1, base + Vector3(-20.0, 1.0, -12.0))
	checkpoint("cp_dishes", base + Vector3(0, 0.4, 12.0), 180.0)

var _dish_puzzle: PuzzleBase

func _check_dishes() -> void:
	if _dish_puzzle == null or _dish_puzzle.is_solved:
		return
	var powered: bool = power.is_powered("ch4_dishes")
	var ok := powered
	for d in _dishes:
		var want: int = _dish_target[int(d.index)]
		var got: int = (d.valve as ValveWheel).step
		var hit := got == want and powered
		var mat := (d.lamp as MeshInstance3D).material_override as StandardMaterial3D
		var c := Color(0.45, 1.0, 0.6) if hit else Color(0.4, 0.4, 0.45)
		mat.albedo_color = c
		mat.emission = c
		mat.emission_energy_multiplier = 2.6 if hit else 0.4
		if not hit:
			ok = false
	if ok:
		_flags.dishes = true
		_dish_puzzle.mark_solved()
		if _challenge_armed and (GameState.run.get("time", 0.0) - _challenge_start) <= _storm_cycle:
			GameState.complete_challenge()
			say("Inside one front. That is the fastest anyone has ever aligned this array.",
				"MOTE", 4.0)
		say("Array is on the White Signal. The signal room will decode it.", "MOTE", 4.4)

func _arm_challenge() -> void:
	if _challenge_armed:
		return
	_challenge_armed = true
	_challenge_start = float(GameState.run.get("time", 0.0))

# ---------------------------------------------------------------- signal room
func _build_signal() -> void:
	var base := on_ground(0, -104)
	static_mesh(ProcAssets.room_shell(Vector3(18.0, 5.0, 14.0), 0.6, 3.4, 3.6, true, 0),
		"concrete_aged", base + Vector3(0, 2.8, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	for i in 6:
		decor(ProcAssets.box_mesh(Vector3(1.6, 2.2, 0.8)), "metal_dark",
			base + Vector3(-6.0 + float(i % 3) * 6.0, 1.1, -4.0 + float(i / 3) * 8.0))
	decor(ProcAssets.box_mesh(Vector3(4.0, 1.2, 1.0)),
		ProcAssets.emissive(Color(0.5, 0.9, 1.0), 1.2), base + Vector3(0, 1.4, -5.6))

	var it := Interactable.new()
	it.prompt = "Decode the White Signal"
	it.hold_time = 1.6
	it.one_shot = true
	it.position = base + Vector3(0, 1.4, -5.0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 2.6
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(base))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch4_signal"
	pz.title = "Signal Room"
	pz.hint_subtle = "The decoder is dark."
	pz.hint_guided = "It needs the array pointed correctly first."
	pz.hint_directed = "Align all three dishes, then use the decoder console."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(0, 2.0, 0), Vector3(12, 4, 10), func() -> void:
		if not pz.is_solved:
			pz.mark_solved())
	fragment(2, base + Vector3(6.0, 1.0, 4.0))
	hidden_marker(base + Vector3(-7.0, 1.0, 4.5))

func _finale(base: Vector3) -> void:
	if _signal_done:
		return
	_signal_done = true
	_flags.signal = true
	AudioDirector.play("machine_start", -2.0)
	SceneFlow.flash(Color(0.85, 0.95, 1.0, 0.3), 0.8)
	set_objective("White Signal decoded.")
	await cinematic(
		[base + Vector3(-22, 10, 22), base + Vector3(6, 14, 4), base + Vector3(0, 24, -20)],
		[base + Vector3(0, 3, 0), base + Vector3(0, 6, -6), base + Vector3(0, -4, -60)],
		10.0,
		[["It is a countdown. It has been a countdown the whole time.",
			"MOTE"],
		 ["The three realities are converging. When they meet there will be one world, and it will not be a stable one.",
			"MOTE"],
		 ["There is a machine in the desert that was built to stop exactly this. We are going to go and wake it up.",
			"MOTE"]])
	finish()

# ---------------------------------------------------------------- hooks
func on_begin(mode: String) -> void:
	player.device.unlock_all()
	if mode != "checkpoint":
		say("Minus thirty-one and falling. The suit will hold. Keep moving anyway.",
			"MOTE", 4.6)
	set_objective(String(info.objective))
	weather.set_intensity(0.4)

func ambience_profiles() -> Array:
	return ["blizzard", "wind", "machine"]

func ambience_volumes() -> Array:
	return [0.42, 0.34, 0.08]

func on_state_changed(s: int) -> void:
	AudioDirector.fade_ambience(0, [0.16, 0.48, 0.24][clampi(s, 0, 2)], 1.6)

func _process(dt: float) -> void:
	# Storm fronts sweep through on a cycle: visibility and guardian sight drop
	# together, which makes the front a resource rather than a nuisance.
	if not GameState.run.get("active", false):
		return
	_storm_phase = fposmod(_storm_phase + dt / _storm_cycle, 1.0)
	var front := pow(sin(_storm_phase * PI), 3.0)
	weather.set_intensity(0.25 + front * 0.75)
	if atmosphere:
		var env := atmosphere.environment
		if env:
			env.fog_density = lerpf(0.0022, 0.030, front)
			env.volumetric_fog_density = lerpf(0.008, 0.055, front)
	for g in guardians:
		if is_instance_valid(g):
			(g as Guardian).awareness = maxf(0.0,
				(g as Guardian).awareness - front * dt * 0.9)

func storm_intensity() -> float:
	return pow(sin(_storm_phase * PI), 3.0)

func save_flags() -> Dictionary:
	var f := _flags.duplicate()
	var steps: Array = []
	for d in _dishes:
		steps.append((d.valve as ValveWheel).step)
	f["dish_steps"] = steps
	return f

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	if flags.has("dish_steps"):
		var steps: Array = flags.dish_steps
		for i in mini(steps.size(), _dishes.size()):
			(_dishes[i].valve as ValveWheel).set_step(int(steps[i]))

func shot_spots() -> Array:
	return [
		{"name": "ridge", "pos": on_ground(30, 60, 16.0), "look": on_ground(0, 10, 10.0)},
		{"name": "channel", "pos": on_ground(26, -6, 12.0), "look": on_ground(0, -20, 6.0)},
		{"name": "dishes", "pos": on_ground(30, -60, 16.0), "look": on_ground(0, -80, 8.0)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "A frost-split lens, still in its case, with a card: 'Cracked 09/11. Refraction now doubles every source. Kept it. The double image is the only way we noticed the signal was arriving twice.'"
		1: return "Night watch rota. Two names a shift for four years, then one name, then a pencil line drawn down the remaining weeks and the words 'listening alone is still listening.'"
		2: return "An antenna blueprint annotated in three different hands. The last annotation reads: 'It is not coming from anywhere. It is coming from WHEN. Stop looking up. Start looking sideways.'"
	return ""
