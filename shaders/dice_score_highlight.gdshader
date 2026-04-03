// dice_score_highlight.gdshader
// Spatial shader applied to the FaceHighlight mesh when a die scores.
// Draws an expanding annular ring + inner fill that fades outward.
// Colour, progress and alpha are all driven by Tweens in GDScript.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

// Set from GDScript to GameData.ACCENT_BLUE (starchunk teal)
uniform vec4  highlight_color : source_color = vec4(0.04, 0.62, 0.66, 1.0);

// 0 → 1: ripple travels from face centre outward
uniform float progress  : hint_range(0.0, 1.0) = 0.0;

// Master opacity envelope — tween 0 → 1 → 0
uniform float alpha     : hint_range(0.0, 1.0) = 1.0;

// Thickness of the expanding ring in UV space
uniform float ring_width : hint_range(0.01, 0.35) = 0.08;

void fragment() {
	// Centre UV on face (0..1 → -1..1)
	vec2  c    = UV * 2.0 - 1.0;
	float dist = length(c);

	// Ring expands from 0 → ~1.5 so it sweeps past the die edge
	float ring_pos = progress * 1.5;
	float ring     = 1.0 - smoothstep(0.0, ring_width, abs(dist - ring_pos));

	// Solid inner glow that shrinks as ring expands
	float fill     = (1.0 - progress) * 0.3 * smoothstep(0.0, 0.12, 1.0 - dist);

	float combined = clamp(ring + fill, 0.0, 1.0);

	ALBEDO = highlight_color.rgb;
	ALPHA  = combined * alpha * highlight_color.a;
}
