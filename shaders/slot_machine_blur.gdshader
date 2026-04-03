shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float blur_speed : hint_range(0.0, 2.0) = 1.0;
uniform float blur_offset : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Apply horizontal blur effect for slot machine spin
	vec2 uv = UV;
	vec4 color = vec4(0.0);
	
	// Sample multiple points for blur
	int samples = int(blur_amount) + 1;
	for (int i = -samples; i <= samples; i++) {
		float offset = float(i) * blur_amount * 0.01;
		vec2 sample_uv = vec2(uv.x + offset, uv.y);
		color += texture(TEXTURE, sample_uv);
	}
	
	color /= float(samples * 2 + 1);
	
	// Add slight motion blur tint
	color.rgb = mix(color.rgb, vec3(1.0), 0.1 * blur_amount);
	
	COLOR = color;
}