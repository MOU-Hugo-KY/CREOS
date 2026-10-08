class_name TarotCard
extends Control
## Carte de tarot d'un héros (Loge des héros), pack « Arcanes » (assets/ui/arcanes/, positions dans
## arcanes.json). Repère 384 × 640, mis à l'échelle par `scale`. Fenêtre : décor arcane de l'élément
## (ou l'illustration du héros) puis le héros ; cadre de la rareté ; numéro romain dans le cartouche
## du haut, nom dans le ruban du bas, titre d'arcane dessous ; emblèmes dans les médaillons.
## Un héros pas encore recruté montre le dos de la carte.

const SIZE := Vector2(384, 640)
const WINDOW := Rect2(32, 112, 320, 400)
const FEET := Vector2(160, 344)  # pieds du héros dans la fenêtre
const DIR := "res://assets/ui/arcanes/"
const F := "fiche_heros"
const ELEMENT_KEYS := {"feu": "fire", "eau": "water", "nature": "nature", "lumiere": "light", "ombre": "shadow"}
const CLASS_KEYS := {"gardien": "guardian", "lame": "blade", "arcaniste": "arcanist", "traqueur": "tracker",
	"moine": "monk", "soutien": "support", "lancier": "lancer", "illusionniste": "illusionist", "automate": "automaton"}
const FRAMES := {2: "rare", 3: "epique", 4: "legendaire"}
## Couleur du titre d'arcane selon la rareté (métal du cadre).
const METAL := {2: Color("f0b878"), 3: Color("cfd8ff"), 4: Color("ffd860")}
const INK := Color("3a2430")

static var _arcanes: Dictionary = {}

var hero: Dictionary = {}
var owned := true
var content: Control  # la fenêtre (découpée) : décor, puis le héros
var _face: Control
var _back: TextureRect
var _shine: TextureRect


static func arcane(id: String) -> Dictionary:
	if _arcanes.is_empty():
		_arcanes = GameData.load_json("res://data/arcanes.json").get("arcanes", {})
	return _arcanes.get(id, {"number": "?", "title": ""})


static func pack_tex(path: String) -> Texture2D:
	return load(DIR + path) if ResourceLoader.exists(DIR + path) else null


## `still` : le héros en image fixe (ou son illustration) ; sinon la fenêtre garde seulement le décor
## et l'appelant pose un héros animé dans `content`.
func setup(h: Dictionary, is_owned: bool, still := true) -> TarotCard:
	hero = h
	owned = is_owned
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var id := String(h.get("id", ""))
	var rarity := int(h.get("rarity", 2))
	var elem := String(h.get("element", "ombre"))
	var shadow := _image(self, pack_tex("cartes/carte_ombre.png"), Rect2(Vector2(0, 30), SIZE))
	shadow.modulate.a = 0.8
	_face = Control.new()
	_face.size = SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)
	content = Control.new()
	content.position = WINDOW.position
	content.size = WINDOW.size
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(content)
	var illus := pack_tex("illustrations/%s.png" % id) if still else null
	if illus:
		_image(content, illus, Rect2(Vector2.ZERO, WINDOW.size))
	else:
		_image(content, pack_tex("cartes/fond_arcane_%s.png" % elem), Rect2(Vector2.ZERO, WINDOW.size))
		if still:
			_add_still_hero()
	_shine = _image(content, pack_tex("cartes/carte_brillance.png"), Rect2(-WINDOW.position - Vector2(SIZE.x, 0), SIZE))
	_shine.modulate.a = 0.0
	_image(_face, pack_tex("cartes/cadre_%s.png" % FRAMES.get(rarity, "rare")), Rect2(Vector2.ZERO, SIZE))
	var a := arcane(id)
	ScreenPack.text(_face, String(a.number), Rect2(120, 58, 144, 40), 28, INK, HORIZONTAL_ALIGNMENT_CENTER)
	ScreenPack.text(_face, String(h.get("name", "")).to_upper(), Rect2(104, 529, 176, 34), 24, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_emblem("classe_%s_64" % CLASS_KEYS.get(h.get("class"), "blade"), Vector2(46, 558))
	_emblem("element_%s_64" % ELEMENT_KEYS.get(elem, "shadow"), Vector2(338, 558))
	_back = _image(self, pack_tex("cartes/dos_carte.png"), Rect2(Vector2.ZERO, SIZE))
	set_face_up(owned)
	return self


func set_face_up(up: bool) -> void:
	_face.visible = up
	_back.visible = not up


## Reflet qui traverse la fenêtre (survol).
func shine() -> void:
	if _shine == null:
		return
	_shine.position.x = -WINDOW.position.x - SIZE.x
	_shine.modulate.a = 0.9
	var tw := create_tween()
	tw.tween_property(_shine, "position:x", -WINDOW.position.x + SIZE.x * 0.6, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_shine, "modulate:a", 0.0, 0.1)


## Retourne la carte (aplatie puis rouverte) ; `on_middle` est appelé quand elle est de profil.
func flip(on_middle: Callable = Callable(), duration := 0.32) -> void:
	pivot_offset = SIZE / 2.0
	var tw := create_tween()
	var sx := scale.x
	tw.tween_property(self, "scale:x", 0.0, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if on_middle.is_valid():
			on_middle.call())
	tw.tween_property(self, "scale:x", sx, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _add_still_hero() -> void:
	var sheet := PixelSheet.for_actor(String(hero.get("id", "")))
	if sheet == null or not sheet.anims.has("idle"):
		return
	var tex: Texture2D = sheet.anims.idle.frames[0][0]
	var body := sheet.body_rect()
	# Même règle que le combat (tailles égalisées) : ~2,8 pour un héros moyen, arrondi au demi.
	var k := clampf(roundf(780.0 / maxf(1.0, body.size.y) * 2.0) / 2.0, 2.0, 3.5)
	var art := _image(content, tex, Rect2(FEET - sheet.anchor * k, tex.get_size() * k))
	art.stretch_mode = TextureRect.STRETCH_SCALE


func _emblem(name: String, center: Vector2) -> void:
	var t := ScreenPack.trimmed(ScreenPack.tex(F, name))
	var ic := _image(_face, t, Rect2(center - Vector2(17, 17), Vector2(34, 34)))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _image(parent: Control, t: Texture2D, r: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr
