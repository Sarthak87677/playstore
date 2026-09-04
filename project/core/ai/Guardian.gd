extends CharacterBody3D
class_name Guardian
## A malfunctioning maintenance machine. Encounters are tense but not gory:
## guardians shock rather than shred, they can be stunned with an EMP, avoided
## entirely, or disabled by the environment (dropped mass, live water, a floor
## that stops existing when you shift the ground out from under them).
##
## Behaviour is state-aware. In Memory the unit is a docile service drone; in
## Ruin it is damaged and hostile; in Bloom it is choked with growth and slow.

signal alerted()
signal lost_player()
signal disabled(by: String)

enum St { DORMANT, PATROL, SUSPICIOUS, ALERT, SEARCH, STUNNED, DOWN }

@export var patrol_points: Array = []
@export var home_yaw: float = 0.0
@export var guard_id: String = ""
@export var start_state: int = St.PATROL

var state: int = St.PATROL
var player: Player
var manager: VeilManager
var health: float = Tuning.GUARD_HEALTH
var awareness: float = 0.0
var _patrol_i := 0
var _wait := 0.0
var _stun_t := 0.0
var _pulse_cd := 0.0
var _search_t := 0.0
var _last_seen := Vector3.ZERO
var _reported_bypass := false
var _seen_ever := false
var _veil_state := Veil.State.RUIN

var _hull: Node3D
var _eye: MeshInstance3D
var _eye_light: SpotLight3D
var _legs: Array = []
var _t := 0.0
var _base_y := 0.0

func _ready() -> void:
	add_to_group("guardian")
	collision_layer = Veil.L_GUARDIAN
	collision_mask = Veil.L_WORLD | Veil.L_PROP
	floor_max_angle = deg_to_rad(55.0)
	state = start_state
	_build()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_base_y = position.y

func bind(p: Player, m: VeilManager) -> void:
	player = p
	manager = m

func _build() -> void:
	_hull = Node3D.new()
	_hull.position.y = 1.05
	add_child(_hull)
	var body_mat := ProcAssets.mat("metal_dark")
	var trim := ProcAssets.mat("metal_rust")

	var core := MeshInstance3D.new()
	core.mesh = ProcAssets.rock_mesh(1234, 0.52, 0.10, 10, 14, 0.72)
	core.material_override = body_mat
	_hull.add_child(core)

	var collar := MeshInstance3D.new()
	collar.mesh = ProcAssets.ring_mesh(0.52, 0.07, 20, 6)
	collar.material_override = trim
	_hull.add_child(collar)

	_eye = MeshInstance3D.new()
	_eye.mesh = ProcAssets.sphere_mesh(0.13, 8, 12)
	_eye.material_override = ProcAssets.additive(Color(1.0, 0.6, 0.25), 3.0, false)
	_eye.position = Vector3(0, 0.06, 0.46)
	_hull.add_child(_eye)

	_eye_light = SpotLight3D.new()
	_eye_light.light_color = Color(1.0, 0.66, 0.3)
	_eye_light.light_energy = 2.6
	_eye_light.spot_range = 18.0
	_eye_light.spot_angle = 32.0
	_eye_light.shadow_enabled = false
	_eye_light.position = Vector3(0, 0.05, 0.5)
	_eye_light.rotation_degrees = Vector3(0, 180, 0)
	_hull.add_child(_eye_light)

	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var hip := Node3D.new()
		hip.position = Vector3(cos(a) * 0.42, -0.18, sin(a) * 0.42)
		hip.rotation.y = -a
		_hull.add_child(hip)
		var upper := MeshInstance3D.new()
		upper.mesh = ProcAssets.box_mesh(Vector3(0.09, 0.42, 0.09))
		upper.material_override = body_mat
		upper.position = Vector3(0, -0.21, 0)
		hip.add_child(upper)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.42, 0)
		hip.add_child(knee)
		var lower := MeshInstance3D.new()
		lower.mesh = ProcAssets.box_mesh(Vector3(0.07, 0.44, 0.07))
		lower.material_override = trim
		lower.position = Vector3(0, -0.22, 0)
		knee.add_child(lower)
		_legs.append({"hip": hip, "knee": knee, "phase": float(i) * PI * 0.5})

func _view_distance() -> float:
	var d: float = Tuning.GUARD_VIEW_DIST[GameState.difficulty()]
	match _veil_state:
		Veil.State.MEMORY: return d * 0.55       # docile: barely looking
		Veil.State.BLOOM: return d * 0.7         # overgrown optics
		_: return d

func _view_angle() -> float:
	return Tuning.GUARD_VIEW_ANGLE[GameState.difficulty()]

func _speed() -> float:
	var s: float = Tuning.GUARD_CHASE_SPEED if state == St.ALERT else Tuning.GUARD_PATROL_SPEED
	match _veil_state:
		Veil.State.MEMORY: return s * 0.6
		Veil.State.BLOOM: return s * 0.55
		_: return s

