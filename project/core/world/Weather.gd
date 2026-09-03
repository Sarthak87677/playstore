extends Node3D
class_name Weather
## Particle weather that follows the camera, plus wind gusts, lightning and
## per-state intensity. Weather is a gameplay layer as well as a look: glass
## rain damages, blizzards cut visibility, sandstorms hide guardians.

signal lightning_struck(position: Vector3)
signal gust(strength: float)

var kind: String = "none"
var follow: Node3D
var vegetation: Vegetation
var intensity: float = 1.0
var _emitters: Array = []
var _gust_t := 0.0
var _bolt_t := 6.0
var _flash_light: DirectionalLight3D
var _hazard_area: Area3D
var _shard_timer := 0.0
var damage_enabled := true

func setup(p_kind: String, p_follow: Node3D, p_veg: Vegetation = null) -> void:
	kind = p_kind
	follow = p_follow
	vegetation = p_veg
	match kind:
		"glass_rain": _make_glass_rain()
		"rain": _make_rain()
		"blizzard": _make_snow()
		"sandstorm": _make_sand()
		"drifting_pollen": _make_pollen()
		"sea_mist": _make_mist()
		"thunderstorm": _make_rain(); _make_storm_light()
		"embers": _make_embers()
		"convergence": _make_convergence()
		_: pass

func _particles(count: int, mesh: Mesh, mat: Material, box: Vector3,
		velocity: Vector3, spread: float, lifetime: float, scale_range: Vector2,
		gravity: Vector3) -> GPUParticles3D:
	var d := Settings.preset_data()
	var p := GPUParticles3D.new()
	p.amount = maxi(8, int(count * float(d.particles)))
	p.lifetime = lifetime
	p.preprocess = lifetime * 0.6
	p.visibility_aabb = AABB(-box * 0.5, box)
	p.draw_pass_1 = mesh
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box * 0.5
	pm.direction = velocity.normalized()
	pm.spread = spread
	pm.initial_velocity_min = velocity.length() * 0.75
	pm.initial_velocity_max = velocity.length() * 1.25
	pm.gravity = gravity
	pm.scale_min = scale_range.x
	pm.scale_max = scale_range.y
	pm.damping_min = 0.0
	pm.damping_max = 0.6
	p.process_material = pm
	add_child(p)
	_emitters.append(p)
	return p

func _make_glass_rain() -> void:
	var m := ProcAssets.crystal_mesh(7, 0.34, 0.035, 4)
	var mat := ProcAssets.mat("glass_broken").duplicate() as StandardMaterial3D
	mat.albedo_color = Color(0.78, 0.88, 0.95, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.75, 0.9)
	mat.emission_energy_multiplier = 0.5
	_particles(900, m, mat, Vector3(70, 34, 70), Vector3(0.6, -14, 0.3), 6.0,
		2.6, Vector2(0.6, 1.6), Vector3(0, -22, 0))
	_hazard_area = Area3D.new()
	_hazard_area.add_to_group("hazard")
	_hazard_area.collision_layer = Veil.L_HAZARD
	_hazard_area.collision_mask = 0
	_hazard_area.set_meta("kind", "glass rain")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(400, 90, 400)
	cs.shape = bs
	_hazard_area.add_child(cs)
	add_child(_hazard_area)
	_hazard_area.monitoring = false
	_hazard_area.monitorable = true

func _make_rain() -> void:
	var m := ProcAssets.box_mesh(Vector3(0.012, 0.28, 0.012))
	var mat := ProcAssets.additive(Color(0.65, 0.78, 0.9, 0.5), 0.5)
	_particles(1600, m, mat, Vector3(60, 30, 60), Vector3(1.2, -18, 0.6), 4.0,
		1.6, Vector2(0.7, 1.4), Vector3(0, -30, 0))

func _make_snow() -> void:
	var m := ProcAssets.plane_mesh(Vector2(0.055, 0.055))
	var mat := ProcAssets.additive(Color(0.9, 0.95, 1.0, 0.75), 0.9)
	_particles(1400, m, mat, Vector3(64, 30, 64), Vector3(2.4, -3.4, 1.0), 32.0,
		6.0, Vector2(0.6, 1.9), Vector3(0.6, -2.4, 0.2))

func _make_sand() -> void:
	var m := ProcAssets.plane_mesh(Vector2(0.09, 0.09))
	var mat := ProcAssets.additive(Color(0.82, 0.68, 0.42, 0.28), 0.5)
	_particles(1100, m, mat, Vector3(70, 24, 70), Vector3(9.0, -0.6, 3.0), 26.0,
		3.4, Vector2(1.0, 3.4), Vector3(1.4, -0.6, 0.4))

