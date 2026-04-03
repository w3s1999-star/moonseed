shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// ── Sprite atlas ────────────────────────────────────────────────
uniform sampler2D shape_atlas    : filter_nearest, repeat_disable;
uniform sampler2D shape_texture  : filter_nearest, repeat_disable;
uniform bool      use_atlas      = false;
uniform int       atlas_cols     = 3;
uniform int       atlas_rows     = 2;
uniform bool      use_sprite_color = false;

// ── Wind ────────────────────────────────────────────────────────
//   Based on: VERTEX.x += wind.x * max(0.0, (1-UV.y) - heightOffset)
//   Wind vector is driven by layered sine noise (OpenSimplex-style).
uniform float wind_speed     : hint_range(0.0, 5.0)  = 1.0;
uniform float wind_strength  : hint_range(0.0, 2.0)  = 0.28;
uniform vec2  wind_direction                          = vec2(1.0, 0.3);
uniform float height_offset  : hint_range(0.0, 1.0)  = 0.08;  // root lock

// ── Mouse interaction ───────────────────────────────────────────
uniform vec2  mouse_world_xz                          = vec2(0.0, 0.0);
uniform float mouse_brush_radius : hint_range(0.1, 10.0) = 3.0;
uniform vec2  mouse_influence                         = vec2(0.0, 0.0);

// ── Colors ──────────────────────────────────────────────────────
uniform sampler2D noise_texture;
uniform sampler2D color_gradient;
uniform float     random_variation : hint_range(0.0, 1.0, 0.001) = 0.06;

// ── Transparency ────────────────────────────────────────────────
uniform float alpha_cut_start : hint_range(0.0, 1.0, 0.05) = 0.1;
uniform float alpha_cut_end   : hint_range(0.0, 1.0, 0.05) = 0.9;
// 0=Smooth  1=Dithered  2=Hard-cut
uniform int   alpha_mode : hint_enum("Smooth", "Dithered", "Cut") = 1;

// ── Shadow pass ─────────────────────────────────────────────────
// Set true on a second MultiMesh to draw a soft drop shadow.
uniform bool  is_shadow_pass                          = false;
uniform float shadow_opacity : hint_range(0.0, 1.0)  = 0.35;
uniform vec3  shadow_color                            = vec3(0.0, 0.05, 0.02);
// Shadow squash + shift (light direction projection on ground)
uniform vec2  shadow_world_offset                     = vec2(0.18, 0.12);
uniform float shadow_squash   : hint_range(0.0, 1.0) = 0.22;

varying flat int  inst_id;
varying     vec3  world_pos;

// ── Helpers ──────────────────────────────────────────────────────

vec2 sprite_atlas_uv(vec2 uv, int index, int cols, int rows) {
	int i   = index % (cols * rows);
	float c = float(i % cols);
	float r = float(i / cols);
	vec2 ts = vec2(1.0 / float(cols), 1.0 / float(rows));
	return uv * ts + vec2(c, r) * ts;
}

float rnd(int idx, int seed) {
	return fract(sin(float(idx * 127 + seed * 311)) * 43758.5453);
}

// Layered sine noise – smooth, spatially-varying, no texture needed.
// Mimics OpenSimplex: combines three sine waves at different freq/phase.
float simplex_wind(vec2 xz, float t) {
	float a = sin(xz.x * 0.31 + xz.y * 0.17 + t * 1.00) * 0.50;
	float b = sin(xz.x * 0.73 - xz.y * 0.59 + t * 0.70) * 0.30;
	float c = sin(xz.x * 0.19 + xz.y * 0.83 + t * 1.40) * 0.20;
	return a + b + c;   // range ≈ –1 … +1
}

// Bayer 4×4 ordered dither
float bayer4(vec2 fc) {
	int x = int(fc.x) % 4;
	int y = int(fc.y) % 4;
	int idx = x + y * 4;
	// 4×4 Bayer matrix
	float m[16];
	m[0]= 0.0/16.0; m[1]=8.0/16.0; m[2]=2.0/16.0; m[3]=10.0/16.0;
	m[4]=12.0/16.0; m[5]=4.0/16.0; m[6]=14.0/16.0; m[7]=6.0/16.0;
	m[8]= 3.0/16.0; m[9]=11.0/16.0;m[10]=1.0/16.0;m[11]=9.0/16.0;
	m[12]=15.0/16.0;m[13]=7.0/16.0;m[14]=13.0/16.0;m[15]=5.0/16.0;
	return m[idx];
}

