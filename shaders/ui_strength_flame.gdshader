shader_type canvas_item;

// Procedural UI flame for label glow (fire + sparks + smoke) with no textures.
// Tuned for small UI regions such as score bar labels.

uniform float speed : hint_range(0.1, 5.0) = 1.25;
uniform float pixel_size : hint_range(0.001, 0.1) = 0.012;
uniform float effect_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float flicker_strength : hint_range(0.0, 0.5) = 0.18;

uniform vec3 from_color : source_color = vec3(0.20, 0.70, 1.00);
uniform vec3 to_color : source_color = vec3(0.02, 0.22, 0.64);
uniform vec3 spark_color : source_color = vec3(0.68, 0.88, 1.00);
uniform vec3 smoke_color : source_color = vec3(0.05, 0.09, 0.16);

uniform int particle_count : hint_range(16, 160) = 72;
uniform float brightness : hint_range(0.0001, 0.02) = 0.0025;
uniform float fire_shift : hint_range(0.0, 0.6) = 0.22;
uniform float fire_shift_frequency : hint_range(1.0, 12.0) = 6.4;
uniform vec2 flame_size = vec2(0.34, 0.92);
uniform vec2 glow = vec2(0.001, 0.08);

uniform int spark_count : hint_range(1, 48) = 14;
uniform float spark_size : hint_range(0.0005, 0.01) = 0.0032;
uniform float spark_speed : hint_range(0.1, 4.0) = 1.6;

uniform int smoke_count : hint_range(4, 36) = 10;
uniform float smoke_size : hint_range(0.001, 0.08) = 0.03;
uniform float smoke_drift : hint_range(0.0, 0.6) = 0.16;
uniform float wind_force : hint_range(-0.5, 0.5) = 0.0;

uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float saturation_factor : hint_range(0.0, 2.0) = 1.2;
uniform float aspect_ratio : hint_range(0.01, 5.0) = 1.0;
uniform vec2 pos_offset = vec2(0.0, -0.58);
uniform float strength_boost : hint_range(1.0, 4.0) = 1.0;

float hash1(float t) {
	return fract(cos(t * 124.97) * 248.842) - 0.5;
}

float sat(float x) {
	return clamp(x, 0.0, 1.0);
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.w - q.y) / (6.0 * d + e) + q.z, d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.w);
	return c.z * mix(K.xxx, clamp(p - K.x, 0.0, 1.0), c.y);
}

vec3 simulate_fire(vec2 uv, float t) {
	vec3 res = vec3(0.0);
	const int MAX_FIRE = 160;
	for (int i = 0; i < MAX_FIRE; i++) {
		if (i >= particle_count) {
			break;
		}
		float fi = float(i);
		float ct = fract(t + (fi + 1.0) / float(max(particle_count, 1)));
		float seed = hash1((fi + 1.0) * (t - ct));
		vec2 dir = vec2(wind_force, flame_size.y);
		dir.x += (cos(t * seed) * sin(ct * fire_shift_frequency)) * mix(0.0, fire_shift, log(max(ct, 0.02)));
		float cb = sat(mix(brightness, 0.0, ct));
		vec2 off = vec2(seed * flame_size.x, 0.0);
		float d = length(uv - off - (dir * ct));
		res += mix(from_color * abs(seed), to_color, ct) * smoothstep(glow.x, glow.y, cb / max(d, 0.0001));
	}
	return res;
}

vec3 simulate_sparks(vec2 uv, float t) {
	vec3 spark_res = vec3(0.0);
	const int MAX_SPARKS = 48;
	t *= spark_speed;
	for (int i = 0; i < MAX_SPARKS; i++) {
		if (i >= spark_count) {
			break;
		}
		float id = (float(i) + 1.0) * 133.0;
		float ct = fract(t + id / 100.0);
		float seed = hash1(id);
		vec2 dir = vec2(seed * 0.36 + wind_force * 2.0, flame_size.y * 2.2);
		vec2 center = vec2(seed * flame_size.x * 0.22, 0.0) + (dir * ct);
		float dist = length(uv - center);
		float influence = sat(1.0 - dist / (spark_size * 5.0));
		float sharp = pow(influence, 14.0);
		float life = sat(1.0 - ct * 1.9);
		spark_res += spark_color * sharp * life * 55.0;
	}
	return spark_res;
}

vec3 simulate_smoke(vec2 uv, float t) {
	vec3 smoke_res = vec3(0.0);
	const int MAX_SMOKE = 36;
	for (int i = 0; i < MAX_SMOKE; i++) {
		if (i >= smoke_count) {
			break;
		}
		float id = (float(i) + 1.0) * 111.0;
		float ct = fract(t * 0.48 + id / 100.0);
		float seed = hash1(id);
		vec2 dir = vec2(seed * smoke_drift + wind_force * 0.7, flame_size.y * 1.35);
		float cb = sat(mix(brightness * 9.0, 0.0, ct * 1.45));
		vec2 off = vec2(seed * flame_size.x * 0.42, flame_size.y * 0.58);
		smoke_res += smoke_color * smoothstep(smoke_size, smoke_size * 2.0, cb / max(length(uv - off - (dir * ct)), 0.0001));
	}
	return smoke_res;
}

void fragment() {
	// For UI text, COLOR already contains the glyph alpha and modulated label color.
	// Relying on COLOR avoids explicit TEXTURE sampling, which can fail for this label path.
	vec4 base = COLOR;

	vec2 p = UV * 2.0 - 1.0;
	p.x *= aspect_ratio;
	p.y *= -1.0;
	p -= pos_offset;
	vec2 pixelated = floor(p / pixel_size) * pixel_size;

	float t = (TIME + 23.0) * speed;
	vec3 fire_col = simulate_fire(pixelated, t);
	vec3 spark_col = simulate_sparks(pixelated, t);
	vec3 smoke_col = simulate_smoke(pixelated, t);
	vec3 flame_col = fire_col + spark_col + smoke_col;

	vec3 hsv = rgb_to_hsv(flame_col);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * saturation_factor, 0.0, 1.0);
	flame_col = hsv_to_rgb(hsv);

	float flick = (hash1((TIME + 5.0) * 6.0) + 0.5) * flicker_strength;
	flame_col *= (1.0 + flick) * strength_boost;

	float intensity = max(max(flame_col.r, flame_col.g), flame_col.b);
	float flame_alpha = smoothstep(0.01, 0.56, intensity);

	float mask = smoothstep(0.02, 0.35, base.a);
	float fx = effect_alpha * mask * flame_alpha;

	vec3 out_rgb = base.rgb + flame_col * fx;
	float out_a = max(base.a, fx * 0.85);
	COLOR = vec4(out_rgb, out_a);
}
