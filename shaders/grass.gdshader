// grass.gdshader — MOONSEED v0.8
// GDD §17.3: Animated grass movement for the Garden background.
shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.2;
uniform float strength : hint_range(0.0, 0.1) = 0.025;
uniform float wave_freq : hint_range(1.0, 20.0) = 6.0;

// obstacles to push grass away (world XZ coords)
uniform int obstacle_count : hint_range(0,32) = 0;
uniform vec2 obstacles[32];
uniform float obstacle_radius : hint_range(0.0,3.0) = 1.2;
uniform float obstacle_strength : hint_range(0.0,2.0) = 0.2;

void vertex() {
	// Sway only the top portion of each grass sprite (UV.y < 0.5)
	float sway_mask = max(0.0, 0.5 - UV.y) * 2.0;
	float t = TIME * speed;
	VERTEX.x += sin(t + VERTEX.y * wave_freq) * strength * sway_mask * 60.0;
	// obstacle avoidance / bowing
	vec2 pos = VERTEX.xz;
	for (int i = 0; i < obstacle_count; i++) {
		vec2 diff = pos - obstacles[i];
		float d = length(diff);
		if (d < obstacle_radius && d > 0.001) {
			vec2 dir = diff / d;
			float factor = (1.0 - d / obstacle_radius) * obstacle_strength;
			VERTEX.x += dir.x * factor;
			VERTEX.z += dir.y * factor;
		}
	}
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
