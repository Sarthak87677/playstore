shader_type sky;
render_mode use_debanding;

// Physically-flavoured sky with two cloud decks.
//
// ProceduralSkyMaterial gives a vertical gradient and a sun disc, which reads as
// a painted backdrop: every outdoor frame in the game had an empty sky. This
// adds a Rayleigh-ish gradient, aerial haze toward the horizon, a limb-darkened
// sun with forward scattering, and two layers of raymarched cloud -- cumulus at
// altitude and a thin cirrus veil above it -- lit by the same sun direction the
// world uses.

group_uniforms colour;
uniform vec3 zenith : source_color = vec3(0.11, 0.24, 0.48);
uniform vec3 horizon : source_color = vec3(0.62, 0.72, 0.86);
uniform vec3 ground_col : source_color = vec3(0.14, 0.13, 0.12);
uniform vec3 sun_col : source_color = vec3(1.0, 0.94, 0.84);
uniform float sky_energy = 1.0;
uniform float horizon_falloff : hint_range(0.5, 8.0) = 2.6;
uniform float haze : hint_range(0.0, 1.0) = 0.35;

group_uniforms sun;
uniform float sun_size_deg : hint_range(0.2, 20.0) = 3.0;
uniform float sun_glow : hint_range(0.0, 4.0) = 1.2;

group_uniforms clouds;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_density : hint_range(0.0, 4.0) = 1.5;
uniform vec3 cloud_col : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 cloud_dark : source_color = vec3(0.36, 0.40, 0.48);
uniform float cloud_height = 900.0;
uniform float cloud_scale = 0.00085;
uniform float cirrus_amount : hint_range(0.0, 1.0) = 0.4;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_speed = 9.0;
uniform int cloud_steps : hint_range(0, 24) = 10;

// ---------------------------------------------------------------- value noise
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.86, 0.5), vec2(-0.5, 0.86));
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) { break; }
		v += amp * vnoise(p);
		p = rot * p * 2.03;
		amp *= 0.5;
	}
	return v;
}

// Cloud coverage at a point on the deck. Billowed with a second warp so the
// edges are not the smooth blobs a single fbm gives.
//
// This function is the entire cost of the sky, so it is written to be called a
// handful of times per pixel. The first version of this shader marched the deck
// and took a sun sample at every step: roughly three hundred noise octaves per
// pixel, which is not a price worth paying for a backdrop.
float coverage(vec2 p, float t) {
	vec2 w = p + vec2(fbm(p * 0.6 + t * 0.03, 2), fbm(p * 0.6 + 4.7 - t * 0.02, 2)) * 1.4;
	float base = fbm(w, 4);
	float edge = fbm(w * 3.1 + 11.0, 2);
	float c = base * 0.80 + edge * 0.20;
	// cloud_amount 0 = clear, 1 = overcast
	float thresh = mix(0.72, 0.18, cloud_amount);
	return smoothstep(thresh, thresh + 0.30, c);
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(0.3, 0.6, 0.2));
	float up = clamp(dir.y, -1.0, 1.0);

	// --- gradient. Rayleigh falls off with height; haze lifts the horizon.
	float t = pow(clamp(1.0 - max(up, 0.0), 0.0, 1.0), horizon_falloff);
	vec3 col = mix(zenith, horizon, t);
	col = mix(col, horizon, haze * t * 0.8);
	if (up < 0.0) {
		col = mix(col, ground_col, clamp(-up * 3.0, 0.0, 1.0));
	}

	// --- sun: limb-darkened disc plus a wide forward-scattering halo.
	float cos_sun = dot(dir, sun_dir);
	float ang = acos(clamp(cos_sun, -1.0, 1.0));
	float rad = radians(sun_size_deg) * 0.5;
	float disc = 1.0 - smoothstep(rad * 0.82, rad, ang);
	float limb = mix(0.72, 1.0, clamp(1.0 - ang / max(rad, 1e-4), 0.0, 1.0));
	float halo = pow(max(cos_sun, 0.0), 220.0) * 0.55
		+ pow(max(cos_sun, 0.0), 12.0) * 0.10;
	col += sun_col * halo * sun_glow;

	// --- clouds. Flat-earth deck: intersect the view ray with a plane and
	// march a short way along it so the deck has thickness rather than being a
	// texture pasted on the dome.
	if (up > 0.008 && cloud_amount > 0.002) {
		float dist = cloud_height / up;
		vec2 base_uv = (dir.xz * dist) * cloud_scale + wind_dir * TIME * wind_speed * cloud_scale;

		// Density once, then a short walk toward the sun for self-shadowing. The
		// deck is optically thick and close to flat, so marching through its
		// depth adds almost nothing that a light-direction gradient does not.
		float acc = coverage(base_uv, TIME * 0.05);
		int steps = clamp(cloud_steps / 4, 1, 4);
		float lit = 0.0;
		for (int i = 1; i <= 4; i++) {
			if (i > steps) { break; }
			lit += coverage(base_uv + sun_dir.xz * float(i) * 0.22, TIME * 0.05);
		}
		lit /= float(steps);
		float alpha = clamp(acc * cloud_density, 0.0, 1.0);
		// Fade the deck into the horizon so it does not end in a hard line.
		alpha *= smoothstep(0.008, 0.14, up);

		// More cloud along the sun direction means less light reaching here.
		float shade = clamp(1.0 - lit * 0.85, 0.0, 1.0);
		vec3 cc = mix(cloud_dark, cloud_col, shade);
		// Silver lining: sun behind a thin edge.
		cc += sun_col * pow(max(cos_sun, 0.0), 8.0) * (1.0 - shade) * 0.6;
		col = mix(col, cc, alpha);

		// Thin cirrus veil above the cumulus.
		if (cirrus_amount > 0.002) {
			vec2 cu = (dir.xz * (cloud_height * 2.6 / up)) * cloud_scale * 0.45
				+ wind_dir * TIME * wind_speed * 0.4 * cloud_scale;
			float ci = fbm(cu * vec2(1.0, 3.4), 4);
			ci = smoothstep(0.52, 0.86, ci) * cirrus_amount;
			ci *= smoothstep(0.02, 0.30, up);
			col = mix(col, cloud_col * (0.86 + 0.14 * shade), ci * 0.55);
		}
	}

	// The disc goes on last so cloud never covers a blown-out sun edge oddly.
	col = mix(col, sun_col * 12.0 * limb, disc);

	COLOR = col * sky_energy;
}
