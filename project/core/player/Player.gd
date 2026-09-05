extends CharacterBody3D
class_name Player
## The survey engineer. Third-person locomotion, survival state, interaction and
## the bridge between player input and the Veilforge Device.

signal shield_changed(value: float, maximum: float)
signal air_changed(value: float, maximum: float)
signal died()
signal respawned()
signal interact_focus(target: Interactable)
signal mode_changed(mode: String)
signal footstep(surface: int)
signal took_damage(amount: float, source: String)

enum Mode { GROUND, AIR, CLIMB, SWIM, MANTLE, DODGE, DEAD, CUTSCENE }

var mode: int = Mode.GROUND
var body: PlayerBody
var cam: PlayerCamera
var device: VeilDevice
var manager: VeilManager

# --- survival
var shield: float = Tuning.SHIELD_MAX
var shield_max: float = Tuning.SHIELD_MAX
var air: float = Tuning.DROWN_TIME
var invulnerable := false
var _regen_delay := 0.0
var _iframes := 0.0

# --- locomotion
var _coyote := 0.0
var _jump_buffer := 0.0
var _crouched := false
var _sprinting := false
var _step_dist := 0.0
var _fall_start_y := 0.0
var _falling := false
var _land_timer := 0.0
var _last_impact := 0.0
var _dodge_dir := Vector3.ZERO
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _mantle_t := 0.0
var _climb_normal := Vector3.FORWARD
var _climb_stamina := 0.0
var _air_jump_used := false
var _last_yaw := 0.0
var _prev_velocity := Vector3.ZERO
var _accel := Vector3.ZERO
var _surface: int = Veil.Surface.STONE
var _in_water := false
var _water_top := -1e9
var _hazards: Array = []
var _focus: Interactable = null
var _hold_t := 0.0
var _input_enabled := true
var _stand_shape: CollisionShape3D
var _spawn_point := Vector3.ZERO
var _spawn_yaw := 0.0
var _footstep_variant := 0

func _ready() -> void:
	add_to_group("player")
	collision_layer = Veil.L_PLAYER
	collision_mask = Veil.L_WORLD | Veil.L_PROP
	floor_max_angle = deg_to_rad(Tuning.SLOPE_LIMIT_DEG)
	floor_snap_length = 0.45
	up_direction = Vector3.UP
	slide_on_ceiling = true

	_stand_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = Tuning.STAND_HEIGHT
	_stand_shape.shape = cap
	_stand_shape.position = Vector3(0, Tuning.STAND_HEIGHT * 0.5, 0)
	add_child(_stand_shape)

	body = PlayerBody.new()
	add_child(body)

	device = VeilDevice.new()
	device.player = self
	add_child(device)

	var sensor := Area3D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = Veil.L_WATER | Veil.L_HAZARD
	var scol := CollisionShape3D.new()
	var sc := CapsuleShape3D.new()
	sc.radius = 0.36
	sc.height = Tuning.STAND_HEIGHT
	scol.shape = sc
	scol.position = Vector3(0, Tuning.STAND_HEIGHT * 0.5, 0)
	sensor.add_child(scol)
	sensor.area_entered.connect(_on_area_entered)
	sensor.area_exited.connect(_on_area_exited)
	add_child(sensor)

	shield_max = GameState.shield_max()
	shield = shield_max
	_climb_stamina = GameState.climb_stamina()
	_spawn_point = global_position

func bind(p_cam: PlayerCamera, p_mgr: VeilManager) -> void:
	cam = p_cam
	device.camera = p_cam.camera
	manager = p_mgr
	device.manager = p_mgr

func set_input_enabled(v: bool) -> void:
	_input_enabled = v
	if not v:
		device.set_aiming(false)
		device.end_scan()

func set_spawn(pos: Vector3, yaw: float) -> void:
	_spawn_point = pos
	_spawn_yaw = yaw

