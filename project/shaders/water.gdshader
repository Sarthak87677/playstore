shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec4 shallow_col : source_color = vec4(0.20, 0.52, 0.55, 0.55);
uniform vec4 deep_col : source_color = vec4(0.03, 0.13, 0.20, 0.94);
uniform vec3 foam_col : source_color = vec3(0.86, 0.93, 0.95);
uniform float depth_fade = 4.2;
uniform float wave_scale = 0.09;
uniform float wave_speed = 0.045;
uniform float normal_strength = 0.45;
uniform float refraction = 0.028;
uniform float wave_height = 0.06;
uniform float rough : hint_range(0.0, 1.0) = 0.05;

void vertex() {
	float t = TIME * 0.6;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.7 + t) * wave_height
		+ sin(w.z * 0.53 - t * 1.3) * wave_height * 0.7;
}

void fragment() {
	vec2 uv = UV * wave_scale * 40.0;
	vec2 f1 = uv + vec2(TIME * wave_speed, TIME * wave_speed * 0.6);
	vec2 f2 = uv * 1.7 - vec2(TIME * wave_speed * 0.8, TIME * wave_speed * 1.1);
	vec3 n1 = texture(normal_a, f1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_b, f2).xyz * 2.0 - 1.0;
	vec3 n = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	float linear_scene = -(upos.z / upos.w);
	float diff = clamp((linear_scene + VERTEX.z) / depth_fade, 0.0, 1.0);

	vec3 refr = texture(screen_tex, SCREEN_UV + n.xy * refraction).rgb;
	vec3 water = mix(shallow_col.rgb, deep_col.rgb, diff);
	float foam = smoothstep(0.06, 0.0, diff);

	ALBEDO = mix(mix(refr, water, mix(0.45, 0.96, diff)), foam_col, foam * 0.7);
	ALPHA = mix(shallow_col.a, deep_col.a, diff) + foam * 0.35;
	ROUGHNESS = rough + foam * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.85;
}
