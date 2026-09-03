extends Node3D
class_name Conduit
## The visible run between two PowerPoints. Its geometry differs by state
## (intact cable in Memory, snapped stub in Ruin, conductive vine in Bloom) and
## it can also be made to conduct by imprinting CONDUCTIVE onto it.

var from_pos: Vector3
var to_pos: Vector3
var conducting := false
var imprint: Imprintable
var subject: VeilSubject
var conductive_states: Array = [Veil.State.MEMORY]
var _mesh: MeshInstance3D
var _glow: MeshInstance3D
var manager: VeilManager

func build(a: Vector3, b: Vector3, p_states: Array, mgr: VeilManager,
		allow_imprint: bool = true, sag: float = 0.6) -> void:
	from_pos = a
	to_pos = b
	conductive_states = p_states
	manager = mgr
	global_position = (a + b) * 0.5

	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var segs := 10
	for i in segs + 1:
		var t := float(i) / float(segs)
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		pts.append(p - global_position)
		radii.append(0.055)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ProcAssets.tube_mesh("cd_%.1f_%.1f_%.1f" % [a.x, a.z, b.x], pts, radii, 6, 0.4)
	_mesh.material_override = ProcAssets.mat("metal_dark")
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	_glow = MeshInstance3D.new()
	_glow.mesh = _mesh.mesh
	_glow.material_override = ProcAssets.additive(Color(0.45, 0.95, 1.0), 2.6)
	_glow.visible = false
	_glow.scale = Vector3.ONE * 1.25
	add_child(_glow)

	if allow_imprint:
		imprint = Imprintable.new()
		imprint.label = "Conduit"
		imprint.accepted = [Veil.Prop.CONDUCTIVE]
		imprint.hold_seconds = 0.0
		add_child(imprint)

func is_conductive() -> bool:
	if imprint and imprint.current == Veil.Prop.CONDUCTIVE:
		return true
	if manager == null:
		return false
	return manager.state_at(global_position) in conductive_states

func set_conducting(v: bool) -> void:
	if conducting == v:
		return
	conducting = v
	_glow.visible = v