// ── Vertex ───────────────────────────────────────────────────────

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inst_id   = INSTANCE_ID;

	// Billboard: align quad to camera, then add wind on top
	mat4 bbm = mat4(
		MAIN_CAM_INV_VIEW_MATRIX[0],
		MAIN_CAM_INV_VIEW_MATRIX[1],
		MAIN_CAM_INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bbm;

	if (is_shadow_pass) {
		// Project shadow flat onto ground – squash Y, shift XZ in light direction
		VERTEX.y *= shadow_squash;
		VERTEX.x += shadow_world_offset.x;
		VERTEX.z += shadow_world_offset.y;
	} else {
		// ── Wind displacement (height-anchored, ref: Twitter shader) ──
		// Sway factor: zero at root (UV.y≈1), max at tip (UV.y≈0)
		float sway = max(0.0, (1.0 - UV.y) - height_offset);

		// Spatially-varying wind via layered sines (OpenSimplex-like)
		float t     = TIME * wind_speed;
		float noise = simplex_wind(world_pos.xz * 0.4, t);

		// Instance-level phase offset so blades don't all move in sync
		float phase_off = rnd(INSTANCE_ID, 7) * TAU;
		float inst_sway = sin(t * 1.1 + phase_off) * 0.15;
		float total_wind = (noise + inst_sway) * wind_strength;

		vec2 dir_n = normalize(wind_direction);
		VERTEX += (VIEW_MATRIX * vec4(
			dir_n.x * total_wind * sway,
			0.0,
			dir_n.y * total_wind * sway,
			0.0)).xyz;

		// Mouse push-away (same as before)
		float dist_to_mouse = length(world_pos.xz - mouse_world_xz);
		float proximity     = max(0.0, 1.0 - dist_to_mouse / mouse_brush_radius);
		float falloff       = proximity * proximity;
		vec2  push          = mouse_influence * falloff * sway;
		VERTEX += (VIEW_MATRIX * vec4(push.x, 0.0, push.y, 0.0)).xyz;
	}

	NORMAL = vec3(0.0, 1.0, 0.0);
}

// ── Fragment ─────────────────────────────────────────────────────

void fragment() {
	// Sample sprite / atlas
	float alpha_mask = 0.0;
	vec3  sprite_rgb = vec3(0.5);

	if (use_atlas) {
		vec2  suv    = sprite_atlas_uv(UV, inst_id, atlas_cols, atlas_rows);
		vec4  sample = texture(shape_atlas, suv);
		alpha_mask   = sample.a;
		sprite_rgb   = sample.rgb;
	} else {
		alpha_mask = texture(shape_texture, UV).r;
	}

	if (is_shadow_pass) {
		// Shadow: uniform dark color, soften edges toward tip
		float tip_fade = UV.y;
		ALBEDO = shadow_color;
		ALPHA  = alpha_mask * shadow_opacity * tip_fade;
	} else {
		// Color: sprite color or procedural gradient
		float noise_val = texture(noise_texture, world_pos.xz * 0.1).r;
		if (rnd(inst_id, 1) < random_variation) noise_val += 0.4;
		vec4 grad_col = texture(color_gradient, vec2(clamp(noise_val, 0.0, 1.0), 0.0));

		if (use_atlas && use_sprite_color) {
			ALBEDO = sprite_rgb;
		} else {
			ALBEDO = grad_col.rgb;
		}

		// Transparency modes
		float alpha = alpha_mask;
		if (alpha_mode == 0) {
			ALPHA = alpha;
		} else {
			alpha = clamp((alpha_mask - alpha_cut_start) / max(0.001, alpha_cut_end - alpha_cut_start), 0.0, 1.0);
			if (alpha_mode == 1) {
				alpha = step(bayer4(FRAGCOORD.xy) + 0.01, alpha);
			}
			if (alpha < 0.1) discard;
		}
	}
}

void light() {
	float ndotl = dot(LIGHT, NORMAL) * ATTENUATION;
	DIFFUSE_LIGHT += ndotl;
}
