extends Node3D
class_name ChapterBase
## Base class and construction kit for the eight chapters.
##
## A chapter script overrides `build_world()` and calls the helpers here to
## place terrain, structures, veil subjects, puzzles, guardians, collectibles
## and triggers. Everything is generated at load time, so chapters are compact,
## readable data rather than binary scene files.

signal objective_set(text: String)
signal chapter_complete()
signal checkpoint_saved(id: String)
signal dialogue(text: String, speaker: String, duration: float)

var index: int = 0
var info: Dictionary = {}
var manager: VeilManager
var atmosphere: Atmosphere
var weather: Weather
var vegetation: Vegetation
var terrain: Terrain
var player: Player
var cam: PlayerCamera
var mote: Mote
var power: PowerNet

var spawn_position := Vector3(0, 2, 0)
var spawn_yaw := 0.0
var checkpoints: Array = []
var active_checkpoint: Dictionary = {}
var puzzles: Array = []
var guardians: Array = []
var _finished := false
var _time_trial := false
var _seq_step := 0
var rng := RandomNumberGenerator.new()

# ================================================================ lifecycle
func setup(p_index: int) -> void:
	index = p_index
	info = ChapterDB.get_chapter(index)
	rng.seed = 0x1000 + index * 7919
	name = "Chapter%02d" % (index + 1)

## Called by Game.gd. Yields between phases so the loading bar can move.
func construct(p_player: Player, p_cam: PlayerCamera, p_mote: Mote) -> void:
	player = p_player
	cam = p_cam
	mote = p_mote

	manager = VeilManager.new()
	manager.base_state = Veil.State.RUIN
	add_child(manager)
	manager.set_player(player)

	power = PowerNet.new()
	add_child(power)

	vegetation = Vegetation.new()
	add_child(vegetation)
	if Log.skipping("veg"):
		vegetation.set_process(false)

	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(build_palettes(), manager.base_state)

	weather = Weather.new()
	add_child(weather)

	SceneFlow.report(0.10, "Shaping terrain")
	await get_tree().process_frame
	await build_world()

	SceneFlow.report(0.86, "Placing systems")
	await get_tree().process_frame
	if not Log.skipping("weather"):
		weather.setup(String(info.get("weather", "none")), player, vegetation)
	manager.local_state_changed.connect(_on_local_state)
	_on_local_state(manager.base_state)

	for n in _all_nodes(self):
		if n is VeilSubject:
			manager.register(n)
		elif n is Guardian:
			if Log.skipping("guardians"):
				(n as Guardian).queue_free()
				continue
			(n as Guardian).bind(player, manager)
			guardians.append(n)
		elif n is PuzzleBase:
			puzzles.append(n)

	# Never let a chapter start the player inside or under the ground.
	if terrain != null:
		var g := terrain.height_at(spawn_position.x, spawn_position.z)
		if spawn_position.y < g + 0.5:
			spawn_position.y = g + 1.2

	SceneFlow.report(0.96, "Final checks")
	await get_tree().process_frame

func begin_play(mode: String) -> void:
	_time_trial = mode == "time_trial"
	GameState.run["time_trial"] = _time_trial
	set_objective(String(info.get("objective", "")))
	configure_audio()
	on_begin(mode)

## Overridden by chapters.
func build_world() -> void:
	await get_tree().process_frame

func build_palettes() -> Array:
	var mem: Color = info.get("sky_memory", Color(0.7, 0.8, 0.9))
	var ruin: Color = info.get("sky_ruin", Color(0.4, 0.42, 0.48))
	var bloom: Color = info.get("sky_bloom", Color(0.5, 0.8, 0.6))
	return [
		# MEMORY - clean, high, slightly cool. Long sightlines, crisp shadows.
		Atmosphere.palette(mem.darkened(0.42), mem, mem.lightened(0.06),
			Color(1.0, 0.97, 0.90), 2.6, 0.0010, 0.0045,
			{"saturation": 0.96, "contrast": 1.06, "glow": 0.5, "exposure": 1.0,
			 "sun_pitch": -54.0, "sun_yaw": 28.0, "fill_energy": 0.26,
			 "ambient": 0.80, "fog_begin": 70.0, "fog_end": 900.0, "sky_energy": 0.95,
			 "fog_aerial": 0.05}),
		# RUIN - heavy, desaturated, low sun. Air you can see.
		Atmosphere.palette(ruin.darkened(0.5), ruin, ruin.lightened(0.02),
			Color(0.94, 0.89, 0.83), 1.5, 0.0022, 0.0090,
			{"saturation": 0.80, "contrast": 1.14, "glow": 0.30, "exposure": 0.95,
			 "sun_pitch": -30.0, "sun_yaw": 64.0, "fill_energy": 0.14,
			 "ambient": 0.62, "fog_begin": 34.0, "fog_end": 560.0, "sky_energy": 0.7,
			 "fog_aerial": 0.10}),
		# BLOOM - warm, saturated, dappled. Mid fog for depth between canopies.
		Atmosphere.palette(bloom.darkened(0.44), bloom, bloom.lightened(0.05),
			Color(1.0, 0.98, 0.88), 2.2, 0.0016, 0.0070,
			{"saturation": 1.16, "contrast": 1.08, "glow": 0.55, "exposure": 1.0,
			 "sun_pitch": -48.0, "sun_yaw": 16.0, "fill_energy": 0.24,
			 "ambient": 0.78, "fog_begin": 50.0, "fog_end": 700.0, "sky_energy": 0.9,
			 "fog_aerial": 0.07}),
	]

