// bg_ember.gdshader — MOONSEED v0.8
// GDD §17.3: Ember table background (purchasable cosmetic)
shader_type canvas_item;

uniform float speed : hint_range(0.01, 1.0) = 0.15;
uniform vec4 color_hot  : source_color = vec4(1.0, 0.35, 0.0, 1.0);
uniform vec4 color_cool : source_color = vec4(0.12, 0.03, 0.0, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(17.3, 41.7))) * 4375.85); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	vec2 uv = UV * 4.0 + vec2(0.0, -TIME * speed);
	float n = noise(uv) * 0.55 + noise(uv * 2.0 + 1.3) * 0.35 + noise(uv * 4.5 + 2.7) * 0.1;
	n = pow(n, 1.4);
	vec4 col = mix(color_cool, color_hot, n);
	// Embers: bright sparks drifting up
	vec2 em_uv = UV * 40.0 + vec2(sin(TIME + UV.y * 5.0) * 0.3, -TIME * 0.9);
	float ember = step(0.97, hash(floor(em_uv)));
	col.rgb += vec3(ember * n * 2.0, ember * n * 0.5, 0.0);
	COLOR = col;
}
