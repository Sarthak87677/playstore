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
uniform float ground_variation : hint_range(0.0, 1.0) = 0.7;
uniform float slope_start : hint_range(0.0, 1.0) = 0.62;
uniform float slope_end   : hint_range(0.0, 1.0) = 0.88;
uniform float peak_start = 24.0;
uniform float peak_end = 40.0;
uniform float rough_ground : hint_range(0.0, 1.0) = 0.94;
uniform float rough_slope  : hint_range(0.0, 1.0) = 0.88;
uniform float normal_depth : hint_range(0.0, 3.0) = 0.9;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.35;
uniform float detail_scale = 0.9;
// 0 = cheapest path (Low preset), 1 = every extra sample.
uniform float quality : hint_range(0.0, 1.0) = 1.0;
uniform float detail_fade_start = 12.0;
uniform float detail_fade_end = 46.0;

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

// Height-aware blend. A linear mix between two materials cross-fades them into
// a smear; real boundaries interlock, because the higher surface wins locally.
// Using each layer's own luminance as a stand-in for height makes gravel poke
// through grass at the edges instead of dissolving into it.
vec3 height_blend(vec3 a, vec3 b, float t, float sharpness) {
	float ha = dot(a, vec3(0.299, 0.587, 0.114));
	float hb = dot(b, vec3(0.299, 0.587, 0.114));
	float ma = (1.0 - t) + ha * sharpness;
	float mb = t + hb * sharpness;
	float m = max(ma, mb) - 0.14;
	float wa = max(ma - m, 0.0);
	float wb = max(mb - m, 0.0);
	return (a * wa + b * wb) / max(wa + wb, 0.0001);
}

void fragment() {
	vec3 n = normalize(w_norm);
	float up = clamp(n.y, 0.0, 1.0);

	// Break the slope threshold with macro noise so the seam is organic.
	float macro = texture(macro_tex, w_pos.xz * macro_scale).r;
	float steep = 1.0 - smoothstep(slope_start + (macro - 0.5) * 0.18,
		slope_end + (macro - 0.5) * 0.18, up);
	float peak = smoothstep(peak_start, peak_end, w_pos.y + (macro - 0.5) * 8.0);

	// Two-tone ground. A single flat tint over the whole valley is what reads as
	// a painted plane rather than as land: real ground is patchy, drier on the
	// rises and richer in the hollows. A second, lower-frequency noise band
	// pushes the ground tint toward a drier, less saturated variant so the
	// colour breaks up at a scale you notice while walking.
	float patch = texture(macro_tex, w_pos.xz * macro_scale * 3.1 + vec2(0.37, 0.11)).r;
	patch = smoothstep(0.34, 0.72, patch);
	vec3 dry = mix(ground_tint.rgb, vec3(dot(ground_tint.rgb, vec3(0.299, 0.587, 0.114))),
		0.45) * 1.18;
	vec3 g_tint = mix(ground_tint.rgb, dry, patch * ground_variation);
	vec3 a_ground = triplanar(tex_ground, w_pos, n, uv_scale) * g_tint;
	vec3 a_slope  = triplanar(tex_slope,  w_pos, n, uv_scale * 0.55) * slope_tint.rgb;
	vec3 a_peak   = triplanar(tex_peak,   w_pos, n, uv_scale * 0.8) * peak_tint.rgb;

	vec3 col = height_blend(a_ground, a_slope, steep, 0.85);
	col = height_blend(col, a_peak, peak * (1.0 - steep * 0.55), 0.7);

	// Close-range detail, faded out by distance. Tiling that is invisible at a
	// metre is a repeating pattern at fifty, and smooth ground at fifty is
	// featureless paint at one; running both and cross-fading by view distance
	// is what stops either from being true.
	float view_d = length(w_pos - CAMERA_POSITION_WORLD);
	float near_w = 1.0 - smoothstep(detail_fade_start, detail_fade_end, view_d);
	if (quality > 0.5 && near_w > 0.01) {
		float fine = triplanar(tex_ground, w_pos, n, uv_scale * 4.2).r;
		float grit = triplanar(tex_slope, w_pos, n, uv_scale * 9.0).r;
		float d = mix(fine, grit, steep);
		col *= mix(1.0, 0.80 + 0.40 * d, detail_scale * near_w);
	} else {
		float fine = triplanar(tex_ground, w_pos, n, uv_scale * 3.5).r;
		col *= mix(1.0, 0.86 + 0.28 * fine, detail_scale * 0.5);
	}
	// Large-scale tonal drift keeps big surfaces from reading as a flat wash.
	col *= mix(1.0 - macro_strength * 0.5, 1.0 + macro_strength * 0.5, macro);

	ALBEDO = col;
	// Roughness is never uniform on real ground: damp hollows are glossier than
	// dry rises, and that variation is most of what sells a wet-looking surface.
	float rough = mix(rough_ground, rough_slope, steep);
	rough = clamp(rough - (macro - 0.5) * 0.16 - patch * 0.06, 0.05, 1.0);
	ROUGHNESS = rough;
	SPECULAR = 0.32;
	METALLIC = 0.0;

	vec3 nm = mix(triplanar(nrm_ground, w_pos, n, uv_scale),
		triplanar(nrm_slope, w_pos, n, uv_scale * 0.55), steep);
	if (quality > 0.5 && near_w > 0.01) {
		// A second normal octave at close range. Detail normals do more for
		// perceived surface depth than any amount of extra albedo detail.
		vec3 nd = triplanar(nrm_ground, w_pos, n, uv_scale * 4.2);
		nm = normalize(mix(nm, normalize(nm + (nd - vec3(0.5, 0.5, 0.0)) * 0.9), near_w));
	}
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth * mix(1.0, 1.5, near_w);
	AO = mix(1.0, 0.70 + 0.30 * macro, ao_strength);
	AO_LIGHT_AFFECT = 0.30;
}
