extends AnimatableBody3D
class_name MovingPlatform
## Platform that ferries the player between points. Uses AnimatableBody3D so
## CharacterBody3D riders are carried correctly by the physics engine.

signal arrived(index: int)

@export var points: Array[Vector3] = []
@export var speed: float = 2.2
@export var wait_time: float = 1.4
@export var size: Vector3 = Vector3(3.0, 0.3, 3.0)
@export var auto_run: bool = true
@export var loop_mode: bool = true
@export var material_name: String = "metal"

var running := true
var _i := 0
var _wait := 0.0
var _dir := 1

func _ready() -> void:
	add_to_group("moving_platform")
	sync_to_physics = true
	collision_layer = Veil.L_WORLD
	set_meta("surface", Veil.Surface.METAL)
	var m := MeshInstance3D.new()
	m.mesh = ProcAssets.box_mesh(size, 0.8)
	m.material_override = ProcAssets.mat(material_name)
	add_child(m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)
	running = auto_run
	if points.size() > 0:
		global_position = points[0]

func _physics_process(dt: float) -> void:
	if not running or points.size() < 2:
		return
	if _wait > 0.0:
		_wait -= dt
		return
	var goal := points[_i]
	var to := goal - global_position
	if to.length() < speed * dt * 1.2:
		global_position = goal
		arrived.emit(_i)
		_wait = wait_time
		_advance()
		return
	global_position += to.normalized() * speed * dt

func _advance() -> void:
	if loop_mode:
		_i = (_i + 1) % points.size()
		return
	_i += _dir
	if _i >= points.size():
		_i = points.size() - 2
		_dir = -1
	elif _i < 0:
		_i = 1
		_dir = 1

func start() -> void:
	running = true

func stop() -> void:
	running = false
