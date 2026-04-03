/*
Pixelated God Rays Shader — Garden Day/Night
Modified from:
  godotshaders.com/shader/god-rays
  godotshaders.com/shader/god-rays-2d-godot-v4-4-1/
  godotshaders.com/shader/pixelated-god-rays/

Uses a seamless NoiseTexture2D (set noiseTex uniform) to eliminate boundary
lines. Set noiseTex/noise/frequency ~0.5 and enable seamless on the resource.
Requires a real texture on the TextureRect (e.g. GradientTexture2D).
*/
shader_type canvas_item;
render_mode unshaded;

uniform int blend_mode : hint_enum(
	"Screen:0","Hard Light:1","Soft Light:2","Clamp:3","Negative:4",
	"Multiply:5","Darken:6","Lighten:7","Difference:8","Exclusion:9"
) = 0;

uniform sampler2D noiseTex;

uniform float angle    = -0.3;
uniform float position = -0.2;
uniform float spread        : hint_range(0.0, 1.0)  = 0.5;
uniform float cutoff        : hint_range(-1.0, 1.0) = 0.1;
uniform float falloff       : hint_range(0.0, 1.0)  = 0.2;
uniform float edge_fade     : hint_range(0.0, 1.0)  = 0.15;
uniform float speed         = 1.0;
uniform float ray1_density  = 8.0;
uniform float ray2_density  = 30.0;
uniform float ray2_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4  ray_color : source_color = vec4(1.0, 0.9, 0.65, 0.8);
uniform bool  hdr       = false;
uniform float seed      = 5.0;

