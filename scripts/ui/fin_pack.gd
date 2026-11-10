class_name FinPack
extends RefCounted
## Pièces du pack « Finitions » (assets/ui/finitions/<écran>/, positions dans <écran>.json, repère
## 1920 × 1080) : textures, boîtes 9-slice, boutons à quatre états, jauges découpées, planches.

const DIR := "res://assets/ui/finitions/"

static var _json: Dictionary = {}
static var _tex: Dictionary = {}
static var _sober: Dictionary = {}

## Charte « pixel art sobre » (docs/charte_pixel_sobre.md) : les pièces dorées des packs (rubans, parchemins,
## cartouches, boutons) sont remplacées par des pièces dessinées ici, à gros pixels (P px), cadre fin, sans dorure.
const SOBER := false  # à remettre à true quand les fonds sobres seront là
const P := 4  # un pixel d'art = 4 px d'écran
const INK := Color("1c1b24")
const SOBER_KINDS := {  # couleur de fond, couleur du texte
	"ribbon": [Color("9c3f4a"), Color("f4ece0")],
	"paper": [Color("e9e0c9"), Color("1c1b24")],
	"pill": [Color("2b2d3a"), Color("f4ece0")],
	"teal": [Color("4fb3a5"), Color("ffffff")],
	"slate": [Color("4a5468"), Color("f4ece0")],
	"panel": [Color("2b2d3a"), Color("f4ece0")],
}


## Le genre sobre d'une pièce du pack (« » = on garde l'image d'origine).
static func sober_kind(path: String) -> String:
	if not SOBER:
		return ""
	var f := path.get_file().get_basename()
	if f.begins_with("bandeau_titre"):
		return "ribbon"
	if f.begins_with("parchemin") or f.begins_with("infobulle") or f.begins_with("toast"):
		return "paper"
	if f.begins_with("cartouche_monnaie") or f.begins_with("cartouche_ressource"):
		return "pill"
	if f.begins_with("tiroir_heros") or f.begins_with("panneau_rivaux"):
		return "panel"
	return ""


## Genre sobre d'un bouton du pack (`base` sans suffixe d'état).
static func sober_button_kind(base: String) -> String:
	if not SOBER:
		return ""
	var f := base.get_file()
	if f == "retour" or f == "fermer":
		return "slate"
	if f.begins_with("bouton_"):
		return "teal"
	return ""


## Texture d'une pièce sobre de `size` px. state : normal, hover, pressed, disabled.
## Fond uni, cadre d'encre d'un pixel, liseré clair en haut, ombre dure en bas.
static func sober_tex(kind: String, size: Vector2i, state := "normal") -> ImageTexture:
	var key := "%s|%d|%d|%s" % [kind, size.x, size.y, state]
	if _sober.has(key):
		return _sober[key]
	var w := maxi(size.x, 4 * P)
	var h := maxi(size.y, 4 * P)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base: Color = SOBER_KINDS.get(kind, SOBER_KINDS.slate)[0]
	if state == "hover":
		base = base.lightened(0.12)
	elif state == "pressed":
		base = base.darkened(0.12)
	elif state == "disabled":
		base = Color(0.42, 0.43, 0.47)
	var sh := 0 if state == "pressed" else P  # ombre dure sous la pièce
	var top := P if state == "pressed" else 0  # appuyé : la pièce descend d'un pixel
	var body := Rect2i(0, top, w, h - sh - top)
	if sh > 0:
		img.fill_rect(Rect2i(P, h - sh - P, w - P, sh + P), Color(INK, 0.5))
	img.fill_rect(body, INK)
	var inner := body.grow(-P)
	img.fill_rect(inner, base)
	if state != "pressed":
		img.fill_rect(Rect2i(inner.position, Vector2i(inner.size.x, P)), base.lightened(0.22))
	img.fill_rect(Rect2i(inner.position.x, inner.end.y - P, inner.size.x, P), base.darkened(0.18))
	var t := ImageTexture.create_from_image(img)
	_sober[key] = t
	return t


static func sober_text_color(kind: String) -> Color:
	return SOBER_KINDS.get(kind, SOBER_KINDS.slate)[1]


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
	if sober_kind(path) != "":
		t.texture = sober_tex(sober_kind(path), Vector2i(r.size))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = ScreenPack.filter_for(t.texture, r.size)
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
	var sk := sober_kind(path)
	if sk != "":
		np.texture = sober_tex(sk, Vector2i(12 * P, 12 * P))
		m = [3 * P, 3 * P, 3 * P, 4 * P]
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
	var sk := sober_button_kind(base)
	if sk != "":
		var sz := Vector2i(r.size)
		b.texture_normal = sober_tex(sk, sz)
		b.texture_hover = sober_tex(sk, sz, "hover")
		b.texture_pressed = sober_tex(sk, sz, "pressed")
		b.texture_disabled = sober_tex(sk, sz, "disabled")
		color = sober_text_color(sk)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_filter = ScreenPack.filter_for(b.texture_normal, r.size)
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