func _physics_process(dt: float) -> void:
	_t += dt
	if manager:
		var s := manager.state_at(global_position)
		if s != _veil_state:
			_on_state_change(s)
	if not is_on_floor():
		velocity.y = maxf(velocity.y - Tuning.GRAVITY * dt, -Tuning.TERMINAL_VELOCITY)
	else:
		velocity.y = -1.0

	match state:
		St.DORMANT: _tick_dormant(dt)
		St.PATROL: _tick_patrol(dt)
		St.SUSPICIOUS: _tick_suspicious(dt)
		St.ALERT: _tick_alert(dt)
		St.SEARCH: _tick_search(dt)
		St.STUNNED: _tick_stunned(dt)
		St.DOWN:
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()
	_animate(dt)
	_check_crush()

func _on_state_change(s: int) -> void:
	_veil_state = s
	match s:
		Veil.State.MEMORY:
			if state in [St.ALERT, St.SEARCH, St.SUSPICIOUS]:
				_calm()
			if state != St.DOWN:
				state = St.DORMANT
			_set_eye(Color(0.45, 0.85, 1.0))
		Veil.State.BLOOM:
			if state == St.DORMANT:
				state = St.PATROL
			_set_eye(Color(0.55, 1.0, 0.6))
		_:
			if state == St.DORMANT:
				state = St.PATROL
			_set_eye(Color(1.0, 0.6, 0.25))

func _set_eye(c: Color) -> void:
	var m := _eye.material_override as StandardMaterial3D
	m.albedo_color = c
	m.emission = c
	_eye_light.light_color = c

func _can_see_player() -> bool:
	if player == null or not player.is_alive():
		return false
	if _veil_state == Veil.State.MEMORY:
		return false
	var to := player.global_position + Vector3(0, 1.0, 0) - (global_position + Vector3(0, 1.05, 0))
	var d := to.length()
	if d > _view_distance():
		return false
	var fwd := -global_transform.basis.z
	if rad_to_deg(fwd.angle_to(to.normalized())) > _view_angle() * 0.5:
		# Very close contact is noticed regardless of facing.
		if d > 3.2:
			return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.05, 0), player.global_position + Vector3(0, 1.0, 0))
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [get_rid(), player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.is_empty()

func _tick_dormant(dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_hull.rotation.y = sin(_t * 0.4) * 0.25
	awareness = maxf(0.0, awareness - dt * 1.5)

func _tick_patrol(dt: float) -> void:
	awareness = maxf(0.0, awareness - dt * 0.6)
	if _can_see_player():
		state = St.SUSPICIOUS
		return
	if patrol_points.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		rotation.y = lerp_angle(rotation.y, deg_to_rad(home_yaw) + sin(_t * 0.3) * 0.8, dt)
		return
	if _wait > 0.0:
		_wait -= dt
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var goal: Vector3 = patrol_points[_patrol_i % patrol_points.size()]
	_move_toward(goal, dt)
	if Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 1.2:
		_patrol_i += 1
		_wait = randf_range(1.2, 3.0)

func _tick_suspicious(dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not _can_see_player():
		awareness = maxf(0.0, awareness - dt * 0.9)
		if awareness <= 0.0:
			state = St.PATROL
		return
	_face(player.global_position, dt, 4.0)
	awareness += dt / maxf(Tuning.GUARD_NOTICE_TIME[GameState.difficulty()], 0.1)
	if awareness >= 1.0:
		_go_alert()

func _go_alert() -> void:
	state = St.ALERT
	awareness = 1.0
	_seen_ever = true
	GameState.note_spotted()
	AudioDirector.play_3d("guardian_alert", get_tree().current_scene, global_position, -4.0)
	AudioDirector.set_intensity(0.9)
	alerted.emit()

func _tick_alert(dt: float) -> void:
	if player == null or not player.is_alive():
		_calm()
		return
	if _can_see_player():
		_last_seen = player.global_position
		_search_t = Tuning.GUARD_SEARCH_TIME
	else:
		_search_t -= dt
		if _search_t <= 0.0:
			state = St.SEARCH
			_search_t = Tuning.GUARD_SEARCH_TIME
			lost_player.emit()
			return
	_move_toward(_last_seen, dt)
	var d := global_position.distance_to(player.global_position)
	_pulse_cd -= dt
	if d < 9.0 and _pulse_cd <= 0.0:
		_fire_pulse()

func _tick_search(dt: float) -> void:
	_search_t -= dt
	if _can_see_player():
		_go_alert()
		return
	if _search_t <= 0.0:
		_calm()
		return
	var wander := _last_seen + Vector3(sin(_t * 0.9) * 5.0, 0, cos(_t * 0.7) * 5.0)
	_move_toward(wander, dt)

func _calm() -> void:
	state = St.PATROL
	awareness = 0.0
	AudioDirector.set_intensity(0.15)
	if not _reported_bypass and not _seen_ever:
		_reported_bypass = true
		GameState.note_bypass()

func _tick_stunned(dt: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_stun_t -= dt
	_hull.rotation.z = sin(_t * 26.0) * 0.14
	_hull.rotation.x = cos(_t * 21.0) * 0.09
	if _stun_t <= 0.0:
		_hull.rotation = Vector3.ZERO
		state = St.SEARCH
		_search_t = Tuning.GUARD_SEARCH_TIME * 0.5

func _move_toward(goal: Vector3, dt: float) -> void:
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 0.4:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := to.normalized()
	# Simple obstacle sidestep so guardians do not grind into walls.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.9, 0), global_position + Vector3(0, 0.9, 0) + dir * 1.6)
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [get_rid()]
	if not space.intersect_ray(q).is_empty():
		dir = dir.rotated(Vector3.UP, PI * 0.42)
	var s := _speed()
	velocity.x = dir.x * s
	velocity.z = dir.z * s
	_face(global_position + dir, dt, 6.0)

func _face(point: Vector3, dt: float, speed: float) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(dt * speed, 0.0, 1.0))

func _fire_pulse() -> void:
	_pulse_cd = Tuning.GUARD_PULSE_INTERVAL[GameState.difficulty()]
	AudioDirector.play_3d("guardian_pulse", get_tree().current_scene, global_position, -5.0)
	var ring := MeshInstance3D.new()
	ring.mesh = ProcAssets.ring_mesh(0.6, 0.06, 24, 6)
	ring.material_override = ProcAssets.additive(Color(1.0, 0.55, 0.3), 3.0)
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector3(0, 1.0, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3.ONE * 12.0, 0.42)
	t.tween_property(ring, "transparency", 1.0, 0.42)
	t.chain().tween_callback(ring.queue_free)
	if player and player.global_position.distance_to(global_position) < 9.5:
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 1.0, 0), player.global_position + Vector3(0, 1.0, 0))
		q.collision_mask = Veil.L_WORLD
		q.exclude = [get_rid(), player.get_rid()]
		if space.intersect_ray(q).is_empty():
			player.apply_damage(
				Tuning.GUARD_PULSE_DAMAGE[GameState.difficulty()], "guardian pulse")

func apply_emp(duration: float) -> void:
	if state == St.DOWN:
		return
	_stun_t = duration
	state = St.STUNNED
	awareness = 0.0
	AudioDirector.play_3d("guardian_stun", get_tree().current_scene, global_position, -6.0)
	var spark := GPUParticles3D.new()
	spark.amount = 40
	spark.lifetime = 0.8
	spark.one_shot = true
	spark.draw_pass_1 = ProcAssets.plane_mesh(Vector2(0.05, 0.05))
	spark.material_override = ProcAssets.additive(Color(0.6, 0.9, 1.0), 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -6, 0)
	spark.process_material = pm
	_hull.add_child(spark)
	spark.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(spark): spark.queue_free())