# ================================================================ input
func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled or mode == Mode.DEAD or mode == Mode.CUTSCENE:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam.add_look((event as InputEventMouseMotion).relative)
		Hints.did("look")
	if event.is_action_pressed("jump"):
		_jump_buffer = Tuning.JUMP_BUFFER
	if event.is_action_pressed("veil_next"):
		device.cycle_state(1)
	if event.is_action_pressed("veil_prev"):
		device.cycle_state(-1)
	if event.is_action_pressed("veil_shift"):
		device.perform_shift()
	if event.is_action_pressed("veil_pin"):
		device.pin_field()
	if event.is_action_pressed("imprint"):
		device.try_imprint()
	if event.is_action_pressed("emp"):
		device.fire_emp()
	if event.is_action_pressed("dodge"):
		_try_dodge()
	if event.is_action_pressed("photo_reset"):
		cam.recentre()
	if event.is_action_pressed("interact"):
		_try_interact()
	if Settings.aim_hold:
		if event.is_action_pressed("veil_aim"):
			device.set_aiming(true)
			Hints.did("veil_aim")
		elif event.is_action_released("veil_aim"):
			device.set_aiming(false)
	elif event.is_action_pressed("veil_aim"):
		device.toggle_aim()
		Hints.did("veil_aim")
	if Settings.scan_hold:
		if event.is_action_pressed("scan"):
			device.begin_scan()
		elif event.is_action_released("scan"):
			device.end_scan()
	elif event.is_action_pressed("scan"):
		if device._scanning: device.end_scan()
		else: device.begin_scan()

func _wish_dir() -> Vector3:
	if not _input_enabled or mode == Mode.DEAD or mode == Mode.CUTSCENE:
		return Vector3.ZERO
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if iv.length_squared() > 0.02:
		Hints.did("move")
	var f := cam.forward_flat()
	var r := cam.right_flat()
	return (r * iv.x + f * -iv.y).limit_length(1.0)

# ================================================================ main loop
func _physics_process(dt: float) -> void:
	_dodge_cd = maxf(0.0, _dodge_cd - dt)
	_iframes = maxf(0.0, _iframes - dt)
	_jump_buffer = maxf(0.0, _jump_buffer - dt)
	_land_timer = maxf(0.0, _land_timer - dt)

	if _input_enabled and mode != Mode.DEAD:
		cam.set_pad_look(Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)))
		cam.set_aim_mode(device.aiming)

	match mode:
		Mode.GROUND, Mode.AIR: _move_normal(dt)
		Mode.CLIMB: _move_climb(dt)
		Mode.SWIM: _move_swim(dt)
		Mode.MANTLE: _move_mantle(dt)
		Mode.DODGE: _move_dodge(dt)
		Mode.DEAD, Mode.CUTSCENE:
			velocity = velocity.move_toward(Vector3.ZERO, dt * 20.0)
			move_and_slide()

	_accel = (velocity - _prev_velocity) / maxf(dt, 0.0001)
	_prev_velocity = velocity
	_update_survival(dt)
	_update_focus()
	_update_body(dt)

func _speed_target() -> float:
	if _crouched:
		return Tuning.CROUCH_SPEED
	if _sprinting:
		return GameState.sprint_speed()
	return Tuning.WALK_SPEED

