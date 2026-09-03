extends Node3D
class_name PlayerBody
## Procedurally built and procedurally animated survey engineer.
##
## No rigged model ships with the game, so the figure is assembled from tapered
## solids on a joint hierarchy and driven by a hand-written locomotion cycle:
## hips counter-rotate against the shoulders, arms swing opposite the legs,
## the torso leans into acceleration and the head keeps looking where the
## camera looks.

var suit_primary := Color(0.42, 0.45, 0.50)
var suit_accent := Color(0.95, 0.55, 0.20)

var root: Node3D
var hips: Node3D
var torso: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var visor: MeshInstance3D
var arm_l: Array = []      # [shoulder, elbow]
var arm_r: Array = []
var leg_l: Array = []      # [hip, knee]
var leg_r: Array = []
var pack_light: OmniLight3D

var _cycle := 0.0
var _lean := Vector2.ZERO
var _blend_air := 0.0
var _blend_crouch := 0.0
var _blend_climb := 0.0
var _breath := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0

func _ready() -> void:
	_build()
	apply_suit(GameState.suit_colors())

func _seg(parent: Node3D, size: Vector3, offset: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = ProcAssets.box_mesh(size, 1.0)
	m.material_override = mat
	m.position = offset
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)
	return m

func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build() -> void:
	var suit := ProcAssets.mat("metal").duplicate() as StandardMaterial3D
	suit.albedo_color = suit_primary
	suit.roughness = 0.72
	suit.metallic = 0.12
	var trim := ProcAssets.emissive(suit_accent, 1.1)
	var dark := ProcAssets.mat("metal_dark")

	root = Node3D.new()
	add_child(root)

	hips = _joint(root, Vector3(0, 0.94, 0))
	_seg(hips, Vector3(0.34, 0.20, 0.24), Vector3.ZERO, suit)

	torso = _joint(hips, Vector3(0, 0.16, 0))
	_seg(torso, Vector3(0.36, 0.26, 0.24), Vector3(0, 0.11, 0), suit)
	chest = _joint(torso, Vector3(0, 0.26, 0))
	_seg(chest, Vector3(0.42, 0.30, 0.26), Vector3(0, 0.12, 0), suit)
	_seg(chest, Vector3(0.10, 0.03, 0.02), Vector3(0.13, 0.16, 0.135), trim)
	# survey pack + its lamp
	_seg(chest, Vector3(0.30, 0.28, 0.14), Vector3(0, 0.10, -0.19), dark)
	pack_light = OmniLight3D.new()
	pack_light.light_color = suit_accent
	pack_light.light_energy = 0.5
	pack_light.omni_range = 3.2
	pack_light.position = Vector3(0, 0.16, -0.26)
	pack_light.shadow_enabled = false
	chest.add_child(pack_light)

	neck = _joint(chest, Vector3(0, 0.28, 0))
	head = _joint(neck, Vector3(0, 0.10, 0))
	_seg(head, Vector3(0.22, 0.24, 0.24), Vector3.ZERO, suit)
	visor = _seg(head, Vector3(0.19, 0.09, 0.02), Vector3(0, 0.02, 0.12),
		ProcAssets.emissive(Color(0.45, 0.85, 1.0), 1.6))

	for side in [-1.0, 1.0]:
		var sh := _joint(chest, Vector3(0.25 * side, 0.18, 0))
		_seg(sh, Vector3(0.12, 0.28, 0.13), Vector3(0, -0.14, 0), suit)
		var el := _joint(sh, Vector3(0, -0.28, 0))
		_seg(el, Vector3(0.10, 0.26, 0.11), Vector3(0, -0.13, 0), suit)
		_seg(el, Vector3(0.11, 0.09, 0.12), Vector3(0, -0.29, 0), dark)
		if side < 0.0:
			arm_l = [sh, el]
			# The Veilforge Device is worn on the left forearm.
			_seg(el, Vector3(0.13, 0.14, 0.14), Vector3(0, -0.20, 0.02), dark)
			_seg(el, Vector3(0.08, 0.02, 0.09), Vector3(0, -0.135, 0.06), trim)
		else:
			arm_r = [sh, el]

	for side in [-1.0, 1.0]:
		var hp := _joint(hips, Vector3(0.11 * side, -0.10, 0))
		_seg(hp, Vector3(0.15, 0.36, 0.16), Vector3(0, -0.18, 0), suit)
		var kn := _joint(hp, Vector3(0, -0.36, 0))
		_seg(kn, Vector3(0.13, 0.34, 0.14), Vector3(0, -0.17, 0), suit)
		_seg(kn, Vector3(0.14, 0.08, 0.26), Vector3(0, -0.36, 0.04), dark)
		if side < 0.0: leg_l = [hp, kn]
		else: leg_r = [hp, kn]

func apply_suit(colors: Dictionary) -> void:
	suit_primary = colors.get("primary", suit_primary)
	suit_accent = colors.get("accent", suit_accent)
	for m in _all_meshes(self):
		var mat := m.material_override as StandardMaterial3D
		if mat == null:
			continue
		if mat.emission_enabled and mat.albedo_color != Color(0.45, 0.85, 1.0):
			mat.albedo_color = suit_accent
			mat.emission = suit_accent
		elif not mat.emission_enabled and mat.albedo_color.v > 0.25:
			mat.albedo_color = suit_primary
	if pack_light:
		pack_light.light_color = suit_accent

