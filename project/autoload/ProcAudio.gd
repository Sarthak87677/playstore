extends Node
## Procedural audio synthesis. Every sound in VEILFORGE is generated from
## oscillators, noise and envelopes at runtime - no sample libraries ship with
## the game. Buffers are cached per session.
##
## Instruments are rendered as short pitched one-shots; AudioDirector sequences
## them into adaptive music, which keeps generation cost to well under a second
## per chapter instead of rendering minutes of audio.

const RATE := 22050
const RATE_HI := 32000

var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 0xA17D10

# ================================================================ core render
func _to_wav(samples: PackedFloat32Array, rate: int, loop: bool,
		fade_edges: bool = false) -> AudioStreamWAV:
	var n := samples.size()
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var fade := 0
	if fade_edges:
		fade = mini(int(rate * 0.02), n / 4)
	for i in n:
		var v := samples[i]
		if fade > 0:
			if i < fade:
				v *= float(i) / float(fade)
			elif i >= n - fade:
				v *= float(n - 1 - i) / float(fade)
		buf.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = buf
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n - 1
	return w

func _adsr(i: int, n: int, a: float, d: float, s: float, r: float) -> float:
	var t := float(i) / float(n)
	var ae := maxf(a, 0.0001)
	var de := maxf(d, 0.0001)
	var re := maxf(r, 0.0001)
	if t < ae:
		return t / ae
	if t < ae + de:
		return lerpf(1.0, s, (t - ae) / de)
	if t > 1.0 - re:
		return s * maxf(0.0, (1.0 - t) / re)
	return s

static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)

# ================================================================ instruments
## Warm sine/triangle stack with slow attack. The harmonic bed of every chapter.
func pad(note: float, dur: float = 3.0, bright: float = 0.35,
		detune: float = 0.16) -> AudioStreamWAV:
	var key := "pad_%.2f_%.2f_%.2f_%.2f" % [note, dur, bright, detune]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var f := midi_hz(note)
	var ph := [0.0, 0.0, 0.0, 0.0]
	var freqs := [f, f * (1.0 + detune * 0.006), f * 2.0, f * 3.0]
	var amps := [1.0, 0.85, bright * 0.5, bright * 0.22]
	var inv := 1.0 / float(RATE)
	for i in n:
		var v := 0.0
		for k in 4:
			ph[k] += freqs[k] * inv * TAU
			v += sin(ph[k]) * amps[k]
		v *= _adsr(i, n, 0.22, 0.20, 0.72, 0.42) * 0.20
		s[i] = v
	var w := _to_wav(s, RATE, false, true)
	_cache[key] = w
	return w

## Plucked string via a damped Karplus-Strong loop. Bright, decays fast.
func pluck(note: float, dur: float = 1.6, damp: float = 0.495) -> AudioStreamWAV:
	var key := "plk_%.2f_%.2f_%.3f" % [note, dur, damp]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var f := midi_hz(note)
	var L := maxi(4, int(float(RATE) / f))
	var ring := PackedFloat32Array(); ring.resize(L)
	var r := RandomNumberGenerator.new(); r.seed = int(note * 131.0) + 17
	for i in L:
		ring[i] = r.randf_range(-1.0, 1.0)
	var s := PackedFloat32Array(); s.resize(n)
	var idx := 0
	for i in n:
		var cur := ring[idx]
		var nxt := ring[(idx + 1) % L]
		var out := (cur + nxt) * damp
		ring[idx] = out
		idx = (idx + 1) % L
		s[i] = cur * _adsr(i, n, 0.002, 0.12, 0.55, 0.5) * 0.36
	var w := _to_wav(s, RATE, false, true)
	_cache[key] = w
	return w

