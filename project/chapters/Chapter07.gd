extends ChapterBase
## CHAPTER 7 - ARCHIVE ZERO
## An interior chapter. The building is intact in all three states, so the
## puzzles stop being about traversal and start being about combining
## properties across states with no margin for a wasted imprint.

var _noise := FastNoiseLite.new()
var _flags := {"foyer": false, "stacks": false, "cold": false, "ledger": false,
	"triptych": false, "record": false, "gate": false, "origin": false}

var _fail_count_at_start := 0
var _origin_done := false
var _record_lock: ResonanceLock
var _gate: Gate
var _stack_shelves: Array = []
var _triptych_state := [0, 0, 0]
var _triptych_target := [Veil.State.MEMORY, Veil.State.RUIN, Veil.State.BLOOM]

# ---------------------------------------------------------------- terrain
func _h(x: float, z: float) -> float:
	# A flat plateau: this chapter is architecture, not landscape.
	var n := _noise
	var y := 0.0 + n.get_noise_2d(x * 0.5, z * 0.5) * 0.8
	var edge := clampf((Vector2(x, z).length() - 120.0) / 30.0, 0.0, 1.0)
	y -= edge * 40.0
	return y

func build_world() -> void:
	_noise.seed = 7707
	_noise.frequency = 0.012
	manager.base_state = Veil.State.RUIN
	spawn_yaw = PI

	SceneFlow.report(0.12, "Levelling the plateau")
	build_terrain(Vector2(300, 300), 180, Callable(self, "_h"), "archive",
		Veil.Surface.STONE)
	spawn_position = on_ground(0, 104, 1.2)
	await get_tree().process_frame

	SceneFlow.report(0.24, "Approach")
	_build_approach()
	await get_tree().process_frame

	SceneFlow.report(0.36, "Foyer")
	_build_foyer()
	await get_tree().process_frame

	SceneFlow.report(0.48, "The stacks")
	_build_stacks()
	await get_tree().process_frame

	SceneFlow.report(0.58, "Cold store")
	_build_cold()
	await get_tree().process_frame

	SceneFlow.report(0.68, "Ledger hall")
	_build_ledger()
	await get_tree().process_frame

	SceneFlow.report(0.78, "Triptych")
	_build_triptych()
	await get_tree().process_frame

	SceneFlow.report(0.88, "Record chamber")
	_build_record()
	_build_origin()
	await get_tree().process_frame

# ---------------------------------------------------------------- approach
func _corridor(from: Vector3, to: Vector3, w: float, h: float,
		mat: String = "concrete") -> void:
	var mid := (from + to) * 0.5
	var d := to - from
	var len := d.length()
	var yaw := atan2(d.x, d.z)
	box(Vector3(w + 1.2, 0.4, len), mat, mid + Vector3(0, -0.2, 0),
		Vector3(0, yaw, 0), Veil.Surface.STONE)
	box(Vector3(0.4, h, len), mat, mid + Vector3(0, h * 0.5, 0) +
		Vector3(cos(yaw), 0, -sin(yaw)) * (w * 0.5), Vector3(0, yaw, 0))
	box(Vector3(0.4, h, len), mat, mid + Vector3(0, h * 0.5, 0) -
		Vector3(cos(yaw), 0, -sin(yaw)) * (w * 0.5), Vector3(0, yaw, 0))
	box(Vector3(w + 1.2, 0.4, len), mat, mid + Vector3(0, h, 0),
		Vector3(0, yaw, 0), Veil.Surface.STONE)

func _build_approach() -> void:
	var base := on_ground(0, 104)
	box(Vector3(30.0, 0.6, 18.0), "tile", base + Vector3(0, -0.2, 0),
		Vector3.ZERO, Veil.Surface.STONE)
	for i in 8:
		decor(ProcAssets.cylinder_mesh(0.7, 9.0, 16), "concrete",
			base + Vector3(-12.0 + float(i % 4) * 8.0, 4.5, -4.0 + float(i / 4) * 8.0))
	decor(ProcAssets.box_mesh(Vector3(30.0, 1.6, 20.0)), "concrete",
		base + Vector3(0, 9.8, 0))
	scannable(base + Vector3(0, 1.6, 6.0), "Dedication Plate",
		"ARCHIVE ZERO. Nothing recorded here leaves here. Nothing recorded here is ever wrong.",
		Veil.Prop.RIGID, -1, 3.0)
	checkpoint("cp_approach", base + Vector3(0, 0.4, -6.0), 180.0)
	trigger(base + Vector3(0, 3, -10.0), Vector3(26, 8, 6), func() -> void:
		say("The building is intact in all three states. That should not be possible.",
			"MOTE", 5.2)
		say("Which means whoever built it knew about the Fracture before it happened.",
			"MOTE", 5.0))
	_corridor(base + Vector3(0, 0, -10.0), Vector3(0, base.y, 66.0), 8.0, 5.0)

