shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.96, 0.91, 0.72, 1.0);
uniform vec4 shaded_color : source_color = vec4(0.03, 0.05, 0.10, 1.0);
uniform float phase_pos : hint_range(0.0, 1.0, 0.001) = 0.5;
uniform float dist : hint_range(0.0, 240.0, 0.01) = 240.0;
uniform sampler2D noise_texture;
uniform float roughness : hint_range(0.0, 4.0, 0.01) = 1.63;

const float TAU_F = 6.28318530718;

void fragment() {
	vec2 uv = 2.0 * (UV - vec2(0.5));
	float uv_len = length(uv);
	float height = (texture(noise_texture, UV).r - 0.5) * roughness;
	vec3 sphere_point = vec3(uv.x + height, uv.y, sqrt(max(0.0, 1.0 - dot(uv, uv))));
	float phase_angle = phase_pos * TAU_F;
	vec3 light_point = dist * vec3(sin(phase_angle), uv.y / dist, -cos(phase_angle));
	float dot_val = dot(sphere_point, (light_point - sphere_point) / length(light_point - sphere_point));
	float val = smoothstep(-0.05, 0.0, dot_val);

	COLOR = mix(shaded_color, color, val);
	COLOR.a *= 1.0 - smoothstep(0.98, 1.0, uv_len);
}