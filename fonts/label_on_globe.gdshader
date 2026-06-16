shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear;
uniform vec4 albedo_color : source_color = vec4(1.0);

void vertex() {
    // Text stark an die Kugeloberfläche ziehen
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 normalized = normalize(world_pos);
    VERTEX = normalized * (length(world_pos) * 1.0018); // sehr nah an Oberfläche
}

void fragment() {
    vec4 tex_color = texture(texture_albedo, UV);
    ALBEDO = tex_color.rgb * albedo_color.rgb;
    ALPHA = tex_color.a;
}