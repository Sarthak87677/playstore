extends Area3D
class_name Scannable
## Anything the player can point the scanner at. Carries a display name, a
## short field note (environmental storytelling without voice acting) and,
## optionally, a recordable property that the state-transfer mechanic uses.

signal scanned(by: Node)

@export var display_name: String = "Unidentified object"
@export var note: String = ""
@export var property: int = Veil.Prop.NONE
## Which reality state must be active here for the property to be recordable.
## -1 means "any state".
@export var property_state: int = -1
@export var unique_id: String = ""
@export var xp_bonus: int = 0
@export var is_wildlife: bool = false
@export var is_fragment: bool = false
@export var fragment_index: int = -1

var already_scanned := false
var _outline: MeshInstance3D = null

func _ready() -> void:
	add_to_group("scannable")
	collision_layer = Veil.L_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true
	if unique_id == "":
		unique_id = "%s_%s" % [get_tree().current_scene.name if get_tree().current_scene else "w", name]

func can_record() -> bool:
	if property == Veil.Prop.NONE:
		return false
	if property_state < 0:
		return true
	var mgr := _manager()
	return mgr != null and mgr.state_at(global_position) == property_state

func _manager() -> VeilManager:
	var g := get_tree().get_first_node_in_group("veil_manager")
	return g as VeilManager

func perform_scan(by: Node) -> Dictionary:
	var first := not already_scanned
	already_scanned = true
	GameState.note_scan(unique_id)
	if xp_bonus > 0 and first:
		GameState.award(xp_bonus, display_name, true)
	if is_wildlife and first:
		GameState.note_wildlife()
	scanned.emit(by)
	return {
		"name": display_name, "note": note,
		"property": property if can_record() else Veil.Prop.NONE,
		"first": first,
	}