## Two-operator FM bell. Used for discovery stings and Memory-state melody.
func bell(note: float, dur: float = 2.4, index: float = 3.2, ratio: float = 2.01) -> AudioStreamWAV:
	var key := "bel_%.2f_%.2f_%.2f_%.2f" % [note, dur, index, ratio]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var f := midi_hz(note)
	var inv := 1.0 / float(RATE)
	var cp := 0.0
	var mp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env := exp(-3.4 * t)
		mp += f * ratio * inv * TAU
		cp += f * inv * TAU
		s[i] = sin(cp + sin(mp) * index * env) * env * 0.28
	var w := _to_wav(s, RATE, false, true)
	_cache[key] = w
	return w

## Deep sub-bass swell for Ruin-state weight and impacts.
func sub(note: float, dur: float = 2.0) -> AudioStreamWAV:
	var key := "sub_%.2f_%.2f" % [note, dur]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var f := midi_hz(note)
	var inv := 1.0 / float(RATE)
	var ph := 0.0
	for i in n:
		ph += f * inv * TAU
		s[i] = (sin(ph) + sin(ph * 0.5) * 0.4) * _adsr(i, n, 0.05, 0.3, 0.5, 0.4) * 0.34
	var w := _to_wav(s, RATE, false, true)
	_cache[key] = w
	return w

