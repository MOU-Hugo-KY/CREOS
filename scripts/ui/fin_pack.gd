class_name FinPack
extends RefCounted
## Pièces du pack « Finitions » (assets/ui/finitions/<écran>/, positions dans <écran>.json, repère
## 1920 × 1080) : textures, boîtes 9-slice, boutons à quatre états, jauges découpées, planches.

const DIR := "res://assets/ui/finitions/"

static var _json: Dictionary = {}
static var _tex: Dictionary = {}


static func available(screen: String) -> bool:
	return FileAccess.file_exists(DIR + screen + "/" + screen + ".json")


static func data(screen: String) -> Dictionary:
	if not _json.has(screen):
		var f := FileAccess.open(DIR + screen + "/" + screen + ".json", FileAccess.READ)
		_json[screen] = JSON.parse_string(f.get_as_text()) if f else {}
	return _json[screen]


## `path` relatif au dossier finitions (« port_franc/ruban_haut.png ») ou au dossier de l'écran.
static func tex(path: String, screen := "") -> Texture2D:
	var full := DIR + (screen + "/" if screen != "" and not path.begins_with(screen + "/") else "") + path
	if not _tex.has(full):
		_tex[full] = load(full) if ResourceLoader.exists(full) else null
	return _tex[full]


static func rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


static func image(parent: Node, path: String, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = r.position
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	var c := ScreenPack.cover_behind(parent, t.texture, r)
	if c:
		t.set_meta("cover", c)
	return t


## Boîte 9-slice ; marges [gauche, haut, droite, bas].
static func nine(parent: Node, path: String, r: Rect2, m: Array) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = tex(path)
	np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if m.size() >= 4:
		np.patch_margin_left = int(m[0])
		np.patch_margin_top = int(m[1])
		np.patch_margin_right = int(m[2])
		np.patch_margin_bottom = int(m[3])
	np.position = r.position
	np.size = r.size
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(np)
	return np


## Marges 9-slice d'une image d'après le JSON de l'écran (clé « nine_slice »), sinon `fallback`.
static func margins(screen: String, path: String, fallback := [24, 24, 24, 24]) -> Array:
	var ns = data(screen).get("nine_slice", {})
	if ns is Dictionary:
		var v = ns.get(path, ns.get(screen + "/" + path, null))
		if v is Array:
			return v
		if v is Dictionary:
			if v.has("marges"):
				return v.marges
			if v.has("margins"):
				return v.margins
			if v.has("left"):
				return [v.left, v.top, v.right, v.bottom]
	return fallback


## Bouton à quatre états : `base` sans le suffixe (« port_franc/boutons/heros » →
## heros_normal / _survol / _appuye / _desactive).
static func button(parent: Node, base: String, r: Rect2, label := "", font := 26, color := Color("f3d9a0")) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex(base + "_normal.png")
	b.texture_hover = tex(base + "_survol.png")
	b.texture_pressed = tex(base + "_appuye.png")
	b.texture_disabled = tex(base + "_desactive.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = r.position
	b.size = r.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	if label != "":
		var l := ScreenPack.shadow(ScreenPack.text(b, label, Rect2(Vector2.ZERO, r.size), font, color, HORIZONTAL_ALIGNMENT_CENTER), 3)
		l.name = "Label"
	return b


## Jauge : fond 9-slice + remplissage découpé (pas étiré) selon `ratio` 0..1.
class Gauge extends Control:
	var fill: TextureRect
	var _w := 0.0

	func setup(back: String, back_rect: Rect2, back_m: Array, front: String, front_rect: Rect2) -> Gauge:
		position = back_rect.position
		size = back_rect.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		FinPack.nine(self, back, Rect2(Vector2.ZERO, back_rect.size), back_m)
		fill = TextureRect.new()
		fill.texture = FinPack.tex(front)
		fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fill.stretch_mode = TextureRect.STRETCH_TILE
		fill.position = front_rect.position - back_rect.position
		fill.size = front_rect.size
		fill.clip_contents = true
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_w = front_rect.size.x
		add_child(fill)
		return self

	func set_ratio(r: float) -> void:
		fill.size.x = roundf(_w * clampf(r, 0.0, 1.0))
		fill.visible = fill.size.x >= 1.0


## Planche horizontale (format générique des packs Finitions : file, frame_size, frame_count,
## durations_ms ou duration_ms, pivot, loop).
static func sheet(a: Dictionary) -> MageRoom.Sheet:
	var s := MageRoom.Sheet.new()
	s.base_dir = DIR
	var d := {"file": a.get("file", a.get("fichier", "")), "frame_size": a.get("frame_size", a.get("taille_image", [64, 64])),
		"frame_count": int(a.get("frame_count", a.get("nombre", a.get("frames", 1)))), "loop": bool(a.get("loop", a.get("boucle", false))),
		"pivot": a.get("pivot", [0, 0]), "duration_ms": int(a.get("duration_ms", a.get("duree_ms", 100)))}
	var durs = a.get("durations_ms", a.get("frame_durations_ms", null))
	if durs is Array:
		d["frame_durations_ms"] = durs
	s.anims = {"a": d}
	s.load_anim("a")
	return s
