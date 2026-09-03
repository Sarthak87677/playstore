extends Node3D
class_name VeilField
## The visible, movable reality field. Renders as a shimmering shell whose
## colour reports the state it will impose, plus a ground ring so the player can
## judge coverage on uneven terrain.

var radius: float = 6.0:
	set(v):
		radius = maxf(0.5, v)
		_resize()
var target_state: int = Veil.State.MEMORY:
	set(v):
		target_state = clampi(v, 0, 2)
		_recolor()
var pinned: bool = false
var life: float = 0.0          # seconds remaining when pinned; <=0 = infinite
var active: bool = true

var _shell: MeshInstance3D
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0

func _ready() -> void:
	add_to_group("veil_field")
	_shell = MeshInstance3D.new()
	_shell.mesh = SphereMesh.new()
	(_shell.mesh as SphereMesh).radial_segments = 32
	(_shell.mesh as SphereMesh).rings = 18
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)

	_core = MeshInstance3D.new()
	_core.mesh = SphereMesh.new()
	(_core.mesh as SphereMesh).radial_segments = 12
	(_core.mesh as SphereMesh).rings = 8
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_ring = MeshInstance3D.new()
	_ring.mesh = ProcAssets.ring_mesh(1.0, 0.02, 48, 6)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_energy = 1.6
	_light.shadow_enabled = false
	add_child(_light)

	_resize()
	_recolor()

func _resize() -> void:
	if _shell == null:
		return
	var sm := _shell.mesh as SphereMesh
	sm.radius = radius
	sm.height = radius * 2.0
	var cm := _core.mesh as SphereMesh
	cm.radius = radius * 0.10
	cm.height = radius * 0.20
	_ring.scale = Vector3(radius, 1.0, radius)
	_light.omni_range = radius * 2.4

func _recolor() -> void:
	if _shell == null:
		return
	var c := Settings.state_color(target_state)
	var shell_mat := ProcAssets.additive(Color(c.r, c.g, c.b, 0.10), 0.55)
	_shell.material_override = shell_mat
	_core.material_override = ProcAssets.additive(c, 3.2, false)
	_ring.material_override = ProcAssets.additive(c, 2.4)
	_light.light_color = c

func _process(dt: float) -> void:
	_t += dt
	if not active:
		return
	var pulse := 1.0 + sin(_t * 2.6) * 0.018
	_shell.scale = Vector3.ONE * pulse
	_core.rotation.y += dt * 1.4
	_ring.rotation.y += dt * (0.5 if pinned else 0.22)
	_light.light_energy = (2.2 if pinned else 1.5) + sin(_t * 4.0) * 0.25
	if pinned and life > 0.0:
		life -= dt
		var frac := clampf(life / 3.0, 0.0, 1.0)
		if life < 3.0:
			# Flicker out in the last three seconds as a fair warning.
			_shell.visible = fmod(_t * 8.0, 1.0) < 0.4 + frac * 0.6

func set_visible_shell(v: bool) -> void:
	_shell.visible = v
	_core.visible = v
	_ring.visible = v
	_light.visible = v
