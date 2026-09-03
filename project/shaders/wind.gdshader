shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.28, 0.50, 0.24, 1.0);
uniform vec4 tip_tint : source_color = vec4(0.42, 0.66, 0.30, 1.0);
uniform vec3 backlight_col : source_color = vec3(0.10, 0.24, 0.08);
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.1;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float sway_height = 1.4;
uniform float rough : hint_range(0.0, 1.0) = 0.82;
uniform float gust = 0.0;

varying float v_h;

void vertex() {
	v_h = clamp(VERTEX.y / max(sway_height, 0.01), 0.0, 1.0);
	vec3 wpos = MODEL_MATRIX[3].xyz;
	float phase = wpos.x * 0.42 + wpos.z * 0.31;
	float t = TIME * wind_speed;
	float w = sin(t + phase) * 0.62 + sin(t * 1.73 + phase * 1.31) * 0.38;
	w *= (1.0 + gust * 1.8);
	vec2 d = normalize(wind_dir);
	float amp = wind_strength * v_h * v_h;
	VERTEX.x += d.x * w * amp;
	VERTEX.z += d.y * w * amp;
	VERTEX.y -= abs(w) * amp * 0.25;
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV * 2.0).rgb;
	vec3 col = mix(tint.rgb, tip_tint.rgb, v_h) * (0.65 + 0.7 * tex);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.2;
	BACKLIGHT = backlight_col;
	NORMAL_MAP_DEPTH = 1.0;
}
