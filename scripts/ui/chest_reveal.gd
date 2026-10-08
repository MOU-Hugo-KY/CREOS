class_name ChestReveal
extends Control
## Ouverture d'un coffre de fin de niveau (pack « Coffres et Esprits », assets/ui/coffres/) : le coffre
## fermé tremble, s'ouvre (12 images), les rayons de sa rareté jaillissent derrière, puis le panneau
## liste son contenu avec les icônes des Esprits. Un clic referme. Aussi : icônes des Esprits pour tout le jeu.

signal done

const DIR := "res://assets/ui/coffres/"
const COLORS := {"bois": Color("e0b070"), "fer": Color("8fb8ff"), "or": Color("ffd25a"), "serment": Color("d39bff")}

static var _data: Dictionary = {}

var _chest: Control
var _rays: Control
var _panel: Control
var _frames: Array = []  # [Texture2D, durée s]
var _ray_frames: Array = []
var _t := 0.0
var _ray_start := 0.0
var _playing := false


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DIR + "coffres.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text()) if f else {}
	return _data


static func tex(path: String) -> Texture2D:
	return load(DIR + path) if ResourceLoader.exists(DIR + path) else null


## Icône d'un Esprit (« esprit_petit_feu »), 64 ou 128 px ; null si ce n'est pas un Esprit.
static func esprit_icon(item: String, size := 64) -> Texture2D:
	if not item.begins_with("esprit_"):
		return null
	return tex("esprits/%s_%d.png" % [item, size])


## Cadre de rareté d'un Esprit (bois, fer, or, violet-or selon son stade).
static func esprit_frame(item: String) -> Texture2D:
	return tex("esprits/cadre_esprit_%s_64.png" % item.get_slice("_", 1))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and not _playing:
			visible = false
			done.emit())


## Montre l'ouverture du coffre `chest` ({kind, name, rewards}).
func show_chest(chest: Dictionary, name_of: Callable) -> void:
	for c in get_children():
		c.queue_free()
	var kind := String(chest.kind)
	var d: Dictionary = data().get("coffres", {}).get(kind, {})
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var root := ScreenPack.frame(self)
	var title := ScreenPack.text(root, String(chest.name).to_upper(), Rect2(560, 40, 800, 70), 48, COLORS.get(kind, UiKit.WHITE),
		HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 4)
	_frames = (d.get("ouverture", {}).get("frames", []) as Array).map(func(f: Dictionary) -> Array:
		return [tex(String(f.image)), float(f.duration_ms) / 1000.0])
	var eclat: Dictionary = d.get("eclat", {})
	_ray_frames = (eclat.get("frames", []) as Array).map(func(f: Dictionary) -> Array:
		return [tex(String(f.image)), float(f.duration_ms) / 1000.0])
	_ray_start = float(eclat.get("start_after_ms", 400)) / 1000.0
	# Coffre agrandi ×2 : pivot [128, 220] posé à (960, 560) ; rayons centrés sur la lumière [128, 135].
	_rays = TextureRect.new()
	_rays.size = Vector2(768, 768)
	_rays.position = Vector2(960 - 768 / 2.0, 600 - (220 - 135) * 2 - 768 / 2.0)
	_rays.stretch_mode = TextureRect.STRETCH_SCALE
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_rays)
	_chest = TextureRect.new()
	(_chest as TextureRect).texture = tex(String(d.get("ferme", "")))
	_chest.size = Vector2(512, 512)
	_chest.position = Vector2(960 - 256, 600 - 440)
	(_chest as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_chest)
	# Contenu, révélé à la fin de l'ouverture.
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.size = Vector2(1920, 1080)
	_panel.modulate.a = 0.0
	root.add_child(_panel)
	var keys: Array = chest.rewards.keys()
	var w := 150.0
	var x0 := 960.0 - keys.size() * w / 2.0
	for i in keys.size():
		var key: String = keys[i]
		var r := Rect2(x0 + i * w + 11, 700, 128, 128)
		ScreenPack.panel(_panel, "combat", "reward_slot", r)
		var frame := esprit_frame(key) if key.begins_with("esprit_") else null
		if frame:
			ScreenPack.image(_panel, frame, Rect2(r.position + Vector2(16, 10), Vector2(96, 96)))
		var icon := esprit_icon(key, 128)
		if icon == null:
			icon = ScreenPack.tex("combat", {"gold": "reward_gold_64", "gems": "reward_gems_64",
				"fragments_relique": "reward_relic_fragment_64"}.get(key, "reward_materials_64"))
		ScreenPack.image(_panel, icon, Rect2(r.position + Vector2(16, 10), Vector2(96, 96)))
		ScreenPack.text(_panel, "×%d" % int(chest.rewards[key]), Rect2(r.position.x, r.end.y - 34, r.size.x - 10, 30), 24,
			UiKit.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		ScreenPack.text(_panel, String(name_of.call(key, int(chest.rewards[key]))), Rect2(r.position.x - 20, r.end.y + 6, r.size.x + 40, 30), 19,
			UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	ScreenPack.text(_panel, "Touche pour continuer", Rect2(560, 900, 800, 40), 22, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_t = 0.0
	_playing = true
	visible = true


func _process(delta: float) -> void:
	if not visible or not _playing:
		return
	_t += delta
	# Ouverture du coffre.
	var acc := 0.0
	var shown: Texture2D = null
	for f: Array in _frames:
		acc += float(f[1])
		shown = f[0]
		if _t < acc:
			break
	if shown and _chest is TextureRect:
		(_chest as TextureRect).texture = shown
	# Rayons de rareté derrière le coffre (puis la dernière image reste).
	var rt := _t - _ray_start
	if rt >= 0.0 and not _ray_frames.is_empty():
		var racc := 0.0
		for f: Array in _ray_frames:
			racc += float(f[1])
			(_rays as TextureRect).texture = f[0]
			if rt < racc:
				break
	if _t >= acc:
		_playing = false
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.3)
