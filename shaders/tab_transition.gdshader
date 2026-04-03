shader_type canvas_item;

// License: CC0 | Author: Ultipuk | https://ultipuk.xyz
// Modified for USE_CLOSING (wipe in then wipe out)

#define USE_CLOSING

uniform float progress: hint_range(0.0, 1.0) = 0.0;
uniform float width: hint_range(0.0, 1.0) = 0.4;
uniform sampler2D tile_texture: source_color, repeat_enable;
uniform float tile_pixel_size = 36.0;
uniform float tile_grown_scale: hint_range(0.0, 16.0) = 2.5;
uniform sampler2D transition_texture;

void fragment() {
	vec2 tile_uv = vec2(
		fract(FRAGCOORD.x / tile_pixel_size),
		fract(FRAGCOORD.y / tile_pixel_size)
	);
	vec2 transition_uv = UV;

#ifdef USE_CLOSING
	float part;
	float transition;
	if (progress > 0.5) {
		part = (1.0 - (progress - 0.5) * 2.0) * (1.0 + 2.0 * width) - width;
		transition = 1.0 - texture(transition_texture, transition_uv).r;
	} else {
		part = 2.0 * progress * (1.0 + 2.0 * width) - width;
		transition = texture(transition_texture, transition_uv).r;
	}
#else
	float part = progress * (1.0 + 2.0 * width) - width;
	float transition = texture(transition_texture, transition_uv).r;
#endif

	float window = max(0.0, min(1.0, width + (part - transition) / max(width, 0.001)));
	tile_uv = tile_uv * 2.0 - 1.0;
	tile_uv /= max(window * tile_grown_scale, 0.001);
	tile_uv = (tile_uv + 1.0) * 0.5;
	vec4 tile = texture(tile_texture, tile_uv);
	COLOR *= tile;
}
