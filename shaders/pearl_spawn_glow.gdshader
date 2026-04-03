// Simple radial spawn-glow for Moonpearls.
// blend_add: renders purely additive so it glows behind the pearl.
// No uniforms — alpha is driven by the ColorRect's modulate.a from GDScript.
shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float d    = length(UV - vec2(0.5)) * 2.0;   // 0 at centre → 1 at edge
	float glow = pow(max(0.0, 1.0 - d), 2.5);
	// Soft pearl-white with a faint cool tint
	COLOR = vec4(0.82, 0.91, 1.0, glow);
}
