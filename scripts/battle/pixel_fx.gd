class_name PixelFx
extends RefCounted
## Effets d'attaque en pixel art (pack pixelfx) — affichage seulement.
## data/pixelfx.json dit, pour chaque attaque, quel effet jouer et où ; les planches viennent de
## `node tools/export_pixelfx.mjs` (assets/pixelfx/). Chaque effet est un AnimatedSprite2D qui se libère seul.

const DATA_PATH := "res://data/pixelfx.json"
const DIR := "res://assets/pixelfx/"
const MAX_TARGET_SPAN := 4.5  # taille max d'un effet posé sur une cible, en hauteurs de cible
const HERO_PIXELS := 40.0  # hauteur d'un personnage pixelfx : sert à mettre l'effet à l'échelle du héros

const MONSTERS_PATH := "res://data/pixelfx_monsters.json"
const UI_PATH := "res://data/pixelfx_ui.json"

static var _data: Dictionary = {}
static var _monsters: Dictionary = {}
static var _ui: Dictionary = {}
static var _frames: Dictionary = {}  # clé de planche -> [SpriteFrames, info]


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data


## L'entrée de data/pixelfx.json pour cette attaque, ou {} s'il n'y en a pas.
static func entry(attack_id: String) -> Dictionary:
	return data().get("attacks", {}).get(attack_id, {})


static func _json(path: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return d if d is Dictionary else {}


## Effet d'une attaque de monstre, choisi par les règles de data/pixelfx_monsters.json (voir son "_doc").
## `def_id` : id du monstre dans data/monsters.json. Renvoie {} si ce n'est pas un monstre.
static func monster_entry(def_id: String, attack_id: String) -> Dictionary:
	if _monsters.is_empty():
		_monsters = _json(MONSTERS_PATH)
	var r := _monsters
	if r.get("ids", {}).has(attack_id):
		return r.ids[attack_id]
	var m: Dictionary = GameData.monsters.get(def_id, {})
	if m.is_empty():
		return {}
	var el := String(m.get("element", ""))
	var e: Dictionary = {}
	if attack_id.ends_with("_skill") and m.get("boss", false):
		e = r.get("regional_skill" if m.get("regional_boss", false) else "skill", {}).get(el, {})
	elif String(m.get("attack_kind", "")) == "magic":
		e = r.get("magic", {}).get(el, {})
	elif String(m.get("range", "")) == "ranged":
		e = r.get("ranged", {})
	else:
		var fam: Dictionary = r.get("families", {})
		e = fam.get(String(m.get("family", "")), fam.get("_default", {}))
	if e.is_empty():
		return {}
	e = e.duplicate()
	var pal := String(r.get("elements", {}).get(el, {}).get("pal", "none"))
	if not e.has("pal") and pal != "none":
		e.pal = pal
	return e


## Les choix d'effets d'interface (data/pixelfx_ui.json) : entrée (ou liste d'entrées) sous `key`.
static func ui_entry(key: String) -> Variant:
	if _ui.is_empty():
		_ui = _json(UI_PATH)
	return _ui.get(key, {})


## Joue l'effet d'interface `key` (data/pixelfx_ui.json) au point `pos` de `parent` : chaque entrée
## { fx, pal?, k (échelle entière), dx, dy, delay, speed, flip, alpha, max, z }. `kmul` multiplie k (entier) ;
## `index` (>= 0) : place parmi les enfants de `parent` (pour passer derrière un personnage) ; `wait` : attente en plus (s).
static func ui_play(parent: Node, key: String, pos: Vector2, kmul := 1, index := -1, wait := 0.0) -> void:
	var v: Variant = ui_entry(key)
	var list: Array = v if v is Array else ([v] if v is Dictionary and not (v as Dictionary).is_empty() else [])
	for e: Dictionary in list:
		var at := pos + Vector2(float(e.get("dx", 0)), float(e.get("dy", 0)))
		var k := float(int(e.get("k", 1)) * kmul)
		var go := func() -> void:
			if is_instance_valid(parent):
				var spr := spawn(parent, e, at, k, int(e.get("z", 5)))
				if spr and index >= 0:
					parent.move_child(spr, mini(index, parent.get_child_count() - 1))
		var delay := float(e.get("delay", 0.0)) + wait
		if delay > 0.0 and parent.is_inside_tree():
			parent.get_tree().create_timer(delay).timeout.connect(go)
		else:
			go.call()


## Échelle entière d'un effet de personnage pour une unité de `height` pixels.
static func unit_scale(height: float, size := 1.0) -> float:
	return maxf(1.0, roundf(clampf(height / HERO_PIXELS, 1.0, 4.0) * size))


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
	# Sur une cible, une grande planche (effet de zone joué sur chaque cible) ne dépasse pas
	# MAX_TARGET_SPAN fois la taille de la cible : sinon les anneaux et explosions se recouvrent.
	if at != "src":
		var span := maxf(float(info.size[0]), float(info.size[1]))
		k = minf(k, maxf(1.0, floorf(MAX_TARGET_SPAN * ref_h * float(e.get("size", 1.0)) / span)))
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


## Pose un effet pixelfx de décor (ou n'importe quel effet) : `e` = { fx, pal?, speed?, loop?, alpha?, flip? }.
## `k` = échelle (entière de préférence, pour garder les pixels nets). Un effet en boucle reste jusqu'à ce que
## son parent soit libéré ; sinon il se libère à la fin. Renvoie le sprite (ou null si la planche manque).
static func spawn(parent: Node, e: Dictionary, pos: Vector2, k := 1.0, z := 0) -> AnimatedSprite2D:
	var got := _load(_key(e))
	if got.is_empty():
		return null
	var info: Dictionary = got[1]
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = got[0]
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var flip := bool(e.get("flip", false))
	spr.flip_h = flip
	var px: float = info.pivot[0]
	spr.offset = Vector2(-(float(info.size[0]) - px) if flip else -px, -float(info.pivot[1]))
	spr.scale = Vector2(k, k)
	spr.position = pos
	spr.z_index = z
	spr.speed_scale = float(e.get("speed", 1.0))
	spr.modulate.a = float(e.get("alpha", 1.0))
	parent.add_child(spr)
	var loop: bool = bool(e.get("loop", info.get("loop", false))) and not bool(e.get("once", false))
	if e.has("max") and not loop:
		var tw := spr.create_tween()
		tw.tween_interval(maxf(0.0, float(e.max) - 0.25))
		tw.tween_property(spr, "modulate:a", 0.0, 0.25)
		tw.tween_callback(spr.queue_free)
	if loop:
		spr.animation_finished.connect(func() -> void: spr.play())
		spr.frame = randi() % maxi(1, int(info.frames))  # décalage : deux torches ne battent pas ensemble
	else:
		spr.animation_finished.connect(spr.queue_free)
	spr.play()
	return spr
