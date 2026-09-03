extends Node3D
class_name PressurePlate
## Weight-activated plate. Accepts the player, physics props, or a guardian.
## Required mass is configurable so "stand on it yourself" and "you need
## something heavy" are different puzzles.

signal pressed()
signal released()
signal weight_changed(total: float)

@export var required_mass: float = 40.0
@export var plate_size: Vector3 = Vector3(2.0, 0.16, 2.0)
@export var accepts_player: bool = true
@export var latching: bool = false

var active := false
var _bodies: Array = []
var _plate: MeshInstance3D
var _light: OmniLight3D
var _area: Area3D
var _rest_y := 0.0

func _ready() -> void:
	add_to_group("pressure_plate")
	var base := MeshInstance3D.new()
	base.mesh = ProcAssets.box_mesh(plate_size * Vector3(1.18, 0.4, 1.18))
	base.material_override = ProcAssets.mat("metal_dark")
	base.position.y = -plate_size.y * 0.4
	add_child(base)

	_plate = MeshInstance3D.new()
	_plate.mesh = ProcAssets.box_mesh(plate_size)
	_plate.material_override = ProcAssets.mat("metal")
	add_child(_plate)
	_rest_y = _plate.position.y

	var body := StaticBody3D.new()
	body.collision_layer = Veil.L_WORLD
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = plate_size
	cs.shape = bs
	body.add_child(cs)
	body.set_meta("surface", Veil.Surface.METAL)
	add_child(body)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.4, 0.3)
	_light.light_energy = 0.8
	_light.omni_range = 3.0
	_light.position.y = 0.4
	add_child(_light)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = Veil.L_PLAYER | Veil.L_PROP | Veil.L_GUARDIAN
	var acs := CollisionShape3D.new()
	var abs_shape := BoxShape3D.new()
	abs_shape.size = Vector3(plate_size.x, 1.4, plate_size.z)
	acs.shape = abs_shape
	acs.position.y = 0.7
	_area.add_child(acs)
	_area.body_entered.connect(_on_enter)
	_area.body_exited.connect(_on_exit)
	add_child(_area)

func _on_enter(b: Node3D) -> void:
	if b is Player and not accepts_player:
		return
	if not (b in _bodies):
		_bodies.append(b)
		_evaluate()

func _on_exit(b: Node3D) -> void:
	if b in _bodies:
		_bodies.erase(b)
		_evaluate()

func total_mass() -> float:
	var m := 0.0
	for b in _bodies:
		if not is_instance_valid(b):
			continue
		if b is RigidBody3D:
			m += (b as RigidBody3D).mass
		elif b is Player:
			m += 78.0
		elif b is Guardian:
			m += 220.0
	return m

func _evaluate() -> void:
	var m := total_mass()
	weight_changed.emit(m)
	var want := m >= required_mass
	if want == active:
		return
	if active and latching:
		return
	active = want
	var t := create_tween()
	t.tween_property(_plate, "position:y", _rest_y + (-plate_size.y * 0.55 if active else 0.0), 0.18)
	_light.light_color = Color(0.4, 1.0, 0.5) if active else Color(1.0, 0.4, 0.3)
	AudioDirector.play_3d("switch", get_tree().current_scene, global_position, -8.0,
		1.15 if active else 0.85)
	if active: pressed.emit()
	else: released.emit()

func _physics_process(_dt: float) -> void:
	# Bodies can be freed or shifted out of existence beneath us.
	var dirty := false
	for i in range(_bodies.size() - 1, -1, -1):
		if not is_instance_valid(_bodies[i]) or not (_bodies[i] as Node3D).is_inside_tree():
			_bodies.remove_at(i)
			dirty = true
	if dirty:
		_evaluate()
