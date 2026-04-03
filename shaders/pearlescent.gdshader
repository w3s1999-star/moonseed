shader_type canvas_item;

uniform float time : hint_range(0.0, 10.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.18;
uniform vec2 speed = vec2(0.6, 0.0);
uniform float stripe_scale = 6.0;
uniform float softness = 0.12;
uniform float corner_radius = 0.06; // relative to min(size.x,size.y)

// simple HSV->RGB approximation using cosines for smooth rainbow band
vec3 hue_to_rgb(float h) {
    float x = 6.28318530718 * h;
    return vec3(0.5 + 0.5 * cos(x + 0.0), 0.5 + 0.5 * cos(x + 2.09439510239), 0.5 + 0.5 * cos(x + 4.18879020479));
}

// rounded rect mask (signed distance approx)
float rounded_rect_mask(vec2 uv) {
    // uv in 0..1
    vec2 p = uv - 0.5;
    vec2 a = abs(p) - vec2(0.5 - corner_radius);
    float outside = length(max(a, vec2(0.0)));
    float inside = min(max(a.x, a.y), 0.0);
    return outside + inside;
}

void fragment() {
    vec2 uv = UV;
    float t = time * speed.x;

    // Create moving stripe pattern across the card
    float band = sin((uv.x * stripe_scale) + t) * 0.5 + 0.5;
    band = pow(band, 1.6);

    // Map band to a hue value and get color
    float hue = fract(uv.x * 0.8 + t * 0.12 + uv.y * 0.18);
    vec3 rainb = hue_to_rgb(hue);

    // Pearlescent base: subtle desaturated highlight blended with rainbow
    vec3 pearl = mix(vec3(1.0), rainb, 0.88);

    // Use band as strength and fade near edges using rounded rect mask
    float sd = rounded_rect_mask(uv);
    float m = 1.0 - smoothstep( (0.5 - corner_radius) - softness, (0.5 - corner_radius) + softness, length(max(abs(uv-0.5) - vec2(0.5 - corner_radius), vec2(0.0))) );

    float alpha = intensity * band * m;

    COLOR = vec4(pearl * alpha, alpha);
}
