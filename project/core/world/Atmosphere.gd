extends WorldEnvironment
class_name Atmosphere
## Sky, lighting, fog and post-processing, with a distinct look per reality
## state that cross-fades as the player's local state changes.

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial
var _state: int = Veil.State.RUIN
var _blend: Dictionary = {}
var presets: Array = []          # three dictionaries, indexed by Veil.State
var time_of_day := 0.42          # 0..1, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
var day_length := 0.0            # seconds for a full cycle; 0 = frozen
var _lerp_speed := 1.4

func setup(p_presets: Array, initial_state: int, tod: float = 0.42) -> void:
	presets = p_presets
	_state = clampi(initial_state, 0, 2)
	time_of_day = tod

	var env := Environment.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_energy_multiplier = 1.0
	_sky_mat.ground_energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.tonemap_exposure = 1.0
	environment = env

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.045
	sun.shadow_normal_bias = 1.4
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.shadow_enabled = false
	fill.light_energy = 0.24
	add_child(fill)

	_blend = _preset(_state).duplicate(true)
	_apply(_blend, true)
	Settings.video_changed.connect(_apply_quality)
	_apply_quality()

func _preset(s: int) -> Dictionary:
	return presets[clampi(s, 0, presets.size() - 1)]

func set_state(s: int) -> void:
	_state = clampi(s, 0, 2)

func force_state(s: int) -> void:
	_state = clampi(s, 0, 2)
	_blend = _preset(_state).duplicate(true)
	_apply(_blend, true)

func _process(dt: float) -> void:
	if day_length > 0.0:
		time_of_day = fposmod(time_of_day + dt / day_length, 1.0)
	var target := _preset(_state)
	var k := clampf(dt * _lerp_speed, 0.0, 1.0)
	var changed := false
	for key in target.keys():
		var a: Variant = _blend.get(key, target[key])
		var b: Variant = target[key]
		if a is Color:
			_blend[key] = (a as Color).lerp(b as Color, k)
			changed = true
		elif a is float or a is int:
			_blend[key] = lerpf(float(a), float(b), k)
			changed = true
		else:
			_blend[key] = b
	if changed:
		_apply(_blend, false)

func _apply(p: Dictionary, instant: bool) -> void:
	var env := environment
	if env == null:
		return
	_sky_mat.sky_top_color = p.get("sky_top", Color(0.3, 0.4, 0.6))
	_sky_mat.sky_horizon_color = p.get("sky_horizon", Color(0.6, 0.65, 0.7))
	_sky_mat.ground_horizon_color = p.get("sky_horizon", Color(0.6, 0.65, 0.7))
	_sky_mat.ground_bottom_color = p.get("ground", Color(0.15, 0.14, 0.13))
	_sky_mat.sun_angle_max = float(p.get("sun_size", 8.0))
	_sky_mat.sky_energy_multiplier = float(p.get("sky_energy", 1.0))

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = p.get("fog", Color(0.6, 0.65, 0.7))
	env.fog_light_energy = float(p.get("fog_energy", 0.9))
	env.fog_density = float(p.get("fog_density", 0.0022))
	env.fog_sky_affect = float(p.get("fog_sky", 0.12))
	env.fog_aerial_perspective = float(p.get("fog_aerial", 0.14))
	env.fog_depth_begin = float(p.get("fog_begin", 22.0))
	env.fog_depth_end = float(p.get("fog_end", 640.0))
	env.fog_depth_curve = 1.35
	env.ambient_light_energy = float(p.get("ambient", 0.85))

	env.volumetric_fog_density = float(p.get("vol_density", 0.02))
	env.volumetric_fog_albedo = p.get("vol_color", Color(0.8, 0.85, 0.9))
	env.volumetric_fog_emission = p.get("vol_emission", Color(0, 0, 0))
	env.volumetric_fog_emission_energy = float(p.get("vol_emission_energy", 0.0))
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_gi_inject = 0.85
	env.volumetric_fog_anisotropy = 0.25
	env.volumetric_fog_detail_spread = 2.4

	env.adjustment_enabled = true
	env.adjustment_brightness = float(p.get("brightness", 1.0)) * Settings.brightness
	env.adjustment_contrast = float(p.get("contrast", 1.02))
	env.adjustment_saturation = float(p.get("saturation", 1.0))
	env.tonemap_exposure = float(p.get("exposure", 1.0))

	env.glow_intensity = float(p.get("glow", 0.42))
	env.glow_bloom = float(p.get("bloom", 0.04))
	env.glow_hdr_threshold = 1.35
	env.glow_hdr_scale = 2.0
	env.glow_strength = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.ssao_radius = 1.6
	env.ssao_intensity = float(p.get("ssao", 1.5))
	env.ssr_max_steps = 28
	env.ssr_fade_in = 0.2

	var sun_angle: float = float(p.get("sun_pitch", -46.0))
	var sun_yaw: float = float(p.get("sun_yaw", 42.0))
	if day_length > 0.0:
		sun_angle = -lerpf(4.0, 78.0, sin(time_of_day * PI) * 0.5 + 0.5)
		sun_yaw = time_of_day * 360.0 - 90.0
	sun.rotation_degrees = Vector3(sun_angle, sun_yaw, 0)
	sun.light_color = p.get("sun_color", Color(1, 0.96, 0.9))
	sun.light_energy = float(p.get("sun_energy", 1.6))
	sun.light_angular_distance = float(p.get("sun_softness", 0.6))
	fill.rotation_degrees = Vector3(-24.0, sun_yaw + 180.0, 0)
	fill.light_color = p.get("fill_color", Color(0.55, 0.65, 0.85))
	fill.light_energy = float(p.get("fill_energy", 0.22))

func _apply_quality() -> void:
	var d := Settings.preset_data()
	var env := environment
	if env == null:
		return
	env.ssao_enabled = bool(d.ssao)
	env.ssil_enabled = bool(d.ssil)
	env.ssr_enabled = bool(d.ssr)
	env.volumetric_fog_enabled = bool(d.volumetric)
	env.glow_enabled = bool(d.glow)
	env.sdfgi_enabled = bool(d.sdfgi)
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 1.0
	sun.directional_shadow_max_distance = 140.0 if not bool(d.sdfgi) else 220.0
	if environment:
		environment.adjustment_brightness = float(_blend.get("brightness", 1.0)) * Settings.brightness

## Standard palette builders so chapters stay declarative.
static func palette(sky_top: Color, sky_horizon: Color, fog: Color, sun_color: Color,
		sun_energy: float, fog_density: float, vol: float, extra: Dictionary = {}) -> Dictionary:
	var d := {
		"sky_top": sky_top, "sky_horizon": sky_horizon, "ground": fog.darkened(0.7),
		"fog": fog, "fog_density": fog_density, "vol_density": vol,
		"vol_color": fog.lightened(0.1), "sun_color": sun_color, "sun_energy": sun_energy,
		"fill_color": sky_top.lightened(0.15), "fill_energy": 0.20,
		"brightness": 1.0, "contrast": 1.09, "saturation": 1.02, "exposure": 1.0,
		"glow": 0.40, "bloom": 0.04, "ssao": 1.8, "sun_pitch": -46.0, "sun_yaw": 42.0,
		"sun_size": 6.0, "sun_softness": 0.5, "sky_energy": 0.85, "fog_sky": 0.12,
		"fog_aerial": 0.14, "fog_begin": 22.0, "fog_end": 640.0, "fog_energy": 0.9,
		"ambient": 0.85,
	}
	d.merge(extra, true)
	return d
