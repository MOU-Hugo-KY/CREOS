class_name RoundPortrait
extends TextureRect
## Portrait rond d'un héros, découpé dans son image d'aperçu (assets/heroes/<nom>/apercu.png),
## avec un anneau de la couleur de son élément.

const SHADER := """
shader_type canvas_item;
uniform vec4 ring_color : source_color = vec4(1.0);
uniform vec4 bg_color : source_color = vec4(0.2, 0.2, 0.25, 1.0);
uniform float grey = 0.0;
uniform float ring_width = 0.08;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = mix(bg_color.rgb, tex.rgb, tex.a);
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))) * 0.6, grey);
	c = mix(c, ring_color.rgb, smoothstep(1.0 - ring_width - 0.03, 1.0 - ring_width, r));
	COLOR = vec4(c, 1.0 - smoothstep(0.97, 1.0, r));
}
"""

static var _shader: Shader
static var _cache: Dictionary = {}  # chemin -> ImageTexture découpée


## `hero` : données de heroes.json (avec "model" et "element").
func setup(hero: Dictionary, diameter: float, ring := 0.08) -> RoundPortrait:
	custom_minimum_size = Vector2(diameter, diameter)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = portrait_texture(hero)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	var color := Palette.element_color(hero.get("element", ""))
	m.set_shader_parameter("ring_color", color)
	m.set_shader_parameter("bg_color", color.darkened(0.65))
	m.set_shader_parameter("ring_width", ring)
	material = m
	return self


func set_grey(on: bool) -> void:
	(material as ShaderMaterial).set_shader_parameter("grey", 1.0 if on else 0.0)


## Haut de l'image d'aperçu (la tête et le buste), découpé en carré.
## (Une vraie image découpée, pas une AtlasTexture : le masque rond du shader a besoin d'UV de 0 à 1.)
static func portrait_texture(hero: Dictionary) -> Texture2D:
	var path: String = String(hero.get("model", "")).get_base_dir() + "/apercu.png"
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var img: Image = (load(path) as Texture2D).get_image()
	var w := img.get_width()
	var crop := img.get_region(Rect2i(int(w * 0.24), int(w * 0.1), int(w * 0.52), int(w * 0.52)))
	var tex := ImageTexture.create_from_image(crop)
	_cache[path] = tex
	return tex
