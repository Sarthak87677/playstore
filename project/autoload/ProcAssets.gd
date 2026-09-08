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

## Where a material also carries an `albedo_texture`, the two multiply, so this
## tint is chosen against that texture rather than picked on its own: it carries
## the hue, and its brightness is set so that tint x texture lands on a sensible
## mean albedo for the surface. Getting this wrong in either direction is
## visible from across the level — a mid-dark tint over an already-coloured
## texture crushed every prop to near-black (the same mistake the terrain shader
## made), and over-correcting to near-white blew Nacre City's facades out to
## flat paper and turned the forest neon.
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

## Deep parallax from the material's own normal map.
##
## The single biggest difference between a flat textured surface and one that
## looks real is whether the surface has depth when you look across it. A normal
## map fakes the lighting of depth; parallax actually displaces the texture
## lookup, so mortar lines sink and stones stand proud as you move. It is the
## most expensive per-pixel option on a StandardMaterial3D, so it goes only on
## the materials the player stands next to, and the step counts stay modest.
func _depth(m: StandardMaterial3D, scale: float = 0.035, layers: int = 10) -> StandardMaterial3D:
	if m.normal_texture == null:
		return m
	# Godot does not support height mapping on triplanar materials at all -- it
	# drops it and logs a warning per material. Every caller here is triplanar,
	# so the parallax was doing nothing but filling the log. Deepen the normal
	# instead, which is the part of the effect triplanar can actually render.
	if m.uv1_triplanar:
		m.normal_enabled = true
		# A gentle lift only. The first version multiplied by 1.45 and capped at
		# 3.0, which on the rock and cliff maps carved pits deep enough to shade
		# near-black -- the slopes came out looking like animal hide.
		m.normal_scale = minf(m.normal_scale * 1.12, 1.8)
		return m
	# These parallax steps cost three texture samples rather than one. Measured,
	# it was the most expensive thing in the frame by a wide margin, and the
	# target hardware includes integrated GPUs -- so it is a High-and-above
	# feature, off below that. Materials are cached, so this is read once.
	var q := float(Settings.preset_data().get("parallax", 0.0))
	if q <= 0.01:
		return m
	layers = maxi(2, int(round(float(layers) * q)))
	m.heightmap_enabled = true
	m.heightmap_texture = m.normal_texture
	m.heightmap_scale = scale
	m.heightmap_deep_parallax = true
	m.heightmap_min_layers = maxi(2, layers / 2)
	m.heightmap_max_layers = layers
	m.heightmap_flip_texture = false
	return m

## A second, finer copy of the surface blended in close up. Godot applies detail
## maps over the base, which breaks the tiling that otherwise reads as wallpaper.
func _detail(m: StandardMaterial3D, tex: Texture2D, nrm: Texture2D,
		blend: int = BaseMaterial3D.BLEND_MODE_MIX) -> StandardMaterial3D:
	m.detail_enabled = true
	m.detail_blend_mode = blend
	m.detail_albedo = tex
	if nrm != null:
		m.detail_normal = nrm
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	return m