func _move_normal(dt: float) -> void:
	var grounded := is_on_floor()
	var wish := _wish_dir()

	var want_crouch := Input.is_action_pressed("crouch") if Settings.crouch_hold \
		else _crouched
	if not Settings.crouch_hold and Input.is_action_just_pressed("crouch"):
		want_crouch = not _crouched
	if want_crouch != _crouched:
		if not want_crouch and _blocked_above():
			want_crouch = true
		_set_crouched(want_crouch)

	_sprinting = Input.is_action_pressed("sprint") and not _crouched \
		and wish.length_squared() > 0.1 and grounded
	if _sprinting:
		Hints.did("sprint")
	cam.set_sprint(_sprinting)

	# --- horizontal
	var target := wish * _speed_target()
	var hv := Vector3(velocity.x, 0, velocity.z)
	if grounded:
		var a := Tuning.ACCEL_GROUND if wish.length_squared() > 0.01 else Tuning.FRICTION
		hv = hv.move_toward(target, a * dt)
	else:
		var control := GameState.air_control()
		hv = hv.move_toward(target, Tuning.ACCEL_AIR * control * 3.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z

	# --- vertical
	if grounded:
		_coyote = Tuning.COYOTE_TIME
		_air_jump_used = false
		if velocity.y < 0.0:
			velocity.y = -2.0
		if _falling:
			_do_land()
	else:
		_coyote = maxf(0.0, _coyote - dt)
		velocity.y = maxf(velocity.y - Tuning.GRAVITY * dt, -Tuning.TERMINAL_VELOCITY)
		if not _falling and velocity.y < -0.5:
			_falling = true
			_fall_start_y = global_position.y
		elif _falling:
			_fall_start_y = maxf(_fall_start_y, global_position.y)

	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_do_jump(Tuning.JUMP_VELOCITY)
		elif not _air_jump_used and GameState.has_veil_jump() and device.spend(12.0):
			_air_jump_used = true
			_do_jump(Tuning.JUMP_VELOCITY * 0.92)
			SceneFlow.flash(Color(Settings.state_color(device.selected_state), 0.10), 0.2)
		elif _try_mantle():
			pass

	mode = Mode.GROUND if grounded else Mode.AIR
	_face_movement(dt)
	move_and_slide()
	_check_climb_attach()
	_footsteps(dt, grounded)

func _do_jump(force: float) -> void:
	velocity.y = force
	_jump_buffer = 0.0
	_coyote = 0.0
	_falling = true
	_fall_start_y = global_position.y
	AudioDirector.play_3d("jump", get_tree().current_scene, global_position, -10.0,
		randf_range(0.94, 1.06))
	Hints.did("jump")

func _do_land() -> void:
	_falling = false
	var drop := maxf(0.0, _fall_start_y - global_position.y)
	var impact := sqrt(2.0 * Tuning.GRAVITY * drop)
	_last_impact = impact
	_land_timer = GameState.roll_window()
	var rolled := Input.is_action_pressed("crouch")
	if impact >= Tuning.LAND_FATAL and not rolled:
		AudioDirector.play_3d("land_hard", get_tree().current_scene, global_position, -2.0)
		apply_damage(9999.0, "fall")
		return
	if impact >= Tuning.LAND_HARD:
		if rolled:
			AudioDirector.play_3d("roll", get_tree().current_scene, global_position, -6.0)
			cam.shake(0.18)
			velocity += -global_transform.basis.z * 2.0
		else:
			var dmg := (impact - Tuning.LAND_HARD) * 5.4 * GameState.fall_damage_scale()
			apply_damage(dmg, "fall")
			AudioDirector.play_3d("land_hard", get_tree().current_scene, global_position, -4.0)
			cam.shake(0.42)
			body.play_land(0.3)
	elif impact >= Tuning.LAND_SOFT:
		AudioDirector.play_3d("land_soft", get_tree().current_scene, global_position, -12.0)
		cam.shake(0.10)
		body.play_land(0.15)
	Hints.did("crouch", 1 if rolled else 0)

func _set_crouched(v: bool) -> void:
	_crouched = v
	var cap := _stand_shape.shape as CapsuleShape3D
	cap.height = Tuning.CROUCH_HEIGHT if v else Tuning.STAND_HEIGHT
	_stand_shape.position.y = cap.height * 0.5
	cam.set_crouched(v)
	if v:
		Hints.did("crouch")

func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, Tuning.CROUCH_HEIGHT, 0),
		global_position + Vector3(0, Tuning.STAND_HEIGHT + 0.12, 0))
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()

func _face_movement(dt: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want_yaw: float
	if device.aiming:
		want_yaw = deg_to_rad(cam.yaw)
	elif hv.length_squared() > 0.35:
		want_yaw = atan2(hv.x, hv.z)
	else:
		return
	rotation.y = lerp_angle(rotation.y, want_yaw, clampf(dt * 11.0, 0.0, 1.0))

# ---------------------------------------------------------------- mantle
func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	var origin := global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 0.85)
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [get_rid()]
	var wall := space.intersect_ray(q)
	if wall.is_empty():
		return false
	var probe := (wall.position as Vector3) + fwd * 0.42 + Vector3(0, Tuning.MANTLE_MAX_HEIGHT + 0.6, 0)
	var q2 := PhysicsRayQueryParameters3D.create(probe, probe - Vector3(0, Tuning.MANTLE_MAX_HEIGHT + 1.2, 0))
	q2.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty():
		return false
	var h := (top.position as Vector3).y - global_position.y
	if h < Tuning.MANTLE_MIN_HEIGHT or h > Tuning.MANTLE_MAX_HEIGHT:
		return false
	if (top.normal as Vector3).dot(Vector3.UP) < 0.6:
		return false
	# Head clearance above the target.
	var q3 := PhysicsRayQueryParameters3D.create(
		(top.position as Vector3) + Vector3(0, 0.15, 0),
		(top.position as Vector3) + Vector3(0, Tuning.STAND_HEIGHT, 0))
	q3.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q3.exclude = [get_rid()]
	if not space.intersect_ray(q3).is_empty():
		return false
	_mantle_from = global_position
	_mantle_to = (top.position as Vector3) + fwd * 0.22
	_mantle_t = 0.0
	mode = Mode.MANTLE
	velocity = Vector3.ZERO
	_jump_buffer = 0.0
	_falling = false
	AudioDirector.play_3d("mantle", get_tree().current_scene, global_position, -8.0)
	mode_changed.emit("mantle")
	return true

