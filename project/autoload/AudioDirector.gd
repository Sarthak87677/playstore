extends Node
## Audio buses, adaptive music and global one-shot playback.
##
## Music is a live sequencer rather than a rendered track: ProcAudio supplies
## short pitched one-shots and this node schedules them on a beat clock. Layers
## fade in with tension, and each reality state has its own register, scale
## colour and instrument mix, so Memory / Ruin / Bloom are audibly distinct.

signal beat(index: int)

const BUSES := ["Music", "SFX", "Ambience", "UI"]
const POOL_2D := 20

# Scales as semitone offsets from the chapter root.
const SCALES := {
	"aeolian":    [0, 2, 3, 5, 7, 8, 10],
	"dorian":     [0, 2, 3, 5, 7, 9, 10],
	"lydian":     [0, 2, 4, 6, 7, 9, 11],
	"phrygian":   [0, 1, 3, 5, 7, 8, 10],
	"pentatonic": [0, 3, 5, 7, 10],
	"whole":      [0, 2, 4, 6, 8, 10],
	"harmonic":   [0, 2, 3, 5, 7, 8, 11],
}

var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_i := 0
var _amb: Array[AudioStreamPlayer] = []

# ---- music state
var enabled := true
var tempo := 62.0
var root_note := 45.0
var scale_name := "aeolian"
var intensity := 0.0            # 0 calm .. 1 danger
var _target_intensity := 0.0
var state_tint: int = Veil.State.RUIN
var _beat_t := 0.0
var _beat_i := 0
var _phrase := 0
var _melody_seed := 1
var _rng := RandomNumberGenerator.new()
var _muted_for_cutscene := false
var _duck := 1.0
var _duck_target := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_rng.seed = 12345
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_music_players.append(p)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.volume_db = -80.0
		add_child(p)
		_amb.append(p)

func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) >= 0:
			continue
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, b)
		AudioServer.set_bus_send(idx, "Master")
	# Gentle space on music + ambience; a limiter keeps the master honest.
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0 and AudioServer.get_bus_effect_count(mi) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.72; rv.damping = 0.42; rv.wet = 0.30; rv.dry = 0.85
		rv.predelay_msec = 30.0; rv.spread = 0.8
		AudioServer.add_bus_effect(mi, rv)
	var ai := AudioServer.get_bus_index("Ambience")
	if ai >= 0 and AudioServer.get_bus_effect_count(ai) == 0:
		var rv2 := AudioEffectReverb.new()
		rv2.room_size = 0.55; rv2.wet = 0.18; rv2.dry = 0.95
		AudioServer.add_bus_effect(ai, rv2)
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -0.6
		lim.threshold_db = -1.4
		AudioServer.add_bus_effect(0, lim)

# ================================================================ one-shots
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var s := ProcAudio.sfx(name)
	if s == null:
		return
	_play_stream(s, volume_db, pitch, bus)

func play_ui(name: String, volume_db: float = 0.0) -> void:
	_play_stream(ProcAudio.sfx(name), volume_db, 1.0, "UI")

func _play_stream(s: AudioStream, volume_db: float, pitch: float, bus: String) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.05, 4.0)
	p.play()

## Frees a one-shot player when it finishes. Some audio drivers - including the
## silent fallback used on machines with no output device - never emit
## `finished`, so a Timer parented to the player guarantees cleanup. The timer
## dies with the node, so nothing here can outlive what it refers to.
func _arm_autofree(p: Node, s: AudioStream) -> void:
	p.finished.connect(p.queue_free)
	var life := 4.0
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		life = maxf(0.5, float(wav.data.size()) * 0.5
			/ maxf(float(wav.mix_rate), 1.0)) + 0.6
	var t := Timer.new()
	t.wait_time = life
	t.one_shot = true
	t.autostart = true
	p.add_child(t)
	t.timeout.connect(p.queue_free)

## Positional one-shot from an already-built stream.
func play_stream_3d(s: AudioStream, world: Node, pos: Vector3, volume_db: float = 0.0,
		pitch: float = 1.0, max_dist: float = 40.0) -> void:
	if world == null or not world.is_inside_tree() or s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.05, 4.0)
	p.max_distance = max_dist
	p.unit_size = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	world.add_child(p)
	p.global_position = pos
	p.play()
	_arm_autofree(p, s)

## Positional one-shot at a world point (creates a short-lived 3D player).
func play_3d(name: String, world: Node, pos: Vector3, volume_db: float = 0.0,
		pitch: float = 1.0, max_dist: float = 40.0) -> void:
	if world == null or not world.is_inside_tree():
		return
	var s: AudioStream = ProcAudio.sfx(name)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.05, 4.0)
	p.max_distance = max_dist
	p.unit_size = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	world.add_child(p)
	p.global_position = pos
	p.play()
	_arm_autofree(p, s)

# ================================================================ ambience
func set_ambience(profiles: Array, volumes: Array = []) -> void:
	for i in _amb.size():
		var p := _amb[i]
		if i < profiles.size():
			var prof := String(profiles[i])
			var want_vol: float = float(volumes[i]) if i < volumes.size() else 0.55
			var stream := ProcAudio.ambience(prof, 6.0, 100 + i * 7)
			if p.stream != stream:
				p.stream = stream
				p.play()
			create_tween().tween_property(p, "volume_db",
				linear_to_db(maxf(want_vol, 0.0005)), 1.6)
		else:
			create_tween().tween_property(p, "volume_db", -80.0, 1.2)

