shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas_color : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_orm : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float wind_strength : hint_range(0.0, 0.15) = 0.055;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.4;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float phase = world.x * 0.63 + world.z * 0.41;
    float amount = COLOR.r; // 0 at each plant's foot, 1 near its top.
    VERTEX.x += sin(TIME * wind_speed + phase) * amount * wind_strength;
    VERTEX.z += cos(TIME * wind_speed * 0.81 + phase) * amount * wind_strength * 0.55;
}
void fragment() {
    vec4 col = texture(atlas_color, UV);
    ALBEDO = col.rgb; // Never multiply by COLOR.rgb: it stores wind weights.
    ALPHA = col.a;
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    NORMAL_MAP = texture(atlas_normal, UV).rgb;
    vec3 orm = texture(atlas_orm, UV).rgb;
    AO = orm.r;
    ROUGHNESS = orm.g;
    METALLIC = orm.b;
}
