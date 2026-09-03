extends RigidBody3D
class_name PhysicsProp
## Carryable, throwable puzzle mass. Buoyancy, conductivity and rigidity are all
## imprintable, which is how a crate becomes a raft, a bridge or a switch.

signal picked_up(by: Node)
signal dropped()

@export var prop_mass: float = 45.0
@export var size: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var label: String = "Crate"
@export var material_name: String = "wood"
@export var surface: int = Veil.Surface.WOOD

var carried_by: Node3D = null
var imprint: Imprintable
var interact: Interactable
var _carry_offset := Vector3(0, 0.2, -1.1)

func _ready() -> void:
	add_to_group("physics_prop")
	add_to_group("buoyant")
	mass = prop_mass
	collision_layer = Veil.L_PROP
	collision_mask = Veil.L_WORLD | Veil.L_PROP | Veil.L_PLAYER
	set_meta("base_layer", Veil.L_PROP)
	set_meta("base_mask", Veil.L_WORLD | Veil.L_PROP | Veil.L_PLAYER)
	set_meta("surface", surface)
	set_meta("buoyancy", 0.7)
	continuous_cd = true
	can_sleep = true

	var m := MeshInstance3D.new()
	m.mesh = ProcAssets.box_mesh(size, 1.4)
	m.material_override = ProcAssets.mat(material_name)
	add_child(m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)

	imprint = Imprintable.new()
	imprint.label = label
	imprint.accepted = [Veil.Prop.BUOYANT, Veil.Prop.RIGID, Veil.Prop.CONDUCTIVE,
		Veil.Prop.LUMINOUS, Veil.Prop.HOLLOW]
	add_child(imprint)
	imprint.imprinted.connect(_on_imprint)

	interact = Interactable.new()
	interact.prompt = "Carry %s" % label
	var ics := CollisionShape3D.new()
	var isp := SphereShape3D.new()
	isp.radius = maxf(size.length() * 0.6, 0.9)
	ics.shape = isp
	interact.add_child(ics)
	interact.used.connect(_on_used)
	add_child(interact)

func _on_imprint(prop: int) -> void:
	match prop:
		Veil.Prop.BUOYANT:
			set_meta("buoyancy", 3.2)
			gravity_scale = 0.35
		Veil.Prop.HOLLOW:
			mass = prop_mass * 0.35
			set_meta("buoyancy", 2.4)
		Veil.Prop.RIGID:
			freeze = true
			freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		Veil.Prop.LUMINOUS:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.94, 0.72)
			l.light_energy = 2.4
			l.omni_range = 9.0
			add_child(l)
		Veil.Prop.CONDUCTIVE:
			pass

func _on_used(by: Node) -> void:
	if carried_by == null:
		pick_up(by as Node3D)
	else:
		drop()

func pick_up(by: Node3D) -> void:
	if freeze:
		return
	carried_by = by
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 0
	interact.prompt = "Drop %s" % label
	picked_up.emit(by)

func drop() -> void:
	if carried_by == null:
		return
	var thrower := carried_by
	carried_by = null
	freeze = false
	collision_layer = Veil.L_PROP
	interact.prompt = "Carry %s" % label
	if thrower is Player:
		linear_velocity = -thrower.global_transform.basis.z * 3.0 + Vector3.UP * 1.4
	dropped.emit()

func _physics_process(dt: float) -> void:
	if carried_by != null and is_instance_valid(carried_by):
		var want := carried_by.global_position \
			+ carried_by.global_transform.basis * _carry_offset + Vector3(0, 0.9, 0)
		global_position = global_position.lerp(want, clampf(dt * 16.0, 0.0, 1.0))
		global_rotation.y = carried_by.global_rotation.y
	elif carried_by != null:
		carried_by = null
