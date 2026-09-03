extends Node3D
class_name LightPrism
## Rotatable prism that redirects a beam. Beams are real raycasts, so anything
## that appears or disappears with a reality shift blocks or frees the path.

signal beam_hit(target: Node)
signal rotated(yaw_step: int)

@export var steps: int = 8
@export var beam_length: float = 40.0
@export var emitter: bool = false
@export var beam_color: Color = Color(1.0, 0.92, 0.7)

var yaw_step := 0
var active := false
var _beam: MeshInstance3D
var _crystal: MeshInstance3D
var interact: Interactable
var _hit_node: Node = null
var _light: OmniLight3D

func _ready() -> void:
	add_to_group("light_prism")
	var post := MeshInstance3D.new()
	post.mesh = ProcAssets.cylinder_mesh(0.16, 1.2, 10)
	post.position.y = 0.6
	post.material_override = ProcAssets.mat("metal_dark")
	add_child(post)

	_crystal = MeshInstance3D.new()
	_crystal.mesh = ProcAssets.crystal_mesh(77, 0.5, 0.22, 6)
	_crystal.position.y = 1.2
	_crystal.material_override = ProcAssets.mat("glass")
	add_child(_crystal)

	var body := StaticBody3D.new()
	body.collision_layer = Veil.L_WORLD
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.24
	cy.height = 1.9
	cs.shape = cy
	cs.position.y = 0.95
	body.add_child(cs)
	body.set_meta("surface", Veil.Surface.GLASS)
	add_child(body)

	_beam = MeshInstance3D.new()
	_beam.mesh = ProcAssets.cylinder_mesh(0.045, 1.0, 8, false)
	_beam.material_override = ProcAssets.additive(beam_color, 3.2)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)

	_light = OmniLight3D.new()
	_light.light_color = beam_color
	_light.light_energy = 0.0
	_light.omni_range = 8.0
	_light.position.y = 1.3
	add_child(_light)

	interact = Interactable.new()
	interact.prompt = "Rotate prism"
	var ics := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.6
	ics.shape = sp
	ics.position.y = 1.0
	interact.add_child(ics)
	interact.used.connect(_on_used)
	add_child(interact)
	active = emitter

func _on_used(_by: Node) -> void:
	yaw_step = (yaw_step + 1) % steps
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_crystal, "rotation:y", TAU * float(yaw_step) / float(steps), 0.34)
	AudioDirector.play_3d("switch", get_tree().current_scene, global_position, -8.0, 1.1)
	rotated.emit(yaw_step)

func direction() -> Vector3:
	var a := TAU * float(yaw_step) / float(steps)
	return Vector3(sin(a), 0, cos(a))

func energise(on: bool) -> void:
	active = on

func _physics_process(_dt: float) -> void:
	_beam.visible = active
	_light.light_energy = 2.2 if active else 0.0
	var cm := _crystal.material_override
	if not active:
		if _hit_node != null:
			_hit_node = null
		return
	var origin := global_position + Vector3(0, 1.2, 0)
	var dir := direction()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * beam_length)
	q.collision_mask = Veil.L_WORLD | Veil.L_PROP | Veil.L_PLAYER
	var hit := space.intersect_ray(q)
	var end: Vector3 = hit.position if not hit.is_empty() else origin + dir * beam_length
	var len := origin.distance_to(end)
	_beam.position = to_local((origin + end) * 0.5)
	_beam.scale = Vector3(1, maxf(len, 0.05), 1)
	_beam.rotation = Vector3.ZERO
	_beam.look_at_from_position(_beam.global_position, end, Vector3.UP)
	_beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var node: Node = hit.collider if not hit.is_empty() else null
	if node != _hit_node:
		_hit_node = node
		beam_hit.emit(node)

func hit_target() -> Node:
	return _hit_node
