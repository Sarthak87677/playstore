extends Node3D
class_name Imprintable
## A target that will accept a recorded property. This is the second half of the
## state-transfer mechanic: record CONDUCTIVE from an intact Memory cable, then
## imprint it onto the dead Ruin conduit that actually spans the gap.

signal imprinted(prop: int)
signal imprint_rejected(prop: int)
signal imprint_cleared()

@export var accepted: Array[int] = []
@export var label: String = "Receptive surface"
@export var hold_seconds: float = 0.0     # 0 = permanent
@export var one_shot: bool = false

var current: int = Veil.Prop.NONE
var _timer := 0.0
var _spent := false
var _glow: MeshInstance3D = null

func _ready() -> void:
	add_to_group("imprintable")

func accepts(prop: int) -> bool:
	if _spent and one_shot:
		return false
	if prop == Veil.Prop.NONE:
		return false
	return accepted.is_empty() or (prop in accepted)

func apply(prop: int) -> bool:
	if not accepts(prop):
		imprint_rejected.emit(prop)
		return false
	current = prop
	_spent = true
	_timer = hold_seconds
	_show_glow(Veil.PROP_COLORS[clampi(prop, 0, Veil.PROP_COLORS.size() - 1)])
	imprinted.emit(prop)
	return true

func clear_imprint() -> void:
	if current == Veil.Prop.NONE:
		return
	current = Veil.Prop.NONE
	_timer = 0.0
	_hide_glow()
	imprint_cleared.emit()

func _process(dt: float) -> void:
	if current != Veil.Prop.NONE and hold_seconds > 0.0:
		_timer -= dt
		if _timer <= 0.0:
			clear_imprint()

func _show_glow(c: Color) -> void:
	if _glow == null:
		_glow = MeshInstance3D.new()
		_glow.mesh = ProcAssets.ring_mesh(0.55, 0.045, 24, 6)
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_glow)
	_glow.material_override = ProcAssets.additive(c, 3.0)
	_glow.visible = true

func _hide_glow() -> void:
	if _glow:
		_glow.visible = false