func _build_mat(name: String) -> StandardMaterial3D:
	match name:
		# ---------------------------------------------------------- stone / rock
		"rock":
			var m := _base(Color(0.736, 0.708, 0.666), 0.88, 0.0)
			# Same problem as cliff: too few features per tile to hide the repeat.
			m.albedo_texture = noise_tex("rock_a", 11, 0.026, [
				[0.0, Color(0.28, 0.27, 0.26)], [0.42, Color(0.41, 0.40, 0.38)],
				[0.72, Color(0.53, 0.51, 0.48)], [1.0, Color(0.62, 0.60, 0.56)]], 5)
			m.normal_enabled = true
			m.normal_texture = normal_tex("rock_a", 11, 0.055, 5.5, 5)
			m.normal_scale = 1.0
			m.roughness_texture = noise_tex("rock_r", 12, 0.02, [
				[0.0, Color(0.62, 0.62, 0.62)], [1.0, Color(1.0, 1.0, 1.0)]], 3)
			m.ao_enabled = true
			m.ao_texture = noise_tex("rock_ao", 13, 0.014, [
				[0.0, Color(0.55, 0.55, 0.55)], [0.6, Color(1, 1, 1)], [1.0, Color(1, 1, 1)]], 3)
			m.ao_light_affect = 0.55
			return _depth(_tri(m, 0.28), 0.030, 12)
		"rock_dark":
			var m := mat("rock").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.34, 0.333, 0.354)
			m.roughness = 0.92
			return m
		"rock_wet":
			var m := mat("rock").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.397, 0.411, 0.425)
			m.roughness = 0.34
			m.metallic_specular = 0.7
			return m
		"cliff":
			var m := _base(Color(1, 0.944, 0.889), 0.94, 0.0)
			# 0.030, not 0.006. At the old frequency a 512px tile held about
			# three noise features, so tiling it across a hillside repeated a
			# handful of large blobs -- the single most artificial thing in any
			# wide shot. Higher frequency plus the same octave count gives rock
			# structure at metres AND grain at centimetres.
			# Frequency raised but contrast pulled in. Ridged noise at this scale
			# with the old near-black-to-light ramp printed hard dark spots all
			# over the slopes -- an animal-hide pattern, not rock. Rock varies in
			# tone far less than it varies in relief, so the range narrows here
			# and the normal map carries the detail instead.
			m.albedo_texture = noise_tex("cliff_a", 21, 0.020, [
				[0.0, Color(0.30, 0.29, 0.27)], [0.35, Color(0.38, 0.36, 0.34)],
				[0.65, Color(0.46, 0.44, 0.41)], [1.0, Color(0.55, 0.53, 0.50)]], 6,
				TEX_SIZE, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
			m.normal_enabled = true
			m.normal_texture = normal_tex("cliff_a", 21, 0.045, 5.5, 6)
			m.normal_scale = 1.05
			return _depth(_tri(m, 0.16), 0.042, 12)

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
			var m := _base(Color(1, 0.806, 0.613), 0.96, 0.0)
			m.albedo_texture = noise_tex("dirt_a", 41, 0.028, [
				[0.0, Color(0.17, 0.13, 0.10)], [0.5, Color(0.30, 0.24, 0.18)],
				[1.0, Color(0.44, 0.36, 0.27)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("dirt_a", 41, 0.05, 6.0, 4)
			return _tri(m, 0.42)
		"sand":
			var m := _base(Color(0.806, 0.683, 0.47), 0.90, 0.0)
			m.albedo_texture = noise_tex("sand_a", 51, 0.05, [
				[0.0, Color(0.58, 0.48, 0.33)], [0.5, Color(0.74, 0.63, 0.44)],
				[1.0, Color(0.86, 0.76, 0.56)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("sand_a", 51, 0.09, 3.2, 3)
			return _tri(m, 0.6)
		"snow":
			var m := _base(Color(0.63, 0.651, 0.686), 0.55, 0.0)
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
			var m := _base(Color(0.581, 0.558, 0.558), 0.98, 0.0)
			m.albedo_texture = noise_tex("ash_a", 71, 0.035, [
				[0.0, Color(0.14, 0.13, 0.13)], [1.0, Color(0.34, 0.33, 0.32)]], 4)
			return _tri(m, 0.5)

		# ---------------------------------------------------------- built
		"concrete":
			var m := _base(Color(0.623, 0.623, 0.595), 0.86, 0.0)
			m.albedo_texture = noise_tex("conc_a", 81, 0.015, [
				[0.0, Color(0.38, 0.38, 0.37)], [0.45, Color(0.55, 0.55, 0.53)],
				[0.8, Color(0.64, 0.64, 0.62)], [1.0, Color(0.70, 0.70, 0.67)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("conc_a", 81, 0.04, 4.0, 4)
			m.ao_enabled = true
			m.ao_texture = noise_tex("conc_ao", 82, 0.01, [
				[0.0, Color(0.6, 0.6, 0.6)], [1.0, Color(1, 1, 1)]], 3)
			return _depth(_tri(m, 0.24), 0.024, 10)
		"concrete_aged":
			var m := mat("concrete").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.491, 0.491, 0.463)
			m.roughness = 0.95
			return m
		"metal":
			var m := _base(Color(0.777, 0.802, 0.84), 0.42, 0.92)
			m.albedo_texture = noise_tex("metal_a", 91, 0.02, [
				[0.0, Color(0.42, 0.44, 0.47)], [0.5, Color(0.62, 0.64, 0.67)],
				[1.0, Color(0.78, 0.80, 0.83)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("metal_a", 91, 0.06, 2.4, 3)
			m.roughness_texture = noise_tex("metal_r", 92, 0.03, [
				[0.0, Color(0.22, 0.22, 0.22)], [1.0, Color(0.72, 0.72, 0.72)]], 3)
			return _tri(m, 0.3)
		"metal_rust":
			var m := _base(Color(1, 0.635, 0.404), 0.82, 0.45)
			m.albedo_texture = noise_tex("rust_a", 101, 0.022, [
				[0.0, Color(0.20, 0.13, 0.09)], [0.35, Color(0.42, 0.24, 0.13)],
				[0.7, Color(0.58, 0.34, 0.18)], [1.0, Color(0.36, 0.30, 0.27)]], 5)
			m.normal_enabled = true
			m.normal_texture = normal_tex("rust_a", 101, 0.05, 6.0, 4)
			return _tri(m, 0.34)
		"metal_dark":
			var m := _base(Color(0.573, 0.597, 0.668), 0.38, 0.95)
			m.albedo_texture = noise_tex("mdark_a", 111, 0.025, [
				[0.0, Color(0.09, 0.10, 0.11)], [1.0, Color(0.24, 0.25, 0.28)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("mdark_a", 111, 0.07, 2.0, 3)
			return _tri(m, 0.35)
		"brass":
			var m := _base(Color(1, 0.778, 0.361), 0.30, 0.95)
			m.albedo_texture = noise_tex("brass_a", 121, 0.03, [
				[0.0, Color(0.50, 0.38, 0.16)], [1.0, Color(0.86, 0.70, 0.34)]], 3)
			return _tri(m, 0.3)
		"glass":
			# metallic_specular 0.95 at roughness 0.04 is a mirror. Reflecting an
			# overcast sky it clipped to flat white, so every glass shard near the
			# camera rendered as a featureless blob with no facets -- the one
			# material the tint pass never touched, which is why it survived every
			# other correction. Real glass reflects strongly only at grazing
			# angles, which Fresnel already gives; the flat boost was double-
			# counting it.
			var m := _base(Color(0.72, 0.82, 0.88, 0.20), 0.09, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic_specular = 0.42
			m.refraction_enabled = false
			m.backlight_enabled = true
			m.backlight = Color(0.11, 0.15, 0.18)
			return m
		"glass_broken":
			var m := mat("glass").duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.62, 0.68, 0.70, 0.34)
			m.roughness = 0.42
			m.normal_enabled = true
			m.normal_texture = normal_tex("glassb", 131, 0.08, 9.0, 4)
			return m
		"wood":
			var m := _base(Color(1, 0.711, 0.444), 0.88, 0.0)
			m.albedo_texture = noise_tex("wood_a", 141, 0.006, [
				[0.0, Color(0.20, 0.13, 0.08)], [0.45, Color(0.34, 0.23, 0.14)],
				[1.0, Color(0.48, 0.34, 0.20)]], 3, TEX_SIZE,
				FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
			m.normal_enabled = true
			m.normal_texture = normal_tex("wood_a", 141, 0.02, 5.0, 3)
			return _tri(m, 0.35)
		"bark":
			var m := _base(Color(1, 0.8, 0.6), 0.95, 0.0)
			m.albedo_texture = noise_tex("bark_a", 151, 0.012, [
				[0.0, Color(0.12, 0.10, 0.08)], [0.4, Color(0.25, 0.20, 0.15)],
				[0.8, Color(0.36, 0.29, 0.21)], [1.0, Color(0.44, 0.37, 0.28)]], 5,
				TEX_SIZE, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED)
			m.normal_enabled = true
			m.normal_texture = normal_tex("bark_a", 151, 0.03, 14.0, 5)
			m.normal_scale = 1.6
			return _tri(m, 0.5)
		# ---------------------------------------------------------- people
		"skin":
			# Skin is not a plastic: it is rough at a scale you cannot see, it
			# scatters light through the thin parts, and its specular is weak and
			# broad. Getting those three wrong is most of what makes a CG person
			# look like a mannequin.
			var m := _base(Color(0.78, 0.62, 0.53), 0.52, 0.0)
			m.normal_enabled = true
			m.normal_texture = normal_tex("skin_n", 501, 0.32, 1.6, 3, TEX_SIZE_SMALL)
			m.normal_scale = 0.30
			m.specular = 0.28
			m.backlight_enabled = true
			m.backlight = Color(0.24, 0.09, 0.07)
			m.roughness_texture = noise_tex("skin_r", 502, 0.10, [
				[0.0, Color(0.82, 0.82, 0.82)], [1.0, Color(1.0, 1.0, 1.0)]], 3,
				TEX_SIZE_SMALL)
			return m
		"cloth":
			var m := _base(Color(0.70, 0.72, 0.75), 0.92, 0.0)
			m.albedo_texture = noise_tex("cloth_a", 511, 0.09, [
				[0.0, Color(0.62, 0.62, 0.64)], [0.5, Color(0.82, 0.82, 0.84)],
				[1.0, Color(0.96, 0.96, 0.97)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("cloth_n", 512, 0.22, 3.2, 3)
			m.normal_scale = 0.85
			m.specular = 0.14
			m.ao_enabled = true
			m.ao_texture = noise_tex("cloth_ao", 513, 0.05, [
				[0.0, Color(0.70, 0.70, 0.70)], [0.65, Color(1, 1, 1)],
				[1.0, Color(1, 1, 1)]], 3)
			return m
		"resin":
			var m := _base(Color(0.58, 0.44, 0.22, 0.86), 0.18, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.backlight_enabled = true
			m.backlight = Color(0.5, 0.34, 0.12)
			return m
		"tile":
			var m := _base(Color(0.598, 0.616, 0.633), 0.28, 0.05)
			m.albedo_texture = noise_tex("tile_a", 161, 0.05, [
				[0.0, Color(0.52, 0.55, 0.58)], [0.5, Color(0.70, 0.72, 0.74)],
				[1.0, Color(0.82, 0.84, 0.86)]], 3)
			m.normal_enabled = true
			m.normal_texture = normal_tex("tile_a", 161, 0.05, 3.0, 3)
			return _tri(m, 0.5)
		"nacre":
			var m := _base(Color(0.555, 0.592, 0.647), 0.18, 0.30)
			m.albedo_texture = noise_tex("nacre_a", 171, 0.02, [
				[0.0, Color(0.68, 0.76, 0.86)], [0.35, Color(0.88, 0.84, 0.92)],
				[0.65, Color(0.80, 0.90, 0.88)], [1.0, Color(0.94, 0.92, 0.86)]], 4)
			m.normal_enabled = true
			m.normal_texture = normal_tex("nacre_a", 171, 0.05, 2.0, 3)
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.7
			m.clearcoat_enabled = true
			m.clearcoat = 0.5
			m.clearcoat_roughness = 0.16
			return _tri(m, 0.34)

		# ---------------------------------------------------------- organic
		"foliage":
			# Vegetation keeps its authored tint. Fitting these to a luma target
			# pushes the green channel to full, which reads as neon rather than as
			# leaves; the double-darkening these numbers look like is the point.
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
			m.emission = Color(0.08, 0.24, 0.12)
			m.emission_energy_multiplier = 0.10
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
	# An emissive surface keeps a DARK albedo. Giving it the same bright colour
	# as its emission double-counts: the emission is added on top of a surface
	# that is already being lit, and if the object also carries its own lamp --
	# which glowing props here do -- the sum clips to white and the object loses
	# its shape entirely.
	m.albedo_color = Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, c.a)
	m.emission_enabled = true
	m.emission = c
	# Emission is linear and uncapped: energy 1.8 on a colour with a 1.0 channel
	# put 1.8 into that channel, which clips to pure white however the tonemapper
	# is set. Emissive props were rendering as featureless white shapes. Held
	# under 1.0 so a glowing object keeps its hue and the HDR threshold, not the
	# clip, decides what blooms.
	# 0.62, not 0.95. These props sit under an additive halo and usually carry
	# their own lamp as well, so a surface that only just fits under 1.0 on its
	# own still clips once everything is summed.
	m.emission_energy_multiplier = minf(energy, 0.62 / maxf(maxf(c.r, c.g), maxf(c.b, 0.001)))
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
	# Additive blending adds the albedo AND the emission, so a full-alpha colour
	# at a high energy puts several times the colour into the frame. Both halves
	# are damped, and brightness comes from the HDR threshold rather than from
	# stacking contributions.
	#
	# The budget has to assume the surface is drawn MORE THAN ONCE. These are
	# rings and shells, and with culling disabled a view ray crosses both the
	# near and the far side, compositing two additive layers on the same pixel.
	# Sizing the budget for one layer is what left the Device halo and the
	# beacon rings as featureless white pills: two faces at 0.56 in the blue
	# channel, over an emissive prop that was already at 0.9, clipped every
	# channel to 1.0 and the shape disappeared.
	var layers := 2.0 if cull_disabled else 1.0
	var peak := maxf(maxf(c.r, c.g), maxf(c.b, 0.001))
	var alpha := 0.30 / layers
	m.albedo_color = Color(c.r, c.g, c.b, c.a * alpha)
	m.emission_enabled = true
	m.emission = c
	# Leave room underneath for the lit surface the halo is drawn over.
	var budget := 0.55 / layers
	m.emission_energy_multiplier = minf(energy * 0.22,
		maxf(budget - alpha * peak, 0.02) / peak)
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

## A triangle whose winding is forced to face `out`. Chamfer geometry has eight
## corner cases whose orientation is easy to get subtly wrong; deriving the
## winding from the direction the surface should face gets it right every time.
func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		ua := Vector2.ZERO, ub := Vector2.RIGHT, uc := Vector2.DOWN) -> void:
	if (b - a).cross(c - a).dot(out) >= 0.0:
		_tri3(st, a, b, c, ua, ub, uc)
	else:
		_tri3(st, a, c, b, ua, uc, ub)

func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		out: Vector3, uv_scale: float = 1.0) -> void:
	var w := (b - a).length() * uv_scale
	var hgt := (d - a).length() * uv_scale
	_tri_out(st, a, b, c, out, Vector2(0, 0), Vector2(w, 0), Vector2(w, hgt))
	_tri_out(st, a, c, d, out, Vector2(0, 0), Vector2(w, hgt), Vector2(0, hgt))

## Axis-aligned chamfered box under an arbitrary transform. Winding = outward.
##
## The chamfer is the point. A perfect 90-degree edge is the single clearest
## tell that a shape came out of a primitive generator rather than out of a
## world: nothing built, cast, cut or weathered has one, and the thin highlight
## along a real edge is most of what the eye uses to read an object's form.
## Every wall, floor, lintel, truss member and stair tread in the game goes
## through here, so this one change reshapes the built world.
func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, uv_scale: float = 1.0,
		chamfer: float = -1.0) -> void:
	var h := size * 0.5
	var small: float = minf(minf(size.x, size.y), size.z)
	var c: float = clampf(small * 0.06, 0.006, 0.05) if chamfer < 0.0 else chamfer
	c = minf(c, small * 0.3)
	# Below a couple of centimetres the chamfer is not worth the triangles.
	if c < 0.004:
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
		return

	var hs := [h.x, h.y, h.z]
	# A vertex of the chamfered box: `full` names the axis held at its full
	# half-extent, the other two are inset by the chamfer.
	var vert := func(sx: float, sy: float, sz: float, full: int) -> Vector3:
		var sg := [sx, sy, sz]
		var v := Vector3.ZERO
		for a in 3:
			v[a] = sg[a] * (hs[a] if a == full else hs[a] - c)
		return v
	var dirv := func(sx: float, sy: float, sz: float) -> Vector3:
		return (xf.basis * Vector3(sx, sy, sz)).normalized()

	# Six inset faces.
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var ua := (axis + 1) % 3
			var va := (axis + 2) % 3
			var quad: Array = []
			for corner in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var sg := [0.0, 0.0, 0.0]
				sg[axis] = sgn
				sg[ua] = corner[0]
				sg[va] = corner[1]
				quad.append(xf * vert.call(sg[0], sg[1], sg[2], axis))
			var nrm := [0.0, 0.0, 0.0]
			nrm[axis] = sgn
			_quad_out(st, quad[0], quad[1], quad[2], quad[3],
				dirv.call(nrm[0], nrm[1], nrm[2]), uv_scale)

	# Twelve edge chamfers: two axes pinned to a sign, the third spanning.
	for a in 3:
		for b in range(a + 1, 3):
			var free_axis: int = 3 - a - b
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var ends: Array = []
					for sf in [-1.0, 1.0]:
						var sg := [0.0, 0.0, 0.0]
						sg[a] = sa
						sg[b] = sb
						sg[free_axis] = sf
						ends.append([xf * vert.call(sg[0], sg[1], sg[2], a),
							xf * vert.call(sg[0], sg[1], sg[2], b)])
					var nrm := [0.0, 0.0, 0.0]
					nrm[a] = sa
					nrm[b] = sb
					_quad_out(st, ends[0][0], ends[0][1], ends[1][1], ends[1][0],
						dirv.call(nrm[0], nrm[1], nrm[2]), uv_scale)

	# Eight corner triangles closing the three chamfers that meet there.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_tri_out(st,
					xf * vert.call(sx, sy, sz, 0),
					xf * vert.call(sx, sy, sz, 1),
					xf * vert.call(sx, sy, sz, 2),
					dirv.call(sx, sy, sz))

func _commit(st: SurfaceTool, smooth: bool = false) -> ArrayMesh:
	if smooth:
		st.generate_normals()
	st.generate_tangents()
	st.index()
	st.optimize_indices_for_cache()
	return st.commit()

# ---------------------------------------------------------------- shape cache
var _shapes: Dictionary = {}

## Collision shapes are expensive to build and are shared by every instance of
## a cached mesh, so they are cached alongside the meshes themselves.
func trimesh_shape(m: Mesh) -> Shape3D:
	var key := "t%d" % m.get_instance_id()
	if _shapes.has(key):
		return _shapes[key]
	var s := m.create_trimesh_shape()
	_shapes[key] = s
	return s

func convex_shape(m: Mesh) -> Shape3D:
	var key := "c%d" % m.get_instance_id()
	if _shapes.has(key):
		return _shapes[key]
	var s := m.create_convex_shape(true, true)
	_shapes[key] = s
	return s

func _cached(key: String, fn: Callable) -> Mesh:
	if _mesh.has(key):
		return _mesh[key]
	var m: Mesh = fn.call()
	if m == null:
		# SurfaceTool.commit() returns null for a surface with no triangles.
		# Hand back an empty ArrayMesh instead so a degenerate parameter set
		# cannot propagate a null into MeshInstance3D or the collision builder.
		Log.warn("ProcAssets: generator produced no geometry for '%s'" % key)
		m = ArrayMesh.new()
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

## A machine limb segment: a tapered, faceted tube with a swollen joint at each
## end. Box legs are the loudest "this is a prototype" signal a walker can send,
## because a real actuated limb is never a constant-section stick -- it is thick
## at the joints, where the bearing and the housing live, and thin along the
## span, where only the load matters.
func limb_mesh(length: float, top_radius: float, bottom_radius: float,
		sides: int = 10, joint: float = 1.55) -> Mesh:
	var key := "limb_%.3f_%.3f_%.3f_%d_%.2f" % [length, top_radius, bottom_radius,
		sides, joint]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var n: int = maxi(5, sides)
		# Profile down the limb: fraction of length, radius multiplier. The
		# bulges at 0 and 1 are the joint housings.
		var profile := [
			[0.00, joint * 0.86], [0.07, joint], [0.16, 1.0],
			[0.50, 0.88], [0.84, 1.0], [0.93, joint], [1.00, joint * 0.86],
		]
		var radius_at := func(t: float) -> float:
			return lerpf(top_radius, bottom_radius, t)
		var ring := func(idx: int) -> Array:
			var e: Array = profile[idx]
			var t: float = float(e[0])
			var rad: float = radius_at.call(t) * float(e[1])
			var y := -length * t
			var pts: Array = []
			for i in n:
				var a := TAU * float(i) / float(n)
				# Slight ellipticity so the limb has a front and a side rather
				# than reading as a lathe-turned dowel.
				pts.append(Vector3(cos(a) * rad, y, sin(a) * rad * 0.78))
			return pts
		for k in range(profile.size() - 1):
			var r0: Array = ring.call(k)
			var r1: Array = ring.call(k + 1)
			var v0: float = float(profile[k][0])
			var v1: float = float(profile[k + 1][0])
			for i in n:
				var j := (i + 1) % n
				var u0 := float(i) / float(n)
				var u1 := float(i + 1) / float(n)
				_tri3(st, r0[i], r0[j], r1[j],
					Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_tri3(st, r0[i], r1[j], r1[i],
					Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
		# Cap both ends so the limb is closed where it meets its joint.
		var top: Array = ring.call(0)
		var bot: Array = ring.call(profile.size() - 1)
		for i in n:
			var j := (i + 1) % n
			_tri3(st, Vector3(0, 0, 0), top[j], top[i])
			_tri3(st, Vector3(0, -length, 0), bot[i], bot[j])
		return _commit(st, true))

## A small boat hull: tapered bow, chined sides, flat deck, squared stern.
##
## The survey skiff the game opens on was a 4x8 metre cuboid, and it is the
## first object the player ever stands on. A hull is defined by its curves --
## the taper toward the bow, the chine where topside meets bottom, the sheer
## rising forward -- and none of those survive being a box.
func hull_mesh(length: float, beam: float, depth: float, sections: int = 16) -> Mesh:
	var key := "hull_%.2f_%.2f_%.2f_%d" % [length, beam, depth, sections]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var n: int = maxi(6, sections)
		var hb := beam * 0.5
		var hd := depth * 0.5
		# Cross-section as (half-width factor, height factor) pairs, keel first
		# and up the starboard side to the deck edge.
		var side := [
			[0.00, -1.00],   # keel
			[0.46, -0.86],   # turn of the bilge
			[0.82, -0.42],   # lower chine
			[0.97, 0.10],    # upper chine
			[1.00, 0.72],    # deck edge
		]
		var loops: Array = []
		for k in range(n + 1):
			var t := float(k) / float(n)
			# Beam: full through the middle, squared off aft, drawn to a stem
			# forward. The cubic keeps the shoulders full so the taper reads as
			# a bow rather than as a wedge.
			var taper: float = 1.0 - pow(clampf((t - 0.45) / 0.55, 0.0, 1.0), 1.7) * 0.94
			taper *= lerpf(0.86, 1.0, smoothstep(0.0, 0.28, t))
			# Sheer: the deck line rises toward the bow and a little aft.
			var sheer: float = 1.0 + pow(clampf((t - 0.5) / 0.5, 0.0, 1.0), 2.0) * 0.30 \
				+ pow(clampf((0.28 - t) / 0.28, 0.0, 1.0), 2.0) * 0.10
			var z := lerpf(-length * 0.5, length * 0.5, t)
			var loop: PackedVector3Array = []
			# Keel and starboard side, then port side mirrored back down, so the
			# loop is closed and consistently wound.
			for i in side.size():
				var w: float = float(side[i][0]) * hb * taper
				var y: float = float(side[i][1]) * hd
				if side[i][1] > 0.0:
					y *= sheer
				loop.append(Vector3(w, y, z))
			# Port side, mirrored and walked back down. The keel sits on the
			# centreline, so it is not repeated -- the loop closes onto it.
			for i in range(side.size() - 1, 0, -1):
				var w2: float = -float(side[i][0]) * hb * taper
				var y2: float = float(side[i][1]) * hd
				if side[i][1] > 0.0:
					y2 *= sheer
				loop.append(Vector3(w2, y2, z))
			loops.append(loop)
		var m: int = loops[0].size()
		for k in range(n):
			var a: PackedVector3Array = loops[k]
			var b: PackedVector3Array = loops[k + 1]
			for i in m:
				var j := (i + 1) % m
				var v0: float = float(k) / float(n) * length
				var v1: float = float(k + 1) / float(n) * length
				var u0 := float(i) / float(m) * beam * 2.0
				var u1 := float(i + 1) / float(m) * beam * 2.0
				_tri_out(st, a[i], a[j], b[j], (a[i] + a[j] + b[j]) / 3.0 * Vector3(1, 1, 0),
					Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_tri_out(st, a[i], b[j], b[i], (a[i] + b[j] + b[i]) / 3.0 * Vector3(1, 1, 0),
					Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
		# Transom and stem caps.
		for pair in [[loops[0], Vector3(0, 0, -1)], [loops[n], Vector3(0, 0, 1)]]:
			var loop: PackedVector3Array = pair[0]
			var out: Vector3 = pair[1]
			var mid := Vector3.ZERO
			for v in loop:
				mid += v
			mid /= float(loop.size())
			for i in loop.size():
				var j := (i + 1) % loop.size()
				_tri_out(st, mid, loop[i], loop[j], out)
		return _commit(st, true))

## A lofted torso: hips, waist, ribcage, chest, shoulders.
##
## Built the way the hull is, from elliptical cross-sections stacked up the body
## and skinned between, because a torso is defined by how its width and depth
## change with height -- narrow and deep at the waist, wide and shallow across
## the shoulders. A capsule or a box gets none of that and reads instantly as a
## placeholder.
func body_mesh(height: float, width: float, depth: float, segs: int = 12) -> Mesh:
	var key := "body_%.2f_%.2f_%.2f_%d" % [height, width, depth, segs]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var n: int = maxi(8, segs)
		var ring: int = 12
		# t from hips (0) to the base of the neck (1): half-width, half-depth.
		var profile := [
			[0.00, 0.92, 0.86], [0.10, 0.98, 0.90], [0.24, 0.86, 0.76],
			[0.38, 0.80, 0.72], [0.52, 0.88, 0.80], [0.68, 1.00, 0.88],
			[0.82, 1.00, 0.86], [0.92, 0.84, 0.72], [1.00, 0.52, 0.50],
		]
		var sample := func(t: float) -> Vector3:
			# Piecewise-linear through the profile, so the shape is exactly the
			# table above rather than a curve that smooths the waist away.
			var i := 0
			while i < profile.size() - 2 and float(profile[i + 1][0]) < t:
				i += 1
			var a: Array = profile[i]
			var b: Array = profile[i + 1]
			var span: float = maxf(float(b[0]) - float(a[0]), 1e-5)
			var k: float = clampf((t - float(a[0])) / span, 0.0, 1.0)
			return Vector3(lerpf(float(a[1]), float(b[1]), k) * width * 0.5,
				t * height, lerpf(float(a[2]), float(b[2]), k) * depth * 0.5)
		var loops: Array = []
		for i in range(n + 1):
			var t := float(i) / float(n)
			var d := sample.call(t) as Vector3
			var loop: PackedVector3Array = []
			for j in ring:
				var a := TAU * float(j) / float(ring)
				# Flatten the back slightly: a person is not an extruded ellipse.
				var z := sin(a) * d.z * (1.0 if sin(a) > 0.0 else 0.86)
				loop.append(Vector3(cos(a) * d.x, d.y, z))
			loops.append(loop)
		for i in n:
			var a: PackedVector3Array = loops[i]
			var b: PackedVector3Array = loops[i + 1]
			for j in ring:
				var k := (j + 1) % ring
				var v0 := float(i) / float(n)
				var v1 := float(i + 1) / float(n)
				var u0 := float(j) / float(ring)
				var u1 := float(j + 1) / float(ring)
				var out0 := Vector3(a[j].x, 0.0, a[j].z)
				_tri_out(st, a[j], a[k], b[k], out0,
					Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_tri_out(st, a[j], b[k], b[j], out0,
					Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
		# Close the hips and the neck opening.
		for pair in [[loops[0], Vector3.DOWN], [loops[n], Vector3.UP]]:
			var loop: PackedVector3Array = pair[0]
			var out: Vector3 = pair[1]
			var mid := Vector3.ZERO
			for v in loop:
				mid += v
			mid /= float(loop.size())
			for j in loop.size():
				var k2 := (j + 1) % loop.size()
				_tri_out(st, mid, loop[j], loop[k2], out)
		return _commit(st, true))

## A head: an ellipsoid narrowed at the jaw and flattened at the back.
func head_mesh(radius: float, rings: int = 10, segs: int = 14) -> Mesh:
	var key := "head_%.3f_%d_%d" % [radius, rings, segs]
	return _cached(key, func() -> Mesh:
		var st := _st()
		var nr: int = maxi(6, rings)
		var ns: int = maxi(8, segs)
		var at := func(i: int, j: int) -> Vector3:
			var v := PI * float(i) / float(nr)          # 0 = crown, PI = chin
			var u := TAU * float(j) / float(ns)
			var y := cos(v)
			var r := sin(v)
			# Taper toward the chin and swell slightly at the cranium.
			var jaw: float = lerpf(0.62, 1.0, smoothstep(0.0, 0.55, 1.0 - (y * 0.5 + 0.5)))
			var w: float = r * lerpf(jaw, 1.0, clampf(y * 0.5 + 0.5, 0.0, 1.0))
			var z := sin(u) * w
			if sin(u) < 0.0:
				z *= 0.88                                # flatter at the back
			return Vector3(cos(u) * w * 0.86, y * 1.18, z) * radius
		for i in nr:
			for j in ns:
				var p00: Vector3 = at.call(i, j)
				var p10: Vector3 = at.call(i + 1, j)
				var p11: Vector3 = at.call(i + 1, (j + 1) % ns)
				var p01: Vector3 = at.call(i, (j + 1) % ns)
				var u0 := float(j) / float(ns)
				var u1 := float(j + 1) / float(ns)
				var v0 := float(i) / float(nr)
				var v1 := float(i + 1) / float(nr)
				_tri_out(st, p00, p10, p11, p00.normalized(),
					Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
				_tri_out(st, p00, p11, p01, p00.normalized(),
					Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
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

## A built slab: bevelled, subdivided and very slightly warped.
##
## This replaces what used to be a mathematically perfect cuboid, and it is the
## single largest visual change in the game, because almost every constructed
## thing in every chapter goes through here -- walls, crates, platforms, hulls,
## lintels. A perfect box gives itself away in two ways that no amount of
## texture work can hide:
##
##  * A razor 90-degree edge. Real edges are chipped, cast, poured or milled,
##    and all of those leave a chamfer that catches a highlight. That thin line
##    of light along every edge is most of what the eye reads as "an object"
##    rather than "a primitive".
##  * A perfectly flat face. Four coplanar vertices shade as one dead-flat
##    gradient, so a large wall reads as painted cardboard however good the
##    material is.
##
## So the box is generated as a rounded box: a subdivided cube projected onto a
## rounded-box surface, then displaced along its normal by a little noise. The
## result stays strictly inside the nominal size, which matters because callers
## pair this mesh with a BoxShape3D of exactly that size -- the collider may be
## a hair larger than the visual, never smaller.
func box_mesh(size: Vector3, uv_scale: float = 1.0, wear: float = 1.0,
		seed_v: int = 0) -> Mesh:
	var key := "box_%.2f_%.2f_%.2f_%.2f_%.2f_%d" % [size.x, size.y, size.z,
		uv_scale, wear, seed_v]
	return _cached(key, func() -> Mesh:
		var h := size * 0.5
		var small: float = minf(minf(size.x, size.y), size.z)
		# The bevel has to stay small relative to the thinnest axis or a slab
		# turns into a pillow.
		var r: float = clampf(small * 0.075, 0.008, 0.075) * clampf(wear, 0.0, 2.0)
		r = minf(r, small * 0.24)
		var amp: float = minf(small * 0.012, 0.010) * clampf(wear, 0.0, 2.0)
		var inner := Vector3(maxf(h.x - r, 0.0), maxf(h.y - r, 0.0), maxf(h.z - r, 0.0))
		var st := _st()
		# Sample positions along an axis: the box edge, two steps through the
		# chamfer, then the flat interior. The chamfer boundary has to be an
		# explicit sample -- on a plain uniform grid a coarse face has no vertex
		# where the bevel starts, and the whole face collapses into a pyramid.
		var axis_coords := func(half: float, inner_half: float) -> Array:
			var out: Array = []
			out.append(-half)
			if inner_half < half - 1e-6:
				out.append(-lerpf(inner_half, half, 0.55))
				out.append(-inner_half)
			var span := inner_half * 2.0
			var steps: int = clampi(int(ceil(span / 0.7)), 1, 10)
			for k in range(1, steps):
				out.append(lerpf(-inner_half, inner_half, float(k) / float(steps)))
			if inner_half < half - 1e-6:
				out.append(inner_half)
				out.append(lerpf(inner_half, half, 0.55))
			out.append(half)
			return out
		var coords := [axis_coords.call(h.x, inner.x), axis_coords.call(h.y, inner.y),
			axis_coords.call(h.z, inner.z)]
		# Project a point on the nominal box onto the rounded-box surface, then
		# push it in or out slightly. Exact rounded-box mapping: clamp to the
		# inner core, then step out by the bevel radius along the offset.
		var surf := func(p: Vector3) -> Vector3:
			var q := Vector3(clampf(p.x, -inner.x, inner.x),
				clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
			var d := p - q
			if d.length_squared() < 1e-10:
				return q
			var nrm := d.normalized()
			var v := q + nrm * r
			if amp > 0.0:
				# Cheap deterministic value noise: enough to break the plane,
				# not enough to move the surface off its collider.
				var w := sin(v.x * 5.7 + float(seed_v) * 1.3) \
					* sin(v.y * 6.9 + 1.7 + float(seed_v) * 0.7) \
					* sin(v.z * 6.1 + 3.1 + float(seed_v) * 2.1)
				var w2 := sin(v.x * 17.3 + 0.4) * sin(v.y * 15.1 + 2.2) * sin(v.z * 19.7 + 5.0)
				# Biased so the displacement is never positive. Callers pair this
				# mesh with a BoxShape3D of the nominal size, and a surface that
				# bulges past its own collider lets the player stand inside the
				# visible geometry. Weathering takes material away in any case.
				v += nrm * (w * amp + w2 * amp * 0.35 - amp * 1.35)
			return v
		# Six faces, each a grid over those coordinates. Axis: 0=x, 1=y, 2=z.
		var hs := [h.x, h.y, h.z]
		for axis in 3:
			var ua := (axis + 1) % 3
			var va := (axis + 2) % 3
			# (ua, va, axis) is right-handed for every cyclic choice, so the
			# positive face keeps its winding and only the negative one flips.
			var cu: Array = coords[ua]
			var cv: Array = coords[va]
			for sgn in [-1.0, 1.0]:
				for i in range(cu.size() - 1):
					for j in range(cv.size() - 1):
						var at := func(di: int, dj: int) -> Vector3:
							var p := Vector3.ZERO
							p[axis] = sgn * hs[axis]
							p[ua] = cu[i + di]
							p[va] = cv[j + dj]
							return surf.call(p)
						# Explicit types: Callable.call() returns Variant, and
						# this project treats an inferred Variant as an error.
						var p00: Vector3 = at.call(0, 0)
						var p10: Vector3 = at.call(1, 0)
						var p11: Vector3 = at.call(1, 1)
						var p01: Vector3 = at.call(0, 1)
						var u0: float = (float(cu[i]) + hs[ua]) * uv_scale
						var u1: float = (float(cu[i + 1]) + hs[ua]) * uv_scale
						var v0: float = (float(cv[j]) + hs[va]) * uv_scale
						var v1: float = (float(cv[j + 1]) + hs[va]) * uv_scale
						if sgn > 0.0:
							_tri3(st, p00, p10, p11,
								Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
							_tri3(st, p00, p11, p01,
								Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
						else:
							_tri3(st, p00, p11, p10,
								Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
							_tri3(st, p00, p01, p11,
								Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
		# Smooth normals: the bevel needs them, and a flat face's vertices are
		# still coplanar so its shading is unchanged.
		return _commit(st, true))

func sphere_mesh(radius: float, rings: int = 12, segs: int = 18) -> Mesh:
	return rock_mesh(0, radius, 0.0, rings, segs, 1.0)

# ============================================================ terrain materials
## Multi-layer triplanar terrain surfaces, one per biome. Each is a ShaderMaterial
## fed by the same procedural noise textures the object materials use.
const TERRAIN_PRESETS := {
	"valley": {"ground": "grass", "slope": "cliff", "peak": "rock",
		"gt": Color(0.31, 0.38, 0.19), "st": Color(0.42, 0.40, 0.35),
		"pt": Color(0.46, 0.46, 0.47), "peak_start": 36.0, "peak_end": 62.0, "uv": 0.26},
	"forest": {"ground": "moss", "slope": "cliff", "peak": "rock",
		"gt": Color(0.25, 0.35, 0.16), "st": Color(0.38, 0.37, 0.32),
		"pt": Color(0.45, 0.47, 0.42), "peak_start": 40.0, "peak_end": 70.0, "uv": 0.28},
	"city": {"ground": "concrete", "slope": "concrete_aged", "peak": "tile",
		"gt": Color(0.56, 0.57, 0.58), "st": Color(0.46, 0.47, 0.49),
		"pt": Color(0.68, 0.70, 0.74), "peak_start": 26.0, "peak_end": 48.0, "uv": 0.20},
	"mountain": {"ground": "snow", "slope": "cliff", "peak": "snow",
		"gt": Color(0.70, 0.75, 0.82), "st": Color(0.32, 0.33, 0.36),
		"pt": Color(0.80, 0.84, 0.90), "peak_start": 16.0, "peak_end": 34.0, "uv": 0.22},
	"desert": {"ground": "sand", "slope": "rock", "peak": "rock",
		"gt": Color(0.68, 0.58, 0.39), "st": Color(0.52, 0.45, 0.34),
		"pt": Color(0.58, 0.51, 0.38), "peak_start": 28.0, "peak_end": 52.0, "uv": 0.24},
	"islands": {"ground": "sand", "slope": "rock_wet", "peak": "grass",
		"gt": Color(0.58, 0.52, 0.39), "st": Color(0.36, 0.38, 0.38),
		"pt": Color(0.30, 0.40, 0.24), "peak_start": 12.0, "peak_end": 26.0, "uv": 0.26},
	"archive": {"ground": "tile", "slope": "concrete", "peak": "concrete",
		"gt": Color(0.62, 0.64, 0.67), "st": Color(0.48, 0.49, 0.52),
		"pt": Color(0.56, 0.58, 0.61), "peak_start": 30.0, "peak_end": 60.0, "uv": 0.18},
	"core": {"ground": "metal_dark", "slope": "rock_dark", "peak": "brass",
		"gt": Color(0.34, 0.35, 0.38), "st": Color(0.28, 0.29, 0.32),
		"pt": Color(0.56, 0.47, 0.28), "peak_start": 24.0, "peak_end": 48.0, "uv": 0.22},
}

func terrain_material(preset: String) -> ShaderMaterial:
	var key := "terrain_" + preset
	if _mat.has(key):
		return _mat[key]
	var d: Dictionary = TERRAIN_PRESETS.get(preset, TERRAIN_PRESETS.valley)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("tex_ground", _detail_of(String(d.ground), 0))
	m.set_shader_parameter("tex_slope", _detail_of(String(d.slope), 1))
	m.set_shader_parameter("tex_peak", _detail_of(String(d.peak), 2))
	m.set_shader_parameter("nrm_ground", _terrain_normal_of(String(d.ground), 0))
	m.set_shader_parameter("nrm_slope", _terrain_normal_of(String(d.slope), 1))
	m.set_shader_parameter("macro_tex", noise_tex("macro", 909, 0.004,
		[[0.0, Color.BLACK], [1.0, Color.WHITE]], 4, TEX_SIZE))
	m.set_shader_parameter("ground_tint", Color(d.gt))
	m.set_shader_parameter("slope_tint", Color(d.st))
	m.set_shader_parameter("peak_tint", Color(d.pt))
	m.set_shader_parameter("uv_scale", float(d.uv))
	# The close-range detail octaves are two extra triplanar samples each; Low
	# takes the single-sample path instead.
	m.set_shader_parameter("quality",
		1.0 if float(Settings.preset_data().get("terrain_res", 1.0)) > 0.8 else 0.0)
	m.set_shader_parameter("peak_start", float(d.peak_start))
	m.set_shader_parameter("peak_end", float(d.peak_end))
	m.set_shader_parameter("macro_scale", 0.0075)
	m.set_shader_parameter("macro_strength", 0.42)
	m.set_shader_parameter("normal_depth", 0.40)
	m.set_shader_parameter("detail_scale", 0.9)
	_mat[key] = m
	return m

## Greyscale detail for the terrain shader. The layer tints carry the colour, so
## the detail map has to stay achromatic - multiplying an already-coloured albedo
## by a tint darkens the surface twice and the ground reads as near-black.
const DETAIL_SHAPES := {
	"grass":         [0.014, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"moss":          [0.018, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"sand":          [0.020, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"snow":          [0.012, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"cliff":         [0.010, 5, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED],
	"rock":          [0.012, 4, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_FBM],
	"rock_dark":     [0.012, 4, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_FBM],
	"rock_wet":      [0.014, 4, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_FBM],
	"concrete":      [0.009, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"concrete_aged": [0.011, 4, FastNoiseLite.TYPE_SIMPLEX, FastNoiseLite.FRACTAL_RIDGED],
	"tile":          [0.020, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"metal_dark":    [0.016, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
	"brass":         [0.016, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM],
}

func _detail_of(name: String, slot: int) -> Texture2D:
	var d: Array = DETAIL_SHAPES.get(name, [0.04, 4,
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM])
	return noise_tex("detail_%s" % name, 4400 + slot * 17, float(d[0]),
		[[0.0, Color(0.46, 0.46, 0.46)], [0.45, Color(0.80, 0.80, 0.80)],
		 [0.78, Color(1.02, 1.02, 1.02)], [1.0, Color(1.18, 1.18, 1.18)]],
		int(d[1]), TEX_SIZE, int(d[2]), int(d[3]))

## Terrain normals must be far gentler than object normals: three triplanar
## projections of a strong bump map fight each other and shade the ground into
## a mottled mess of near-black and near-white patches.
func _terrain_normal_of(name: String, slot: int) -> Texture2D:
	var d: Array = DETAIL_SHAPES.get(name, [0.04, 4,
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH, FastNoiseLite.FRACTAL_FBM])
	return normal_tex("tnrm_%s" % name, 5500 + slot * 13, float(d[0]) * 2.2,
		2.2, mini(int(d[1]), 4), TEX_SIZE, int(d[2]))

func _normal_of(name: String) -> Texture2D:
	var sm := mat(name)
	if sm.normal_texture != null:
		return sm.normal_texture
	return normal_tex("fallback_n_" + name, 2, 0.05, 3.0, 3, TEX_SIZE_SMALL)

func clear_cache() -> void:
	_mesh.clear()
