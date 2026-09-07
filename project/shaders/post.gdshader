shader_type canvas_item;
render_mode unshaded;

// Full-screen finishing pass.
//
// Godot's Environment gives tonemapping, glow and adjustments; it does not give
// the things that separate a render from a photograph: a lens that is not
// perfect, a sensor that is not noiseless, and edges that fall off. All of it is
// deliberately subtle -- the brief asks for tasteful, and every one of these
// effects is ugly the moment it becomes visible as an effect.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

uniform float grain : hint_range(0.0, 0.2) = 0.030;
uniform float grain_size : hint_range(0.5, 4.0) = 1.35;
uniform float vignette : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_soft : hint_range(0.1, 1.5) = 0.75;
uniform float aberration : hint_range(0.0, 4.0) = 0.7;
uniform float sharpen : hint_range(0.0, 1.5) = 0.42;
uniform float bloom_streak : hint_range(0.0, 1.0) = 0.0;
uniform float time_seed = 0.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);

	// --- chromatic aberration. Zero in the centre, growing with the square of
	// the radius, the way a real lens misbehaves.
	vec3 col;
	if (aberration > 0.001) {
		vec2 off = c * r2 * aberration * 0.006;
		col.r = texture(screen, uv + off).r;
		col.g = texture(screen, uv).g;
		col.b = texture(screen, uv - off).b;
	} else {
		col = texture(screen, uv).rgb;
	}

	// --- unsharp mask. Procedural noise textures and a soft GI solution both
	// lose micro-contrast; this puts some back without ringing.
	if (sharpen > 0.001) {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 blur = texture(screen, uv + vec2(px.x, 0.0)).rgb
			+ texture(screen, uv - vec2(px.x, 0.0)).rgb
			+ texture(screen, uv + vec2(0.0, px.y)).rgb
			+ texture(screen, uv - vec2(0.0, px.y)).rgb;
		blur *= 0.25;
		col += (col - blur) * sharpen;
	}

	// --- vignette, in luminance rather than flat darkening, so colour does not
	// shift in the corners.
	if (vignette > 0.001) {
		float v = smoothstep(0.80, vignette_soft * 0.25, r2 * 1.6);
		col *= mix(1.0, mix(1.0 - vignette, 1.0, v), 1.0);
	}

	// --- sensor grain, scaled by luminance so it sits in the mid-tones and
	// leaves clean blacks and highlights alone.
	if (grain > 0.0001) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		float shape = 4.0 * lum * (1.0 - lum);
		vec2 gp = floor(FRAGCOORD.xy / max(grain_size, 0.5));
		float n = hash13(vec3(gp, time_seed)) - 0.5;
		col += n * grain * shape;
	}

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