func _move_mantle(dt: float) -> void:
	_mantle_t += dt / Tuning.MANTLE_DURATION
	var t := clampf(_mantle_t, 0.0, 1.0)
	var arc := sin(t * PI) * 0.28
	global_position = _mantle_from.lerp(_mantle_to, t) + Vector3(0, arc, 0)
	if t >= 1.0:
		mode = Mode.GROUND
		velocity = Vector3.ZERO
		mode_changed.emit("ground")

# ---------------------------------------------------------------- climb
func _check_climb_attach() -> void:
	if mode == Mode.CLIMB:
		return
	var s := _climb_surface()
	if s.is_empty():
		return
	if Input.is_action_just_pressed("interact"):
		_begin_climb(s.normal)

func _climb_surface() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	var origin := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 0.9)
	q.collision_mask = Veil.L_CLIMB
	q.exclude = [get_rid()]
	return space.intersect_ray(q)

func _begin_climb(normal: Vector3) -> void:
	mode = Mode.CLIMB
	_climb_normal = normal
	_climb_stamina = GameState.climb_stamina()
	velocity = Vector3.ZERO
	AudioDirector.play_3d("climb_grab", get_tree().current_scene, global_position, -8.0)
	Hints.did("climb")
	mode_changed.emit("climb")

func _move_climb(dt: float) -> void:
	var s := _climb_surface()
	if s.is_empty():
		_end_climb()
		return
	_climb_normal = s.normal
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var right := Vector3.UP.cross(_climb_normal).normalized()
	var upv := _climb_normal.cross(right).normalized()
	var v := (right * iv.x + upv * -iv.y) * Tuning.CLIMB_SPEED
	velocity = v - _climb_normal * 1.2
	_climb_stamina -= dt * (1.4 if v.length_squared() > 0.1 else 0.5)
	if _climb_stamina <= 0.0 or Input.is_action_just_pressed("crouch"):
		_end_climb()
		return
	if Input.is_action_just_pressed("jump"):
		_end_climb()
		velocity = _climb_normal * 3.4 + Vector3.UP * Tuning.JUMP_VELOCITY * 0.8
		return
	rotation.y = lerp_angle(rotation.y, atan2(-_climb_normal.x, -_climb_normal.z),
		clampf(dt * 10.0, 0.0, 1.0))
	move_and_slide()
	if is_on_floor() and iv.y > 0.2:
		_end_climb()
	# Top-out: if nothing in front at chest height any more, mantle over.
	if velocity.y > 0.1 and _try_mantle():
		return

func _end_climb() -> void:
	if mode != Mode.CLIMB:
		return
	mode = Mode.AIR
	_falling = true
	_fall_start_y = global_position.y
	mode_changed.emit("air")

func climb_stamina_fraction() -> float:
	return clampf(_climb_stamina / maxf(GameState.climb_stamina(), 0.01), 0.0, 1.0)

# ---------------------------------------------------------------- dodge
func _try_dodge() -> void:
	if _dodge_cd > 0.0 or mode == Mode.CLIMB or mode == Mode.SWIM:
		return
	if not device.spend(Tuning.DODGE_COST * Tuning.energy_scale(GameState.difficulty())):
		return
	var w := _wish_dir()
	_dodge_dir = w if w.length_squared() > 0.05 else -global_transform.basis.z
	_dodge_t = 0.0
	_dodge_cd = Tuning.DODGE_COOLDOWN
	_iframes = Tuning.DODGE_IFRAMES
	mode = Mode.DODGE
	AudioDirector.play_3d("dodge", get_tree().current_scene, global_position, -8.0)
	cam.shake(0.12)
	Hints.did("dodge")
	mode_changed.emit("dodge")

func _move_dodge(dt: float) -> void:
	_dodge_t += dt
	var t := clampf(_dodge_t / Tuning.DODGE_DURATION, 0.0, 1.0)
	var speed := Tuning.DODGE_DISTANCE / Tuning.DODGE_DURATION * (1.0 - t * 0.55)
	velocity.x = _dodge_dir.x * speed
	velocity.z = _dodge_dir.z * speed
	velocity.y = maxf(velocity.y - Tuning.GRAVITY * dt, -Tuning.TERMINAL_VELOCITY)
	if is_on_floor():
		velocity.y = -1.0
	move_and_slide()
	if t >= 1.0:
		mode = Mode.GROUND if is_on_floor() else Mode.AIR
		mode_changed.emit("ground")

