extends Node3D
class_name Mote
## MOTE: the survey drone. Follows on a critically damped spring, orbits points
## of interest, chirps, and speaks in subtitles. Its light colour reports the
## reality state at its own position, which is a genuinely useful readout when
## the player is standing at the edge of a field.

signal spoke(text: String, speaker: String, duration: float)

var target: Node3D
var shell: MeshInstance3D
var ring: MeshInstance3D
var light: OmniLight3D
var _vel := Vector3.ZERO
var _t := 0.0
var _orbit_target: Node3D = null
var _orbit_time := 0.0
var _speak_queue: Array = []
var _speak_cd := 0.0
var _idle_chatter := 20.0
var _state := Veil.State.RUIN
var _manager: VeilManager
var offset := Vector3(-0.85, 1.85, -0.6)

const IDLE_LINES := [
	"Field integrity holding. For now.",
	"I keep three maps of this place and none of them agree.",
	"Cell reads nominal. Do try to keep it that way.",
	"Something moved. Probably nothing. Probably.",
	"You are the only warm thing on my sensors.",
	"Recording. Everything you do is going in the log.",
]

func _ready() -> void:
	add_to_group("mote")
	_build()

func _build() -> void:
	var c := GameState.mote_colors()
	shell = MeshInstance3D.new()
	shell.mesh = ProcAssets.rock_mesh(99, 0.17, 0.05, 10, 14, 0.92)
	var m := ProcAssets.mat("metal").duplicate() as StandardMaterial3D
	m.albedo_color = c.get("shell", Color(0.72, 0.74, 0.78))
	m.roughness = 0.32
	m.metallic = 0.8
	shell.material_override = m
	add_child(shell)

	ring = MeshInstance3D.new()
	ring.mesh = ProcAssets.ring_mesh(0.26, 0.022, 22, 6)
	ring.material_override = ProcAssets.additive(c.get("light", Color(0.55, 0.85, 1.0)), 2.6)
	add_child(ring)

	var eye := MeshInstance3D.new()
	eye.mesh = ProcAssets.sphere_mesh(0.06, 8, 10)
	eye.material_override = ProcAssets.additive(c.get("light", Color(0.55, 0.85, 1.0)), 3.4, false)
	eye.position = Vector3(0, 0, 0.15)
	add_child(eye)

	light = OmniLight3D.new()
	light.light_color = c.get("light", Color(0.55, 0.85, 1.0))
	light.light_energy = 1.5
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)

func bind(p_target: Node3D, p_mgr: VeilManager) -> void:
	target = p_target
	_manager = p_mgr
	if target:
		global_position = target.global_position + offset

func say(text: String, speaker: String = "MOTE", duration: float = 4.0,
		priority: bool = false) -> void:
	var entry := {"text": text, "speaker": speaker, "duration": duration}
	if priority:
		_speak_queue.push_front(entry)
		_speak_cd = 0.0
	else:
		_speak_queue.append(entry)

func say_now(text: String, speaker: String = "MOTE", duration: float = 4.0) -> void:
	_speak_queue.clear()
	_speak_cd = 0.0
	say(text, speaker, duration, true)

func orbit(node: Node3D, seconds: float = 6.0) -> void:
	_orbit_target = node
	_orbit_time = seconds

func _process(dt: float) -> void:
	_t += dt
	_update_motion(dt)
	_update_speech(dt)
	if _manager:
		var s := _manager.state_at(global_position)
		if s != _state:
			_state = s
			var c := Settings.state_color(s)
			light.light_color = c
			(ring.material_override as StandardMaterial3D).albedo_color = c
			(ring.material_override as StandardMaterial3D).emission = c
	ring.rotation.y += dt * 2.2
	ring.rotation.x = sin(_t * 1.3) * 0.5
	light.light_energy = 1.4 + sin(_t * 3.1) * 0.22

func _update_motion(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var goal: Vector3
	if _orbit_target != null and is_instance_valid(_orbit_target) and _orbit_time > 0.0:
		_orbit_time -= dt
		var a := _t * 1.6
		goal = _orbit_target.global_position + Vector3(cos(a) * 1.1, 0.75, sin(a) * 1.1)
	else:
		_orbit_target = null
		var b := target.global_transform.basis
		goal = target.global_position + b * offset
		goal.y += sin(_t * 1.4) * 0.10
	# critically damped spring
	var to := goal - global_position
	_vel = _vel.lerp(to * 7.0, clampf(dt * 7.0, 0.0, 1.0))
	global_position += _vel * dt
	var look := (target.global_position + Vector3(0, 1.2, 0)) - global_position
	if look.length_squared() > 0.01:
		var want := Basis.looking_at(look.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(want, clampf(dt * 5.0, 0.0, 1.0))

func _update_speech(dt: float) -> void:
	_speak_cd = maxf(0.0, _speak_cd - dt)
	if _speak_cd > 0.0:
		return
	if _speak_queue.is_empty():
		_idle_chatter -= dt
		if _idle_chatter <= 0.0:
			_idle_chatter = randf_range(75.0, 160.0)
			if GameState.run.get("active", false):
				say(IDLE_LINES[randi() % IDLE_LINES.size()], "MOTE", 3.4)
		return
	var e: Dictionary = _speak_queue.pop_front()
	_speak_cd = float(e.duration) + 0.35
	AudioDirector.play("mote_chirp", -18.0, randf_range(0.94, 1.1))
	spoke.emit(String(e.text), String(e.speaker), float(e.duration))

func apply_skin() -> void:
	var c := GameState.mote_colors()
	(shell.material_override as StandardMaterial3D).albedo_color = c.get("shell", Color.WHITE)
	var lc: Color = c.get("light", Color(0.55, 0.85, 1.0))
	light.light_color = lc
	(ring.material_override as StandardMaterial3D).albedo_color = lc
	(ring.material_override as StandardMaterial3D).emission = lc

func ping_hint() -> void:
	AudioDirector.play("mote_query", -12.0)
	var t := create_tween()
	t.tween_property(light, "light_energy", 3.6, 0.12)
	t.tween_property(light, "light_energy", 1.5, 0.6)