# ---------------------------------------------------------------- foyer
func _build_foyer() -> void:
	var base := Vector3(0, on_ground(0, 60).y, 60.0)
	static_mesh(ProcAssets.room_shell(Vector3(28.0, 8.0, 24.0), 0.8, 6.0, 5.0, true, 1),
		"concrete", base + Vector3(0, 4.2, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)
	for i in 4:
		decor(ProcAssets.cylinder_mesh(0.9, 7.6, 18), "tile",
			base + Vector3(-8.0 + float(i % 2) * 16.0, 3.8, -6.0 + float(i / 2) * 12.0))

	# The inner door reads the visitor: it opens only for a device that has
	# recorded all three states in this room.
	_gate = Gate.new()
	_gate.size = Vector3(6.0, 5.0, 0.6)
	_gate.open_offset = Vector3(0, 5.2, 0)
	_gate.material_name = "metal"
	_gate.position = base + Vector3(0, 2.6, -12.2)
	add_child(_gate)

	var seen := {0: false, 1: false, 2: false}
	var reader := decor(ProcAssets.ring_mesh(1.1, 0.12, 24, 8),
		ProcAssets.emissive(Color(0.4, 0.4, 0.45), 0.4), base + Vector3(0, 3.0, -11.4))

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch7_foyer"
	pz.title = "Reader Arch"
	pz.hint_subtle = "The arch is watching what you are, not who."
	pz.hint_guided = "It wants to see all three realities from where you are standing."
	pz.hint_directed = "Stand in the foyer and shift the room to Memory, then Ruin, then Bloom. The arch opens once it has read all three."
	pz.position = base
	add_child(pz)
	pz.register_hints()

	trigger(base + Vector3(0, 3, 4.0), Vector3(24, 8, 18), func() -> void:
		say("The arch is a reader. Show it everything you can do.", "MOTE", 4.0), false)
	manager.local_state_changed.connect(func(s: int) -> void:
		if player.global_position.distance_to(base) > 20.0:
			return
		if seen.get(s, true):
			return
		seen[s] = true
		AudioDirector.play_3d("switch", get_tree().current_scene,
			reader.global_position, -6.0, 1.0 + 0.12 * float(s))
		var n := 0
		for k in seen.keys():
			if seen[k]: n += 1
		var mat := reader.material_override as StandardMaterial3D
		var c: Color = Settings.state_color(s)
		mat.albedo_color = c
		mat.emission = c
		mat.emission_energy_multiplier = 1.0 + float(n)
		if n >= 3 and not pz.is_solved:
			_flags.foyer = true
			_gate.open()
			pz.mark_solved()
			say("Read and admitted. It has been waiting a long time for someone with a device.",
				"MOTE", 4.6))
	fragment(0, base + Vector3(10.0, 1.0, 8.0))

# ---------------------------------------------------------------- stacks
func _build_stacks() -> void:
	var base := Vector3(0, on_ground(0, 26).y, 26.0)
	_corridor(Vector3(0, base.y, 46.0), Vector3(0, base.y, 38.0), 8.0, 5.0)
	static_mesh(ProcAssets.room_shell(Vector3(34.0, 9.0, 26.0), 0.8, 6.0, 5.0, true, 1),
		"concrete", base + Vector3(0, 4.8, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)

	# Rolling shelves. In Memory they are on their rails and can be pushed;
	# in Ruin they have collapsed into a barricade; in Bloom growth has lifted
	# them into a staircase.
	for i in 5:
		var p := base + Vector3(-12.0 + float(i) * 6.0, 0, 2.0)
		var mem := variant_group([
			variant_box(Vector3(4.4, 4.0, 1.2), "wood", Vector3(0, 2.0, 0),
				Vector3.ZERO, Veil.Surface.WOOD),
			variant_box(Vector3(4.4, 0.2, 1.4), "metal", Vector3(0, 0.1, 0),
				Vector3.ZERO, Veil.Surface.METAL)])
		var ruin := variant_mesh(ProcAssets.debris_mesh(1000 + i, 12, 2.4, 1.3),
			"wood", Vector3(0, 0.6, 0), Vector3.ZERO, Veil.Surface.WOOD)
		var bloom := variant_box(Vector3(4.4, 0.5, 2.6), "bark",
			Vector3(0, 0.8 + float(i) * 1.1, 0), Vector3.ZERO, Veil.Surface.WOOD)
		_stack_shelves.append(veil_subject("shelf_%d" % i, p, mem, ruin, bloom, 3.2))

	# The way on is a hatch four metres up.
	box(Vector3(5.0, 0.5, 5.0), "metal", base + Vector3(10.0, 5.6, -8.0),
		Vector3.ZERO, Veil.Surface.METAL)
	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch7_stacks"
	pz.title = "The Stacks"
	pz.hint_subtle = "The hatch is above the shelves, not past them."
	pz.hint_guided = "In one state the shelves are a staircase."
	pz.hint_directed = "Shift the stacks to Bloom. Growth has lifted the shelves into ascending steps - climb them to the hatch."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	trigger(base + Vector3(10.0, 6.6, -8.0), Vector3(6, 3, 6), func() -> void:
		_flags.stacks = true
		if not pz.is_solved:
			pz.mark_solved())
	scannable(base + Vector3(-14.0, 1.6, -8.0), "Reading Desk",
		"One chair, one lamp, one indentation in the wood where an elbow rested for years.")
	checkpoint("cp_stacks", base + Vector3(10.0, 6.0, -10.0), 180.0)

# ---------------------------------------------------------------- cold store
func _build_cold() -> void:
	var base := Vector3(0, on_ground(0, -6).y + 5.6, -6.0)
	static_mesh(ProcAssets.room_shell(Vector3(24.0, 6.0, 20.0), 0.7, 5.0, 4.4, true, 1),
		"metal_dark", base + Vector3(0, 3.2, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.METAL)
	for i in 6:
		decor(ProcAssets.box_mesh(Vector3(2.0, 3.0, 1.2)), "metal",
			base + Vector3(-8.0 + float(i % 3) * 8.0, 1.5, -5.0 + float(i / 3) * 10.0))

	# A hazard field of coolant vapour that only clears when the room is Frozen
	# solid - which is what the FROZEN imprint on the room core does.
	var haz := hazard(base + Vector3(0, 2.0, 0), Vector3(22, 4, 18),
		Tuning.HAZ_COLD_DPS * 2.4, "coolant vapour")
	var im := Imprintable.new()
	im.label = "Store Core"
	im.accepted = [Veil.Prop.FROZEN]
	im.position = base + Vector3(0, 1.2, -7.0)
	add_child(im)
	box(Vector3(1.6, 1.4, 1.6), "metal_dark", base + Vector3(0, 0.7, -7.0),
		Vector3.ZERO, Veil.Surface.METAL)

	var sc := scannable(base + Vector3(9.0, 1.6, 7.0), "Sample Cabinet",
		"Frost on the inside of the glass, in the shape of a hand.",
		Veil.Prop.FROZEN, -1, 2.6)
	sc.xp_bonus = 90

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch7_cold"
	pz.title = "Cold Store"
	pz.hint_subtle = "The vapour is the problem. It is a liquid that is not committed."
	pz.hint_guided = "Make the room's core properly frozen and the vapour has nowhere to go."
	pz.hint_directed = "Scan the sample cabinet for Frozen and imprint it onto the store core. The vapour settles out."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	im.imprinted.connect(func(_p: int) -> void:
		haz.set_meta("dps", 0.0)
		haz.set_deferred("monitorable", false)
		_flags.cold = true
		AudioDirector.play_3d("shift_memory", get_tree().current_scene,
			base, -4.0, 0.7)
		if not pz.is_solved:
			pz.mark_solved()
			say("Vapour is out of the air and onto the walls. Do not lean on anything.",
				"MOTE", 4.0))
	component(base + Vector3(-9.0, 1.0, 7.0))

# ---------------------------------------------------------------- ledger
func _build_ledger() -> void:
	var base := Vector3(0, on_ground(0, -38).y + 5.6, -38.0)
	static_mesh(ProcAssets.room_shell(Vector3(30.0, 8.0, 24.0), 0.8, 5.0, 4.6, true, 1),
		"concrete", base + Vector3(0, 4.2, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)

	# Four plinths. Each takes a property, but only three are correct, and a
	# wrong imprint is consumed - hence the "no failed imprint" challenge.
	var wants := [Veil.Prop.RESONANT, Veil.Prop.CONDUCTIVE, Veil.Prop.LUMINOUS]
	var lock := ResonanceLock.new()
	lock.position = base + Vector3(0, 0.2, 8.0)
	add_child(lock)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var p := base + Vector3(cos(a) * 8.0, 0.2, sin(a) * 8.0 - 2.0)
		box(Vector3(1.3, 1.1, 1.3), "tile", p + Vector3(0, 0.55, 0),
			Vector3.ZERO, Veil.Surface.STONE)
		var im := Imprintable.new()
		im.label = ["Tone Plinth", "Current Plinth", "Light Plinth"][i]
		im.accepted = [wants[i]]
		im.hold_seconds = 150.0
		im.position = p + Vector3(0, 1.2, 0)
		add_child(im)
		var want: int = wants[i]
		lock.add_condition(func() -> bool: return im.current == want,
			Veil.prop_name(want))
	lock.hint_subtle = "Three plinths, three different appetites, and they do not say which."
	lock.hint_guided = "Their labels are the answer: tone, current, light."
	lock.hint_directed = "Imprint Resonant on the tone plinth, Conductive on the current plinth and Luminous on the light plinth. A wrong imprint is spent, so read the labels first."
	lock.register_hints()
	lock.solved.connect(func(_p: bool) -> void:
		_flags.ledger = true
		say("Ledger hall is open. The record chamber is behind it.", "MOTE", 4.0))

	# A resonant source: the archive's own carrier tone, audible only in Memory.
	var bell_mem := variant_mesh(ProcAssets.ring_mesh(1.6, 0.24, 26, 8), "brass",
		Vector3.ZERO, Vector3(PI * 0.5, 0, 0), Veil.Surface.METAL)
	veil_subject("carrier_bell", base + Vector3(-11.0, 2.0, 8.0), bell_mem, null, null, 3.0)
	var sc := scannable(base + Vector3(-11.0, 2.0, 8.0), "Carrier Bell",
		"It holds the Veilforge tone indefinitely and does not seem to mind.",
		Veil.Prop.RESONANT, Veil.State.MEMORY, 3.0)
	sc.xp_bonus = 110
	var sc2 := scannable(base + Vector3(11.0, 2.0, 8.0), "Standing Lamp",
		"Filament intact, no supply, still lit.",
		Veil.Prop.LUMINOUS, -1, 2.6)
	sc2.xp_bonus = 80
	fragment(1, base + Vector3(0, 1.0, -9.0))
	checkpoint("cp_ledger", base + Vector3(0, 0.4, 9.0), 180.0)

# ---------------------------------------------------------------- triptych
func _build_triptych() -> void:
	var base := Vector3(0, on_ground(0, -66).y + 5.6, -66.0)
	static_mesh(ProcAssets.room_shell(Vector3(32.0, 9.0, 22.0), 0.8, 5.0, 4.6, true, 1),
		"concrete", base + Vector3(0, 4.7, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.STONE)

	# Three alcoves, each of which must be held in a *different* state at once.
	# The player has one movable field and one pin, so the third has to be the
	# world's base state: this is the chapter's hardest idea.
	var frames: Array = []
	for i in 3:
		var p := base + Vector3(-10.0 + float(i) * 10.0, 0, -7.0)
		box(Vector3(6.0, 6.0, 1.0), "tile", p + Vector3(0, 3.0, -1.0))
		var glyph := decor(ProcAssets.ring_mesh(1.5, 0.16, 24, 8),
			ProcAssets.emissive(Color(0.35, 0.35, 0.4), 0.4), p + Vector3(0, 3.0, -0.3))
		frames.append({"pos": p, "glyph": glyph, "index": i})

	var pz := PuzzleBase.new()
	pz.puzzle_id = "ch7_triptych"
	pz.title = "Triptych"
	pz.hint_subtle = "Three alcoves. Three different states. At the same time."
	pz.hint_guided = "You can hold two fields at once - the one you aim and the one you pin. The third alcove has to be the world's own state."
	pz.hint_directed = "Set the base state by shifting the whole hall, pin a field on the second alcove, and hold the aimed field on the third. Left wants Memory, centre wants Ruin, right wants Bloom."
	pz.position = base
	add_child(pz)
	pz.register_hints()
	_triptych_frames = frames
	_triptych_puzzle = pz
	fragment(2, base + Vector3(12.0, 1.0, 6.0))
	hidden_marker(base + Vector3(-12.0, 1.0, 6.0))

var _triptych_frames: Array = []
var _triptych_puzzle: PuzzleBase

func _check_triptych() -> void:
	if _triptych_puzzle == null or _triptych_puzzle.is_solved:
		return
	var all_ok := true
	for f in _triptych_frames:
		var s := manager.state_at((f.pos as Vector3) + Vector3(0, 1.5, 0))
		var want: int = _triptych_target[int(f.index)]
		var ok := s == want
		var mat := (f.glyph as MeshInstance3D).material_override as StandardMaterial3D
		var c: Color = Settings.state_color(want) if ok else Color(0.35, 0.35, 0.4)
		mat.albedo_color = c
		mat.emission = c
		mat.emission_energy_multiplier = 3.0 if ok else 0.4
		if not ok:
			all_ok = false
	if all_ok:
		_flags.triptych = true
		_triptych_puzzle.mark_solved()
		say("All three at once. That is the trick the Fracture pulled, at planetary scale.",
			"MOTE", 5.0)

# ---------------------------------------------------------------- record
func _build_record() -> void:
	var base := Vector3(0, on_ground(0, -94).y + 5.6, -94.0)
	static_mesh(ProcAssets.room_shell(Vector3(26.0, 9.0, 22.0), 0.9, 5.0, 4.6, true, 1),
		"metal_dark", base + Vector3(0, 4.8, 0), Vector3.ZERO, Vector3.ONE,
		Veil.Surface.METAL)
	for i in 5:
		decor(ProcAssets.ring_mesh(7.0 - float(i) * 1.0, 0.3, 28, 8), "brass",
			base + Vector3(0, 1.5 + float(i) * 1.6, 0))

	_record_lock = ResonanceLock.new()
	_record_lock.position = base + Vector3(0, 0.2, 7.0)
	add_child(_record_lock)
	_record_lock.add_condition(func() -> bool: return bool(_flags.get("ledger", false)),
		"Ledger opened")
	_record_lock.add_condition(func() -> bool: return bool(_flags.get("triptych", false)),
		"Triptych held")
	_record_lock.add_condition(func() -> bool: return bool(_flags.get("cold", false)),
		"Store stabilised")
	_record_lock.hint_subtle = "The chamber will not read until the archive is whole."
	_record_lock.hint_guided = "The ledger, the triptych and the cold store all feed this room."
	_record_lock.hint_directed = "Finish the ledger plinths, hold the triptych in three states, and freeze the cold store. Then the record plays."
	_record_lock.register_hints()
	_record_lock.solved.connect(func(_p: bool) -> void:
		_flags.record = true
		_flags.gate = true
		say("Record reconstructed. Playing it.", "MOTE", 3.4))

	var it := Interactable.new()
	it.prompt = "Play the Fracture record"
	it.hold_time = 1.8
	it.one_shot = true
	it.position = base + Vector3(0, 1.4, 0)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 3.4
	cs.shape = sp
	it.add_child(cs)
	add_child(it)
	it.used.connect(func(_b: Node) -> void: _finale(base))
	_record_interact = it
	it.enabled = false
	_record_lock.solved.connect(func(_p: bool) -> void: it.enabled = true)
	checkpoint("cp_record", base + Vector3(0, 0.4, 8.0), 180.0)

var _record_interact: Interactable

func _build_origin() -> void:
	# Corridors linking every hall, so the archive reads as one building.
	var y := on_ground(0, 0).y
	_corridor(Vector3(0, y + 5.6, 14.0), Vector3(0, y + 5.6, 4.0), 6.0, 4.4, "metal_dark")
	_corridor(Vector3(0, y + 5.6, -16.0), Vector3(0, y + 5.6, -26.0), 6.0, 4.4)
	_corridor(Vector3(0, y + 5.6, -50.0), Vector3(0, y + 5.6, -55.0), 6.0, 4.4)
	_corridor(Vector3(0, y + 5.6, -77.0), Vector3(0, y + 5.6, -83.0), 6.0, 4.4, "metal_dark")
	guardian(Vector3(8, y + 5.8, -50.0), [
		Vector3(8, y + 5.8, -50.0), Vector3(-8, y + 5.8, -50.0)])

func _finale(base: Vector3) -> void:
	if _origin_done:
		return
	_origin_done = true
	_flags.origin = true
	AudioDirector.play("machine_start", -2.0)
	SceneFlow.flash(Color(0.9, 0.9, 1.0, 0.35), 1.0)
	set_objective("Fracture record reconstructed.")
	if int(GameState.run.get("imprint_fails", 0)) <= _fail_count_at_start:
		GameState.complete_challenge()
		say("Not one wasted imprint in the whole archive. The building noticed.",
			"MOTE", 4.0)
	await cinematic(
		[base + Vector3(-18, 6, 20), base + Vector3(6, 10, 6), base + Vector3(0, 16, -18)],
		[base + Vector3(0, 4, 0), base + Vector3(0, 5, 0), base + Vector3(0, 3, -40)],
		12.0,
		[["The climate engine was already built. They only had to switch it on.",
			"MOTE"],
		 ["It runs by holding a location in three states at once and averaging them. Memory for what the world was, Bloom for what it could be, Ruin for what it is.",
			"MOTE"],
		 ["The Fracture was not an accident. It was the first second of the engine starting, and then nobody completed the sequence.",
			"MOTE"],
		 ["Someone has to finish it. There is exactly one of us here.", "MOTE"]])
	finish()

# ---------------------------------------------------------------- hooks
func _process(_dt: float) -> void:
	if GameState.run.get("active", false):
		_check_triptych()

func on_begin(mode: String) -> void:
	player.device.unlock_all()
	_fail_count_at_start = int(GameState.run.get("imprint_fails", 0))
	if mode != "checkpoint":
		say("Archive Zero. No windows, no dust, and the lights came on when we arrived.",
			"MOTE", 5.2)
	set_objective(String(info.objective))
	weather.set_intensity(0.1)

func ambience_profiles() -> Array:
	return ["cave", "machine"]

func ambience_volumes() -> Array:
	return [0.34, 0.22]

func on_state_changed(s: int) -> void:
	AudioDirector.fade_ambience(1, [0.30, 0.18, 0.12][clampi(s, 0, 2)], 1.4)

func save_flags() -> Dictionary:
	return _flags.duplicate()

func load_flags(flags: Dictionary) -> void:
	for k in _flags.keys():
		if flags.has(k):
			_flags[k] = bool(flags[k])
	if bool(_flags.get("foyer", false)) and _gate:
		_gate.open()
	if bool(_flags.get("record", false)) and _record_interact:
		_record_interact.enabled = true

func shot_spots() -> Array:
	var y := on_ground(0, 0).y
	return [
		{"name": "approach", "pos": Vector3(22, y + 10, 118), "look": Vector3(0, y + 4, 70)},
		{"name": "stacks", "pos": Vector3(14, y + 8, 40), "look": Vector3(0, y + 3, 22)},
		{"name": "record", "pos": Vector3(12, y + 10, -80), "look": Vector3(0, y + 7, -94)},
	]

func fragment_text(idx: int) -> String:
	match idx:
		0: return "Founder's annotation, in the margin of a feasibility study: 'Objection noted: we do not know what the third state IS. Response: neither does the planet, and it is going to have one anyway. Better we choose it.'"
		1: return "A rejected proposal, stamped twice. 'Proposal 14: run the engine at one percent for a century. REJECTED - insufficient effect within the lifetime of the committee.' Under the stamp, in pencil: 'insufficient effect within the lifetime of the committee is the whole problem.'"
		2: return "The last shift roster. Nine names. Eight are crossed through with the note RELEASED. The ninth has no note and no crossing, and the handwriting on that line is the same as the pencil in the margin of Proposal 14."
	return ""
