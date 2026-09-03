extends Node3D
class_name WaterVolume
## A body of water: a shaded surface, a swim volume, and a level that puzzles
## can raise or lower. Buoyancy is applied to any rigid body inside it.

signal level_changed(y: float)

var extent: Vector2 = Vector2(40, 40)
var surface: MeshInstance3D
var area: Area3D
var _shape: BoxShape3D
var _col: CollisionShape3D
var depth: float = 12.0
var target_level: float = 0.0
var _level: float = 0.0
var flow_speed := 0.5

func build(p_extent: Vector2, p_depth: float, level_y: float,
		shallow := Color(0.20, 0.52, 0.55, 0.55), deep := Color(0.03, 0.13, 0.20, 0.94)) -> void:
	extent = p_extent
	depth = p_depth
	_level = level_y
	target_level = level_y

	surface = MeshInstance3D.new()
	surface.mesh = ProcAssets.plane_mesh(extent, 20)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("normal_a", ProcAssets.normal_tex("wv_a", 401, 0.06, 3.0, 3, 256))
	mat.set_shader_parameter("normal_b", ProcAssets.normal_tex("wv_b", 402, 0.11, 2.2, 3, 256))
	mat.set_shader_parameter("shallow_col", shallow)
	mat.set_shader_parameter("deep_col", deep)
	mat.render_priority = 1
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)

	area = Area3D.new()
	area.add_to_group("water_volume")
	area.collision_layer = Veil.L_WATER
	area.collision_mask = 0
	area.monitorable = true
	area.monitoring = true
	_shape = BoxShape3D.new()
	_shape.size = Vector3(extent.x, depth, extent.y)
	_col = CollisionShape3D.new()
	_col.shape = _shape
	area.add_child(_col)
	add_child(area)
	_apply_level(_level)

func _apply_level(y: float) -> void:
	_level = y
	surface.position.y = y
	area.position.y = y - depth * 0.5
	area.set_meta("depth_top", depth * 0.5)
	level_changed.emit(y)

func set_level(y: float, time: float = 2.4) -> void:
	target_level = y
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_apply_level, _level, y, time)

func level() -> float:
	return _level

func contains(p: Vector3) -> bool:
	var local := to_local(p)
	return absf(local.x) <= extent.x * 0.5 and absf(local.z) <= extent.y * 0.5 \
		and p.y <= _level and p.y >= _level - depth

func _physics_process(dt: float) -> void:
	# Buoyancy for physics props (used by the float/sink puzzles).
	for n in get_tree().get_nodes_in_group("buoyant"):
		var rb := n as RigidBody3D
		if rb == null or rb.freeze:
			continue
		if not contains(rb.global_position):
			continue
		var submersion := clampf((_level - rb.global_position.y) / 0.9, 0.0, 1.0)
		var lift: float = float(rb.get_meta("buoyancy", 1.35))
		rb.apply_central_force(Vector3.UP * submersion * lift * rb.mass * 22.0)
		rb.linear_velocity = rb.linear_velocity.lerp(
			Vector3(rb.linear_velocity.x * 0.86, rb.linear_velocity.y * 0.7,
				rb.linear_velocity.z * 0.86), clampf(dt * 4.0, 0.0, 1.0))
