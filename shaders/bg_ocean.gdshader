// bg_ocean.gdshader — MOONSEED v0.8
// GDD §17.3: Ocean table background (purchasable cosmetic)
shader_type canvas_item;

uniform float speed : hint_range(0.01, 1.0) = 0.2;
uniform vec4 color_deep : source_color = vec4(0.0, 0.08, 0.22, 1.0);
uniform vec4 color_surf : source_color = vec4(0.0, 0.45, 0.65, 1.0);

void fragment() {
	float wave1 = sin(UV.x * 12.0 + TIME * speed * 2.0) * 0.025;
	float wave2 = sin(UV.x * 7.0  - TIME * speed * 1.3 + 1.0) * 0.015;
	float wave3 = sin(UV.x * 20.0 + TIME * speed * 3.0 + 2.5) * 0.008;
	float depth = UV.y + wave1 + wave2 + wave3;
	vec4 col = mix(color_surf, color_deep, smoothstep(0.3, 0.8, depth));
	// Caustics shimmer
	float shimmer = sin(UV.x * 30.0 + TIME + wave1 * 40.0) * sin(UV.y * 25.0 - TIME * 1.1);
	col.rgb += vec3(0.0, shimmer * 0.04, shimmer * 0.06) * (1.0 - depth);
	COLOR = col;
}
