shader_type spatial;
render_mode unshaded, cull_disabled;

// procedural metaballic splash
// particle system in a shader that "clips" feathered particles to achieve a metaballic effect

/*
	Copyright 2025 Ali

	Permission is hereby granted, free of charge, to any person obtaining a copy of
	this software and associated documentation files (the "Software"), to deal in
	the Software without restriction, including without limitation the rights to use,
	copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
	Software, and to permit persons to whom the Software is furnished to do so,
	subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/** Toggle Front Culling. Front face will not appear. */
uniform bool front_cull = false;

/** Toggle Back Culling. Back face will not appear. */
uniform bool back_cull = false;

group_uniforms animate;

/**
	* This value animates the shader as it changes when [param derive_progress] == 1.
	* Modify it with an animation player or edit it from gdScript with:
	[code]material.set_shader_parameter("progress", new_value)[/code]
*/
uniform float progress : hint_range(0.0, 1.0, 0.001);

/**
	* Different ways to drive the shader's animation.
	* <0> [enum Time], Shader animates with global [constant TIME]
	* <1> [enum Progress], Shader animates with [param progress]
	* <2> [enum Lifetime], Shader animates with particle lifetime, [member INSTANCE_CUSTOM.y]
*/
uniform int derive_progress : hint_enum("Time","Progress","Lifetime") = 1;

/**
	* Different ways to interpolate the shader's animation.
	* <0> [enum Custom Ease], Use by setting a [CurveTexture] in [param custom_ease]
	* <1> [enum Ease In], Exponetial Ease In
	* <2> [enum Linear], Linear
	* <3> [enum Ease Out], Exponetial Ease Out
	* <4> [enum Ease In Out], Exponetial Ease In and Out
*/
uniform int ease_progress : hint_enum("Custom Ease","Ease In","Linear","Ease Out","Ease In Out") = 2;

/**
	* Set a [CurveTexture] here and change [param ease_progress] to 0.
	* The shader will sample the texture red channel to interpolate the animation.
*/
uniform sampler2D custom_ease : hint_default_white, filter_linear, repeat_disable;

/** Modifies animation length when [param derive_progress] == 1 */
uniform float time_scale : hint_range(0.0, 8.0, 0.01) = 1.0;

group_uniforms colorize;

/**
	* Shade the shader! This setting changes gray values for gradient mapping.
	* <0> [enum Flat], Shader will be a single color and will not graduate.
	* <1> [enum Faux], Shader will sorta graduate, Edges will be darker.
	* <2> [enum Faux8], Like previous, Edges will be even darker. [code]pow(Faux,8.0)[/code]
	* <3> [enum Faux32], Like previous, Edges will be dark. [code]pow(Faux,32.0)[/code]
	* <4> [enum Faux64], Like previous, Edges will be really dark. [code]pow(Faux,64.0)[/code]
	* <5> [enum Faux256], Like previous, Edges will be [b]very dark[/b]. [code]pow(Faux,256.0)[/code]
*/
uniform int shading : hint_enum("Flat", "Faux", "Faux8", "Faux32", "Faux64", "Faux256") = 0;

/**
	* Color the shader with gradient mapping!
	Set a [GradientTexture1D] here to sample from by gray value.
	By default the right-most color value will be used when [param shading] == 0
*/
uniform sampler2D color_gradient : source_color, hint_default_white, repeat_disable;

/** This value will shift how the shader samples [param color_gradient]. */
uniform float shift_gradient : hint_range(-1.0, 1.0, 0.1) = 0.0;

/** This value will shift how the shader samples [param color_gradient], when interpolation is 'finished'. */
uniform float final_shift_gradient : hint_range(-1.0, 1.0, 0.1) = 0.0;

