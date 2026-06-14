shader_type spatial;
render_mode unshaded, depth_draw_always, cull_disabled;

uniform vec4 country_color : source_color = vec4(0.25, 0.6, 1.0, 0.18);
uniform float emission : hint_range(0.0, 3.0) = 0.8;
uniform float border_intensity : hint_range(0.0, 2.0) = 1.2;

void fragment() {
    ALBEDO = country_color.rgb;
    
    // Sehr weicher Fresnel für Kugel-Optik
    float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
    
    ALPHA = country_color.a * (0.55 + fresnel * 0.9);
    EMISSION = country_color.rgb * emission * fresnel;
    
    // Leichter Rand-Effekt
    if (fresnel > 0.85) {
        ALPHA *= border_intensity;
    }
}