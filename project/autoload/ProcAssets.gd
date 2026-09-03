extends Node
## Procedural asset factory. Every mesh, texture and material in VEILFORGE is
## generated here at runtime from noise + maths, so the shipped game carries no
## third-party art. Results are cached for the session.
##
## Textures use NoiseTexture2D (generated on engine threads in C++) rather than
## per-pixel GDScript loops, which keeps chapter load times reasonable.

var _tex: Dictionary = {}
var _mat: Dictionary = {}
var _mesh: Dictionary = {}
var _rng := RandomNumberGenerator.new()

const TEX_SIZE := 512
const TEX_SIZE_SMALL := 256

func _ready() -> void:
	_rng.seed = 0x5EEDF00D

# ============================================================ texture helpers
func _grad(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1] as Color)
	g.offsets = offs
	g.colors = cols
	return g

func _fnl(seed_v: int, freq: float, octaves: int = 4,
		type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
		fractal: int = FastNoiseLite.FRACTAL_FBM, gain: float = 0.5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = type as FastNoiseLite.NoiseType
	n.frequency = freq
	n.fractal_type = fractal as FastNoiseLite.FractalType
	n.fractal_octaves = octaves
	n.fractal_gain = gain
	n.fractal_lacunarity = 2.03
	return n

func noise_tex(key: String, seed_v: int, freq: float, stops: Array,
		octaves: int = 4, size: int = TEX_SIZE, ntype: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
		fractal: int = FastNoiseLite.FRACTAL_FBM) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.seamless_blend_skirt = 0.2
	t.generate_mipmaps = true
	t.noise = _fnl(seed_v, freq, octaves, ntype, fractal)
	if not stops.is_empty():
		t.color_ramp = _grad(stops)
	_tex[key] = t
	return t

func normal_tex(key: String, seed_v: int, freq: float, strength: float = 8.0,
		octaves: int = 4, size: int = TEX_SIZE,
		ntype: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Texture2D:
	var k := key + "_n"
	if _tex.has(k):
		return _tex[k]
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.seamless_blend_skirt = 0.2
	t.generate_mipmaps = true
	t.as_normal_map = true
	t.bump_strength = strength
	t.noise = _fnl(seed_v, freq, octaves, ntype)
	_tex[k] = t
	return t

## Small hand-built images (icons, gradients) where per-pixel control matters.
func radial_tex(key: String, size: int, inner: Color, outer: Color, power: float = 2.0) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := clampf(Vector2(x - c, y - c).length() / c, 0.0, 1.0)
			var f := pow(1.0 - d, power)
			img.set_pixel(x, y, outer.lerp(inner, f))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

func stripe_tex(key: String, size: int, a: Color, b: Color, period: int = 16) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, a if ((x + y) / period) % 2 == 0 else b)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

# ============================================================ material library
## Named PBR surfaces. `mat()` is the single entry point used by every builder.
func mat(name: String) -> StandardMaterial3D:
	if _mat.has(name):
		return _mat[name]
	var m := _build_mat(name)
	_mat[name] = m
	return m

func mat_variant(name: String, tint: Color, rough_add: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f" % [name, tint.to_html(false), rough_add]
	if _mat.has(key):
		return _mat[key]
	var base := mat(name)
	var m: StandardMaterial3D = base.duplicate()
	m.albedo_color = base.albedo_color * tint
	m.roughness = clampf(base.roughness + rough_add, 0.02, 1.0)
	_mat[key] = m
	return m

func _base(albedo: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _tri(m: StandardMaterial3D, scale: float) -> StandardMaterial3D:
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 1.4
	m.uv1_scale = Vector3(scale, scale, scale)
	return m

func _build_mat(name: String) -> StandardMaterial3D:
	match name:
		# ---------------------------------------------------------- stone / rock
		"rock":
			var m := _base(Color(0.42, 0.41, 0.39), 0.88, 0.0)
			m.albedo_texture = noise_tex("rock_a", 11, 0.009, [
				[0.0, Color(0.20, 0.19, 0.18)], [0.42, Color(0.40, 0.39, 0.37)],
				[0.72, Color(0.55, 0.53, 0.50)], [1.0, Color(0.66, 0.64, 0.60)]], 5)
			m.normal_enabled = true
			m.normal_texture = normal_tex("rock_a", 11, 0.022, 12.0, 5)
			m.normal_scale = 1.35
			m.roughness_texture = noise_tex("rock_r", 12, 0.02, [
				[0.0, Color(0.62, 0.62, 0.62)], [1.0, Color(1.0, 1.0, 1.0)]], 3)
			m.ao_enabled = true
			m.ao_texture = noise_tex("rock_ao", 13, 0.014, [
				[0.0, Color(0.55, 0.55, 0.55)], [0.6, Color(1, 1, 1)], [1.0, Color(1, 1, 1)]], 3)
			m.ao_light_affect = 0.55
			return _tri(m, 0.28)
		"rock_dark":
			var m := mat("rock").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.24, 0.235, 0.25)
			m.roughness = 0.92
			return m
		"rock_wet":
			var m := mat("rock").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.28, 0.29, 0.30)
			m.roughness = 0.34
			m.metallic_specular = 0.7
			return m
		"cliff":
			var m := _base(Color(0.36, 0.34, 0.32), 0.94, 0.0)
			m.albedo_texture = noise_tex("cliff_a", 21, 0.006, [
				[0.0, Color(0.17, 0.16, 0.15)], [0.35, Color(0.33, 0.31, 0.29)],
				[0.65, Color(0.46, 0.44, 0.41)], [1.0, Color(0.58, 0.56, 0.52)]], 6,
				TEX_SIZE, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
			m.normal_enabled = true
			m.normal_texture = normal_tex("cliff_a", 21, 0.018, 16.0, 6)
			m.normal_scale = 1.7
			return _tri(m, 0.16)

		# ---------------------------------------------------------- ground
		"grass":
			var m := _base(Color(0.20, 0.34, 0.16), 0.95, 0.0)
			m.albedo_texture = noise_tex("grass_a", 31, 0.03, [
				[0.0, Color(0.11, 0.20, 0.09)], [0.4, Color(0.19, 0.33, 0.14)],
				[0.7, Color(0.27, 0.44, 0.19)], [1.0, Color(0.36, 0.52, 0.24)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("grass_a", 31, 0.06, 5.0, 4)
			return _tri(m, 0.5)
		"dirt":
			var m := _base(Color(0.31, 0.25, 0.19), 0.96, 0.0)
			m.albedo_texture = noise_tex("dirt_a", 41, 0.028, [
				[0.0, Color(0.17, 0.13, 0.10)], [0.5, Color(0.30, 0.24, 0.18)],
				[1.0, Color(0.44, 0.36, 0.27)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("dirt_a", 41, 0.05, 6.0, 4)
			return _tri(m, 0.42)
		"sand":
			var m := _base(Color(0.72, 0.61, 0.42), 0.90, 0.0)
			m.albedo_texture = noise_tex("sand_a", 51, 0.05, [
				[0.0, Color(0.58, 0.48, 0.33)], [0.5, Color(0.74, 0.63, 0.44)],
				[1.0, Color(0.86, 0.76, 0.56)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("sand_a", 51, 0.09, 3.2, 3)
			return _tri(m, 0.6)
		"snow":
			var m := _base(Color(0.90, 0.93, 0.98), 0.55, 0.0)
			m.albedo_texture = noise_tex("snow_a", 61, 0.04, [
				[0.0, Color(0.78, 0.83, 0.92)], [0.6, Color(0.92, 0.95, 0.99)],
				[1.0, Color(1.0, 1.0, 1.0)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("snow_a", 61, 0.07, 3.0, 3)
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.6
			return _tri(m, 0.45)
		"ash":
			var m := _base(Color(0.26, 0.25, 0.25), 0.98, 0.0)
			m.albedo_texture = noise_tex("ash_a", 71, 0.035, [
				[0.0, Color(0.14, 0.13, 0.13)], [1.0, Color(0.34, 0.33, 0.32)]], 4)
			return _tri(m, 0.5)

		# ---------------------------------------------------------- built
		"concrete":
			var m := _base(Color(0.55, 0.55, 0.53), 0.86, 0.0)
			m.albedo_texture = noise_tex("conc_a", 81, 0.015, [
				[0.0, Color(0.38, 0.38, 0.37)], [0.45, Color(0.55, 0.55, 0.53)],
				[0.8, Color(0.64, 0.64, 0.62)], [1.0, Color(0.70, 0.70, 0.67)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("conc_a", 81, 0.04, 4.0, 4)
			m.ao_enabled = true
			m.ao_texture = noise_tex("conc_ao", 82, 0.01, [
				[0.0, Color(0.6, 0.6, 0.6)], [1.0, Color(1, 1, 1)]], 3)
			return _tri(m, 0.24)
		"concrete_aged":
			var m := mat("concrete").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.40, 0.40, 0.38)
			m.roughness = 0.95
			return m
		"metal":
			var m := _base(Color(0.62, 0.64, 0.67), 0.42, 0.92)
			m.albedo_texture = noise_tex("metal_a", 91, 0.02, [
				[0.0, Color(0.42, 0.44, 0.47)], [0.5, Color(0.62, 0.64, 0.67)],
				[1.0, Color(0.78, 0.80, 0.83)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("metal_a", 91, 0.06, 2.4, 3)
			m.roughness_texture = noise_tex("metal_r", 92, 0.03, [
				[0.0, Color(0.22, 0.22, 0.22)], [1.0, Color(0.72, 0.72, 0.72)]], 3)
			return _tri(m, 0.3)
		"metal_rust":
			var m := _base(Color(0.40, 0.25, 0.16), 0.82, 0.45)
			m.albedo_texture = noise_tex("rust_a", 101, 0.022, [
				[0.0, Color(0.20, 0.13, 0.09)], [0.35, Color(0.42, 0.24, 0.13)],
				[0.7, Color(0.58, 0.34, 0.18)], [1.0, Color(0.36, 0.30, 0.27)]], 5)
			m.normal_enabled = true
			m.normal_texture = normal_tex("rust_a", 101, 0.05, 6.0, 4)
			return _tri(m, 0.34)
		"metal_dark":
			var m := _base(Color(0.16, 0.17, 0.19), 0.38, 0.95)
			m.albedo_texture = noise_tex("mdark_a", 111, 0.025, [
				[0.0, Color(0.09, 0.10, 0.11)], [1.0, Color(0.24, 0.25, 0.28)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("mdark_a", 111, 0.07, 2.0, 3)
			return _tri(m, 0.35)
		"brass":
			var m := _base(Color(0.72, 0.56, 0.26), 0.30, 0.95)
			m.albedo_texture = noise_tex("brass_a", 121, 0.03, [
				[0.0, Color(0.50, 0.38, 0.16)], [1.0, Color(0.86, 0.70, 0.34)]], 3)
			return _tri(m, 0.3)
		"glass":
			var m := _base(Color(0.72, 0.82, 0.88, 0.20), 0.04, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic_specular = 0.95
			m.refraction_enabled = false
			m.backlight_enabled = true
			m.backlight = Color(0.2, 0.26, 0.3)
			return m
		"glass_broken":
			var m := mat("glass").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.62, 0.68, 0.70, 0.34)
			m.roughness = 0.30
			m.normal_enabled = true
			m.normal_texture = normal_tex("glassb", 131, 0.08, 9.0, 4)
			return m
		"wood":
			var m := _base(Color(0.34, 0.24, 0.15), 0.88, 0.0)
			m.albedo_texture = noise_tex("wood_a", 141, 0.006, [
				[0.0, Color(0.20, 0.13, 0.08)], [0.45, Color(0.34, 0.23, 0.14)],
				[1.0, Color(0.48, 0.34, 0.20)]], 3, TEX_SIZE,
				FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
			m.normal_enabled = true
			m.normal_texture = normal_tex("wood_a", 141, 0.02, 5.0, 3)
			return _tri(m, 0.35)
		"bark":
			var m := _base(Color(0.26, 0.21, 0.16), 0.95, 0.0)
			m.albedo_texture = noise_tex("bark_a", 151, 0.012, [
				[0.0, Color(0.12, 0.10, 0.08)], [0.4, Color(0.25, 0.20, 0.15)],
				[0.8, Color(0.36, 0.29, 0.21)], [1.0, Color(0.44, 0.37, 0.28)]], 5,
				TEX_SIZE, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
			m.normal_enabled = true
			m.normal_texture = normal_tex("bark_a", 151, 0.03, 14.0, 5)
			m.normal_scale = 1.6
			return _tri(m, 0.5)
		"resin":
			var m := _base(Color(0.58, 0.44, 0.22, 0.86), 0.18, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.backlight_enabled = true
			m.backlight = Color(0.5, 0.34, 0.12)
			return m
		"tile":
			var m := _base(Color(0.68, 0.70, 0.72), 0.28, 0.05)
			m.albedo_texture = noise_tex("tile_a", 161, 0.05, [
				[0.0, Color(0.52, 0.55, 0.58)], [0.5, Color(0.70, 0.72, 0.74)],
				[1.0, Color(0.82, 0.84, 0.86)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("tile_a", 161, 0.05, 3.0, 3)
			return _tri(m, 0.5)
		"nacre":
			var m := _base(Color(0.82, 0.86, 0.90), 0.14, 0.35)
			m.albedo_texture = noise_tex("nacre_a", 171, 0.02, [
				[0.0, Color(0.68, 0.76, 0.86)], [0.35, Color(0.88, 0.84, 0.92)],
				[0.65, Color(0.80, 0.90, 0.88)], [1.0, Color(0.94, 0.92, 0.86)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("nacre_a", 171, 0.05, 2.0, 3)
			m.rim_enabled = true
			m.rim = 0.6
			m.rim_tint = 0.9
			m.clearcoat_enabled = true
			m.clearcoat = 0.8
			m.clearcoat_roughness = 0.1
			return _tri(m, 0.34)

		# ---------------------------------------------------------- organic
		"foliage":
			var m := _base(Color(0.24, 0.46, 0.20), 0.72, 0.0)
			m.albedo_texture = noise_tex("fol_a", 181, 0.04, [
				[0.0, Color(0.10, 0.24, 0.09)], [0.45, Color(0.21, 0.42, 0.17)],
				[0.8, Color(0.32, 0.55, 0.22)], [1.0, Color(0.44, 0.66, 0.28)]], 4)
			m.backlight_enabled = true
			m.backlight = Color(0.14, 0.30, 0.10)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.uv1_scale = Vector3(1, 1, 1)
			return m
		"foliage_bloom":
			var m := mat("foliage").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.30, 0.60, 0.26)
			m.emission_enabled = true
			m.emission = Color(0.10, 0.34, 0.16)
			m.emission_energy_multiplier = 0.35
			return m
		"foliage_dry":
			var m := mat("foliage").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.44, 0.38, 0.18)
			m.backlight = Color(0.22, 0.18, 0.08)
			return m
		"moss":
			var m := _base(Color(0.20, 0.36, 0.16), 0.98, 0.0)
			m.albedo_texture = noise_tex("moss_a", 191, 0.06, [
				[0.0, Color(0.10, 0.20, 0.08)], [1.0, Color(0.28, 0.46, 0.20)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("moss_a", 191, 0.12, 7.0, 4)
			return _tri(m, 0.7)

		# ---------------------------------------------------------- special
		"water":
			var m := _base(Color(0.10, 0.26, 0.32, 0.72), 0.06, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic_specular = 0.9
			m.normal_enabled = true
			m.normal_texture = normal_tex("water_n", 201, 0.05, 3.0, 3)
			m.uv1_scale = Vector3(6, 6, 6)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"ice":
			var m := _base(Color(0.66, 0.80, 0.88, 0.62), 0.08, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic_specular = 0.85
			m.normal_enabled = true
			m.normal_texture = normal_tex("ice_n", 211, 0.04, 5.0, 4)
			m.backlight_enabled = true
			m.backlight = Color(0.3, 0.42, 0.5)
			return _tri(m, 0.3)
		"holo":
			var m := _base(Color(0.5, 0.85, 1.0, 0.45), 0.2, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = Color(0.4, 0.8, 1.0)
			m.emission_energy_multiplier = 2.2
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			return m
		"unlit_white":
			var m := _base(Color.WHITE, 1.0, 0.0)
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return m
	# fallback
	Log.warn("ProcAssets: unknown material '%s'" % name)
	return _base(Color(0.6, 0.6, 0.6), 0.8, 0.0)

## Emissive marker material in a chosen colour.
func emissive(c: Color, energy: float = 2.5) -> StandardMaterial3D:
	var key := "em_%s_%.2f" % [c.to_html(false), energy]
	if _mat.has(key):
		return _mat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.35
	m.metallic = 0.0
	_mat[key] = m
	return m

## Additive unshaded material for beams, sparks, field shells.
func additive(c: Color, energy: float = 2.0, cull_disabled: bool = true) -> StandardMaterial3D:
	var key := "add_%s_%.2f_%s" % [c.to_html(true), energy, cull_disabled]
	if _mat.has(key):
		return _mat[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	m.no_depth_test = false
	if cull_disabled:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat[key] = m
	return m

# ============================================================ mesh helpers
func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _tri3(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua := Vector2.ZERO, ub := Vector2.RIGHT, uc := Vector2.DOWN) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	st.set_normal(n); st.set_uv(ua); st.add_vertex(a)
	st.set_normal(n); st.set_uv(ub); st.add_vertex(b)
	st.set_normal(n); st.set_uv(uc); st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		uv_scale: float = 1.0) -> void:
	var w := (b - a).length() * uv_scale
	var h := (d - a).length() * uv_scale
	_tri3(st, a, b, c, Vector2(0, 0), Vector2(w, 0), Vector2(w, h))
	_tri3(st, a, c, d, Vector2(0, 0), Vector2(w, h), Vector2(0, h))

## Axis-aligned box under an arbitrary transform. Winding = outward.
func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, uv_scale: float = 1.0) -> void:
	var h := size * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, -h.y, h.z), xf * Vector3(-h.x, -h.y, h.z),
		xf * Vector3(-h.x, h.y, -h.z), xf * Vector3(h.x, h.y, -h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z)]
	_quad(st, p[7], p[6], p[5], p[4], uv_scale)   # top
	_quad(st, p[0], p[1], p[2], p[3], uv_scale)   # bottom
	_quad(st, p[3], p[2], p[6], p[7], uv_scale)   # +z
	_quad(st, p[1], p[0], p[4], p[5], uv_scale)   # -z
	_quad(st, p[2], p[1], p[5], p[6], uv_scale)   # +x
	_quad(st, p[0], p[3], p[7], p[4], uv_scale)   # -x

func _commit(st: SurfaceTool, smooth: bool = false) -> ArrayMesh:
	if smooth:
		st.generate_normals()
	st.generate_tangents()
	st.optimize_indices_for_cache()
	return st.commit()

func _cached(key: String, fn: Callable) -> Mesh:
	if _mesh.has(key):
		return _mesh[key]
	var m: Mesh = fn.call()
	_mesh[key] = m
	return m

# ============================================================ mesh generators
## Chunky, believable rock. Ridged noise displacement on a UV sphere,
## flattened slightly on Y so it reads as a boulder rather than a ball.
func rock_mesh(seed_v: int, radius: float = 1.0, roughness: float = 0.34,
		rings: int = 14, segs: int = 20, squash: float = 0.78) -> Mesh:
	var key := "rock_%d_%.2f_%.2f_%d_%.2f" % [seed_v, radius, roughness, rings, squash]
	return _cached(key, func() -> Mesh:
		var n := _fnl(seed_v, 0.9, 4, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_FBM)
		var n2 := _fnl(seed_v + 7, 2.6, 3, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
		var pts: Array = []
		for i in rings + 1:
			var v := float(i) / float(rings)
			var phi := v * PI
			var row: Array = []
			for j in segs + 1:
				var u := float(j) / float(segs)
				var th := u * TAU
				var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				var d := 1.0 + n.get_noise_3dv(dir * 1.7) * roughness \
					+ n2.get_noise_3dv(dir * 3.1) * roughness * 0.32
				var pnt := dir * radius * maxf(d, 0.35)
				pnt.y *= squash
				row.append(pnt)
			pts.append(row)
		var st := _st()
		for i in rings:
			for j in segs:
				var a: Vector3 = pts[i][j]
				var b: Vector3 = pts[i][j + 1]
				var c: Vector3 = pts[i + 1][j + 1]
				var dd: Vector3 = pts[i + 1][j]
				var u0 := float(j) / float(segs)
				var u1 := float(j + 1) / float(segs)
				var v0 := float(i) / float(rings)
				var v1 := float(i + 1) / float(rings)
				_tri3(st, a, b, c, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_tri3(st, a, c, dd, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
		return _commit(st, true))

## Faceted crystal / glass shard - used for Glass-Rain and Nacre set dressing.
func crystal_mesh(seed_v: int, height: float = 2.0, radius: float = 0.4,
		sides: int = 6) -> Mesh:
	var key := "cry_%d_%.2f_%.2f_%d" % [seed_v, height, radius, sides]
	return _cached(key, func() -> Mesh:
		var r := RandomNumberGenerator.new(); r.seed = seed_v
		var st := _st()
		var tip := Vector3(r.randf_range(-0.15, 0.15) * height, height,
			r.randf_range(-0.15, 0.15) * height)
		var bot := Vector3(0, -height * 0.12, 0)
		var ring: Array = []
		var mid: Array = []
		for i in sides:
			var a := TAU * float(i) / float(sides)
			var rr := radius * r.randf_range(0.75, 1.25)
			ring.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
			mid.append(Vector3(cos(a) * rr * 0.82, height * 0.55, sin(a) * rr * 0.82))
		for i in sides:
			var j := (i + 1) % sides
			_quad(st, ring[i], ring[j], mid[j], mid[i])
			_tri3(st, mid[i], mid[j], tip)
			_tri3(st, ring[j], ring[i], bot)
		return _commit(st, false))

## Tapered, bent trunk with optional branches. Returns bark surface only.
func trunk_mesh(seed_v: int, height: float, base_radius: float,
		bend: float = 0.25, segments: int = 9, sides: int = 9,
		taper: float = 0.42) -> Mesh:
	var key := "trunk_%d_%.2f_%.2f_%.2f_%d" % [seed_v, height, base_radius, bend, segments]
	return _cached(key, func() -> Mesh:
		var r := RandomNumberGenerator.new(); r.seed = seed_v
		var st := _st()
		var rings: Array = []
		var pos := Vector3.ZERO
		var dir := Vector3.UP
		for s in segments + 1:
			var t := float(s) / float(segments)
			var rad := base_radius * lerpf(1.0, taper, pow(t, 0.75))
			rad *= r.randf_range(0.93, 1.09)
			var basis_x := dir.cross(Vector3(0.31, 0.0, 0.95)).normalized()
			if basis_x.length_squared() < 0.01:
				basis_x = Vector3.RIGHT
			var basis_z := dir.cross(basis_x).normalized()
			var ring: Array = []
			for i in sides:
				var a := TAU * float(i) / float(sides)
				var wob := 1.0 + sin(a * 3.0 + float(s)) * 0.11
				ring.append(pos + (basis_x * cos(a) + basis_z * sin(a)) * rad * wob)
			rings.append(ring)
			if s < segments:
				var step := height / float(segments)
				dir = (dir + Vector3(r.randf_range(-bend, bend), 0.0,
					r.randf_range(-bend, bend)) * 0.34).normalized()
				pos += dir * step
		for s in segments:
			for i in sides:
				var j := (i + 1) % sides
				var v0 := float(s) / float(segments)
				var v1 := float(s + 1) / float(segments)
				var u0 := float(i) / float(sides)
				var u1 := float(i + 1) / float(sides)
				_tri3(st, rings[s][i], rings[s][j], rings[s + 1][j],
					Vector2(u0, v0 * height), Vector2(u1, v0 * height), Vector2(u1, v1 * height))
				_tri3(st, rings[s][i], rings[s + 1][j], rings[s + 1][i],
					Vector2(u0, v0 * height), Vector2(u1, v1 * height), Vector2(u0, v1 * height))
		return _commit(st, true))

## Canopy: overlapping distorted domes. Cheap, silhouettes well, no alpha cards.
func canopy_mesh(seed_v: int, radius: float, blobs: int = 5,
		rings: int = 6, segs: int = 9) -> Mesh:
	var key := "canopy_%d_%.2f_%d" % [seed_v, radius, blobs]
	return _cached(key, func() -> Mesh:
		var r := RandomNumberGenerator.new(); r.seed = seed_v
		var n := _fnl(seed_v, 1.4, 3)
		var st := _st()
		for b in blobs:
			var off := Vector3(r.randf_range(-1, 1), r.randf_range(-0.45, 0.7),
				r.randf_range(-1, 1)) * radius * 0.55
			var rad := radius * r.randf_range(0.48, 0.85)
			for i in rings:
				for j in segs:
					var f := func(ii: int, jj: int) -> Vector3:
						var phi := PI * float(ii) / float(rings)
						var th := TAU * float(jj) / float(segs)
						var d := Vector3(sin(phi) * cos(th), cos(phi) * 0.82, sin(phi) * sin(th))
						return off + d * rad * (1.0 + n.get_noise_3dv(d * 2.0 + off) * 0.28)
					var a: Vector3 = f.call(i, j)
					var bb: Vector3 = f.call(i, j + 1)
					var c: Vector3 = f.call(i + 1, j + 1)
					var d2: Vector3 = f.call(i + 1, j)
					_tri3(st, a, bb, c)
					_tri3(st, a, c, d2)
		return _commit(st, true))

## Organic tube swept along a poly-line; the backbone of Bloom-state roots,
## vines, cables and pipes.
func tube_mesh(key_extra: String, points: PackedVector3Array,
		radii: PackedFloat32Array, sides: int = 8, uv_repeat: float = 1.0) -> Mesh:
	var key := "tube_%s_%d_%d" % [key_extra, points.size(), sides]
	return _cached(key, func() -> Mesh:
		if points.size() < 2:
			return _commit(_st(), false)
		var st := _st()
		var rings: Array = []
		var up := Vector3.UP
		var run := 0.0
		var runs: Array = []
		for i in points.size():
			var fwd: Vector3
			if i == 0:
				fwd = (points[1] - points[0]).normalized()
			elif i == points.size() - 1:
				fwd = (points[i] - points[i - 1]).normalized()
			else:
				fwd = (points[i + 1] - points[i - 1]).normalized()
			if fwd.length_squared() < 1e-8:
				fwd = Vector3.FORWARD
			var right := fwd.cross(up)
			if right.length_squared() < 1e-6:
				up = Vector3.FORWARD if absf(fwd.y) > 0.9 else Vector3.UP
				right = fwd.cross(up)
			right = right.normalized()
			var realup := right.cross(fwd).normalized()
			up = realup
			var rad: float = radii[mini(i, radii.size() - 1)]
			var ring: Array = []
			for s in sides:
				var a := TAU * float(s) / float(sides)
				ring.append(points[i] + (right * cos(a) + realup * sin(a)) * rad)
			rings.append(ring)
			if i > 0:
				run += points[i].distance_to(points[i - 1])
			runs.append(run * uv_repeat)
		for i in rings.size() - 1:
			for s in sides:
				var t := (s + 1) % sides
				var u0 := float(s) / float(sides)
				var u1 := float(s + 1) / float(sides)
				_tri3(st, rings[i][s], rings[i][t], rings[i + 1][t],
					Vector2(u0, runs[i]), Vector2(u1, runs[i]), Vector2(u1, runs[i + 1]))
				_tri3(st, rings[i][s], rings[i + 1][t], rings[i + 1][s],
					Vector2(u0, runs[i]), Vector2(u1, runs[i + 1]), Vector2(u0, runs[i + 1]))
		return _commit(st, true))

## Hollow rectangular room shell (walls + floor + optional ceiling), with a
## door cut on one side. Used for interiors that the player actually walks into.
func room_shell(size: Vector3, thickness: float, door_w: float, door_h: float,
		ceiling: bool = true, door_side: int = 0) -> Mesh:
	var key := "room_%s_%.2f_%.2f_%.2f_%s_%d" % [size, thickness, door_w, door_h, ceiling, door_side]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var h := size * 0.5
		var t := thickness
		# floor
		_box(st, Transform3D(Basis(), Vector3(0, -h.y - t * 0.5, 0)),
			Vector3(size.x + t * 2, t, size.z + t * 2), 0.4)
		if ceiling:
			_box(st, Transform3D(Basis(), Vector3(0, h.y + t * 0.5, 0)),
				Vector3(size.x + t * 2, t, size.z + t * 2), 0.4)
		# four walls, one of them split around a doorway
		var walls := [
			{"c": Vector3(0, 0, -h.z - t * 0.5), "s": Vector3(size.x, size.y, t), "axis": 0},
			{"c": Vector3(0, 0, h.z + t * 0.5), "s": Vector3(size.x, size.y, t), "axis": 0},
			{"c": Vector3(-h.x - t * 0.5, 0, 0), "s": Vector3(t, size.y, size.z), "axis": 2},
			{"c": Vector3(h.x + t * 0.5, 0, 0), "s": Vector3(t, size.y, size.z), "axis": 2},
		]
		for i in walls.size():
			var w: Dictionary = walls[i]
			if i != door_side:
				_box(st, Transform3D(Basis(), w.c), w.s, 0.4)
				continue
			var span: float = w.s.x if w.axis == 0 else w.s.z
			var side: float = (span - door_w) * 0.5
			var top_h: float = w.s.y - door_h
			for sgn in [-1.0, 1.0]:
				var off := Vector3.ZERO
				var sz: Vector3 = w.s
				if w.axis == 0:
					off.x = sgn * (door_w + side) * 0.5
					sz.x = side
				else:
					off.z = sgn * (door_w + side) * 0.5
					sz.z = side
				if side > 0.02:
					_box(st, Transform3D(Basis(), w.c + off), sz, 0.4)
			if top_h > 0.02:
				var sz2: Vector3 = w.s
				if w.axis == 0: sz2.x = door_w
				else: sz2.z = door_w
				sz2.y = top_h
				_box(st, Transform3D(Basis(), w.c + Vector3(0, (w.s.y - top_h) * 0.5, 0)), sz2, 0.4)
		return _commit(st, false))

## Panelled facade slab with recessed window bays - the city / industrial kit.
func facade_mesh(width: float, height: float, depth: float,
		cols: int, rows: int, inset: float = 0.18, seed_v: int = 0) -> Mesh:
	var key := "fac_%.1f_%.1f_%.1f_%d_%d_%d" % [width, height, depth, cols, rows, seed_v]
	return _cached(key, func() -> Mesh:
		var r := RandomNumberGenerator.new(); r.seed = seed_v
		var st := _st()
		_box(st, Transform3D(), Vector3(width, height, depth), 0.3)
		var cw := width / float(cols)
		var rh := height / float(rows)
		for c in cols:
			for row in rows:
				if r.randf() < 0.18:
					continue
				var x := -width * 0.5 + cw * (c + 0.5)
				var y := -height * 0.5 + rh * (row + 0.5)
				var w2 := cw * 0.62
				var h2 := rh * 0.58
				_box(st, Transform3D(Basis(), Vector3(x, y, depth * 0.5 - inset * 0.5)),
					Vector3(w2, h2, inset), 0.6)
		return _commit(st, false))

## Open lattice truss - girders and cross braces.
func truss_mesh(length: float, width: float, height: float,
		bays: int = 6, bar: float = 0.09) -> Mesh:
	var key := "truss_%.1f_%.1f_%.1f_%d" % [length, width, height, bays]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var hw := width * 0.5
		var hh := height * 0.5
		for sx in [-hw, hw]:
			for sy in [-hh, hh]:
				_box(st, Transform3D(Basis(), Vector3(sx, sy, 0)),
					Vector3(bar, bar, length), 1.0)
		var step := length / float(bays)
		for i in bays + 1:
			var z := -length * 0.5 + step * i
			_box(st, Transform3D(Basis(), Vector3(0, hh, z)), Vector3(width, bar, bar), 1.0)
			_box(st, Transform3D(Basis(), Vector3(0, -hh, z)), Vector3(width, bar, bar), 1.0)
			_box(st, Transform3D(Basis(), Vector3(hw, 0, z)), Vector3(bar, height, bar), 1.0)
			_box(st, Transform3D(Basis(), Vector3(-hw, 0, z)), Vector3(bar, height, bar), 1.0)
		for i in bays:
			var z0 := -length * 0.5 + step * i
			var diag := sqrt(step * step + height * height)
			var ang := atan2(height, step)
			for sx in [-hw, hw]:
				var b := Basis(Vector3.RIGHT, (ang if sx > 0 else -ang))
				_box(st, Transform3D(b, Vector3(sx, 0, z0 + step * 0.5)),
					Vector3(bar * 0.8, bar * 0.8, diag), 1.0)
		return _commit(st, false))

## Staircase with risers and treads (walkable via a matching collision ramp).
func stairs_mesh(steps: int, width: float, rise: float, run: float) -> Mesh:
	var key := "stair_%d_%.2f_%.2f_%.2f" % [steps, width, rise, run]
	return _cached(key, func() -> Mesh:
		var st := _st()
		for i in steps:
			var y := rise * (i + 0.5)
			var z := run * (i + 0.5)
			_box(st, Transform3D(Basis(), Vector3(0, y - rise * 0.5, z)),
				Vector3(width, rise, run), 1.2)
		return _commit(st, false))

## Ring / torus segment - conduits, machine collars, portals.
func ring_mesh(major: float, minor: float, seg_major: int = 28, seg_minor: int = 10,
		arc: float = TAU) -> Mesh:
	var key := "ring_%.2f_%.2f_%d_%d_%.2f" % [major, minor, seg_major, seg_minor, arc]
	return _cached(key, func() -> Mesh:
		var st := _st()
		for i in seg_major:
			for j in seg_minor:
				var f := func(ii: int, jj: int) -> Vector3:
					var a := arc * float(ii) / float(seg_major)
					var b := TAU * float(jj) / float(seg_minor)
					var cx := Vector3(cos(a), 0, sin(a))
					return cx * (major + cos(b) * minor) + Vector3(0, sin(b) * minor, 0)
				_tri3(st, f.call(i, j), f.call(i + 1, j), f.call(i + 1, j + 1))
				_tri3(st, f.call(i, j), f.call(i + 1, j + 1), f.call(i, j + 1))
		return _commit(st, true))

## Broken-slab debris cluster for Ruin-state dressing.
func debris_mesh(seed_v: int, count: int, extent: float, scale: float = 1.0) -> Mesh:
	var key := "deb_%d_%d_%.2f_%.2f" % [seed_v, count, extent, scale]
	return _cached(key, func() -> Mesh:
		var r := RandomNumberGenerator.new(); r.seed = seed_v
		var st := _st()
		for i in count:
			var p := Vector3(r.randf_range(-extent, extent), r.randf_range(-0.1, extent * 0.35),
				r.randf_range(-extent, extent))
			var b := Basis(Vector3(r.randf(), r.randf(), r.randf()).normalized(),
				r.randf_range(0, TAU))
			var s := Vector3(r.randf_range(0.25, 1.1), r.randf_range(0.08, 0.4),
				r.randf_range(0.25, 1.1)) * scale
			_box(st, Transform3D(b, p), s, 1.0)
		return _commit(st, false))

## Simple cylinder (pipes, columns, poles).
func cylinder_mesh(radius: float, height: float, sides: int = 14, caps: bool = true) -> Mesh:
	var key := "cyl_%.2f_%.2f_%d_%s" % [radius, height, sides, caps]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var hy := height * 0.5
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var p0 := Vector3(cos(a0) * radius, -hy, sin(a0) * radius)
			var p1 := Vector3(cos(a1) * radius, -hy, sin(a1) * radius)
			var p2 := Vector3(cos(a1) * radius, hy, sin(a1) * radius)
			var p3 := Vector3(cos(a0) * radius, hy, sin(a0) * radius)
			var u0 := float(i) / float(sides)
			var u1 := float(i + 1) / float(sides)
			_tri3(st, p0, p1, p2, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, height))
			_tri3(st, p0, p2, p3, Vector2(u0, 0), Vector2(u1, height), Vector2(u0, height))
			if caps:
				_tri3(st, Vector3(0, hy, 0), p3, p2)
				_tri3(st, Vector3(0, -hy, 0), p1, p0)
		return _commit(st, true))

## Grass / reed blade cluster used by MultiMeshInstance3D vegetation.
func blade_cluster_mesh(seed_v: int, blades: int = 5, height: float = 0.6,
		width: float = 0.06) -> Mesh:
	var key := "blade_%d_%d_%.2f" % [seed_v, blades, height]
	return _cached(key, func() -> Mesh:
		var r := RandomNumberGenerator.new(); r.seed = seed_v
		var st := _st()
		for i in blades:
			var a := r.randf_range(0, TAU)
			var lean := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.1, 0.34)
			var hgt := height * r.randf_range(0.7, 1.35)
			var w := width * r.randf_range(0.7, 1.3)
			var base := Vector3(r.randf_range(-0.18, 0.18), 0, r.randf_range(-0.18, 0.18))
			var dirv := Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5)) * w
			var mid := base + lean * 0.4 + Vector3(0, hgt * 0.55, 0)
			var tip := base + lean * hgt + Vector3(0, hgt, 0)
			_tri3(st, base - dirv, base + dirv, mid + dirv * 0.55,
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.55))
			_tri3(st, base - dirv, mid + dirv * 0.55, mid - dirv * 0.55,
				Vector2(0, 0), Vector2(1, 0.55), Vector2(0, 0.55))
			_tri3(st, mid - dirv * 0.55, mid + dirv * 0.55, tip,
				Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1))
		return _commit(st, false))

## Flat quad on the XZ plane (water surfaces, decals, floor patches).
func plane_mesh(size: Vector2, subdiv: int = 1) -> Mesh:
	var key := "plane_%.2f_%.2f_%d" % [size.x, size.y, subdiv]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var hx := size.x * 0.5
		var hz := size.y * 0.5
		var n := maxi(1, subdiv)
		for i in n:
			for j in n:
				var x0 := -hx + size.x * float(i) / float(n)
				var x1 := -hx + size.x * float(i + 1) / float(n)
				var z0 := -hz + size.y * float(j) / float(n)
				var z1 := -hz + size.y * float(j + 1) / float(n)
				_tri3(st, Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1),
					Vector2(0, 0), Vector2(0, 1), Vector2(1, 1))
				_tri3(st, Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x1, 0, z0),
					Vector2(0, 0), Vector2(1, 1), Vector2(1, 0))
		return _commit(st, false))

func box_mesh(size: Vector3, uv_scale: float = 1.0) -> Mesh:
	var key := "box_%.2f_%.2f_%.2f_%.2f" % [size.x, size.y, size.z, uv_scale]
	return _cached(key, func() -> Mesh:
		var st := _st()
		_box(st, Transform3D(), size, uv_scale)
		return _commit(st, false))

func sphere_mesh(radius: float, rings: int = 12, segs: int = 18) -> Mesh:
	return rock_mesh(0, radius, 0.0, rings, segs, 1.0)

func clear_cache() -> void:
	_mesh.clear()
