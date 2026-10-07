shader_type canvas_item;
uniform float grayscale : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 col = texture(TEXTURE, UV) * COLOR;
    float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(mix(col.rgb, vec3(gray), grayscale), col.a);
}