## Environmental takedown: crushed by shifted geometry, or dropped mass.
func _check_crush() -> void:
	if state == St.DOWN:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.4, 0), global_position + Vector3(0, 2.3, 0))
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	# Only geometry that appeared *on top* of the unit counts.
	if global_position.y < float(hit.position.y) - 2.25:
		return
	take_down("crushed")

func take_down(by: String = "emp") -> void:
	if state == St.DOWN:
		return
	state = St.DOWN
	health = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	AudioDirector.play_3d("guardian_down", get_tree().current_scene, global_position, -4.0)
	_set_eye(Color(0.2, 0.2, 0.22))
	_eye_light.light_energy = 0.0
	GameState.award(160, "Guardian disabled")
	AudioDirector.set_intensity(0.1)
	disabled.emit(by)
	var t := create_tween()
	t.tween_property(_hull, "position:y", 0.42, 0.6).set_trans(Tween.TRANS_BOUNCE)
	t.parallel().tween_property(_hull, "rotation:z", randf_range(-0.6, 0.6), 0.6)

func on_emp() -> void:
	apply_emp(GameState.emp_stun())

func _animate(dt: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	var amp: float = 0.5 if moving else 0.06
	for l in _legs:
		var ph: float = float(l.phase) + _t * (7.0 if moving else 1.1)
		(l.hip as Node3D).rotation.x = sin(ph) * amp * 0.5
		(l.knee as Node3D).rotation.x = -absf(sin(ph)) * amp - 0.15
	if state != St.DOWN:
		_hull.position.y = 1.05 + sin(_t * 2.2) * 0.04
	if state == St.ALERT:
		_eye_light.light_energy = 3.4 + sin(_t * 12.0) * 0.9
	elif state == St.SUSPICIOUS:
		_eye_light.light_energy = 2.0 + awareness * 2.0
	elif state != St.DOWN:
		_eye_light.light_energy = 1.8

func awareness_fraction() -> float:
	return clampf(awareness, 0.0, 1.0)

func is_hostile() -> bool:
	return state in [St.ALERT, St.SEARCH, St.SUSPICIOUS]
