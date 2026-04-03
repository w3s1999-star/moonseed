// button_shimmer.gdshader — Light sweep across button borders
// Applied as material to buttons; driven by progress uniform (0→1)
shader_type canvas_item;
render_mode blend_add;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer_width : hint_range(0.05, 0.5) = 0.15;
uniform float shimmer_angle : hint_range(-1.0, 1.0) = 0.4;
uniform float shimmer_intensity : hint_range(0.0, 0.3) = 0.10;
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// Create diagonal UV coordinate for the sweep
	float diagonal = UV.x * shimmer_angle + UV.y * (1.0 - shimmer_angle);
	
	// Position of the shimmer band (moves from -width to 1+width over progress)
	float band_center = mix(-shimmer_width, 1.0 + shimmer_width, progress);
	
	// Distance from the band center
	float dist = abs(diagonal - band_center);
	
	// Soft-edged band using smoothstep
	float band = 1.0 - smoothstep(0.0, shimmer_width, dist);
	
	// Fade in/out at the edges of the sweep for polish
	float edge_fade = smoothstep(0.0, 0.15, progress) * smoothstep(1.0, 0.85, progress);
	
	// Final shimmer contribution
	float shimmer = band * shimmer_intensity * edge_fade;
	
	COLOR = vec4(shimmer_color.rgb * shimmer, shimmer);
}