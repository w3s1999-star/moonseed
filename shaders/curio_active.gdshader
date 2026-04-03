shader_type canvas_item;
// Animated rune glow applied to active relic PanelContainer

uniform float speed : hint_range(0.5, 6.0) = 2.8;
uniform float glow_width : hint_range(0.02, 0.35) = 0.12;
uniform vec4  glow_color  : source_color = vec4(1.0, 0.7, 0.1, 1.0);
uniform float intensity   : hint_range(0.0, 1.0)  = 0.85;

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    // Edge distance – thinner = sharper rim
    float ex = min(UV.x, 1.0 - UV.x);
    float ey = min(UV.y, 1.0 - UV.y);
    float edge = min(ex, ey);
    float rim  = 1.0 - smoothstep(0.0, glow_width, edge);

    // Travelling rune band
    float band  = fract(UV.y - TIME * speed * 0.15);
    float rune_glow = smoothstep(0.0, 0.08, band) * smoothstep(0.28, 0.08, band);

    // Pulse
    float pulse = sin(TIME * speed) * 0.4 + 0.6;

    float final_glow = rim * intensity * pulse + rune_glow * 0.4 * pulse;
    final_glow = clamp(final_glow, 0.0, 1.0);

    COLOR.rgb = mix(base.rgb, glow_color.rgb, final_glow * glow_color.a);
    COLOR.a   = base.a;
}
