// bg_aurora.gdshader — MOONSEED v0.8.1
// GDD §17.3: Aurora table background (purchasable cosmetic)
shader_type canvas_item;

uniform float speed : hint_range(0.01, 0.8) = 0.18;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float band1 = sin(uv.x * 5.0 + t * 1.2 + sin(uv.y * 3.0 + t)) * 0.5 + 0.5;
	float band2 = sin(uv.x * 8.0 - t * 0.7 + cos(uv.y * 2.0 + t * 1.5)) * 0.5 + 0.5;
	float band3 = sin(uv.x * 3.5 + t * 0.9) * 0.5 + 0.5;
	vec4 green  = vec4(0.0, band1 * 0.8, band1 * 0.4, 1.0);
	vec4 blue   = vec4(band2 * 0.1, band2 * 0.3, band2, 1.0);
	vec4 violet = vec4(band3 * 0.55, 0.0, band3 * 0.9, 1.0);
	vec4 bg     = vec4(0.01, 0.02, 0.08, 1.0);
	float mask  = smoothstep(0.0, 0.5, uv.y) * (1.0 - smoothstep(0.4, 1.0, uv.y));
	vec4 aurora = (green * 0.45 + blue * 0.35 + violet * 0.2) * mask;
	float star  = step(0.988, fract(sin(dot(floor(UV * 180.0), vec2(127.1, 311.7))) * 43758.5));
	COLOR = bg + aurora + vec4(vec3(star * 0.7), 0.0);
}
