// bg_void.gdshader — MOONSEED v0.8.1
// GDD §17.3: Void table background (purchasable cosmetic)
shader_type canvas_item;

uniform float speed : hint_range(0.001, 0.3) = 0.03;
uniform vec4 color_void  : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_rift  : source_color = vec4(0.08, 0.0, 0.2, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(73.1, 157.3))) * 43758.5); }

void fragment() {
	vec2 uv = UV * 5.0 + vec2(TIME * speed, -TIME * speed * 0.4);
	float n1 = hash(floor(uv * 2.0));
	float n2 = hash(floor(uv * 4.5 + 1.3));
	float rift = pow(max(0.0, sin(uv.x * 8.0 + TIME * 0.5) * sin(uv.y * 6.0 - TIME * 0.3)), 3.0);
	vec4 col = mix(color_void, color_rift, rift * 0.7 + n1 * 0.1);
	// White energy tendrils
	float tendr = step(0.97, n2);
	col.rgb += vec3(tendr * rift * 3.0);
	// Stars
	float star = step(0.992, hash(floor(UV * 220.0)));
	col.rgb += vec3(star * 0.8);
	COLOR = col;
}
