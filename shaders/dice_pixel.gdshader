// dice_pixel.gdshader
// Applied to the SubViewportContainer that renders the 3D dice scene.
// pixel_count is set dynamically from DiceTableArea.gd whenever
// PIXEL_COLS / PIXEL_ROWS constants change.
shader_type canvas_item;

uniform vec2 pixel_count = vec2(150.0, 150.0);

void fragment() {
	vec2 uv  = UV * pixel_count;
	uv       = floor(uv) + 0.5;
	uv      /= pixel_count;
	COLOR    = texture(TEXTURE, uv);
}
