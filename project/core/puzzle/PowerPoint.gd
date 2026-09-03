extends Node3D
class_name PowerPoint
## A node in a PowerNet: generator, junction or consumer. Renders as a pylon
## whose crown lights when energised.

signal powered_changed(on: bool)

@export var point_id: String = ""
@export var is_source: bool = false
@export var is_sink: bool = false
@export var enabled: bool = true
@export var label: String = ""

var powered := false
var _crown: MeshInstance3D
var _light: OmniLight3D
var _off_color := Color(0.30, 0.32, 0.36)
var _on_color := Color(0.45, 0.95, 1.0)

func _ready() -> void:
	add_to_group("power_point")
	if point_id == "":
		point_id = name
	_build()

func _build() -> void:
	var post := MeshInstance3D.new()
	post.mesh = ProcAssets.cylinder_mesh(0.13, 1.7, 10)
	post.position.y = 0.85
	post.material_override = ProcAssets.mat("metal_dark")
	add_child(post)
	var body := StaticBody3D.new()
	body.collision_layer = Veil.L_WORLD
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.18
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	body.add_child(cs)
	body.set_meta("surface", Veil.Surface.METAL)
	add_child(body)

	_crown = MeshInstance3D.new()
	_crown.mesh = ProcAssets.ring_mesh(0.28, 0.05, 18, 6)
	_crown.position.y = 1.78
	_crown.material_override = ProcAssets.emissive(_off_color, 0.3)
	add_child(_crown)

	_light = OmniLight3D.new()
	_light.light_color = _on_color
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.position.y = 1.8
	add_child(_light)

	if is_source:
		var base := MeshInstance3D.new()
		base.mesh = ProcAssets.ring_mesh(0.5, 0.08, 20, 6)
		base.position.y = 0.08
		base.material_override = ProcAssets.mat("brass")
		add_child(base)

func set_powered(on: bool) -> void:
	if powered == on:
		return
	powered = on
	var mat := _crown.material_override as StandardMaterial3D
	var c := _on_color if on else _off_color
	mat.albedo_color = c
	mat.emission = c
	mat.emission_energy_multiplier = 2.8 if on else 0.3
	var t := create_tween()
	t.tween_property(_light, "light_energy", 2.2 if on else 0.0, 0.3)
	if on:
		AudioDirector.play_3d("power_on", get_tree().current_scene, global_position, -12.0)
	powered_changed.emit(on)

func set_enabled(v: bool) -> void:
	enabled = v
