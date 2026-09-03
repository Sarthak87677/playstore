extends PuzzleBase
class_name ResonanceLock
## A lock that opens when a required set of conditions is satisfied at once -
## typically "these three plinths each hold a different imprinted property" or
## "these sections are each in the right state". The classic multi-state puzzle.

signal condition_changed(met: int, total: int)

@export var required: int = 3

var conditions: Array = []      # [{ "check": Callable, "label": String, "met": bool }]
var _ring: MeshInstance3D
var _pips: Array = []
var _light: OmniLight3D
var _met := 0

func _ready() -> void:
	super._ready()
	title = "Resonance Lock"
	hint_subtle = "Three tones, and it will open."
	hint_guided = "Each plinth wants a different property or state. Satisfy all of them together."
	hint_directed = "Scan for the properties this lock names, then imprint one onto each plinth before any of them lapse."
	_build()

func _build() -> void:
	var post := MeshInstance3D.new()
	post.mesh = ProcAssets.cylinder_mesh(0.22, 2.4, 12)
	post.position.y = 1.2
	post.material_override = ProcAssets.mat("metal_dark")
	add_child(post)
	var body := StaticBody3D.new()
	body.collision_layer = Veil.L_WORLD
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.28
	cy.height = 2.4
	cs.shape = cy
	cs.position.y = 1.2
	body.add_child(cs)
	body.set_meta("surface", Veil.Surface.METAL)
	add_child(body)

	_ring = MeshInstance3D.new()
	_ring.mesh = ProcAssets.ring_mesh(0.62, 0.06, 26, 8)
	_ring.position.y = 2.5
	_ring.material_override = ProcAssets.additive(Color(0.6, 0.65, 0.7), 0.8)
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.7, 0.8)
	_light.light_energy = 0.6
	_light.omni_range = 7.0
	_light.position.y = 2.5
	add_child(_light)

func add_condition(check: Callable, label: String) -> void:
	conditions.append({"check": check, "label": label, "met": false})
	var pip := MeshInstance3D.new()
	pip.mesh = ProcAssets.sphere_mesh(0.09, 8, 10)
	pip.material_override = ProcAssets.emissive(Color(0.35, 0.35, 0.4), 0.4)
	var i := _pips.size()
	var a := TAU * float(i) / maxf(float(required), 1.0)
	pip.position = Vector3(cos(a) * 0.62, 2.5, sin(a) * 0.62)
	add_child(pip)
	_pips.append(pip)
	required = maxi(required, conditions.size())

func _process(dt: float) -> void:
	if is_solved:
		_ring.rotation.y += dt * 1.4
		return
	var met := 0
	for i in conditions.size():
		var c: Dictionary = conditions[i]
		var ok: bool = c.check.is_valid() and bool(c.check.call())
		if ok != bool(c.met):
			c.met = ok
			if i < _pips.size():
				var mat := (_pips[i] as MeshInstance3D).material_override as StandardMaterial3D
				var col := Color(0.45, 1.0, 0.6) if ok else Color(0.35, 0.35, 0.4)
				mat.albedo_color = col
				mat.emission = col
				mat.emission_energy_multiplier = 2.6 if ok else 0.4
			AudioDirector.play_3d("switch", get_tree().current_scene, global_position,
				-10.0, 1.2 if ok else 0.8)
		if ok:
			met += 1
	if met != _met:
		_met = met
		condition_changed.emit(met, conditions.size())
		var f := float(met) / maxf(float(conditions.size()), 1.0)
		progress.emit(f)
		_light.light_energy = 0.6 + f * 2.6
		var rm := _ring.material_override as StandardMaterial3D
		var rc := Color(0.6, 0.7, 0.8).lerp(Color(0.5, 1.0, 0.7), f)
		rm.albedo_color = rc
		rm.emission = rc
	if met >= conditions.size() and conditions.size() > 0:
		mark_solved()
		_light.light_energy = 4.0