# ---------------------------------------------------------------- swim
func _move_swim(dt: float) -> void:
	var wish := _wish_dir()
	var vertical := 0.0
	if Input.is_action_pressed("jump"): vertical += 1.0
	if Input.is_action_pressed("crouch"): vertical -= 1.0
	var target := wish * 3.4 + Vector3.UP * vertical * 2.6
	# Slight negative buoyancy unless swimming up.
	target.y -= 0.6
	velocity = velocity.move_toward(target, 6.0 * dt)
	_face_movement(dt)
	move_and_slide()
	var head_y := global_position.y + Tuning.STAND_HEIGHT * 0.85
	if head_y > _water_top:
		air = minf(Tuning.DROWN_TIME, air + dt * 6.0)
	else:
		air -= dt
		if air <= 0.0:
			apply_damage(Tuning.DROWN_DPS * dt, "drowning")
	air_changed.emit(air, Tuning.DROWN_TIME)
	if not _in_water:
		mode = Mode.AIR
		mode_changed.emit("air")
	_step_dist += velocity.length() * dt
	if _step_dist > 3.0:
		_step_dist = 0.0
		AudioDirector.play_3d("swim", get_tree().current_scene, global_position, -14.0)

# ================================================================ footsteps
func _footsteps(dt: float, grounded: bool) -> void:
	if not grounded:
		return
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if speed < 0.6:
		_step_dist = 1.4
		return
	_step_dist += speed * dt
	var stride := 2.35 if _sprinting else (1.35 if _crouched else 1.85)
	if _step_dist >= stride:
		_step_dist = 0.0
		_surface = _surface_under()
		_footstep_variant = (_footstep_variant + 1) % 3
		var vol := -18.0 if _crouched else (-9.0 if _sprinting else -13.0)
		AudioDirector.play_stream_3d(ProcAudio.footstep(_surface, _footstep_variant),
			get_tree().current_scene, global_position, vol, randf_range(0.92, 1.08), 26.0)
		footstep.emit(_surface)

func _surface_under() -> int:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.3, 0), global_position - Vector3(0, 0.8, 0))
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Veil.Surface.STONE
	var col: Object = hit.collider
	if col and col.has_meta("surface"):
		return int(col.get_meta("surface"))
	return Veil.Surface.STONE

func current_surface() -> int:
	return _surface

# ================================================================ survival
func _on_area_entered(a: Area3D) -> void:
	if a.is_in_group("water_volume"):
		_in_water = true
		_water_top = a.global_position.y + float(a.get_meta("depth_top", 0.0))
		if mode != Mode.SWIM:
			mode = Mode.SWIM
			AudioDirector.play_3d("splash", get_tree().current_scene, global_position, -6.0)
			Hints.request("water")
			mode_changed.emit("swim")
	elif a.is_in_group("hazard"):
		if not (a in _hazards):
			_hazards.append(a)

func _on_area_exited(a: Area3D) -> void:
	if a.is_in_group("water_volume"):
		_in_water = false
		if mode == Mode.SWIM:
			mode = Mode.AIR
			_falling = true
			_fall_start_y = global_position.y
			mode_changed.emit("air")
	elif a.is_in_group("hazard"):
		_hazards.erase(a)

func _update_survival(dt: float) -> void:
	for h in _hazards:
		if not is_instance_valid(h):
			continue
		if h.has_meta("dps"):
			apply_damage(float(h.get_meta("dps")) * dt, String(h.get_meta("kind", "hazard")))
		if h.has_method("affect_player"):
			h.affect_player(self, dt)
	if _regen_delay > 0.0:
		_regen_delay = maxf(0.0, _regen_delay - dt)
	elif shield < shield_max and mode != Mode.DEAD:
		shield = minf(shield_max, shield + Tuning.SHIELD_REGEN * dt)
		shield_changed.emit(shield, shield_max)
	if not _in_water and air < Tuning.DROWN_TIME:
		air = minf(Tuning.DROWN_TIME, air + dt * 8.0)
		air_changed.emit(air, Tuning.DROWN_TIME)

