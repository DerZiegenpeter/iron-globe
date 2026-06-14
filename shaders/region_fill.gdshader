shader_type spatial;
render_mode unshaded, depth_draw_always;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 0.35);
uniform float emission_strength : hint_range(0.0, 5.0) = 1.5;

void fragment() {
    ALBEDO = albedo.rgb;
    ALPHA = albedo.a;
    EMISSION = albedo.rgb * emission_strength;
}