extends Node3D
class_name Vegetation
## Wind-reactive scattered vegetation using MultiMeshInstance3D. Density and
## draw distance follow the graphics preset, so Low still runs while Cinematic
## fills the ground.

var _layers: Array = []
var wind_gust := 0.0

func scatter(mesh: Mesh, count: int, area: Rect2, sampler: Callable,
		tint: Color, tip: Color, scale_range: Vector2 = Vector2(0.8, 1.6),
		sway: float = 0.18, seed_v: int = 1, sway_height: float = 1.2,
		cast_shadow: bool = false) -> MultiMeshInstance3D:
	var d := Settings.preset_data()
	var n := maxi(1, int(count * float(d.veg_density)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n

	# Clumping. Uniformly random scatter is the tell that ground cover was
	# placed by a loop: real vegetation grows in patches, thick where the ground
	# holds water and thin where it does not, with bare earth showing between.
	# A low-frequency noise field decides how likely a point is to take, and the
	# same field scales the plant, so clumps are both denser and taller at their
	# centres.
	var clump := FastNoiseLite.new()
	clump.seed = seed_v * 7 + 13
	clump.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	clump.frequency = 0.055

	var placed := 0
	var attempts := 0
	while placed < n and attempts < n * 14:
		attempts += 1
		var x := rng.randf_range(area.position.x, area.position.x + area.size.x)
		var z := rng.randf_range(area.position.y, area.position.y + area.size.y)
		# -1..1 -> 0..1, pushed toward the extremes so patches have edges.
		var c := clampf(clump.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		c = smoothstep(0.30, 0.78, c)
		if rng.randf() > 0.12 + c * 0.95:
			continue
		var res: Variant = sampler.call(x, z)
		if res == null:
			continue
		var pos: Vector3 = res
		if pos.y <= -9000.0:
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y) * lerpf(0.72, 1.12, c)
		# Lean each plant off vertical. A field of perfectly upright clones is
		# the other half of why scattered vegetation reads as instanced.
		var lean := rng.randf_range(0.0, 0.16)
		var lean_dir := rng.randf_range(0.0, TAU)
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		b = Basis(Vector3(cos(lean_dir), 0.0, sin(lean_dir)), lean) * b
		b = b.scaled(Vector3(s, s * rng.randf_range(0.88, 1.15), s))
		mm.set_instance_transform(placed, Transform3D(b, pos))
		placed += 1
	mm.visible_instance_count = placed

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wind.gdshader")
	mat.set_shader_parameter("albedo_tex", ProcAssets.noise_tex("veg_a", 303, 0.08,
		[[0.0, Color(0.35, 0.35, 0.35)], [1.0, Color(1, 1, 1)]], 3, 256))
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("tip_tint", tip)
	mat.set_shader_parameter("backlight_col", Vector3(tint.r * 0.4, tint.g * 0.55, tint.b * 0.35))
	mat.set_shader_parameter("wind_strength", sway)
	mat.set_shader_parameter("sway_height", sway_height)
	mat.set_shader_parameter("wind_speed", 1.05)
	mat.set_shader_parameter("wind_dir", Vector2(1.0, 0.35))
	mat.set_shader_parameter("gust", 0.0)

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = float(d.veg_dist)
	mmi.visibility_range_end_margin = float(d.veg_dist) * 0.15
	mmi.lod_bias = float(d.lod_bias)
	add_child(mmi)
	_layers.append({"node": mmi, "mat": mat})
	return mmi

func set_gust(v: float) -> void:
	wind_gust = v
	for l in _layers:
		(l.mat as ShaderMaterial).set_shader_parameter("gust", v)

func clear_all() -> void:
	for l in _layers:
		if is_instance_valid(l.node):
			l.node.queue_free()
	_layers.clear()

func instance_total() -> int:
	var n := 0
	for l in _layers:
		n += (l.node as MultiMeshInstance3D).multimesh.visible_instance_count
	return n