/**
	* Control how the shader interpolates [param shift_gradient].
	<0> [enum No], Shader will not interpolate shift gradient.
	<1> [enum Progress], Shader will interpolate shift gradient using progress.
	<2>,<3>,<4>,<5> [enum gcN], Shader will interpolate shift gradient using specified [b]generic curve[/b].
*/
uniform int ease_shift_gradient : hint_enum("No", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;

/**
	* This value will make the shader glow/darken.
	Works best when [member WorldEnvironment.Glow] is enabled.
*/
uniform float emission_intensity : hint_range(0.1, 16.0, 0.1) = 1.0;

/**
	* This value will posterize the shading resulting in value bands.
	A zero value will disable the calculation.
	A higher value will result in [i]less[/i] banding.
*/
uniform int chunky_color : hint_range(0, 100, 1) = 0;

group_uniforms colorize.iridescence;

/**
	* Control how the shader applies an iridescence effect to the image.
	<0> [enum No], Shader will not apply iridescence.
	<1> [enum Step], Shader will apply effect with hard edge.
	<2> [enum Smoothstep], Shader will apply effect with a soft edge.
	<3> [enum ValueStep], Shader will apply effect with a hard edge as a multiplier.
	<4> [enum ValueSmoothstep], Shader will apply effect with a soft edge as a multiplier.
*/
uniform int apply_iridescence : hint_enum("No", "Step", "Smoothstep", "ValueStep", "ValueSmoothstep") = 0;

/**
	* Control the features of the iridescence effect.
	X: Rainbow Brightness (sorta)
	Y: Edge 1 (Used in Step and Smoothstep)
	Z: Edge 2 (Used in Smoothstep)
	W: idk, scale sorta but different from [param iridescence_size]

	* Tips:
	While [param apply_iridescence] in [2,4] you can make Edge 1 greater than Edge 2 to have the effect begin from the inside.
*/
uniform vec4 iridescence = vec4(0.0,0.1,0.25,0.0);

/** Effect band size kinda... */
uniform float iridescence_size = 0.2;

/** Effect animation speed. This effect is driven by global time, [constant TIME]. */
uniform float iridescence_time_scale = 1.0;

group_uniforms colorize.chromatic_aberration;

uniform int apply_chroma : hint_enum("No", "Linear", "Radial", "Twist");
uniform int chroma_samples : hint_range(0, 10, 2);
uniform vec2 chroma_offset = vec2(0.01);

group_uniforms particle_options;

uniform int particles : hint_range(0, 100, 1) = 25;
uniform float particle_size : hint_range(0.0, 1.0, 0.001) = 0.05;
uniform sampler2D size_curve : hint_default_white, filter_linear, repeat_disable;
uniform vec2 randomize_size = vec2(1.0);
uniform float particle_feather : hint_range(0.0, 1.0, 0.001) = 0.05;
uniform sampler2D feather_curve : hint_default_white, filter_linear, repeat_disable;
uniform vec2 randomize_feather = vec2(1.0);
uniform float factor_distance : hint_range(0.0, 1.0, 0.1) = 0.0;
uniform vec2 distance_edges = vec2(0.0,0.5);

group_uniforms particle_options.trail_options;

uniform int use_trail : hint_enum("No", "Yes") = 0;
uniform vec2 trail_length = vec2(1.0,0.0);
uniform int ease_trail_length : hint_enum("No", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;
uniform vec2 trail_width = vec2(0.1,0.0);
uniform int ease_trail_width : hint_enum("No", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;
uniform bool trail_factor_distance = false;

group_uniforms system;

uniform float initial_particle_position = 0.02;
uniform bool maintain_ip_domain = false;
uniform float initial_particle_velocity = 1.0;
uniform int ease_ipv : hint_enum("No", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;
uniform int randomness : hint_enum("BoSh", "Sinless") = 0;
uniform int randomness_seed = 0;
uniform int index_shift_randomness : hint_enum("No", "Yes") = 0;

group_uniforms system.emission;

uniform vec2 emission_dir = vec2(0.0,1.0);
uniform float emission_spread : hint_range(0.0, 180.0, 0.1) = 180.0;
uniform vec2 particle_origin = vec2(0.0);
uniform vec4 acceleration = vec4(0.0,1.0,0.0,1.0);
uniform sampler2D acceleration_curve : hint_default_black, filter_linear, repeat_disable;

group_uniforms blobby;

uniform float blob_step : hint_range(0.0, 1.0, 0.001) = 0.5;
uniform int feather_interpolation : hint_enum("Linear","Hermite","Cubic","Cosine","Custom") = 1;
uniform vec2 feather_cubic_handles = vec2(0.0,1.0);
uniform sampler2D custom_feather_interp : hint_default_black, filter_linear, repeat_disable;

group_uniforms overlay;

uniform int enable_overlay : hint_enum("No","A*B*M","A&B*M","A*B","A&B","A","B","M");
uniform float overlay_str : hint_range(-3.0, 3.0, 0.001) = 1.0;
uniform sampler2D overlay_a : source_color, hint_default_white, filter_linear;
uniform vec4 polarize_overlay_a = vec4(0.5,0.5,0.6,0.0);
uniform vec4 animate_overlay_a = vec4(0.0);
uniform sampler2D overlay_b : source_color, hint_default_white, filter_linear;
uniform vec4 polarize_overlay_b = vec4(0.5,0.5,0.6,0.0);
uniform vec4 animate_overlay_b = vec4(0.0);
uniform sampler2D overlay_mask : source_color, hint_default_white, filter_linear;
uniform vec4 polarize_overlay_mask = vec4(0.5,0.5,0.6,0.0);
uniform vec3 sharpen_oabm = vec3(1.0);
uniform vec4 mix_oabm = vec4(vec3(1.0),0.5);
uniform int index_shift_overlay_texture : hint_enum("No", "Yes") = 0;

group_uniforms distortion;

uniform vec2 fisheye = vec2(1.0,0.0);
uniform int ease_fisheye : hint_enum("No", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;
uniform vec2 fisheye_origin = vec2(0.5);
uniform vec2 uv_scale = vec2(1.0);
uniform float uv_rot : hint_range(-360.0, 360.0, 0.01) = 0.0;

group_uniforms distortion.texture_distortion;

uniform int enable_texture_distortion : hint_enum("No","A*B*M","A&B*M","A*B","A&B","A","B","M");
uniform float distortion_fix = 2.0;
uniform float txdistort_str : hint_range(-3.0, 3.0, 0.001) = 1.0;
uniform sampler2D txdistort_a : source_color, hint_default_white, filter_linear;
uniform vec4 polarize_txdist_a = vec4(0.5,0.5,0.6,0.0);
uniform vec4 animate_txdist_a = vec4(0.0);
uniform sampler2D txdistort_b : source_color, hint_default_white, filter_linear;
uniform vec4 polarize_txdist_b = vec4(0.5,0.5,0.6,0.0);
uniform vec4 animate_txdist_b = vec4(0.0);
uniform sampler2D txdistort_mask : source_color, hint_default_white, filter_linear;
uniform vec4 polarize_txdist_mask = vec4(0.5,0.5,0.6,0.0);
uniform vec3 sharpen_dabm = vec3(1.0);
uniform vec4 mix_dabm = vec4(vec3(1.0),0.5);
uniform int index_shift_distort_texture : hint_enum("No", "Yes") = 0;

group_uniforms dissolve;

uniform int alpha_dissolve : hint_enum("No", "Step", "Smoothstep") = 0;
uniform int ease_alpha_dissolve : hint_enum("Progress", "gcA", "gcB", "gcC", "gcD") = 0;
uniform vec2 alpha_edge = vec2(0.9,1.0);

group_uniforms dissolve.proximity_fade;

uniform float proximity_fade_distance = 0.0;
uniform float proximity_fade_offset = 0.9;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform int pf_offset_calculation : hint_range(0, 5, 1) = 3;

group_uniforms vertex;

uniform int billboard : hint_enum("No", "Yes", "Y", "Local Y") = 0;
uniform float camera_offset = 0.0;
uniform vec3 mesh_offset = vec3(0.0);
uniform vec3 final_mesh_offset = vec3(0.0);
uniform int ease_mesh_offset : hint_enum("No", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;
uniform vec3 index_rand_mesh_rot = vec3(0.0);
uniform bool maintain_irm_domain = false;
uniform vec3 mesh_rotation = vec3(0.0);
uniform int animate_mesh_rot_with : hint_enum("Nothing", "Time", "Progress") = 0;
uniform vec3 animate_mesh_rotation = vec3(0.0);
uniform sampler2D vertex_displacement_mask : hint_default_black;
uniform vec3 vertex_displacement_str = vec3(0.0);
uniform vec3 final_vertex_displacement_str = vec3(1.0);
uniform int ease_vert_disp_str_with : hint_enum("Nothing", "Time", "Progress", "gcA", "gcB", "gcC", "gcD") = 0;

group_uniforms curves;

uniform sampler2D generic_curve_A : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D generic_curve_B : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D generic_curve_C : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D generic_curve_D : hint_default_black, filter_linear, repeat_disable;

varying float LIFETIME;
varying float INDEX;
varying flat int pid;

float random(vec2 uv) {
	float seed = float(randomness_seed) / PI;
	if (index_shift_randomness == 1) {seed += float(pid);}
	switch (randomness) {
		case 0:
			return fract(sin(dot(uv.xy,vec2(12.9898 + seed,78.233))) * 43758.5453123 + seed);
		case 1:
			vec3 p3  = fract(vec3(uv.xyx + seed) * .1031);
			p3 += dot(p3, p3.yzx + 33.33);
			return fract((p3.x + p3.y) * p3.z + seed);
	}
	return 0.0;
}

float grayscale(vec3 rgb, int type) {
	if (type == 1) {
		return (rgb.r + rgb.g + rgb.b) / 3.0;
	}
	const float rw = 0.299;
	const float gw = 0.587;
	const float bw = 0.114;
	rgb *= vec3(rw,gw,bw);
	return rgb.r + rgb.g + rgb.b;
}

float remap(float value, vec2 original, vec2 new_range) {
	return new_range.x + (value - original.x) * (new_range.y - new_range.x) / (original.y - original.x);
}

vec2 spherize(vec2 uv, vec2 center, float strength, vec2 offset) {
	vec2 delta = uv - center;
	float delta2 = dot(delta.xy, delta.xy);
	float delta4 = delta2 * delta2;
	vec2 delta_offset = vec2(delta4, delta4) * strength;
	return uv + (delta * delta_offset) + offset;
}

vec2 polar_coordinates(vec2 uv, vec2 center, float zoomm, float repeat) {
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0/(3.1416 * 2.0);
	return mod(vec2(radius * zoomm, angle * repeat), 1.0);
}

float customstep(sampler2D interp,float edge0,float edge1,float value) {
	float t = clamp((value - edge0)/(edge1 - edge0),0.0,1.0);
	return texture(interp,vec2(t,0.0)).r;
}

float cosinestep(float edge0, float edge1, float value) {
	float v2 = (1.0-cos(value * PI) / 2.0);
	return mix(edge0,edge1,v2);
}

float cubicstep(float edge0, float edge1, vec2 handles, float value) {
	float a0,a1,a2,a3,v2;
	v2 = value * value;
	a0 = handles.y - edge1 - handles.x + edge0;
	a1 = handles.x - edge0 - a0;
	a2 = edge1 - handles.x;
	a3 = edge0;
	return (a0*value*v2+a1*v2+a2*value+a3);
}

vec2 scale(vec2 uv, float x, float y) {
	mat2 scalee = mat2(vec2(x, 0.0), vec2(0.0, y));
	uv -= 0.5;
	uv = uv * scalee;
	uv += 0.5;
	return uv;
}

vec2 rotate(vec2 uv, vec2 pivot, float angle) {
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)), vec2(cos(angle), sin(angle)));
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}

mat3 rotateX(float theta) {
	float cosa = cos(theta);
	float sina = sin(theta);
	mat3 rotate_x = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, cosa, -sina),
		vec3(0.0, sina, cosa)
	);
	return rotate_x;
}

mat3 rotateY(float theta) {
	float cosa = cos(theta);
	float sina = sin(theta);
	mat3 rotate_y = mat3(
		vec3(cosa, 0.0, sina),
		vec3(0.0, 1.0, 0.0),
		vec3(-sina, 0.0, cosa)
	);
	return rotate_y;
}

mat3 rotateZ(float theta) {
	float cosa = cos(theta);
	float sina = sin(theta);
	mat3 rotate_z = mat3(
		vec3(cosa,-sina, 0.0),
		vec3(sina, cosa, 0.0),
		vec3(0.0, 0.0, 1.0)
	);
	return rotate_z;
}

float easeInOutExpo(float x) {
	float result;
	if (x <= 0.0) {result = 0.0;}
	else if (x >= 1.0) {result = 1.0;}
	else if (x < 0.5) {result = pow(2.0, 20.0 * x - 10.0) / 2.0;}
	else {result = (2.0 - pow(2.0, -20.0 * x + 10.0)) / 2.0;}
	return result;
}

float get_progress() {
	float p;
	float final;
	if (derive_progress == 2) {p = LIFETIME;}
	else if (derive_progress == 0) {p = mod(TIME * time_scale,1.0);}
	else {p = progress;}

	if (ease_progress == 4) {final = easeInOutExpo(p);}
	else if (ease_progress == 0) {final = texture(custom_ease,vec2(p,0.0)).r;}
	else if (ease_progress == 3) {final = 1.0 - pow(2.0, -10.0 * p);}
	else if (ease_progress == 1) {final = pow(2.0, 10.0 * p - 10.0);}
	else {final = p;}

	return final;
}

float get_eased_valuef(sampler2D ease, float init, float final_value) {
	float sample = texture(ease,vec2(get_progress(),0.0)).r;
	return mix(init,final_value,sample);
}

vec2 get_eased_valuev2(sampler2D ease, vec2 init, vec2 final_value) {
	float sample = texture(ease,vec2(get_progress(),0.0)).r;
	return mix(init,final_value,sample);
}

vec3 get_eased_valuev3(sampler2D ease, vec3 init, vec3 final_value) {
	float sample = texture(ease,vec2(get_progress(),0.0)).r;
	return mix(init,final_value,sample);
}

struct Particle2D {
	vec2 acceleration;
	vec2 inital_velocity;
	vec2 inital_position;
	vec2 velocity;
	vec2 position;
	mat4 draw_info;
};

vec2 get_emission_dir() {
	switch (ease_ipv) {
		case 0: return normalize(emission_dir);
		case 1: return normalize(emission_dir) * get_progress();
		case 2: return get_eased_valuev2(generic_curve_A,normalize(emission_dir),vec2(0.0));
		case 3: return get_eased_valuev2(generic_curve_B,normalize(emission_dir),vec2(0.0));
		case 4: return get_eased_valuev2(generic_curve_C,normalize(emission_dir),vec2(0.0));
		case 5: return get_eased_valuev2(generic_curve_D,normalize(emission_dir),vec2(0.0));
	}
	return normalize(emission_dir);
}

Particle2D make_p2d(float inital_vel, float inital_pos) {
	return Particle2D(
		get_eased_valuev2(acceleration_curve,acceleration.xy,acceleration.zw),
		get_emission_dir() * inital_vel,normalize(emission_dir) * inital_pos,vec2(0.0),vec2(0.0),mat4(0.0));
}

Particle2D get_p2d(Particle2D p2d) {
	p2d.velocity = p2d.inital_velocity + (p2d.acceleration * get_progress());
	p2d.position = p2d.inital_position + (p2d.velocity * get_progress());
	return p2d;
}

float circle(vec2 uv,float radius,float feather) {
	float d = length(uv - vec2(0.5));
	float c = 1.0;
	switch (feather_interpolation) {
		case 0: c = mix(radius, radius + feather, d); break;
		case 2: c = cubicstep(radius, radius + feather, feather_cubic_handles, d); break;
		case 3: c = cosinestep(radius, radius + feather, d); break;
		case 4: c = customstep(custom_feather_interp, radius, radius + feather, d); break;
		default: c = smoothstep(radius, radius + feather, d); break;
	}
	return c;
}

float sdSegment(vec2 p,vec2 a,vec2 b,float feather) {
	p += 0.5;
	vec2 pa = p-a, ba = b-a;
	float h = clamp(dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
	float d = length(pa - ba*h);
	return clamp(smoothstep(0.0,feather,d),0.0,1.0);
}

vec3 get_mesh_offset() {
	switch (ease_mesh_offset) {
		case 0: return mesh_offset;
		case 1: return mix(mesh_offset,final_mesh_offset,get_progress());
		case 2: return get_eased_valuev3(generic_curve_A,mesh_offset,final_mesh_offset);
		case 3: return get_eased_valuev3(generic_curve_B,mesh_offset,final_mesh_offset);
		case 4: return get_eased_valuev3(generic_curve_C,mesh_offset,final_mesh_offset);
		case 5: return get_eased_valuev3(generic_curve_D,mesh_offset,final_mesh_offset);
	}
	return mesh_offset;
}

vec3 get_vertex_disp_amt() {
	switch (ease_vert_disp_str_with) {
		case 0: return vertex_displacement_str;
		case 1: return mix(vertex_displacement_str,final_vertex_displacement_str,get_progress());
		case 2: return get_eased_valuev3(generic_curve_A,vertex_displacement_str,final_vertex_displacement_str);
		case 3: return get_eased_valuev3(generic_curve_B,vertex_displacement_str,final_vertex_displacement_str);
		case 4: return get_eased_valuev3(generic_curve_C,vertex_displacement_str,final_vertex_displacement_str);
		case 5: return get_eased_valuev3(generic_curve_D,vertex_displacement_str,final_vertex_displacement_str);
	}
	return vertex_displacement_str;
}

vec3 get_animated_mesh_rotation() {
	switch (animate_mesh_rot_with) {
		case 0: return vec3(0.0);
		case 1: return radians(animate_mesh_rotation) * TIME;
		case 2: return radians(animate_mesh_rotation) * get_progress();
	}
	return vec3(0.0);
}

void vertex() {
	LIFETIME = INSTANCE_CUSTOM.y;
	INDEX = float(INSTANCE_ID);
	pid = int(INDEX);

	float r = random(vec2(float(pid)));
	float r2 = (random(vec2(float(pid))) - 0.5) * 2.0;

	VERTEX += get_mesh_offset();
	VERTEX += texture(vertex_displacement_mask,UV).r * get_vertex_disp_amt();

	vec3 rot_rand = radians(index_rand_mesh_rot) * r2;
	if (maintain_irm_domain) { rot_rand = radians(index_rand_mesh_rot) * r;}
	vec3 rotation_offset = radians(mesh_rotation) + get_animated_mesh_rotation() + rot_rand;

	mat3 rotation_matrix = rotateX(rotation_offset.x) * rotateY(rotation_offset.y) * rotateZ(rotation_offset.z);
	VERTEX *= rotation_matrix;
	NORMAL *= rotation_matrix;

	if (billboard == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
	if (billboard == 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	}
	if (billboard == 3) {
		vec3 local_up = MODEL_MATRIX[1].xyz;
		vec4 ax = vec4(normalize(cross(local_up, INV_VIEW_MATRIX[2].xyz)), 0.0);
		vec4 ay = vec4(local_up.xyz, 0.0);
		vec4 az = vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, local_up)), 0.0);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(ax, ay, az, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));

	VERTEX += camera_offset * normalize((inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
}

vec4 rainbow(float light_offset, float sin_frequency, float rtime_scale) {
	float t = dot(TIME,8.0) + fract(float(pid));
	vec4 animated_color = vec4(light_offset + sin(2.0*3.14*sin_frequency*(t*rtime_scale)),
	light_offset + sin(2.0*3.14*sin_frequency*(t*rtime_scale) + radians(120.0)),
	light_offset + sin(2.0*3.14*sin_frequency*(t*rtime_scale) + radians(240.0)),
	1.0);
	return animated_color;
}

float get_fisheye() {
	switch (ease_fisheye) {
		case 0: return fisheye.x;
		case 1: return mix(fisheye.x,fisheye.y,get_progress());
		case 2: return get_eased_valuef(generic_curve_A,fisheye.x,fisheye.y);
		case 3: return get_eased_valuef(generic_curve_B,fisheye.x,fisheye.y);
		case 4: return get_eased_valuef(generic_curve_C,fisheye.x,fisheye.y);
		case 5: return get_eased_valuef(generic_curve_D,fisheye.x,fisheye.y);
	}
	return fisheye.x;
}

vec2 get_trail_options() {
	float tl = 1.0;
	float tw = 1.0;
	switch (ease_trail_length) {
		case 0: tl = trail_length.x; break;
		case 1: tl = mix(trail_length.x,trail_length.y,get_progress()); break;
		case 2: tl = get_eased_valuef(generic_curve_A,trail_length.x,trail_length.y); break;
		case 3: tl = get_eased_valuef(generic_curve_B,trail_length.x,trail_length.y); break;
		case 4: tl = get_eased_valuef(generic_curve_C,trail_length.x,trail_length.y); break;
		case 5: tl = get_eased_valuef(generic_curve_D,trail_length.x,trail_length.y); break;
	}
	switch (ease_trail_width) {
		case 0: tw = trail_width.x; break;
		case 1: tw = mix(trail_width.x,trail_width.y,get_progress()); break;
		case 2: tw = get_eased_valuef(generic_curve_A,trail_width.x,trail_width.y); break;
		case 3: tw = get_eased_valuef(generic_curve_B,trail_width.x,trail_width.y); break;
		case 4: tw = get_eased_valuef(generic_curve_C,trail_width.x,trail_width.y); break;
		case 5: tw = get_eased_valuef(generic_curve_D,trail_width.x,trail_width.y); break;
	}
	return vec2(1.0-tl,clamp(tw,0.0,99.0));
}

float get_alpha_dissolve_driver() {
	switch (ease_alpha_dissolve) {
		case 0: return 1.0-get_progress();
		case 1: return texture(generic_curve_A,vec2(get_progress(),0.0)).r;
		case 2: return texture(generic_curve_B,vec2(get_progress(),0.0)).r;
		case 3: return texture(generic_curve_C,vec2(get_progress(),0.0)).r;
		case 4: return texture(generic_curve_D,vec2(get_progress(),0.0)).r;
	}
	return 1.0 - get_progress();
}

float get_shift_gradient() {
	switch (ease_shift_gradient) {
		case 0: return shift_gradient;
		case 1: return mix(shift_gradient,final_shift_gradient,get_progress());
		case 2: return get_eased_valuef(generic_curve_A,shift_gradient,final_shift_gradient);
		case 3: return get_eased_valuef(generic_curve_B,shift_gradient,final_shift_gradient);
		case 4: return get_eased_valuef(generic_curve_C,shift_gradient,final_shift_gradient);
		case 5: return get_eased_valuef(generic_curve_D,shift_gradient,final_shift_gradient);
	}
	return shift_gradient;
}

float get_shading(float original, int profile) {
	switch (profile) {
		case 0: return 1.0;
		case 1: return original;
		case 2: return pow(original,8.0);
		case 3: return pow(original,32.0);
		case 4: return pow(original,64.0);
		case 5: return pow(original,256.0);
	}
	return original;
}

vec2 get_animated_uv(vec2 uv, vec4 animate) {
	vec2 nc = uv;
	float driver = get_progress();
	switch (int(floor(abs(animate.w)))) {
		case 0: driver = 1.0; break;
		case 1: driver = TIME; break;
		case 2: driver = get_progress(); break;
		case 3: driver = texture(generic_curve_A,vec2(get_progress(),0.0)).r; break;
		case 4: driver = texture(generic_curve_B,vec2(get_progress(),0.0)).r; break;
		case 5: driver = texture(generic_curve_C,vec2(get_progress(),0.0)).r; break;
		case 6: driver = texture(generic_curve_D,vec2(get_progress(),0.0)).r; break;
	}
	vec2 anim = animate.xy * driver;
	if (animate.z > 0.0) {anim = animate.xy * (floor(driver * animate.z)/animate.z);}
	nc += anim;
	return nc;
}

float get_transformed_sampler(vec2 uv, sampler2D sample_texture, vec4 polarize, vec4 animate) {
	vec2 plruv = uv;
	if (polarize.w > 0.0) {plruv = polar_coordinates(uv,polarize.xy,polarize.z,polarize.w);}
	plruv = get_animated_uv(plruv,animate);
	return texture(sample_texture,plruv).r;
}

float get_overlay(vec2 uv) {
	vec2 is;
	if (index_shift_overlay_texture == 1) {
		is = vec2(
			random(vec2(float(pid),float(-pid))),
			random(vec2(float(-pid),float(pid)))
		);
	} else {
		is = vec2(0.0);
	}

	float a = get_transformed_sampler(uv + is,overlay_a,polarize_overlay_a,animate_overlay_a);
	float b = get_transformed_sampler(uv - is,overlay_b,polarize_overlay_b,animate_overlay_b);
	float m = get_transformed_sampler(uv,overlay_mask,polarize_overlay_mask,vec4(0.0));
	a = pow(a,sharpen_oabm.x) * mix_oabm.x;
	b = pow(b,sharpen_oabm.y) * mix_oabm.y;
	m = pow(m,sharpen_oabm.z) * mix_oabm.z;
	switch (enable_overlay) {
		case 0: return 0.0;
		case 1: return (a * b * m) * overlay_str;
		case 2: return (mix(a,b,mix_oabm.w) * m) * overlay_str;
		case 3: return (a*b) * overlay_str;
		case 4: return mix(a,b,mix_oabm.w) * overlay_str;
		case 5: return a * overlay_str;
		case 6: return b * overlay_str;
		case 7: return m * overlay_str;
	}
	return 0.0;
}

float get_distortion(vec2 uv) {
	vec2 is;
	if (index_shift_distort_texture == 1) {
		is = vec2(
			random(vec2(float(pid),float(-pid))),
			random(vec2(float(-pid),float(pid)))
		);
	} else {
		is = vec2(0.0);
	}

	float a = get_transformed_sampler(uv - is,txdistort_a,polarize_txdist_a,animate_txdist_a);
	float b = get_transformed_sampler(uv + is,txdistort_b,polarize_txdist_b,animate_txdist_b);
	float m = get_transformed_sampler(uv,txdistort_mask,polarize_txdist_mask,vec4(0.0));
	a = pow(a,sharpen_dabm.x) * mix_dabm.x;
	b = pow(b,sharpen_dabm.y) * mix_dabm.y;
	m = pow(m,sharpen_dabm.z) * mix_dabm.z;
	float d = 0.0;
	switch (enable_texture_distortion) {
		case 0: d = 0.0; break;
		case 1: d = a * b * m; break;
		case 2: d = mix(a,b,mix_dabm.w) * m; break;
		case 3: d = a * b; break;
		case 4: d = mix(a,b,mix_dabm.w); break;
		case 5: d = a; break;
		case 6: d = b; break;
		case 7: d = m; break;
	}
	return d;
}

float create_image(vec2 uv) {
	float image = 1.0;
	Particle2D[100] pArr;
	for (int i = 0; i < particles; i++) {
		float prog = get_progress();
		float r = (random(vec2(float(i))) - 0.5) * 2.0;
		float r2 = random(vec2(float(i)));
		float ip = (random(vec2(float(i),0.0)) - 0.5) * 2.0 * initial_particle_position;
		if (maintain_ip_domain) ip = random(vec2(float(i),0.0)) * initial_particle_position;
		float iv = random(vec2(0.0,float(i))) * initial_particle_velocity;
		Particle2D p = get_p2d(make_p2d(iv,ip));
		vec2 puv = rotate(uv,vec2(0.5),(radians(emission_spread) * r) + radians(90.0));

		float df = 1.0;
		if (factor_distance > 0.0) {
			df = 1.0-smoothstep(distance_edges.x,distance_edges.y,length(p.position));
			df /= factor_distance;
		}

		float ips = particle_size;
		ips *= mix(min(randomize_size.x,randomize_size.y),max(randomize_size.x,randomize_size.y),r2);
		ips *= df;
		float ps = (ips/2.0) * texture(size_curve,vec2(prog,0.0)).r;

		float ipf = particle_feather;
		ipf *= mix(min(randomize_feather.x,randomize_feather.y),max(randomize_feather.x,randomize_feather.y),r2);
		ipf *= df;
		float pf = ipf * texture(feather_curve,vec2(prog,0.0)).r;

		float circ = circle(puv + p.position, ps, pf);
		float line = 1.0;
		if (use_trail == 1) {
			vec2 twl = get_trail_options();
			if (trail_factor_distance) {twl *= df;}
			line = sdSegment(puv,1.0-p.position,1.0-p.position * twl.x,pf*twl.y);
		}
		p.draw_info[0].xy = puv + p.position;
		p.draw_info[0].zw = vec2(ps,pf);
		p.draw_info[1].x = (radians(emission_spread) * r) + radians(90.0);
		p.draw_info[2].xy = puv;
		p.draw_info[2].zw = p.position;
		pArr[i] = p;

		image *= clamp(circ*line,0.0,1.0);
	}
	return image;
}

float process_image(float image, float ovly) {
	float original_image = 1.0-image;
	if (blob_step > 0.0) {
		image = step(image,blob_step);
	} else {
		image = 1.0-image;
	}
	image += mix(0.0,ovly,image);

	float col = get_shading(original_image, shading);
	if (chunky_color > 0) {col = floor(col * float(chunky_color)) / float(chunky_color);}
	return col;
}

float blob_image(float image) {
	if (blob_step > 0.0) {
		image = step(image,blob_step);
	} else {
		image = 1.0-image;
	}
	return image;
}

void fragment() {
	if (front_cull && FRONT_FACING) {discard;}
	if (back_cull && !FRONT_FACING) {discard;}

	vec2 moduv = rotate(scale(UV,1.0/uv_scale.x,1.0/uv_scale.y),vec2(0.5),radians(uv_rot) + radians(90.0));
	vec2 uv = spherize(moduv,fisheye_origin,get_fisheye(),vec2(0.0)) + particle_origin;
	float d = get_distortion(UV);
	if (enable_texture_distortion != 0) {uv -= vec2(txdistort_str) / distortion_fix;}
	uv += txdistort_str * d;

	float ovly = get_overlay(uv);
	float image = create_image(uv);
	float col = process_image(image,ovly);
	float original_image = 1.0-image;

	if (apply_chroma != 0 && chroma_samples != 0) {
		vec4 chroma_sum = vec4(0.0);
		vec4 weight_sum = vec4(0.0);
		vec2 chroma_uv = uv;
		for (float i = 0.0; i <= 1.0; i += 1.0/float(chroma_samples)) {
			vec2 ca_uv;
			switch (apply_chroma) {
				case 1: ca_uv = chroma_uv + (i-0.5) * chroma_offset; break;
				case 2: ca_uv = mix(chroma_uv,vec2(0.5),(i-0.5) * chroma_offset); break;
				case 3: ca_uv = chroma_uv + vec2(chroma_uv.y-0.5,0.5-chroma_uv.x) * (i-0.5) * chroma_offset; break;
			}
			vec4 ca_color = vec4(process_image(create_image(ca_uv),ovly));
			vec4 ca_weight = vec4(i, 1.0-abs(i*2.0-1.0), 1.0-i, 0.5);
			chroma_sum += ca_color * ca_color * ca_weight;
			weight_sum += ca_weight;
		}
		vec4 chroma_split = sqrt(chroma_sum/weight_sum);
		col = grayscale(chroma_split.rgb,0);
		ALBEDO.rgb = chroma_split.rgb;
		ALPHA = chroma_split.a;
	}

	vec4 mapped_color = texture(color_gradient,vec2(col + get_shift_gradient(),0.0));
	vec2 rainpc = polar_coordinates(UV-0.5*2.0,vec2(0.5),iridescence_size,iridescence.w-(cos(TIME * 0.2 * iridescence_time_scale) + 1.0)) + vec2(0.0,(sin(TIME * 0.2 * iridescence_time_scale) + 1.0));
	vec4 rainbow_color = rainbow(iridescence.x,abs(length(rainpc) * 0.001),1.0);
	float rcut = 1.0;
	switch (apply_iridescence) {
		case 0:
			ALBEDO *= mapped_color.rgb;
			break;
		case 1:
			rcut = 1.0-step(blob_step + iridescence.y,1.0-col);
			ALBEDO *= mix(rainbow_color.rgb,mapped_color.rgb,rcut);
			break;
		case 2:
			rcut = 1.0-smoothstep(iridescence.y,blob_step + iridescence.z,1.0-col);
			ALBEDO *= mix(rainbow_color.rgb,mapped_color.rgb,rcut);
			break;
		case 3:
			rcut = step(blob_step + iridescence.y,1.0-col);
			ALBEDO *= mix(grayscale(rainbow_color.rgb,0)+mapped_color.rgb,mapped_color.rgb,1.0-rcut);
			break;
		case 4:
			rcut = 1.0-smoothstep(iridescence.y,blob_step + iridescence.z,1.0-col);
			ALBEDO *= mix(grayscale(rainbow_color.rgb,0)+mapped_color.rgb,mapped_color.rgb,rcut);
			break;
	}
	ALBEDO *= emission_intensity;

	float image_alpha = blob_image(image);
	float dissolver = original_image;
	switch (alpha_dissolve) {
		case 1:
			image_alpha = 1.0-step(dissolver,remap(get_alpha_dissolve_driver(),vec2(0.0,1.0),alpha_edge.yx));
			break;
		case 2:
			image_alpha = smoothstep(remap(get_alpha_dissolve_driver(),vec2(0.0,1.0),alpha_edge.yx),1.,dissolver);
			break;
	}
	image_alpha += mix(0.0,ovly,image_alpha);
	ALPHA *= image_alpha * COLOR.a;
	if (shading != 0) {ALPHA *= mapped_color.a;}

	float depth_tex = textureLod(depth_texture,SCREEN_UV,0.0).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,depth_tex,1.0);
	world_pos.xyz /= world_pos.w;
	ALPHA *= clamp(1.0-smoothstep(world_pos.z+proximity_fade_distance,world_pos.z,VERTEX.z - (1.0-get_shading(original_image, pf_offset_calculation) * proximity_fade_offset)),0.0,1.0);
}