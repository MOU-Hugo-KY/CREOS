class_name PixelFx
extends RefCounted
## Effets d'attaque en pixel art (pack pixelfx) — affichage seulement.
## data/pixelfx.json dit, pour chaque attaque, quel effet jouer et où ; les planches viennent de
## `node tools/export_pixelfx.mjs` (assets/pixelfx/). Chaque effet est un AnimatedSprite2D qui se libère seul.

const DATA_PATH := "res://data/pixelfx.json"
const DIR := "res://assets/pixelfx/"
const HERO_PIXELS := 40.0  # hauteur d'un personnage pixelfx : sert à mettre l'effet à l'échelle du héros

static var _data: Dictionary = {}
static var _frames: Dictionary = {}  # clé de planche -> [SpriteFrames, info]


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


## L'entrée de data/pixelfx.json pour cette attaque, ou {} s'il n'y en a pas.
static func entry(attack_id: String) -> Dictionary:
	return data().get("attacks", {}).get(attack_id, {})


static func _key(e: Dictionary) -> String:
	return String(e.fx).replace("/", "-") + ("-" + String(e.pal) if e.has("pal") else "")


static func _load(key: String) -> Array:
	if _frames.has(key):
		return _frames[key]
	var out: Array = []
	if FileAccess.file_exists(DIR + key + ".json") and ResourceLoader.exists(DIR + key + ".png"):
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + key + ".json"))
		var tex: Texture2D = load(DIR + key + ".png")
		var sf := SpriteFrames.new()
		sf.set_animation_loop("default", false)
		sf.set_animation_speed("default", float(info.fps))
		var w: int = info.size[0]
		var h: int = info.size[1]
		var cols: int = info.columns
		for i in int(info.frames):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((i % cols) * w, (i / cols) * h, w, h)
			sf.add_frame("default", at)
		out = [sf, info]
	_frames[key] = out
	return out


## Joue l'effet de l'attaque. `src_pos` / `src_height` : l'attaquant ; `feet` / `chest` / `height` : la cible.
## `face_left` : l'attaquant regarde vers la gauche (l'effet est retourné). Renvoie false s'il n'y a pas d'effet.
static func play(parent: Node, e: Dictionary, src_pos: Vector2, src_height: float, feet: Vector2, chest: Vector2,
		height: float, face_left: bool) -> bool:
	if e.is_empty():
		return false
	var got := _load(_key(e))
	if got.is_empty():
		return false
	var info: Dictionary = got[1]
	var at := String(e.get("at", "target"))
	var ref_h := src_height if at == "src" else height
	# échelle entière (pixels nets), à la taille du héros
	var k := maxf(1.0, roundf(clampf(ref_h / HERO_PIXELS, 1.0, 4.0) * float(e.get("size", 1.0))))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = got[0]
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.flip_h = face_left
	var px: float = info.pivot[0]
	spr.offset = Vector2(-(float(info.size[0]) - px) if face_left else -px, -float(info.pivot[1]))
	spr.scale = Vector2(k, k)
	spr.position = src_pos if at == "src" else (feet if at == "feet" else chest)
	spr.z_index = 60
	spr.speed_scale = float(e.get("speed", 1.0))
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	spr.material = mat
	parent.add_child(spr)
	spr.play()
	spr.animation_finished.connect(spr.queue_free)
	if e.has("max"):
		var tw := spr.create_tween()
		tw.tween_interval(maxf(0.0, float(e.max) - 0.25))
		tw.tween_property(spr, "modulate:a", 0.0, 0.25)
		tw.tween_callback(spr.queue_free)
	return true
