extends Node3D
class_name Gate
## A door, hatch, shutter or bridge section that opens when its condition is
## met. Movement is a real transform change with live collision, so an opening
## gate can lift the player or block a guardian.

signal opened()
signal closed()

@export var size: Vector3 = Vector3(3.2, 3.4, 0.35)
@export var open_offset: Vector3 = Vector3(0, 3.5, 0)
@export var open_time: float = 1.6
@export var material_name: String = "metal"
@export var starts_open: bool = false

var is_open := false
var _body: StaticBody3D
var _closed_pos: Vector3
var _tween: Tween

func _ready() -> void:
	add_to_group("gate")
	_body = StaticBody3D.new()
	_body.collision_layer = Veil.L_WORLD
	_body.set_meta("surface", Veil.Surface.METAL)
	add_child(_body)
	var m := MeshInstance3D.new()
	m.mesh = ProcAssets.box_mesh(size, 0.8)
	m.material_override = ProcAssets.mat(material_name)
	_body.add_child(m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	_body.add_child(cs)
	_closed_pos = _body.position
	if starts_open:
		_body.position = _closed_pos + open_offset
		is_open = true

func open() -> void:
	if is_open:
		return
	is_open = true
	_animate(_closed_pos + open_offset)
	AudioDirector.play_3d("door", get_tree().current_scene, global_position, -6.0)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_animate(_closed_pos)
	AudioDirector.play_3d("door", get_tree().current_scene, global_position, -8.0, 0.85)
	closed.emit()

func toggle() -> void:
	if is_open: close()
	else: open()

func _animate(target: Vector3) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_body, "position", target, open_time)