func fade_ambience(idx: int, vol: float, time: float = 1.2) -> void:
	if idx < 0 or idx >= _amb.size():
		return
	create_tween().tween_property(_amb[idx], "volume_db",
		linear_to_db(maxf(vol, 0.0005)), time)

func stop_ambience() -> void:
	for p in _amb:
		p.stop()
		p.volume_db = -80.0

# ================================================================ music
func configure_music(p_tempo: float, p_root: float, p_scale: String, seed_v: int = 1) -> void:
	tempo = clampf(p_tempo, 30.0, 160.0)
	root_note = p_root
	scale_name = p_scale if SCALES.has(p_scale) else "aeolian"
	_melody_seed = seed_v
	_rng.seed = seed_v * 7919 + 13
	_beat_i = 0
	_beat_t = 0.0
	_phrase = 0

func set_intensity(v: float) -> void:
	_target_intensity = clampf(v, 0.0, 1.0)

func set_state_tint(s: int) -> void:
	state_tint = clampi(s, 0, 2)

func music_enabled(v: bool) -> void:
	enabled = v

func duck(amount: float, time: float = 0.4) -> void:
	_duck_target = clampf(amount, 0.0, 1.0)
	var t := create_tween()
	t.tween_method(func(x: float) -> void: _duck = x, _duck, _duck_target, time)

func cutscene_mode(on: bool) -> void:
	_muted_for_cutscene = on
	duck(0.45 if on else 1.0, 0.6)

func _process(dt: float) -> void:
	intensity = move_toward(intensity, _target_intensity, dt * 0.35)
	if not enabled:
		return
	var spb := 60.0 / tempo
	_beat_t += dt
	while _beat_t >= spb:
		_beat_t -= spb
		_on_beat()

func _scale_note(degree: int, octave: int = 0) -> float:
	var sc: Array = SCALES[scale_name]
	var n: int = sc.size()
	var d: int = ((degree % n) + n) % n
	var oct: int = octave + int(floor(float(degree) / float(n)))
	return root_note + float(sc[d]) + 12.0 * float(oct)

## Reality state colours the harmony: Memory sits high and open, Ruin low and
## narrow, Bloom mid with added colour tones.
func _state_offset() -> float:
	match state_tint:
		Veil.State.MEMORY: return 12.0
		Veil.State.RUIN: return -12.0
		_: return 0.0

func _play_music(stream: AudioStream, db: float) -> void:
	var p := _music_players[_music_i]
	_music_i = (_music_i + 1) % _music_players.size()
	p.stream = stream
	p.volume_db = db + linear_to_db(clampf(_duck, 0.02, 1.0))
	p.play()

func _on_beat() -> void:
	beat.emit(_beat_i)
	var bar := _beat_i / 4
	var beat_in_bar := _beat_i % 4
	var off := _state_offset()

	# --- Layer 1: harmonic bed. Always present, changes chord every two bars.
	if beat_in_bar == 0 and bar % 2 == 0:
		_phrase = (_phrase + 1) % 4
		var deg: int = [0, 5, 3, 4][_phrase]
		_play_music(ProcAudio.pad(_scale_note(deg, -1) + off, 4.6,
			snappedf(0.25 + 0.35 * intensity, 0.2)), -13.0)
		if state_tint != Veil.State.RUIN:
			_play_music(ProcAudio.pad(_scale_note(deg + 2, -1) + off, 4.6, 0.2), -18.0)

	# --- Layer 2: low pulse. Enters with mild tension.
	if intensity > 0.12 and beat_in_bar == 0:
		_play_music(ProcAudio.sub(_scale_note(_phrase_root(), -2) + off, 1.6),
			lerpf(-22.0, -12.0, intensity))
	if intensity > 0.45 and beat_in_bar == 2:
		_play_music(ProcAudio.sub(_scale_note(_phrase_root(), -2) + off, 0.9),
			lerpf(-24.0, -15.0, intensity))

	# --- Layer 3: melody. Sparse in calm, denser as tension rises.
	var density := lerpf(0.18, 0.62, intensity)
	if state_tint == Veil.State.BLOOM:
		density += 0.14
	if _rng.randf() < density:
		var deg2 := _rng.randi_range(2, 9)
		var note := _scale_note(deg2, 0) + off
		if state_tint == Veil.State.MEMORY:
			_play_music(ProcAudio.bell(note + 12.0, 2.2), -19.0)
		elif state_tint == Veil.State.BLOOM:
			_play_music(ProcAudio.pluck(note, 1.5), -17.0)
		else:
			_play_music(ProcAudio.pluck(note - 12.0, 1.8, 0.492), -19.0)

	# --- Layer 4: alarm figure, only under real threat.
	if intensity > 0.78 and beat_in_bar % 2 == 0:
		_play_music(ProcAudio.pluck(_scale_note(1, 1) + off, 0.5, 0.48), -20.0)

	_beat_i += 1

func _phrase_root() -> int:
	return [0, 5, 3, 4][_phrase]

func stop_music() -> void:
	for p in _music_players:
		p.stop()

func stop_all() -> void:
	stop_music()
	stop_ambience()
	for p in _pool:
		p.stop()

## Menu bed: slow, wide, Memory-tinted.
func start_menu_music() -> void:
	configure_music(52.0, 45.0, "aeolian", 4242)
	set_state_tint(Veil.State.MEMORY)
	set_intensity(0.0)
	enabled = true
	set_ambience(["wind", "wind_high"], [0.30, 0.16])
