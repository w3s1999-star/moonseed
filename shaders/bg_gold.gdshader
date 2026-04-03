// bg_gold.gdshader — MOONSEED v0.8.1
// GDD §17.3: Gold table background (purchasable cosmetic)
shader_type canvas_item;

uniform float speed : hint_range(0.01, 0.5) = 0.08;
uniform vec4 color_gold  : source_color = vec4(0.72, 0.55, 0.0, 1.0);
uniform vec4 color_dark  : source_color = vec4(0.15, 0.09, 0.0, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	vec2 uv = UV * 3.0 + vec2(TIME * speed, TIME * speed * 0.3);
	float n = noise(uv) * 0.6 + noise(uv * 3.0 + 0.7) * 0.3 + noise(uv * 7.0 + 1.4) * 0.1;
	vec4 col = mix(color_dark, color_gold, pow(n, 1.8));
	// Gilded sparkle grid
	float grid_x = abs(fract(UV.x * 16.0 + TIME * speed * 2.0) - 0.5);
	float grid_y = abs(fract(UV.y * 10.0 + TIME * speed * 1.3) - 0.5);
	float grid   = step(0.46, grid_x) * step(0.46, grid_y);
	col.rgb += vec3(grid * n * 0.5, grid * n * 0.4, 0.0);
	COLOR = col;
}
