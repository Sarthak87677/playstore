shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Triplanar multi-layer terrain: a ground layer on flat ground, a rock layer on
// slopes, and a peak layer above a height band, with large-scale noise breaking
// up the transitions so the blend never reads as a stripe.

uniform sampler2D tex_ground : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_slope  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_peak   : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_ground : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_slope  : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D macro_tex  : source_color, filter_linear_mipmap, repeat_enable;

uniform vec4 ground_tint : source_color = vec4(0.34, 0.40, 0.24, 1.0);
uniform vec4 slope_tint  : source_color = vec4(0.40, 0.38, 0.35, 1.0);
uniform vec4 peak_tint   : source_color = vec4(0.72, 0.74, 0.78, 1.0);

uniform float uv_scale = 0.075;
uniform float macro_scale = 0.006;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.35;
uniform float slope_start : hint_range(0.0, 1.0) = 0.62;
uniform float slope_end   : hint_range(0.0, 1.0) = 0.88;
uniform float peak_start = 24.0;
uniform float peak_end = 40.0;
uniform float rough_ground : hint_range(0.0, 1.0) = 0.94;
uniform float rough_slope  : hint_range(0.0, 1.0) = 0.88;
uniform float normal_depth : hint_range(0.0, 3.0) = 0.9;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.35;
uniform float detail_scale = 0.9;

varying vec3 w_pos;
varying vec3 w_norm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= max(b.x + b.y + b.z, 0.0001);
	return texture(t, p.zy * s).rgb * b.x
		 + texture(t, p.xz * s).rgb * b.y
		 + texture(t, p.xy * s).rgb * b.z;
}

void fragment() {
	vec3 n = normalize(w_norm);
	float up = clamp(n.y, 0.0, 1.0);

	// Break the slope threshold with macro noise so the seam is organic.
	float macro = texture(macro_tex, w_pos.xz * macro_scale).r;
	float steep = 1.0 - smoothstep(slope_start + (macro - 0.5) * 0.18,
		slope_end + (macro - 0.5) * 0.18, up);
	float peak = smoothstep(peak_start, peak_end, w_pos.y + (macro - 0.5) * 8.0);

	vec3 a_ground = triplanar(tex_ground, w_pos, n, uv_scale) * ground_tint.rgb;
	vec3 a_slope  = triplanar(tex_slope,  w_pos, n, uv_scale * 0.55) * slope_tint.rgb;
	vec3 a_peak   = triplanar(tex_peak,   w_pos, n, uv_scale * 0.8) * peak_tint.rgb;

	vec3 col = mix(a_ground, a_slope, steep);
	col = mix(col, a_peak, peak * (1.0 - steep * 0.55));
	// A second, finer octave keeps close-up ground from looking like flat paint
	// without turning distant ground into noise.
	float fine = triplanar(tex_ground, w_pos, n, uv_scale * 3.5).r;
	col *= mix(1.0, 0.86 + 0.28 * fine, detail_scale * 0.5);
	// Large-scale tonal drift keeps big surfaces from reading as a flat wash.
	col *= mix(1.0 - macro_strength * 0.5, 1.0 + macro_strength * 0.5, macro);

	ALBEDO = col;
	ROUGHNESS = mix(rough_ground, rough_slope, steep);
	SPECULAR = 0.32;
	METALLIC = 0.0;

	vec3 nm = mix(triplanar(nrm_ground, w_pos, n, uv_scale),
		triplanar(nrm_slope, w_pos, n, uv_scale * 0.55), steep);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
	AO = mix(1.0, 0.70 + 0.30 * macro, ao_strength);
	AO_LIGHT_AFFECT = 0.30;
}
