extends Node3D
class_name VeilSubject
## An object that exists differently in Memory, Ruin and Bloom.
##
## Each state gets its own child subtree. Switching states swaps geometry,
## enables/disables collision shapes and areas, and fires a signal that
## behaviour scripts (hazards, guardians, puzzles) hook into. This is what makes
## a shift change what the world *is*, not merely how it looks.

signal state_applied(state: int)

@export var subject_id: String = ""
## When true the subject ignores fields entirely (used for permanent results
## of a solved puzzle, or for props that should never shift).
@export var locked: bool = false
## Extra radius added when testing whether the field covers this subject,
## so large structures shift as soon as the field touches them.
@export var influence_radius: float = 0.0

var variants: Array = [null, null, null]
var current_state: int = Veil.State.RUIN
var _applied := false
var _mgr: Node = null

func _ready() -> void:
	add_to_group("veil_subject")
	if subject_id == "":
		subject_id = name

## Register the three subtrees. Any of them may be null (meaning "nothing exists
## here in that state" - which is itself a gameplay fact: floors vanish).
func setup(mem: Node3D, ruin: Node3D, bloom: Node3D, initial: int = Veil.State.RUIN) -> void:
	variants = [mem, ruin, bloom]
	for i in 3:
		var v: Node3D = variants[i]
		if v != null and v.get_parent() != self:
			add_child(v)
	current_state = initial
	_applied = false
	apply_state(initial, true)

func has_variant(s: int) -> bool:
	return variants[clampi(s, 0, 2)] != null

func apply_state(s: int, instant: bool = false) -> void:
	s = clampi(s, 0, 2)
	if locked and _applied:
		return
	if _applied and s == current_state:
		return
	current_state = s
	_applied = true
	for i in 3:
		_set_variant_active(variants[i], i == s, instant)
	state_applied.emit(s)

func _set_variant_active(node: Node, active: bool, instant: bool) -> void:
	if node == null:
		return
	if node is Node3D:
		(node as Node3D).visible = active
	_toggle_physics(node, active)
	if not instant and active and node is Node3D:
		_pop_in(node as Node3D)

func _toggle_physics(node: Node, active: bool) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).set_deferred("disabled", not active)
	elif node is CollisionPolygon3D:
		(node as CollisionPolygon3D).set_deferred("disabled", not active)
	elif node is Area3D:
		var a := node as Area3D
		a.set_deferred("monitoring", active)
		a.set_deferred("monitorable", active)
	elif node is RigidBody3D:
		var rb := node as RigidBody3D
		rb.set_deferred("freeze", not active)
		rb.set_deferred("collision_layer", rb.get_meta("base_layer", Veil.L_PROP) if active else 0)
		rb.set_deferred("collision_mask", rb.get_meta("base_mask", Veil.L_WORLD | Veil.L_PROP) if active else 0)
	elif node is GPUParticles3D:
		(node as GPUParticles3D).emitting = active
	elif node is Light3D:
		(node as Light3D).visible = active
	for c in node.get_children():
		_toggle_physics(c, active)

## Brief scale punch so a shifted object reads as *arriving*, not popping.
func _pop_in(node: Node3D) -> void:
	if not is_inside_tree():
		return
	var base := node.scale
	node.scale = base * 0.86
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "scale", base, 0.28)

## Distance test used by the manager. Uses the subject origin plus its
## influence radius so large props shift when touched, not only when centred.
func covered_by(center: Vector3, radius: float) -> bool:
	return global_position.distance_to(center) <= radius + influence_radius
