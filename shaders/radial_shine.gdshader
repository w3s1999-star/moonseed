// Based on https://godotshaders.com/shader/radial-shine-highlight/ (CC0, shadecore_dev)
shader_type canvas_item;
render_mode blend_add;

uniform vec2  pixelation      = vec2(128.0, 64.0);
uniform float gradient_steps  = 32.0;
uniform sampler2D gradient;
uniform float spread          : hint_range(0.01, 0.4)  = 0.33;
uniform float size            : hint_range(-1.0, 1.0)  = 0.36;
uniform float speed                                    = 1.0;
uniform float ray1_density    : hint_range(0.0, 16.0)  = 8.5;
uniform float ray2_density    : hint_range(0.0, 16.0)  = 8.5;
uniform float ray2_intensity  : hint_range(-2.0, 10.0) = 0.5;
uniform float core_intensity  : hint_range(-1.0, 1.0)  = 0.6;
uniform bool  hdr                                      = false;
uniform float seed                                     = 1.0;
uniform float alpha_mul       : hint_range(0.0, 1.0)   = 0.85;

float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}
float noise(in vec2 uv) {
    vec2 i = floor(uv); vec2 f = fract(uv);
    float a = random(i); float b = random(i + vec2(1,0));
    float c = random(i + vec2(0,1)); float d = random(i + vec2(1,1));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a,b,u.x) + (c-a)*u.y*(1.0-u.x) + (d-b)*u.x*u.y;
}

void fragment() {
    vec2 puv = floor(UV * pixelation) / pixelation;
    vec2 cuv = (puv - 0.5) * (1.0 - size);
    float radius = length(cuv);
    float angle  = atan(cuv.y, cuv.x) + 3.14159265;
    vec2 ray1 = vec2(angle * ray1_density + TIME * -speed + seed + sin(angle*3.0), radius*2.0);
    vec2 ray2 = vec2(angle * ray2_density + TIME *  speed * 1.5 + seed + cos(angle*2.0), radius*2.0);
    float cut = 1.0 - smoothstep(0.33, 0.53, radius);
    ray1 *= cut; ray2 *= cut;
    float rays = hdr ?
        noise(ray1) + (noise(ray2) * ray2_intensity) :
        clamp(noise(ray1) + (noise(ray2) * ray2_intensity), 0.0, 1.0);
    rays *= smoothstep(spread, spread * 0.3, radius);
    float core = smoothstep(0.2, 0.0, radius) * core_intensity;
    rays += core;
    vec4 gc = texture(gradient, vec2(rays, 0.5));
    vec3 shine = vec3(rays) * gc.rgb;
    float a = floor(rays * gradient_steps) / gradient_steps * gc.a * alpha_mul;
    COLOR = vec4(shine, a);
}
