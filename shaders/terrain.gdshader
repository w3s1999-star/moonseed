shader_type canvas_item;

uniform int pixel_amount = 100;
uniform float deepSeaThreshold : hint_range(0.0, 1.0) = 0.38;
uniform float seaThreshold : hint_range(0.0, 1.0) = 0.44;
uniform float shallowSeaThreshold : hint_range(0.0, 1.0) = 0.50;
uniform float sandThreshold : hint_range(0.0, 1.0) = 0.535;
uniform float grassThreshold : hint_range(0.0, 1.0) = 0.60;
uniform float forestThreshold : hint_range(0.0, 1.0) = 0.66;
uniform float mountainThreshold : hint_range(0.0, 1.0) = 0.73;
uniform float snowThreshold : hint_range(0.0, 1.0) = 0.90;

uniform vec4 DEEP_SEA : source_color    = vec4(0.06, 0.14, 0.24, 1.0);
uniform vec4 SEA : source_color         = vec4(0.09, 0.22, 0.38, 1.0);
uniform vec4 SHALLOW_SEA : source_color = vec4(0.14, 0.34, 0.50, 1.0);
uniform vec4 SAND : source_color        = vec4(0.52, 0.48, 0.28, 1.0);
uniform vec4 GRASS : source_color       = vec4(0.20, 0.42, 0.16, 1.0);
uniform vec4 FOREST : source_color      = vec4(0.12, 0.28, 0.10, 1.0);
uniform vec4 MOUNTAIN : source_color    = vec4(0.32, 0.32, 0.28, 1.0);
uniform vec4 SNOW : source_color        = vec4(0.85, 0.90, 0.92, 1.0);

void fragment() {
	vec2 grid_uv = round(UV * float(pixel_amount)) / float(pixel_amount);
	vec4 c = texture(TEXTURE, grid_uv);
	if      (c.r < deepSeaThreshold)    COLOR = DEEP_SEA;
	else if (c.r < seaThreshold)        COLOR = SEA;
	else if (c.r < shallowSeaThreshold) COLOR = SHALLOW_SEA;
	else if (c.r < sandThreshold)       COLOR = SAND;
	else if (c.r < grassThreshold)      COLOR = GRASS;
	else if (c.r < forestThreshold)     COLOR = FOREST;
	else if (c.r < mountainThreshold)   COLOR = MOUNTAIN;
	else                                COLOR = SNOW;
}
