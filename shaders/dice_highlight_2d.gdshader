// dice_highlight_2d.gdshader
// Canvas-item port of dice_score_highlight.gdshader (which is shader_type spatial
// and therefore incompatible with 2-D sprite nodes).
//
// Apply to: FaceHighlight child node inside DiceBase.tscn
//   Node types: Sprite2D  |  AnimatedSprite2D  |  ColorRect
//
// Driven by dice_base.gd during explosion:
//   ShaderMaterial.set_shader_parameter("progress", 0.0..1.0)
//   ShaderMaterial.set_shader_parameter("alpha",    0.0..1.0)
//
// Visual: a gold/yellow ring expands from the die face centre outward,
// with a shrinking inner glow fill — identical algorithm to the spatial
// version, rewritten for the canvas_item pipeline.
//
// Drop-in replacement path: res://shaders/dice_highlight_2d.gdshader

shader_type canvas_item;
render_mode blend_add;

// Warm gold — matches explosion energy
uniform vec4  highlight_color : source_color = vec4(1.0, 0.88, 0.15, 1.0);

// 0 → 1 : ring travels from face centre to beyond the die edge
uniform float progress   : hint_range(0.0, 1.0) = 0.0;

// Master opacity envelope — tween 0 → 1 → 0 from GDScript
uniform float alpha      : hint_range(0.0, 1.0) = 1.0;

// Thickness of the expanding ring in UV space
uniform float ring_width : hint_range(0.01, 0.35) = 0.10;

void fragment() {
	// Re-centre UV: 0..1 → -1..1
	vec2  c    = UV * 2.0 - 1.0;
	float dist = length(c);

	// Ring position expands to 1.5 so it sweeps past the die edge
	float ring_pos = progress * 1.5;
	float ring     = 1.0 - smoothstep(0.0, ring_width, abs(dist - ring_pos));

	// Solid inner fill that collapses as the ring expands
	float fill     = (1.0 - progress) * 0.45
	               * smoothstep(0.0, 0.15, 1.0 - dist);

	float combined = clamp(ring + fill, 0.0, 1.0);

	// blend_add: output is ADDED to what's already drawn beneath.
	// Keep base sprite visible by multiplying it in, then add the glow.
	vec4 base  = texture(TEXTURE, UV);
	float glow = combined * alpha;

	// Mix base pixel with highlight, then let blend_add layer it over the die.
	COLOR = mix(base, highlight_color, glow) * glow;
}