// Pixelation
uniform float pixelSizeScale    : hint_range(1.0, 16.0) = 2.0;
uniform bool  quantize_colors   = true;
uniform int   color_levels      : hint_range(2, 16) = 6;
uniform bool  dither            = false;
uniform float dither_strength   : hint_range(0.0, 1.0) = 0.5;
uniform float opacity           : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// ── Noise ──────────────────────────────────────────────────────
float noise(in vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 ts = vec2(textureSize(noiseTex, 0));
	float a = texture(noiseTex, (i + vec2(0.5, 0.5)) / ts).r;
	float b = texture(noiseTex, (i + vec2(1.5, 0.5)) / ts).r;
	float c = texture(noiseTex, (i + vec2(0.5, 1.5)) / ts).r;
	float d = texture(noiseTex, (i + vec2(1.5, 1.5)) / ts).r;
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

mat2 rotate(float _angle) {
	return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

// ── Blend modes ────────────────────────────────────────────────
vec3 blend_screen(vec3 base, vec3 blend)      { return 1.0 - (1.0 - base) * (1.0 - blend); }
vec3 blend_hard_light(vec3 base, vec3 blend)  { return mix(2.0*base*blend, 1.0-2.0*(1.0-base)*(1.0-blend), step(0.5,blend)); }
vec3 blend_soft_light(vec3 base, vec3 blend) {
	vec3 r;
	r.r = (blend.r<0.5) ? (2.0*base.r*blend.r+base.r*base.r*(1.0-2.0*blend.r)) : (sqrt(base.r)*(2.0*blend.r-1.0)+2.0*base.r*(1.0-blend.r));
	r.g = (blend.g<0.5) ? (2.0*base.g*blend.g+base.g*base.g*(1.0-2.0*blend.g)) : (sqrt(base.g)*(2.0*blend.g-1.0)+2.0*base.g*(1.0-blend.g));
	r.b = (blend.b<0.5) ? (2.0*base.b*blend.b+base.b*base.b*(1.0-2.0*blend.b)) : (sqrt(base.b)*(2.0*blend.b-1.0)+2.0*base.b*(1.0-blend.b));
	return r;
}
vec3 blend_clamp_mode(vec3 base, vec3 blend)  { return clamp(base, 0.0, 1.0); }
vec3 blend_negative(vec3 base, vec3 blend)    { return 1.0 - base; }
vec3 blend_multiply(vec3 base, vec3 blend)    { return base * blend; }
vec3 blend_darken(vec3 base, vec3 blend)      { return min(base, blend); }
vec3 blend_lighten(vec3 base, vec3 blend)     { return max(base, blend); }
vec3 blend_difference(vec3 base, vec3 blend)  { return abs(base - blend); }
vec3 blend_exclusion(vec3 base, vec3 blend)   { return base + blend - 2.0 * base * blend; }

// ── Utility ────────────────────────────────────────────────────
vec2 pixelate_uv(vec2 uv, vec2 psize)         { return floor(uv / psize) * psize; }
vec3 quantize_color(vec3 col, int levels)      { return floor(col * float(levels)) / float(levels); }
float dither_pattern(vec2 uv)                 { vec2 g = floor(uv * 4.0); return mod(g.x + g.y, 2.0); }

// ── Fragment ───────────────────────────────────────────────────
void fragment() {
	vec2 pix_uv        = pixelate_uv(UV,        TEXTURE_PIXEL_SIZE  * pixelSizeScale);
	vec2 screen_pix_uv = pixelate_uv(SCREEN_UV, SCREEN_PIXEL_SIZE   * pixelSizeScale);

	vec2 tuv = (rotate(angle) * (pix_uv - position)) / ((pix_uv.y + spread) - (pix_uv.y * spread));

	vec2 ray1 = vec2(tuv.x * ray1_density + sin(TIME * 0.1 * speed) * (ray1_density * 0.2) + seed, 1.0);
	vec2 ray2 = vec2(tuv.x * ray2_density + sin(TIME * 0.2 * speed) * (ray1_density * 0.2) + seed, 1.0);

	float cut = step(cutoff, tuv.x) * step(cutoff, 1.0 - tuv.x);
	ray1 *= cut;
	ray2 *= cut;

	float rays;
	if (hdr) {
		rays = noise(ray1) + (noise(ray2) * ray2_intensity);
	} else {
		rays = clamp(noise(ray1) + (noise(ray2) * ray2_intensity), 0.0, 1.0);
	}

	rays *= smoothstep(0.0,          falloff,           1.0 - pix_uv.y);
	rays *= smoothstep(0.0 + cutoff, edge_fade + cutoff, tuv.x);
	rays *= smoothstep(0.0 + cutoff, edge_fade + cutoff, 1.0 - tuv.x);

	if (dither) {
		float dn = dither_pattern(UV / TEXTURE_PIXEL_SIZE) * dither_strength;
		rays = clamp(rays + (dn - 0.5) * 0.1, 0.0, 1.0);
	}

	vec3 shine = vec3(rays) * ray_color.rgb;
	if (quantize_colors) {
		shine = quantize_color(shine, color_levels);
	}

	vec4 screen_color = texture(SCREEN_TEXTURE, screen_pix_uv);
	if (quantize_colors) {
		screen_color.rgb = quantize_color(screen_color.rgb, color_levels);
	}

	vec3 sc = screen_color.rgb;
	vec3 blended;
	if      (blend_mode == 0) { blended = blend_screen(sc,      ray_color.rgb); }
	else if (blend_mode == 1) { blended = blend_hard_light(sc,  ray_color.rgb); }
	else if (blend_mode == 2) { blended = blend_soft_light(sc,  ray_color.rgb); }
	else if (blend_mode == 3) { blended = blend_clamp_mode(sc,  ray_color.rgb); }
	else if (blend_mode == 4) { blended = blend_negative(sc,    ray_color.rgb); }
	else if (blend_mode == 5) { blended = blend_multiply(sc,    ray_color.rgb); }
	else if (blend_mode == 6) { blended = blend_darken(sc,      ray_color.rgb); }
	else if (blend_mode == 7) { blended = blend_lighten(sc,     ray_color.rgb); }
	else if (blend_mode == 8) { blended = blend_difference(sc,  ray_color.rgb); }
	else if (blend_mode == 9) { blended = blend_exclusion(sc,   ray_color.rgb); }
	else                      { blended = sc; }

	shine = blended;

	float final_alpha = rays * ray_color.a;
	if (quantize_colors) {
		final_alpha = floor(final_alpha * float(color_levels)) / float(color_levels);
	}
	final_alpha *= opacity;

	COLOR = vec4(shine, final_alpha);
}
