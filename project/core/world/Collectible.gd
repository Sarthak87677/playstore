extends Area3D
class_name Collectible
## Memory Fragments, upgrade components and hidden-area markers.
## Fragments carry a short piece of found text - the game's main storytelling
## channel, since there is no voice acting.

signal collected(kind: String, index: int)

enum Kind { FRAGMENT, COMPONENT, HIDDEN, WILDLIFE }

@export var kind: int = Kind.FRAGMENT
@export var index: int = 0
@export var chapter: int = 0
@export var title: String = ""
@export var text: String = ""

var taken := false
var _visual: Node3D
var _spin := 0.0

func _ready() -> void:
	add_to_group("collectible")
	collision_layer = Veil.L_TRIGGER
	collision_mask = Veil.L_PLAYER
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.5
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body)
	_build_visual()

func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var col := _color()
	match kind:
		Kind.FRAGMENT:
			var shard := MeshInstance3D.new()
			shard.mesh = ProcAssets.crystal_mesh(index * 7 + chapter * 3, 0.42, 0.14, 5)
			shard.material_override = ProcAssets.additive(col, 2.6, false)
			_visual.add_child(shard)
			var halo := MeshInstance3D.new()
			halo.mesh = ProcAssets.ring_mesh(0.42, 0.02, 22, 5)
			halo.material_override = ProcAssets.additive(col, 2.0)
			halo.position.y = 0.2
			_visual.add_child(halo)
		Kind.COMPONENT:
			var box := MeshInstance3D.new()
			box.mesh = ProcAssets.box_mesh(Vector3(0.34, 0.34, 0.34))
			box.material_override = ProcAssets.mat("brass")
			_visual.add_child(box)
			var ring := MeshInstance3D.new()
			ring.mesh = ProcAssets.ring_mesh(0.36, 0.035, 20, 6)
			ring.material_override = ProcAssets.additive(col, 2.4)
			_visual.add_child(ring)
		Kind.HIDDEN:
			var m := MeshInstance3D.new()
			m.mesh = ProcAssets.ring_mesh(0.5, 0.04, 24, 6)
			m.material_override = ProcAssets.additive(col, 2.0)
			_visual.add_child(m)
		Kind.WILDLIFE:
			var b := MeshInstance3D.new()
			b.mesh = ProcAssets.rock_mesh(index + 40, 0.22, 0.4, 8, 12, 0.7)
			b.material_override = ProcAssets.emissive(col, 0.5)
			_visual.add_child(b)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position.y = 0.3
	_visual.add_child(light)

func _color() -> Color:
	match kind:
		Kind.FRAGMENT: return Color(0.62, 0.82, 1.0)
		Kind.COMPONENT: return Color(1.0, 0.78, 0.32)
		Kind.HIDDEN: return Color(0.72, 0.55, 1.0)
		_: return Color(0.55, 1.0, 0.66)

func _process(dt: float) -> void:
	if taken or _visual == null:
		return
	_spin += dt
	_visual.rotation.y += dt * 1.1
	_visual.position.y = sin(_spin * 1.7) * 0.12 + 0.2

func _on_body(b: Node3D) -> void:
	if taken or not (b is Player):
		return
	take()

func take() -> void:
	if taken:
		return
	taken = true
	match kind:
		Kind.FRAGMENT:
			if not GameState.note_fragment(chapter, index):
				# Already owned in a previous run; still give a small reward.
				GameState.award(60, "Fragment (already recorded)")
		Kind.COMPONENT:
			GameState.add_component(chapter)
		Kind.HIDDEN:
			GameState.note_hidden_area()
		Kind.WILDLIFE:
			GameState.note_wildlife()
	AudioDirector.play("collect", -5.0)
	collected.emit(_kind_name(), index)
	if _visual:
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_visual, "scale", Vector3.ONE * 2.2, 0.35)
		t.tween_property(_visual, "position:y", 1.6, 0.35)
		t.chain().tween_callback(queue_free)
	else:
		queue_free()

func _kind_name() -> String:
	return ["fragment", "component", "hidden", "wildlife"][clampi(kind, 0, 3)]
