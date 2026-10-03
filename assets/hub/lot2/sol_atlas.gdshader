shader_type spatial;
render_mode cull_back;
// Sol de Port-Franc (lot 2) : l'atlas a 4 cases (pavés, pierre, terre, herbe) ;
// on répète l'intérieur d'UNE case. UV0 = mètres / 4.
uniform sampler2D atlas_color : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D atlas_orm : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec2 tile_offset = vec2(0.0, 0.5);
uniform vec2 tile_size = vec2(0.5, 0.5);
uniform float inset = 0.01;
uniform float ao_strength = 0.6;
void fragment() {
	vec2 span = tile_size - vec2(inset * 2.0);
	vec2 coord = tile_offset + vec2(inset) + fract(UV) * span;
	// Dérivées calculées sans fract() : pas de couture visible au bord des répétitions.
	vec2 dx = dFdx(UV) * span;
	vec2 dy = dFdy(UV) * span;
	ALBEDO = textureGrad(atlas_color, coord, dx, dy).rgb;
	NORMAL_MAP = textureGrad(atlas_normal, coord, dx, dy).rgb;
	vec3 orm = textureGrad(atlas_orm, coord, dx, dy).rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = ao_strength;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
}
