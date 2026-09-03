extends Node3D
class_name ValveWheel
## Hand wheel that steps a value between discrete stops - used for water level,
## coolant flow and dish elevation. Interacting turns it one notch.

signal turned(step: int, total: int)
signal at_stop(step: int)

@export var stops: int = 4
@export var start_step: int = 0
@export var label: String = "Valve"

var step: int = 0
var _wheel: Node3D
var interact: Interactable
var _spin_tween: Tween

func _ready() -> void:
	add_to_group("valve")
	step = clampi(start_step, 0, stops - 1)
	var post := MeshInstance3D.new()
	post.mesh = ProcAssets.cylinder_mesh(0.1, 1.1, 10)
	post.position.y = 0.55
	post.material_override = ProcAssets.mat("metal_dark")
	add_child(post)

	_wheel = Node3D.new()
	_wheel.position.y = 1.12
	add_child(_wheel)
	var rim := MeshInstance3D.new()
	rim.mesh = ProcAssets.ring_mesh(0.34, 0.055, 22, 6)
	rim.rotation.x = PI * 0.5
	rim.material_override = ProcAssets.mat("brass")
	_wheel.add_child(rim)
	for i in 4:
		var spoke := MeshInstance3D.new()
		spoke.mesh = ProcAssets.box_mesh(Vector3(0.05, 0.05, 0.66))
		spoke.rotation.y = TAU * float(i) / 8.0
		spoke.rotation.x = PI * 0.5
		spoke.material_override = ProcAssets.mat("brass")
		_wheel.add_child(spoke)

	var body := StaticBody3D.new()
	body.collision_layer = Veil.L_WORLD
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.16
	cy.height = 1.2
	cs.shape = cy
	cs.position.y = 0.6
	body.add_child(cs)
	body.set_meta("surface", Veil.Surface.METAL)
	add_child(body)

	interact = Interactable.new()
	interact.prompt = "Turn %s" % label
	var ics := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.5
	ics.shape = sp
	ics.position.y = 1.0
	interact.add_child(ics)
	interact.used.connect(_on_used)
	add_child(interact)
	_apply_visual(true)

func _on_used(_by: Node) -> void:
	step = (step + 1) % stops
	_apply_visual(false)
	AudioDirector.play_3d("switch", get_tree().current_scene, global_position, -6.0, 0.9)
	turned.emit(step, stops)
	at_stop.emit(step)

func set_step(v: int) -> void:
	step = clampi(v, 0, stops - 1)
	_apply_visual(false)
	turned.emit(step, stops)

func _apply_visual(instant: bool) -> void:
	var target := -TAU * float(step) / float(stops) * 1.5
	if instant:
		_wheel.rotation.z = target
		return
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = create_tween()
	_spin_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spin_tween.tween_property(_wheel, "rotation:z", target, 0.5)

func fraction() -> float:
	return float(step) / maxf(float(stops - 1), 1.0)