func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out

func set_visor_state(state: int) -> void:
	var mat := visor.material_override as StandardMaterial3D
	if mat:
		var c := Settings.state_color(state)
		mat.albedo_color = c
		mat.emission = c

# ================================================================ animation
## `speed01` is planar speed normalised to sprint speed.
func animate(dt: float, speed01: float, grounded: bool, crouched: bool,
		climbing: bool, accel: Vector3, look_yaw_delta: float, pitch_deg: float) -> void:
	_breath += dt
	_blend_air = move_toward(_blend_air, 0.0 if grounded else 1.0, dt * 6.0)
	_blend_crouch = move_toward(_blend_crouch, 1.0 if crouched else 0.0, dt * 8.0)
	_blend_climb = move_toward(_blend_climb, 1.0 if climbing else 0.0, dt * 7.0)

	var stride: float = lerpf(6.4, 10.4, speed01)
	_cycle += dt * stride * maxf(speed01, 0.06)
	var swing := sin(_cycle) * lerpf(0.10, 0.95, speed01)
	var swing2 := sin(_cycle + PI) * lerpf(0.10, 0.95, speed01)
	var bob := absf(sin(_cycle)) * lerpf(0.005, 0.052, speed01)

	# torso lean into acceleration, plus a small bank on turns
	_lean = _lean.lerp(Vector2(clampf(accel.z * 0.03, -0.3, 0.3),
		clampf(-look_yaw_delta * 0.02, -0.25, 0.25)), clampf(dt * 6.0, 0.0, 1.0))

	var crouch_drop: float = _blend_crouch * 0.42
	root.position.y = -crouch_drop + (bob if grounded else 0.0)
	hips.rotation = Vector3(
		lerpf(0.0, 0.28, _blend_crouch) + _lean.x * 0.5,
		sin(_cycle) * 0.08 * speed01,
		_lean.y * 0.4)
	torso.rotation = Vector3(
		_lean.x + _blend_crouch * 0.22 + _blend_climb * 0.25,
		-sin(_cycle) * 0.10 * speed01,
		_lean.y * 0.6)
	chest.rotation.x = lerpf(0.0, -0.1, speed01) + sin(_breath * 1.6) * 0.012

	# Head tracks the camera pitch and stays level while walking.
	_head_pitch = lerpf(_head_pitch, clampf(deg_to_rad(pitch_deg) * 0.45, -0.5, 0.5), dt * 8.0)
	neck.rotation = Vector3(_head_pitch - _lean.x, 0, 0)
	head.rotation.y = lerpf(head.rotation.y, clampf(-look_yaw_delta * 0.02, -0.4, 0.4), dt * 8.0)

	if climbing:
		var reach := sin(_cycle * 0.6)
		arm_l[0].rotation = Vector3(-2.1 - reach * 0.5, 0.0, 0.25)
		arm_r[0].rotation = Vector3(-2.1 + reach * 0.5, 0.0, -0.25)
		arm_l[1].rotation.x = -0.5
		arm_r[1].rotation.x = -0.5
		leg_l[0].rotation = Vector3(0.5 + reach * 0.35, 0, 0.12)
		leg_r[0].rotation = Vector3(0.5 - reach * 0.35, 0, -0.12)
		leg_l[1].rotation.x = -0.9
		leg_r[1].rotation.x = -0.9
		return

	if _blend_air > 0.5:
		# airborne tuck
		arm_l[0].rotation = Vector3(-0.9, 0, 0.5)
		arm_r[0].rotation = Vector3(-0.9, 0, -0.5)
		arm_l[1].rotation.x = -0.8
		arm_r[1].rotation.x = -0.8
		leg_l[0].rotation.x = 0.55
		leg_r[0].rotation.x = 0.15
		leg_l[1].rotation.x = -1.0
		leg_r[1].rotation.x = -0.4
		return

	arm_l[0].rotation = Vector3(swing * 0.72, 0, 0.10 + _blend_crouch * 0.2)
	arm_r[0].rotation = Vector3(swing2 * 0.72, 0, -0.10 - _blend_crouch * 0.2)
	arm_l[1].rotation.x = -0.24 - maxf(0.0, swing) * 0.55 - _blend_crouch * 0.3
	arm_r[1].rotation.x = -0.24 - maxf(0.0, swing2) * 0.55 - _blend_crouch * 0.3
	leg_l[0].rotation.x = swing2 * 0.66 - _blend_crouch * 0.5
	leg_r[0].rotation.x = swing * 0.66 - _blend_crouch * 0.5
	leg_l[1].rotation.x = -maxf(0.0, -swing2) * 0.95 - 0.06 - _blend_crouch * 0.75
	leg_r[1].rotation.x = -maxf(0.0, -swing) * 0.95 - 0.06 - _blend_crouch * 0.75

func play_land(strength: float) -> void:
	var t := create_tween()
	t.tween_property(root, "position:y", root.position.y - clampf(strength, 0.05, 0.35), 0.08)
	t.tween_property(root, "position:y", root.position.y, 0.22).set_trans(Tween.TRANS_ELASTIC)

func set_hidden(v: bool) -> void:
	visible = not v
