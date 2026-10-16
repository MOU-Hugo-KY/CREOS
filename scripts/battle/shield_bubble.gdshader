// Bulle de bouclier : bord lumineux, intérieur presque transparent, reflet qui tourne.
// Mélange additif, léger pour le mobile.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(0.5, 0.83, 1.0, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float inside = step(d, 1.0) * texture(TEXTURE, UV).a;
	// Bord : de plus en plus lumineux vers l'extérieur (effet de Fresnel).
	float rim = pow(clamp(d, 0.0, 1.0), 4.0);
	// Bandes pixelisées qui défilent (scintillement).
	float band = step(0.82, fract((p.y + p.x * 0.4) * 3.0 - TIME * 1.2));
	// Petit reflet en haut à gauche.
	float shine = smoothstep(0.25, 0.0, length(p - vec2(-0.4, -0.45)));
	float a = (0.08 + rim * 0.85 + band * 0.12 + shine * 0.6) * inside;
	COLOR = vec4(tint.rgb * a + vec3(shine * inside * 0.5), a) * COLOR.a;
}