func _make_pollen() -> void:
	var m := ProcAssets.plane_mesh(Vector2(0.05, 0.05))
	var mat := ProcAssets.additive(Color(0.95, 0.9, 0.6, 0.55), 1.4)
	_particles(500, m, mat, Vector3(52, 24, 52), Vector3(0.6, -0.35, 0.4), 60.0,
		9.0, Vector2(0.5, 1.6), Vector3(0.2, -0.16, 0.1))

func _make_mist() -> void:
	var m := ProcAssets.plane_mesh(Vector2(5.0, 5.0))
	var mat := ProcAssets.additive(Color(0.72, 0.80, 0.86, 0.045), 0.25)
	_particles(90, m, mat, Vector3(70, 12, 70), Vector3(0.7, 0.05, 0.35), 45.0,
		18.0, Vector2(1.0, 3.0), Vector3.ZERO)

func _make_embers() -> void:
	var m := ProcAssets.plane_mesh(Vector2(0.035, 0.035))
	var mat := ProcAssets.additive(Color(1.0, 0.55, 0.20, 0.9), 3.0)
	_particles(320, m, mat, Vector3(46, 20, 46), Vector3(0.4, 1.4, 0.2), 40.0,
		7.0, Vector2(0.5, 1.5), Vector3(0.2, 0.5, 0.1))

func _make_convergence() -> void:
	for i in 3:
		var m := ProcAssets.plane_mesh(Vector2(0.07, 0.07))
		var mat := ProcAssets.additive(Color(Veil.STATE_COLORS[i], 0.7), 2.4)
		_particles(260, m, mat, Vector3(48, 26, 48),
			Vector3(cos(i * 2.1) * 1.4, 0.9 - i * 0.6, sin(i * 2.1) * 1.4), 50.0,
			8.0, Vector2(0.6, 2.0), Vector3(0, 0.2 - i * 0.2, 0))

func _make_storm_light() -> void:
	_flash_light = DirectionalLight3D.new()
	_flash_light.light_energy = 0.0
	_flash_light.light_color = Color(0.85, 0.92, 1.0)
	_flash_light.rotation_degrees = Vector3(-58, 20, 0)
	_flash_light.shadow_enabled = false
	add_child(_flash_light)

func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)
	for e in _emitters:
		(e as GPUParticles3D).emitting = intensity > 0.02
		(e as GPUParticles3D).speed_scale = 0.4 + intensity * 0.9

func _process(dt: float) -> void:
	if follow and is_instance_valid(follow):
		global_position = follow.global_position + Vector3(0, 8, 0)
	_gust_t -= dt
	if _gust_t <= 0.0:
		_gust_t = randf_range(3.5, 9.0)
		var g := randf_range(0.1, 0.85) * intensity
		if vegetation:
			vegetation.set_gust(g)
		gust.emit(g)
	if kind == "thunderstorm" and _flash_light:
		_bolt_t -= dt
		if _bolt_t <= 0.0:
			_bolt_t = randf_range(7.0, 17.0) / maxf(intensity, 0.15)
			_strike()
		_flash_light.light_energy = maxf(0.0, _flash_light.light_energy - dt * 9.0)
	if kind == "glass_rain" and damage_enabled:
		_shard_timer -= dt
		if _shard_timer <= 0.0:
			_shard_timer = randf_range(2.4, 5.5) / maxf(intensity, 0.15)
			_shard_hit()

func _strike() -> void:
	if _flash_light == null:
		return
	if not Settings.reduce_flashing:
		_flash_light.light_energy = 5.5
	var p := global_position + Vector3(randf_range(-40, 40), 0, randf_range(-40, 40))
	AudioDirector.play("thunder", -6.0, randf_range(0.85, 1.1))
	lightning_struck.emit(p)

## Glass rain occasionally connects. Cover (any roof between sky and player)
## blocks it, which is what makes the tutorial chapter's shelters matter.
func _shard_hit() -> void:
	if follow == null or not is_instance_valid(follow):
		return
	var player := follow as Player
	if player == null or not player.is_alive():
		return
	var space := get_world_3d().direct_space_state
	var from := player.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 40, 0))
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [player.get_rid()]
	if not space.intersect_ray(q).is_empty():
		return      # sheltered
	var mgr := get_tree().get_first_node_in_group("veil_manager") as VeilManager
	if mgr and mgr.state_at(player.global_position) != Veil.State.RUIN:
		return      # only the Ruin sky rains glass
	AudioDirector.play("shard_hit", -4.0)
	player.apply_damage(Tuning.HAZ_SHARD_DAMAGE * Tuning.dmg_scale(GameState.difficulty()),
		"glass shard")
	GameState.run["shard_hits"] = int(GameState.run.get("shard_hits", 0)) + 1
