// bg_nebula.gdshader — MOONSEED v0.8
// GDD §17.3: Nebula table background (purchasable cosmetic)
shader_type canvas_item;

uniform float speed : hint_range(0.01, 0.5) = 0.04;
uniform vec4 color_a : source_color = vec4(0.05, 0.01, 0.18, 1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.22, 0.28, 1.0);
uniform vec4 color_c : source_color = vec4(0.18, 0.02, 0.35, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y);
}

void fragment() {
	vec2 uv = UV * 3.0 + vec2(TIME * speed, TIME * speed * 0.7);
	float n1 = noise(uv);
	float n2 = noise(uv * 2.1 + 1.7);
	float n  = n1 * 0.6 + n2 * 0.4;
	vec4 col = mix(color_a, mix(color_b, color_c, n2), n);
	// Starfield sparkle
	float star = step(0.985, hash(floor(UV * 180.0)));
	col.rgb += vec3(star * (0.5 + 0.5 * sin(TIME * 3.0 + UV.x * 50.0)));
	COLOR = col;
}
