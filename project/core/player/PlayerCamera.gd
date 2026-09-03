extends Node3D
class_name PlayerCamera
## Collision-aware cinematic third-person camera.
##
## A damped spring arm with shoulder offset, sprint/aim FOV, additive shake and
## an auto-recentre. All damping is frame-rate independent so behaviour matches
## between a 60 Hz and a 144 Hz machine.

@export var target_path: NodePath
var target: Node3D
var camera: Camera3D
var arm: SpringArm3D
var pivot: Node3D

var yaw := 0.0
var pitch := -8.0
var distance := Tuning.CAM_DIST
var _dist_current := Tuning.CAM_DIST
var _shoulder := Tuning.CAM_SHOULDER
var _fov_target := Tuning.CAM_FOV
var _shake_amp := 0.0
var _shake_freq := 22.0
var _shake_t := 0.0
var _look_input := Vector2.ZERO
var _pad_look := Vector2.ZERO
var _recentre := 0.0
var _height := Tuning.CAM_HEIGHT
var _height_target := Tuning.CAM_HEIGHT
var enabled := true

func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.32
	arm.collision_mask = Veil.L_WORLD
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = Settings.fov
	camera.near = 0.08
	camera.far = 900.0
	camera.current = true
	arm.add_child(camera)
	_apply_camera_attributes()
	Settings.video_changed.connect(_apply_camera_attributes)
	if target_path != NodePath():
		target = get_node_or_null(target_path) as Node3D

func _apply_camera_attributes() -> void:
	if camera == null:
		return
	camera.fov = Settings.fov
	var att := CameraAttributesPractical.new()
	att.auto_exposure_enabled = true
	att.auto_exposure_min_sensitivity = 12.0
	att.auto_exposure_max_sensitivity = 640.0
	att.auto_exposure_speed = 1.2
	att.auto_exposure_scale = 0.42
	att.dof_blur_far_enabled = Settings.preset_data().get("dof", false)
	att.dof_blur_far_distance = 34.0
	att.dof_blur_far_transition = 22.0
	att.dof_blur_amount = 0.06
	camera.attributes = att

func set_target(t: Node3D) -> void:
	target = t

func add_look(delta: Vector2) -> void:
	_look_input += delta

func set_pad_look(v: Vector2) -> void:
	_pad_look = v

func shake(amount: float, freq: float = 22.0) -> void:
	var scaled := amount * Settings.shake_scale()
	_shake_amp = maxf(_shake_amp, scaled)
	_shake_freq = freq

func set_aim_mode(on: bool) -> void:
	distance = Tuning.CAM_DIST_AIM if on else Tuning.CAM_DIST
	_shoulder = 0.72 if on else Tuning.CAM_SHOULDER
	_fov_target = Tuning.CAM_FOV_AIM if on else Settings.fov

func set_sprint(on: bool) -> void:
	if distance == Tuning.CAM_DIST_AIM:
		return
	_fov_target = (Settings.fov + 8.0) if on else Settings.fov

func set_crouched(on: bool) -> void:
	_height_target = (Tuning.CAM_HEIGHT - 0.55) if on else Tuning.CAM_HEIGHT

func recentre() -> void:
	_recentre = 1.0

func forward_flat() -> Vector3:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	return -(b.z).normalized()

func right_flat() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw)).x.normalized()

func _process(dt: float) -> void:
	if target == null or not enabled:
		return
	# --- rotation -----------------------------------------------------------
	var inv_x := -1.0 if Settings.invert_x else 1.0
	var inv_y := -1.0 if Settings.invert_y else 1.0
	yaw -= _look_input.x * Settings.mouse_sensitivity * inv_x
	pitch -= _look_input.y * Settings.mouse_sensitivity * inv_y
	_look_input = Vector2.ZERO
	if _pad_look.length_squared() > 0.0001:
		var pad_speed := Settings.pad_sensitivity * 60.0 * dt
		yaw -= _pad_look.x * pad_speed * inv_x
		pitch -= _pad_look.y * pad_speed * inv_y
	if _recentre > 0.0:
		_recentre = maxf(0.0, _recentre - dt * 2.2)
		var want := rad_to_deg(target.global_rotation.y) + 180.0
		yaw = lerp_angle(deg_to_rad(yaw), deg_to_rad(want), dt * 6.0)
		yaw = rad_to_deg(yaw)
	pitch = clampf(pitch, Tuning.CAM_PITCH_MIN, Tuning.CAM_PITCH_MAX)

	# --- position -----------------------------------------------------------
	_height = lerpf(_height, _height_target, 1.0 - pow(0.002, dt))
	var focus := target.global_position + Vector3(0, _height, 0)
	global_position = global_position.lerp(focus, 1.0 - pow(0.0009, dt * Tuning.CAM_LAG / 12.0))

	pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	_dist_current = lerpf(_dist_current, distance, 1.0 - pow(0.004, dt))
	arm.spring_length = _dist_current
	camera.position = Vector3(_shoulder, 0, 0)
	camera.fov = lerpf(camera.fov, _fov_target, 1.0 - pow(0.01, dt))

	# --- shake --------------------------------------------------------------
	if _shake_amp > 0.001:
		_shake_t += dt * _shake_freq
		var ox := sin(_shake_t * 1.7) * _shake_amp
		var oy := cos(_shake_t * 2.3) * _shake_amp
		camera.h_offset = ox * 0.12
		camera.v_offset = oy * 0.12
		pivot.rotation_degrees += Vector3(oy * 0.8, ox * 0.8, ox * 1.6)
		_shake_amp = maxf(0.0, _shake_amp - dt * (1.6 + _shake_amp * 3.0))
	else:
		camera.h_offset = lerpf(camera.h_offset, 0.0, dt * 8.0)
		camera.v_offset = lerpf(camera.v_offset, 0.0, dt * 8.0)
