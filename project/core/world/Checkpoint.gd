extends Area3D
class_name Checkpoint
## Autosave point. Entering it stores the run snapshot and a respawn transform.

signal reached(id: String)

@export var id: String = "cp"
@export var label: String = "Checkpoint"
@export var respawn_offset: Vector3 = Vector3.ZERO
@export var respawn_yaw: float = 0.0
@export var silent: bool = false

var triggered := false
var _pillar: MeshInstance3D
var _light: OmniLight3D

func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = Veil.L_TRIGGER
	collision_mask = Veil.L_PLAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(4.0, 4.0, 4.0)
	cs.shape = sh
	cs.position = Vector3(0, 1.8, 0)
	add_child(cs)
	body_entered.connect(_on_body)

	if not silent:
		_pillar = MeshInstance3D.new()
		_pillar.mesh = ProcAssets.cylinder_mesh(0.14, 2.2, 10)
		_pillar.position = Vector3(0, 1.1, 0)
		_pillar.material_override = ProcAssets.mat("metal_dark")
		add_child(_pillar)
		var ring := MeshInstance3D.new()
		ring.mesh = ProcAssets.ring_mesh(0.42, 0.05, 20, 6)
		ring.position = Vector3(0, 2.1, 0)
		ring.material_override = ProcAssets.additive(Color(0.45, 0.9, 1.0), 2.4)
		add_child(ring)
		_light = OmniLight3D.new()
		_light.light_color = Color(0.45, 0.9, 1.0)
		_light.light_energy = 1.2
		_light.omni_range = 6.0
		_light.position = Vector3(0, 2.1, 0)
		add_child(_light)

func _on_body(b: Node3D) -> void:
	if triggered or not (b is Player):
		return
	triggered = true
	var pos := global_position + respawn_offset
	reached.emit(id)
	AudioDirector.play("checkpoint", -8.0)
	if _light:
		var t := create_tween()
		t.tween_property(_light, "light_energy", 3.4, 0.15)
		t.tween_property(_light, "light_energy", 1.2, 0.9)
	Log.info("Checkpoint reached: %s" % id)

func respawn_transform() -> Dictionary:
	return {"pos": global_position + respawn_offset, "yaw": deg_to_rad(respawn_yaw)}
