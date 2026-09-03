extends Area3D
class_name Hazard
## Damaging or impeding volume. Hazards are state-aware: a steam vent may only
## exist in Ruin, and a frozen pool only in Memory.

@export var dps: float = 12.0
@export var kind: String = "hazard"
@export var slow_factor: float = 1.0
@export var push: Vector3 = Vector3.ZERO
@export var lethal: bool = false

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = Veil.L_HAZARD
	collision_mask = 0
	monitoring = false
	monitorable = true
	set_meta("kind", kind)
	set_meta("dps", dps * Tuning.dmg_scale(GameState.difficulty()))

func affect_player(p: Node, dt: float) -> void:
	var pl := p as Player
	if pl == null:
		return
	if lethal:
		pl.apply_damage(9999.0, kind)
		return
	if push != Vector3.ZERO:
		pl.velocity += push * dt

func configure(p_dps: float, p_kind: String) -> void:
	dps = p_dps
	kind = p_kind
	set_meta("kind", kind)
	set_meta("dps", dps * Tuning.dmg_scale(GameState.difficulty()))