# ================================================================ noise beds
func _lowpass(src: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(src.size())
	var rc := 1.0 / (TAU * maxf(cutoff, 1.0))
	var dt := 1.0 / float(rate)
	var a := dt / (rc + dt)
	var y := 0.0
	for i in src.size():
		y += a * (src[i] - y)
		out[i] = y
	return out

func _highpass(src: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(src.size())
	var rc := 1.0 / (TAU * maxf(cutoff, 1.0))
	var dt := 1.0 / float(rate)
	var a := rc / (rc + dt)
	var prev_x := 0.0
	var prev_y := 0.0
	for i in src.size():
		var x := src[i]
		prev_y = a * (prev_y + x - prev_x)
		prev_x = x
		out[i] = prev_y
	return out

func _noise(n: int, seed_v: int) -> PackedFloat32Array:
	var r := RandomNumberGenerator.new(); r.seed = seed_v
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		s[i] = r.randf_range(-1.0, 1.0)
	return s

## Seamless looping ambience bed. `profile` selects the spectral character.
func ambience(profile: String, dur: float = 6.0, seed_v: int = 1) -> AudioStreamWAV:
	var key := "amb_%s_%.1f_%d" % [profile, dur, seed_v]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var base := _noise(n, seed_v)
	var s: PackedFloat32Array
	var gain := 0.30
	match profile:
		"wind":
			s = _lowpass(base, 420.0, RATE)
			gain = 0.55
		"wind_high":
			s = _highpass(_lowpass(base, 2600.0, RATE), 500.0, RATE)
			gain = 0.36
		"blizzard":
			s = _highpass(_lowpass(base, 3800.0, RATE), 240.0, RATE)
			gain = 0.5
		"rain_glass":
			s = _highpass(_lowpass(base, 7000.0, RATE), 1400.0, RATE)
			gain = 0.30
		"forest":
			s = _lowpass(base, 900.0, RATE)
			gain = 0.34
		"water":
			s = _lowpass(_highpass(base, 180.0, RATE), 1500.0, RATE)
			gain = 0.40
		"machine":
			s = _lowpass(base, 160.0, RATE)
			gain = 0.55
		"cave":
			s = _lowpass(base, 260.0, RATE)
			gain = 0.42
		"storm":
			s = _lowpass(base, 700.0, RATE)
			gain = 0.62
		"sand":
			s = _highpass(_lowpass(base, 5200.0, RATE), 900.0, RATE)
			gain = 0.42
		_:
			s = _lowpass(base, 800.0, RATE)
	# Slow amplitude drift so the loop never sounds like a flat hiss.
	var drift := FastNoiseLite.new()
	drift.seed = seed_v + 3
	drift.frequency = 0.9
	for i in n:
		var t := float(i) / float(n)
		var d := 0.72 + 0.42 * (drift.get_noise_1d(t * 60.0) * 0.5 + 0.5)
		# Cross-fade the tail into the head for a click-free loop.
		var xf := 1.0
		var fl := int(n * 0.12)
		if i >= n - fl:
			var k := float(i - (n - fl)) / float(fl)
			s[i] = lerpf(s[i], s[n - 1 - i], k)
			xf = 1.0
		s[i] *= d * gain * xf
	# Machine profile gets a tonal hum on top.
	if profile == "machine":
		var ph := 0.0
		for i in n:
			ph += 52.0 / float(RATE) * TAU
			s[i] += sin(ph) * 0.10 + sin(ph * 2.0) * 0.04
	var w := _to_wav(s, RATE, true, false)
	_cache[key] = w
	return w

# ================================================================ sfx library
func sfx(name: String) -> AudioStreamWAV:
	if _cache.has("sfx_" + name):
		return _cache["sfx_" + name]
	var w := _build_sfx(name)
	_cache["sfx_" + name] = w
	return w

func _sweep(dur: float, f0: float, f1: float, wave: String, env: Array,
		noise_mix: float = 0.0, seed_v: int = 5, gain: float = 0.5) -> PackedFloat32Array:
	var n := int(RATE_HI * dur)
	var s := PackedFloat32Array(); s.resize(n)
	var r := RandomNumberGenerator.new(); r.seed = seed_v
	var ph := 0.0
	var inv := 1.0 / float(RATE_HI)
	for i in n:
		var t := float(i) / float(n)
		var f: float = lerpf(f0, f1, t * t if f1 < f0 else sqrt(t))
		ph += f * inv * TAU
		var v := 0.0
		match wave:
			"sine": v = sin(ph)
			"saw": v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
			"square": v = 1.0 if sin(ph) > 0.0 else -1.0
			"tri": v = asin(sin(ph)) * (2.0 / PI)
		if noise_mix > 0.0:
			v = lerpf(v, r.randf_range(-1, 1), noise_mix)
		s[i] = v * _adsr(i, n, env[0], env[1], env[2], env[3]) * gain
	return s

func _build_sfx(name: String) -> AudioStreamWAV:
	match name:
		# ---- veil device
		"shift_memory":
			var a := _sweep(0.75, 420.0, 1500.0, "sine", [0.02, 0.20, 0.5, 0.55], 0.05, 11, 0.42)
			var b := _sweep(0.75, 630.0, 2250.0, "sine", [0.05, 0.25, 0.4, 0.6], 0.0, 12, 0.22)
			return _mix2(a, b, RATE_HI)
		"shift_ruin":
			var a := _sweep(0.8, 900.0, 110.0, "saw", [0.005, 0.18, 0.35, 0.6], 0.22, 13, 0.40)
			var b := _sweep(0.8, 220.0, 62.0, "sine", [0.01, 0.2, 0.5, 0.55], 0.0, 14, 0.30)
			return _mix2(a, b, RATE_HI)
		"shift_bloom":
			var a := _sweep(0.85, 300.0, 860.0, "tri", [0.06, 0.24, 0.55, 0.5], 0.10, 15, 0.36)
			var b := _sweep(0.85, 1200.0, 1800.0, "sine", [0.12, 0.3, 0.4, 0.45], 0.0, 16, 0.18)
			return _mix2(a, b, RATE_HI)
		"field_open":
			return _to_wav(_sweep(0.42, 180.0, 940.0, "sine", [0.01, 0.14, 0.5, 0.5], 0.06, 17, 0.34), RATE_HI, false, true)
		"field_close":
			return _to_wav(_sweep(0.34, 880.0, 200.0, "sine", [0.01, 0.14, 0.4, 0.55], 0.05, 18, 0.30), RATE_HI, false, true)
		"field_pin":
			return _to_wav(_sweep(0.5, 520.0, 520.0, "sine", [0.01, 0.08, 0.6, 0.5], 0.02, 19, 0.32), RATE_HI, false, true)
		"scan_start":
			return _to_wav(_sweep(0.22, 1200.0, 1600.0, "sine", [0.01, 0.06, 0.6, 0.5], 0.0, 20, 0.22), RATE_HI, false, true)
		"scan_done":
			var a := _sweep(0.5, 880.0, 1320.0, "sine", [0.005, 0.1, 0.4, 0.6], 0.0, 21, 0.26)
			var b := _sweep(0.5, 1320.0, 1760.0, "sine", [0.08, 0.1, 0.4, 0.6], 0.0, 22, 0.16)
			return _mix2(a, b, RATE_HI)
		"imprint":
			var a := _sweep(0.6, 260.0, 1040.0, "tri", [0.01, 0.2, 0.45, 0.5], 0.04, 23, 0.34)
			var b := _sweep(0.6, 1040.0, 780.0, "sine", [0.14, 0.2, 0.4, 0.5], 0.0, 24, 0.20)
			return _mix2(a, b, RATE_HI)
		"imprint_fail":
			return _to_wav(_sweep(0.4, 400.0, 130.0, "square", [0.005, 0.14, 0.3, 0.6], 0.18, 25, 0.26), RATE_HI, false, true)
		"energy_low":
			return _to_wav(_sweep(0.55, 300.0, 210.0, "tri", [0.02, 0.2, 0.4, 0.55], 0.05, 26, 0.28), RATE_HI, false, true)

		# ---- movement
		"jump":
			return _to_wav(_sweep(0.22, 300.0, 520.0, "tri", [0.005, 0.1, 0.3, 0.6], 0.30, 27, 0.24), RATE_HI, false, true)
		"land_soft":
			return _to_wav(_sweep(0.18, 200.0, 90.0, "sine", [0.002, 0.08, 0.2, 0.7], 0.55, 28, 0.30), RATE_HI, false, true)
		"land_hard":
			var a := _sweep(0.34, 260.0, 60.0, "sine", [0.002, 0.1, 0.25, 0.65], 0.60, 29, 0.46)
			var b := _sweep(0.34, 90.0, 45.0, "sine", [0.002, 0.12, 0.3, 0.6], 0.0, 30, 0.34)
			return _mix2(a, b, RATE_HI)
		"roll":
			return _to_wav(_sweep(0.4, 160.0, 70.0, "sine", [0.02, 0.2, 0.3, 0.5], 0.7, 31, 0.28), RATE_HI, false, true)
		"mantle":
			return _to_wav(_sweep(0.3, 180.0, 260.0, "tri", [0.01, 0.12, 0.35, 0.55], 0.45, 32, 0.26), RATE_HI, false, true)
		"climb_grab":
			return _to_wav(_sweep(0.16, 420.0, 240.0, "tri", [0.004, 0.06, 0.3, 0.65], 0.62, 33, 0.24), RATE_HI, false, true)
		"dodge":
			return _to_wav(_sweep(0.26, 900.0, 300.0, "sine", [0.005, 0.1, 0.3, 0.6], 0.42, 34, 0.26), RATE_HI, false, true)
		"splash":
			return _to_wav(_sweep(0.5, 1800.0, 220.0, "sine", [0.004, 0.14, 0.3, 0.6], 0.78, 35, 0.36), RATE_HI, false, true)
		"swim":
			return _to_wav(_sweep(0.55, 700.0, 260.0, "sine", [0.06, 0.2, 0.35, 0.5], 0.72, 36, 0.20), RATE_HI, false, true)

		# ---- interaction / ui
		"ui_hover":
			return _to_wav(_sweep(0.09, 1500.0, 1500.0, "sine", [0.01, 0.04, 0.4, 0.6], 0.0, 37, 0.16), RATE_HI, false, true)
		"ui_click":
			return _to_wav(_sweep(0.13, 900.0, 1400.0, "sine", [0.004, 0.05, 0.4, 0.6], 0.02, 38, 0.24), RATE_HI, false, true)
		"ui_back":
			return _to_wav(_sweep(0.16, 900.0, 520.0, "sine", [0.004, 0.06, 0.4, 0.6], 0.02, 39, 0.22), RATE_HI, false, true)
		"ui_confirm":
			var a := _sweep(0.4, 700.0, 1050.0, "sine", [0.005, 0.1, 0.4, 0.6], 0.0, 40, 0.24)
			var b := _sweep(0.4, 1050.0, 1400.0, "sine", [0.1, 0.1, 0.4, 0.6], 0.0, 41, 0.16)
			return _mix2(a, b, RATE_HI)
		"ui_deny":
			return _to_wav(_sweep(0.22, 320.0, 200.0, "square", [0.004, 0.08, 0.3, 0.65], 0.1, 42, 0.20), RATE_HI, false, true)
		"interact":
			return _to_wav(_sweep(0.2, 620.0, 880.0, "tri", [0.005, 0.07, 0.4, 0.6], 0.06, 43, 0.26), RATE_HI, false, true)
		"switch":
			return _to_wav(_sweep(0.13, 1100.0, 480.0, "square", [0.002, 0.05, 0.25, 0.7], 0.24, 44, 0.24), RATE_HI, false, true)
		"door":
			var a := _sweep(1.1, 90.0, 130.0, "saw", [0.1, 0.3, 0.55, 0.35], 0.35, 45, 0.30)
			var b := _sweep(1.1, 260.0, 190.0, "sine", [0.15, 0.3, 0.4, 0.4], 0.1, 46, 0.16)
			return _mix2(a, b, RATE_HI)
		"machine_start":
			var a := _sweep(1.4, 40.0, 150.0, "saw", [0.25, 0.4, 0.6, 0.3], 0.2, 47, 0.34)
			var b := _sweep(1.4, 300.0, 620.0, "sine", [0.3, 0.3, 0.5, 0.3], 0.05, 48, 0.18)
			return _mix2(a, b, RATE_HI)
		"power_on":
			return _to_wav(_sweep(0.7, 120.0, 700.0, "tri", [0.06, 0.24, 0.55, 0.4], 0.06, 49, 0.32), RATE_HI, false, true)
		"puzzle_solved":
			var a := _sweep(0.9, 660.0, 990.0, "sine", [0.01, 0.16, 0.45, 0.55], 0.0, 50, 0.26)
			var b := _sweep(0.9, 990.0, 1320.0, "sine", [0.12, 0.2, 0.4, 0.5], 0.0, 51, 0.20)
			var c := _sweep(0.9, 1320.0, 1980.0, "sine", [0.26, 0.2, 0.35, 0.45], 0.0, 52, 0.14)
			return _mix3(a, b, c, RATE_HI)
		"collect":
			var a := _sweep(0.7, 880.0, 1760.0, "sine", [0.005, 0.12, 0.4, 0.6], 0.0, 53, 0.24)
			var b := _sweep(0.7, 1320.0, 2640.0, "sine", [0.1, 0.14, 0.35, 0.55], 0.0, 54, 0.14)
			return _mix2(a, b, RATE_HI)
		"checkpoint":
			var a := _sweep(1.2, 330.0, 495.0, "sine", [0.06, 0.2, 0.5, 0.5], 0.0, 55, 0.24)
			var b := _sweep(1.2, 495.0, 660.0, "sine", [0.2, 0.2, 0.45, 0.45], 0.0, 56, 0.16)
			return _mix2(a, b, RATE_HI)
		"level_up":
			var a := _sweep(1.5, 440.0, 880.0, "sine", [0.01, 0.2, 0.5, 0.5], 0.0, 57, 0.24)
			var b := _sweep(1.5, 660.0, 1320.0, "sine", [0.18, 0.2, 0.45, 0.5], 0.0, 58, 0.18)
			var c := _sweep(1.5, 880.0, 1760.0, "sine", [0.36, 0.2, 0.4, 0.45], 0.0, 59, 0.13)
			return _mix3(a, b, c, RATE_HI)

		# ---- combat / hazard
		"emp":
			var a := _sweep(0.9, 2400.0, 90.0, "sine", [0.002, 0.16, 0.35, 0.6], 0.30, 60, 0.50)
			var b := _sweep(0.9, 160.0, 55.0, "sine", [0.004, 0.2, 0.4, 0.55], 0.0, 61, 0.36)
			return _mix2(a, b, RATE_HI)
		"guardian_alert":
			var a := _sweep(0.6, 700.0, 1100.0, "square", [0.01, 0.1, 0.55, 0.45], 0.06, 62, 0.26)
			var b := _sweep(0.6, 350.0, 550.0, "square", [0.01, 0.1, 0.5, 0.5], 0.04, 63, 0.20)
			return _mix2(a, b, RATE_HI)
		"guardian_pulse":
			return _to_wav(_sweep(0.5, 1400.0, 200.0, "saw", [0.004, 0.14, 0.4, 0.55], 0.25, 64, 0.40), RATE_HI, false, true)
		"guardian_stun":
			return _to_wav(_sweep(1.0, 600.0, 70.0, "saw", [0.01, 0.3, 0.35, 0.55], 0.4, 65, 0.34), RATE_HI, false, true)
		"guardian_down":
			var a := _sweep(1.6, 300.0, 40.0, "saw", [0.02, 0.4, 0.3, 0.5], 0.35, 66, 0.36)
			var b := _sweep(1.6, 120.0, 30.0, "sine", [0.02, 0.4, 0.3, 0.5], 0.0, 67, 0.28)
			return _mix2(a, b, RATE_HI)
		"hurt":
			return _to_wav(_sweep(0.4, 520.0, 140.0, "saw", [0.003, 0.14, 0.3, 0.6], 0.45, 68, 0.34), RATE_HI, false, true)
		"shield_break":
			var a := _sweep(0.9, 900.0, 120.0, "square", [0.004, 0.2, 0.3, 0.6], 0.35, 69, 0.36)
			var b := _sweep(0.9, 220.0, 70.0, "sine", [0.004, 0.25, 0.3, 0.6], 0.0, 70, 0.30)
			return _mix2(a, b, RATE_HI)
		"death":
			var a := _sweep(2.0, 400.0, 40.0, "sine", [0.02, 0.5, 0.3, 0.45], 0.2, 71, 0.36)
			var b := _sweep(2.0, 90.0, 28.0, "sine", [0.05, 0.5, 0.3, 0.45], 0.0, 72, 0.30)
			return _mix2(a, b, RATE_HI)
		"shard_hit":
			return _to_wav(_sweep(0.3, 3200.0, 900.0, "sine", [0.002, 0.1, 0.3, 0.65], 0.5, 73, 0.30), RATE_HI, false, true)
		"thunder":
			var a := _sweep(2.4, 120.0, 35.0, "sine", [0.01, 0.5, 0.3, 0.5], 0.72, 74, 0.55)
			var b := _sweep(2.4, 60.0, 24.0, "sine", [0.005, 0.4, 0.35, 0.5], 0.3, 75, 0.40)
			return _mix2(a, b, RATE_HI)
		"steam":
			return _to_wav(_sweep(1.2, 2600.0, 1400.0, "sine", [0.08, 0.3, 0.55, 0.35], 0.92, 76, 0.34), RATE_HI, false, true)
		"electric":
			return _to_wav(_sweep(0.6, 2200.0, 400.0, "square", [0.004, 0.2, 0.35, 0.55], 0.55, 77, 0.32), RATE_HI, false, true)
		"glass_break":
			var a := _sweep(0.7, 4200.0, 1200.0, "sine", [0.002, 0.2, 0.25, 0.7], 0.72, 78, 0.34)
			var b := _sweep(0.7, 2600.0, 700.0, "tri", [0.004, 0.2, 0.25, 0.7], 0.6, 79, 0.24)
			return _mix2(a, b, RATE_HI)

		# ---- mote
		"mote_chirp":
			return _to_wav(_sweep(0.26, 1100.0, 1650.0, "sine", [0.01, 0.08, 0.45, 0.55], 0.0, 80, 0.20), RATE_HI, false, true)
		"mote_query":
			var a := _sweep(0.4, 900.0, 1200.0, "sine", [0.01, 0.1, 0.45, 0.5], 0.0, 81, 0.18)
			var b := _sweep(0.4, 1200.0, 900.0, "sine", [0.16, 0.1, 0.4, 0.5], 0.0, 82, 0.14)
			return _mix2(a, b, RATE_HI)
		"mote_sad":
			return _to_wav(_sweep(0.5, 900.0, 500.0, "sine", [0.02, 0.16, 0.4, 0.55], 0.0, 83, 0.18), RATE_HI, false, true)
	Log.warn("ProcAudio: unknown sfx '%s'" % name)
	return _to_wav(_sweep(0.1, 440.0, 440.0, "sine", [0.01, 0.05, 0.4, 0.5], 0.0, 1, 0.1), RATE_HI, false, true)

func _mix2(a: PackedFloat32Array, b: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var n := maxi(a.size(), b.size())
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size(): v += a[i]
		if i < b.size(): v += b[i]
		s[i] = v
	return _to_wav(s, rate, false, true)

func _mix3(a: PackedFloat32Array, b: PackedFloat32Array, c: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var n := maxi(a.size(), maxi(b.size(), c.size()))
	var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size(): v += a[i]
		if i < b.size(): v += b[i]
		if i < c.size(): v += c[i]
		s[i] = v
	return _to_wav(s, rate, false, true)

# ================================================================ footsteps
## Surface-specific step. Generated per (surface, variant) and cached.
func footstep(surface: int, variant: int) -> AudioStreamWAV:
	var key := "step_%d_%d" % [surface, variant]
	if _cache.has(key):
		return _cache[key]
	var seed_v := 900 + surface * 11 + variant
	var s: PackedFloat32Array
	match surface:
		Veil.Surface.STONE:
			s = _sweep(0.16, 340.0, 120.0, "sine", [0.002, 0.06, 0.2, 0.72], 0.68, seed_v, 0.26)
		Veil.Surface.METAL:
			var a := _sweep(0.28, 900.0, 320.0, "tri", [0.002, 0.1, 0.25, 0.68], 0.42, seed_v, 0.22)
			var b := _sweep(0.28, 2100.0, 1400.0, "sine", [0.002, 0.08, 0.2, 0.72], 0.3, seed_v + 1, 0.10)
			return _cache_ret(key, _mix2(a, b, RATE_HI))
		Veil.Surface.GLASS:
			s = _sweep(0.22, 2600.0, 1100.0, "sine", [0.002, 0.08, 0.2, 0.72], 0.55, seed_v, 0.18)
		Veil.Surface.WATER:
			s = _sweep(0.34, 1500.0, 350.0, "sine", [0.004, 0.12, 0.25, 0.66], 0.82, seed_v, 0.24)
		Veil.Surface.SNOW:
			s = _sweep(0.24, 1800.0, 600.0, "sine", [0.006, 0.12, 0.28, 0.62], 0.9, seed_v, 0.18)
		Veil.Surface.SAND:
			s = _sweep(0.24, 2400.0, 800.0, "sine", [0.006, 0.12, 0.28, 0.62], 0.94, seed_v, 0.16)
		Veil.Surface.FOLIAGE:
			s = _sweep(0.26, 3000.0, 900.0, "sine", [0.004, 0.12, 0.25, 0.66], 0.9, seed_v, 0.15)
		Veil.Surface.WOOD:
			s = _sweep(0.2, 420.0, 180.0, "tri", [0.002, 0.08, 0.22, 0.7], 0.55, seed_v, 0.24)
		_:
			s = _sweep(0.2, 500.0, 200.0, "sine", [0.002, 0.08, 0.22, 0.7], 0.6, seed_v, 0.20)
	return _cache_ret(key, _to_wav(s, RATE_HI, false, true))

func _cache_ret(key: String, w: AudioStreamWAV) -> AudioStreamWAV:
	_cache[key] = w
	return w

func cache_size() -> int:
	return _cache.size()