func apply_damage(amount: float, source: String = "") -> void:
	if mode == Mode.DEAD or invulnerable or _iframes > 0.0 or amount <= 0.0:
		return
	# Only damage the shield actually absorbs is recorded. A lethal hazard deals
	# 9999 so that nothing survives it; recording that verbatim scored a single
	# fall into a pit at -24000, which zeroed the chapter total and locked the
	# rank to C however well the rest of the chapter was played. The death
	# itself is the penalty for falling in.
	var absorbed := minf(amount, shield)
	shield = maxf(0.0, shield - amount)
	_regen_delay = Tuning.SHIELD_REGEN_DELAY
	GameState.note_damage(absorbed)
	took_damage.emit(amount, source)
	shield_changed.emit(shield, shield_max)
	cam.shake(clampf(amount * 0.012, 0.08, 0.5))
	if shield <= 0.0:
		_die(source)
	else:
		AudioDirector.play("hurt", -6.0)

func heal(amount: float) -> void:
	shield = minf(shield_max, shield + amount)
	shield_changed.emit(shield, shield_max)

func _die(source: String) -> void:
	mode = Mode.DEAD
	velocity = Vector3.ZERO
	device.set_aiming(false)
	device.end_scan()
	AudioDirector.play("death", -3.0)
	GameState.note_death()
	Log.info("Player died (%s)" % source)
	died.emit()
	mode_changed.emit("dead")

func revive_at(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO
	shield_max = GameState.shield_max()
	shield = shield_max
	air = Tuning.DROWN_TIME
	_falling = false
	_in_water = false
	_hazards.clear()
	mode = Mode.GROUND
	device.refill(Tuning.ENERGY_MAX)
	device.clear_pin()
	shield_changed.emit(shield, shield_max)
	air_changed.emit(air, Tuning.DROWN_TIME)
	cam.yaw = rad_to_deg(yaw) + 180.0
	respawned.emit()
	mode_changed.emit("ground")

# ================================================================ interaction
func _update_focus() -> void:
	var best: Interactable = null
	var best_score := -1.0
	var cam_pos := cam.camera.global_position
	var fwd := -cam.camera.global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.is_inside_tree() or not it.can_use():
			continue
		var to := it.global_position - global_position
		var d := to.length()
		if d > 3.6:
			continue
		var dir := (it.global_position - cam_pos).normalized()
		var dot := fwd.dot(dir)
		if dot < 0.3:
			continue
		var score := dot * 2.0 - d * 0.2
		if score > best_score:
			best_score = score
			best = it
	if best != _focus:
		if _focus: _focus.set_focus(false)
		_focus = best
		if _focus: _focus.set_focus(true)
		interact_focus.emit(_focus)

func _try_interact() -> void:
	if _focus != null and _focus.can_use():
		if _focus.hold_time > 0.0:
			return
		_focus.use(self)
		Hints.did("interact")
		return
	var s := _climb_surface()
	if not s.is_empty():
		_begin_climb(s.normal)

func _process(dt: float) -> void:
	# Hold-to-use interactions.
	if _focus != null and _focus.hold_time > 0.0 and _input_enabled:
		if Input.is_action_pressed("interact"):
			_hold_t += dt
			if _hold_t >= _focus.hold_time:
				_hold_t = 0.0
				_focus.use(self)
		else:
			_hold_t = 0.0
	else:
		_hold_t = 0.0

func hold_fraction() -> float:
	if _focus == null or _focus.hold_time <= 0.0:
		return 0.0
	return clampf(_hold_t / _focus.hold_time, 0.0, 1.0)

func focus_target() -> Interactable:
	return _focus

# ================================================================ presentation
func _update_body(dt: float) -> void:
	var planar := Vector3(velocity.x, 0, velocity.z).length()
	var speed01 := clampf(planar / maxf(GameState.sprint_speed(), 0.1), 0.0, 1.0)
	var yaw_delta := rad_to_deg(wrapf(rotation.y - _last_yaw, -PI, PI)) / maxf(dt, 0.001)
	_last_yaw = rotation.y
	body.animate(dt, speed01, is_on_floor(), _crouched, mode == Mode.CLIMB,
		_accel, yaw_delta, cam.pitch)
	if manager:
		body.set_visor_state(manager.state_at(global_position))

func is_alive() -> bool:
	return mode != Mode.DEAD

func set_cutscene(v: bool) -> void:
	mode = Mode.CUTSCENE if v else Mode.GROUND
	set_input_enabled(not v)