func configure_audio() -> void:
	AudioDirector.configure_music(60.0 + index * 2.0, 45.0 - (index % 3) * 2.0,
		["aeolian", "dorian", "lydian", "phrygian", "pentatonic", "aeolian", "harmonic", "lydian"][index],
		1000 + index * 37)
	AudioDirector.set_state_tint(manager.base_state)
	AudioDirector.set_intensity(0.08)
	AudioDirector.set_ambience(ambience_profiles(), ambience_volumes())

func ambience_profiles() -> Array:
	return ["wind", "wind_high"]

func ambience_volumes() -> Array:
	return [0.42, 0.18]

func on_begin(mode: String) -> void:
	pass

func _on_local_state(s: int) -> void:
	if atmosphere:
		atmosphere.set_state(s)
	AudioDirector.set_state_tint(s)
	on_state_changed(s)

func on_state_changed(s: int) -> void:
	pass

# ================================================================ construction
func _all_nodes(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out

func _mat(name_or_mat: Variant) -> Material:
	if name_or_mat is Material:
		return name_or_mat
	return ProcAssets.mat(String(name_or_mat))

## Static mesh with automatic trimesh collision.
func static_mesh(mesh: Mesh, mat: Variant, pos: Vector3,
		rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE,
		surface: int = Veil.Surface.STONE, layer: int = Veil.L_WORLD,
		collision: bool = true, parent: Node = null,
		convex: bool = false) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer if collision else 0
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation = rot
	sb.scale = scale
	sb.set_meta("surface", surface)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	sb.add_child(mi)
	if collision:
		var cs := CollisionShape3D.new()
		cs.shape = ProcAssets.convex_shape(mesh) if convex else ProcAssets.trimesh_shape(mesh)
		sb.add_child(cs)
	(parent if parent else self).add_child(sb)
	return sb

## Box primitive with an exact box collider (cheaper than a trimesh).
func box(size: Vector3, mat: Variant, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		surface: int = Veil.Surface.STONE, layer: int = Veil.L_WORLD,
		parent: Node = null, uv: float = 0.8) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation = rot
	sb.set_meta("surface", surface)
	var mi := MeshInstance3D.new()
	mi.mesh = ProcAssets.box_mesh(size, uv)
	mi.material_override = _mat(mat)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	(parent if parent else self).add_child(sb)
	return sb

func decor(mesh: Mesh, mat: Variant, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		scale: Vector3 = Vector3.ONE, parent: Node = null,
		shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi

## Rocks reuse a small pool of base meshes and vary by scale and rotation, so
## meshes and their convex collision shapes stay cached instead of unique.
func rock(pos: Vector3, size: float, seed_v: int = -1, mat: String = "rock",
		parent: Node = null) -> StaticBody3D:
	var s := (seed_v if seed_v >= 0 else rng.randi_range(1, 9999)) % 10
	var m := ProcAssets.rock_mesh(s, 1.0, 0.36, 10, 14, 0.62 + 0.04 * float(s % 6))
	return static_mesh(m, mat, pos, Vector3(rng.randf_range(-0.2, 0.2),
		rng.randf_range(0, TAU), rng.randf_range(-0.2, 0.2)),
		Vector3.ONE * size, Veil.Surface.STONE, Veil.L_WORLD, true, parent, true)

func tree(pos: Vector3, height: float, radius: float, seed_v: int,
		bark: String = "bark", leaf: String = "foliage",
		parent: Node = null, canopy_scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	(parent if parent else self).add_child(root)
	var trunk_m := ProcAssets.trunk_mesh(seed_v, height, radius, 0.22, 8, 8, 0.4)
	var sb := StaticBody3D.new()
	sb.collision_layer = Veil.L_WORLD
	sb.set_meta("surface", Veil.Surface.WOOD)
	var mi := MeshInstance3D.new()
	mi.mesh = trunk_m
	mi.material_override = ProcAssets.mat(bark)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = radius * 0.85
	cy.height = height
	cs.shape = cy
	cs.position.y = height * 0.5
	sb.add_child(cs)
	root.add_child(sb)
	var canopy := MeshInstance3D.new()
	canopy.mesh = ProcAssets.canopy_mesh(seed_v, radius * 7.0 * canopy_scale, 5)
	canopy.material_override = ProcAssets.mat(leaf)
	canopy.position.y = height * 0.94
	root.add_child(canopy)
	return root

## Organic tube run: Bloom roots, vines, cables, pipes.
func tube(points: PackedVector3Array, radius: float, mat: Variant,
		key: String, collision: bool = true, surface: int = Veil.Surface.RESIN,
		parent: Node = null) -> Node3D:
	var radii := PackedFloat32Array()
	for i in points.size():
		var t := float(i) / maxf(float(points.size() - 1), 1.0)
		radii.append(radius * (0.7 + 0.55 * sin(t * PI)))
	var m := ProcAssets.tube_mesh(key, points, radii, 8, 0.35)
	return static_mesh(m, mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE,
		surface, Veil.L_WORLD, collision, parent)

## Climbable face - a thin static body on the climb layer.
func climb_surface(size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		parent: Node = null) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Veil.L_CLIMB
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation = rot
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	# Visible handholds so the route reads without a HUD marker.
	var n := maxi(2, int(size.y / 0.9))
	for i in n:
		var hold := MeshInstance3D.new()
		hold.mesh = ProcAssets.box_mesh(Vector3(0.34, 0.07, 0.14))
		hold.material_override = ProcAssets.emissive(Color(0.85, 0.72, 0.35), 0.5)
		hold.position = Vector3(sin(float(i) * 1.7) * size.x * 0.28,
			-size.y * 0.5 + size.y * (float(i) + 0.5) / float(n), size.z * 0.55)
		sb.add_child(hold)
	(parent if parent else self).add_child(sb)
	return sb

## Register a three-state object. Any variant may be null.
func veil_subject(id: String, pos: Vector3, mem: Node3D, ruin: Node3D, bloom: Node3D,
		influence: float = 0.0, parent: Node = null) -> VeilSubject:
	var vs := VeilSubject.new()
	vs.subject_id = id
	vs.position = pos
	vs.influence_radius = influence
	(parent if parent else self).add_child(vs)
	vs.setup(mem, ruin, bloom, manager.base_state)
	return vs

## Convenience: wrap a mesh+collision into a Node3D suitable for a veil variant.
func variant_box(size: Vector3, mat: Variant, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO, surface: int = Veil.Surface.STONE,
		layer: int = Veil.L_WORLD) -> Node3D:
	var root := Node3D.new()
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.set_meta("surface", surface)
	var mi := MeshInstance3D.new()
	mi.mesh = ProcAssets.box_mesh(size, 0.8)
	mi.material_override = _mat(mat)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation = rot
	root.add_child(sb)
	return root

func variant_mesh(mesh: Mesh, mat: Variant, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO, surface: int = Veil.Surface.STONE,
		collision: bool = true, layer: int = Veil.L_WORLD) -> Node3D:
	var root := Node3D.new()
	var sb := StaticBody3D.new()
	sb.collision_layer = layer if collision else 0
	sb.set_meta("surface", surface)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(mat)
	sb.add_child(mi)
	if collision:
		var cs := CollisionShape3D.new()
		cs.shape = ProcAssets.trimesh_shape(mesh)
		sb.add_child(cs)
	sb.position = pos
	sb.rotation = rot
	root.add_child(sb)
	return root

func variant_group(nodes: Array) -> Node3D:
	var root := Node3D.new()
	for n in nodes:
		if n != null:
			root.add_child(n)
	return root

# ================================================================ gameplay props
func scannable(pos: Vector3, display: String, note: String,
		prop: int = Veil.Prop.NONE, prop_state: int = -1, radius: float = 1.4,
		wildlife: bool = false, parent: Node = null) -> Scannable:
	var s := Scannable.new()
	s.display_name = display
	s.note = note
	s.property = prop
	s.property_state = prop_state
	s.is_wildlife = wildlife
	s.unique_id = "%s_%s" % [info.get("id", "ch"), display.to_snake_case()]
	s.position = pos
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = radius
	cs.shape = sp
	s.add_child(cs)
	(parent if parent else self).add_child(s)
	return s

func fragment(idx: int, pos: Vector3, parent: Node = null) -> Collectible:
	var c := Collectible.new()
	c.kind = Collectible.Kind.FRAGMENT
	c.index = idx
	c.chapter = index
	c.title = String(info.fragments[clampi(idx, 0, 2)])
	c.text = fragment_text(idx)
	c.position = pos
	(parent if parent else self).add_child(c)
	c.collected.connect(func(kind: String, i: int) -> void:
		dialogue.emit("Memory Fragment recovered: %s" % c.title, "SYSTEM", 3.2))
	return c

func fragment_text(idx: int) -> String:
	return ""

func component(pos: Vector3, parent: Node = null) -> Collectible:
	var c := Collectible.new()
	c.kind = Collectible.Kind.COMPONENT
	c.chapter = index
	c.title = String(info.component)
	c.position = pos
	(parent if parent else self).add_child(c)
	c.collected.connect(func(kind: String, i: int) -> void:
		dialogue.emit("Upgrade component acquired: %s" % c.title, "SYSTEM", 3.4))
	return c

func hidden_marker(pos: Vector3, parent: Node = null) -> Collectible:
	var c := Collectible.new()
	c.kind = Collectible.Kind.HIDDEN
	c.chapter = index
	c.position = pos
	(parent if parent else self).add_child(c)
	c.collected.connect(func(kind: String, i: int) -> void:
		dialogue.emit("Hidden area surveyed.", "MOTE", 2.6))
	return c

func wildlife(pos: Vector3, display: String, note: String, parent: Node = null) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	(parent if parent else self).add_child(root)
	var m := MeshInstance3D.new()
	m.mesh = ProcAssets.rock_mesh(rng.randi_range(1, 900), 0.26, 0.45, 8, 12, 0.62)
	m.material_override = ProcAssets.emissive(Color(0.5, 0.95, 0.7), 0.55)
	root.add_child(m)
	var s := scannable(Vector3.ZERO, display, note, Veil.Prop.NONE, -1, 1.6, true, root)
	s.xp_bonus = 90
	return root

func checkpoint(id: String, pos: Vector3, yaw: float = 0.0,
		parent: Node = null) -> Checkpoint:
	var cp := Checkpoint.new()
	cp.id = id
	cp.position = pos
	cp.respawn_yaw = yaw
	cp.respawn_offset = Vector3(0, 0.2, 0)
	(parent if parent else self).add_child(cp)
	cp.reached.connect(_on_checkpoint)
	checkpoints.append(cp)
	return cp

func _on_checkpoint(id: String) -> void:
	for cp in checkpoints:
		if (cp as Checkpoint).id == id:
			var t: Dictionary = (cp as Checkpoint).respawn_transform()
			active_checkpoint = {"id": id, "pos": t.pos, "yaw": t.yaw}
			player.set_spawn(t.pos, t.yaw)
			GameState.store_checkpoint(index, id, {
				"pos": [t.pos.x, t.pos.y, t.pos.z], "yaw": t.yaw,
				"base_state": manager.base_state, "flags": save_flags()})
			checkpoint_saved.emit(id)
			return

## Chapters override these to persist their own switch/gate state.
func save_flags() -> Dictionary:
	return {}

func load_flags(flags: Dictionary) -> void:
	pass

func trigger(pos: Vector3, size: Vector3, on_enter: Callable,
		once: bool = true, parent: Node = null) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = Veil.L_TRIGGER
	a.collision_mask = Veil.L_PLAYER
	a.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	(parent if parent else self).add_child(a)
	var fired := {"v": false}
	a.body_entered.connect(func(b: Node3D) -> void:
		if not (b is Player):
			return
		if once and fired.v:
			return
		fired.v = true
		on_enter.call())
	return a

func hazard(pos: Vector3, size: Vector3, dps: float, kind: String,
		lethal: bool = false, parent: Node = null) -> Hazard:
	var h := Hazard.new()
	h.position = pos
	h.configure(dps, kind)
	h.lethal = lethal
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	h.add_child(cs)
	(parent if parent else self).add_child(h)
	return h

func guardian(pos: Vector3, patrol: Array = [], yaw: float = 0.0,
		start_state: int = Guardian.St.PATROL, parent: Node = null) -> Guardian:
	var g := Guardian.new()
	g.position = pos
	g.home_yaw = yaw
	g.start_state = start_state
	var pts: Array[Vector3] = []
	for p in patrol:
		pts.append(p as Vector3)
	g.patrol_points = pts
	(parent if parent else self).add_child(g)
	return g

func prop(pos: Vector3, size: Vector3, label: String, mass: float = 45.0,
		mat: String = "wood", parent: Node = null) -> PhysicsProp:
	var p := PhysicsProp.new()
	p.position = pos
	p.size = size
	p.label = label
	p.prop_mass = mass
	p.material_name = mat
	(parent if parent else self).add_child(p)
	return p

# ================================================================ direction
func set_objective(text: String) -> void:
	Hints.set_objective(text)
	objective_set.emit(text)

func say(text: String, speaker: String = "MOTE", duration: float = 4.0) -> void:
	if mote:
		mote.say(text, speaker, duration)
	dialogue.emit(text, speaker, duration)

func say_now(text: String, speaker: String = "MOTE", duration: float = 4.0) -> void:
	if mote:
		mote.say_now(text, speaker, duration)
	dialogue.emit(text, speaker, duration)

## In-engine cinematic: fly a temporary camera along key points, then hand back.
func cinematic(points: Array, look_at_points: Array, duration: float,
		lines: Array = []) -> void:
	if points.size() < 2:
		return
	AudioDirector.cutscene_mode(true)
	player.set_cutscene(true)
	var c := Camera3D.new()
	c.fov = 46.0
	c.near = 0.08
	c.far = 900.0
	add_child(c)
	c.global_position = points[0]
	c.current = true
	var elapsed := 0.0
	var line_i := 0
	while elapsed < duration:
		var dt := get_process_delta_time()
		elapsed += dt
		var t := clampf(elapsed / duration, 0.0, 1.0)
		var seg := t * float(points.size() - 1)
		var i := clampi(int(seg), 0, points.size() - 2)
		var f := smoothstep(0.0, 1.0, seg - float(i))
		c.global_position = (points[i] as Vector3).lerp(points[i + 1] as Vector3, f)
		var la_i := clampi(int(t * float(look_at_points.size() - 1)), 0,
			maxi(0, look_at_points.size() - 2))
		var la: Vector3 = (look_at_points[la_i] as Vector3).lerp(
			look_at_points[mini(la_i + 1, look_at_points.size() - 1)] as Vector3, f)
		if c.global_position.distance_to(la) > 0.05:
			c.look_at(la, Vector3.UP)
		if line_i < lines.size() and t >= float(line_i + 1) / float(lines.size() + 1):
			var ln: Array = lines[line_i]
			say_now(String(ln[0]), String(ln[1]), duration / float(lines.size() + 1))
			line_i += 1
		await get_tree().process_frame
	c.current = false
	c.queue_free()
	cam.camera.current = true
	player.set_cutscene(false)
	AudioDirector.cutscene_mode(false)

func finish() -> void:
	if _finished:
		return
	_finished = true
	AudioDirector.set_intensity(0.0)
	chapter_complete.emit()

func is_finished() -> bool:
	return _finished

# ================================================================ helpers
## Build the chapter's terrain with the biome-appropriate layered material.
func build_terrain(size: Vector2, res: int, height_fn: Callable,
		biome: String = "", surface: int = Veil.Surface.STONE) -> Terrain:
	var b := biome if biome != "" else String(info.get("biome", "valley"))
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(size, res, height_fn, ProcAssets.terrain_material(b), surface)
	return terrain

func ground_y(x: float, z: float, fallback: float = 0.0) -> float:
	if terrain:
		return terrain.height_at(x, z)
	return fallback

func on_ground(x: float, z: float, extra: float = 0.0) -> Vector3:
	return Vector3(x, ground_y(x, z) + extra, z)

## Sampler for Vegetation.scatter that respects slope and exclusion zones.
func veg_sampler(max_slope: float = 26.0, exclusions: Array = [],
		min_y: float = -1e9, max_y: float = 1e9) -> Callable:
	return func(x: float, z: float) -> Variant:
		if terrain == null:
			return null
		var y := terrain.height_at(x, z)
		if y < min_y or y > max_y:
			return null
		if terrain.slope_at(x, z) > max_slope:
			return null
		for e in exclusions:
			var r: Rect2 = e
			if r.has_point(Vector2(x, z)):
				return null
		return Vector3(x, y - 0.05, z)

## Vantage points for the rendered capture pass. Chapters override this to
## point the camera at their own set pieces.
func shot_spots() -> Array:
	var p := spawn_position
	return [
		{"name": "spawn", "pos": p + Vector3(9, 6, 9), "look": p + Vector3(0, 1.4, 0)},
	]

func challenge_failed() -> void:
	GameState.run["challenge_failed"] = true

func challenge_ok() -> bool:
	return not bool(GameState.run.get("challenge_failed", false))
