shader_type canvas_item;

uniform vec2 pixelation = vec2(96.0, 96.0);
uniform sampler2D cloud_noise1;
uniform vec2 scroll_speed1 = vec2(0.016, 0.005);
uniform sampler2D cloud_noise2;
uniform vec2 scroll_speed2 = vec2(-0.011, -0.003);
uniform float noise_strength : hint_range(0.0, 3.0, 0.01) = 1.0;
uniform vec2 center_pos = vec2(0.5, 0.5);
uniform float position_impact : hint_range(0.0, 1.0, 0.01) = 0.60;
uniform float center_focus : hint_range(0.1, 5.0, 0.1) = 1.0;
uniform sampler2D color_gradient;

void fragment() {
	vec2 pixel_uv = floor(UV * pixelation) / pixelation;
	vec2 noise_uv_scale = pixel_uv;
	noise_uv_scale.x *= pixelation.x / pixelation.y;
	vec2 noise1uv = fract(noise_uv_scale + TIME * scroll_speed1);
	vec2 noise2uv = fract(noise_uv_scale + TIME * scroll_speed2);
	vec4 noise_col = (texture(cloud_noise1, noise1uv) + texture(cloud_noise2, noise2uv)) * 0.5;
	float dist = distance(pixel_uv, center_pos);
	vec2 furthest = vec2(-min(sign(center_pos.x - 0.5), 0.0), -min(sign(center_pos.y - 0.5), 0.0));
	float max_dist = distance(center_pos, furthest);
	dist /= max(max_dist, 0.001);
	// Pull the fog falloff inward: raising dist to a power >1 concentrates fog nearer the center
	dist = pow(dist, center_focus);
	float noise = noise_col.r * noise_strength;
	float final_v = mix(1.0 - noise, dist, position_impact);
	final_v = clamp(final_v, 0.0, 1.0);
	COLOR = texture(color_gradient, vec2(final_v, final_v));
}
