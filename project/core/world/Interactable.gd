extends Area3D
class_name Interactable
## Anything the player can press Interact on. Supplies the prompt text, an
## optional held-duration, and a marker the HUD draws in world space.

signal used(by: Node)
signal focus_entered()
signal focus_exited()

@export var prompt: String = "Use"
@export var verb: String = "Interact"
@export var hold_time: float = 0.0
@export var enabled: bool = true
@export var one_shot: bool = false
@export var marker: bool = true
@export var marker_offset: Vector3 = Vector3(0, 0.6, 0)

var used_once := false
var focused := false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Veil.L_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true

func can_use() -> bool:
	return enabled and not (one_shot and used_once)

func use(by: Node) -> void:
	if not can_use():
		AudioDirector.play("ui_deny", -12.0)
		return
	used_once = true
	AudioDirector.play_3d("interact", get_tree().current_scene, global_position, -6.0)
	Hints.did("interact")
	Hints.note_progress()
	used.emit(by)

func set_focus(v: bool) -> void:
	if focused == v:
		return
	focused = v
	if v: focus_entered.emit()
	else: focus_exited.emit()
