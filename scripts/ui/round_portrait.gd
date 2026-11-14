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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if PixelSheet.enabled else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	var head := pixel_head(String(hero.get("id", "")))
	if head:
		return head
	var direct := String(hero.get("portrait", ""))
	if direct.begins_with("res://") and ResourceLoader.exists(direct):
		return load(direct)
	if hero.has("puppet"):
		return _puppet_portrait(String(hero.puppet))
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


## Héros dessinés en 2D : la tête découpée dans leur fiche (`portrait` = [x, y, côté] dans puppet.json).
static func _puppet_portrait(folder: String) -> Texture2D:
	if _cache.has(folder):
		return _cache[folder]
	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("puppet.json")))
	var fiche := folder.path_join("fiche.png")
	if not (cfg is Dictionary) or not ResourceLoader.exists(fiche):
		return null
	var r: Array = cfg.get("portrait", [200, 40, 600])
	var img: Image = (load(fiche) as Texture2D).get_image()
	var tex := ImageTexture.create_from_image(img.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[2]))))
	_cache[folder] = tex
	return tex


## Tête tirée du sprite de combat pixel (première image de repos) : un carré centré sur le haut du
## personnage (le centre des rangées du haut, pas de toute la silhouette : capes et armes décalent).
static func pixel_head(id: String) -> Texture2D:
	if id == "":
		return null
	var key := "px:" + id
	if _cache.has(key):
		return _cache[key]
	var sheet := PixelSheet.for_actor(id)
	if sheet == null or not sheet.anims.has("idle"):
		_cache[key] = null
		return null
	var img: Image = (sheet.anims.idle.frames[0][0] as Texture2D).get_image()
	var used := sheet.frame_rect(sheet.anims.idle.frames[0][0])
	var h := used.size.y
	# Axe du corps : le milieu des pieds ; la tête : le haut de la silhouette, près de cet axe.
	var feet := 0.0
	var n := 0
	for y in range(maxi(used.position.y, used.end.y - 10), used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.5:
				feet += x
				n += 1
	feet = feet / maxi(1, n) if n > 0 else used.get_center().x
	var head := 0.0
	var m := 0
	for y in range(used.position.y + int(h * 0.12), used.position.y + int(h * 0.4)):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.5 and absf(x - feet) < h * 0.26:
				head += x
				m += 1
	var cx := int(((head / m) + feet) / 2.0) if m > 0 else int(feet)
	var side := clampi(int(h * 0.74), 32, img.get_height())
	var region := Rect2i(clampi(cx - side / 2, 0, img.get_width() - side), maxi(0, used.position.y - 3), side, side)
	var tex := ImageTexture.create_from_image(img.get_region(region))
	_cache[key] = tex
	return tex
