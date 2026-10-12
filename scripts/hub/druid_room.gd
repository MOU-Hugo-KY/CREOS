class_name DruidRoom
extends Control
## Le Jardin des Esprits (appels d'Esprits, pack « Jardin des Esprits », assets/ui/invocateurs/jardin/,
## positions dans jardin_esprits.json). Repère 1920 × 1080. Au repos : la gardienne à la lanterne
## respire, des lucioles flottent. `ceremony(éléments)` : elle lève sa lanterne, les lueurs montent
## vers le berceau-fleur, les coins des éléments s'éveillent, la fleur s'ouvre ; `show_esprits()` fait
## apparaître l'Esprit le plus rare (animation d'invocation, pack « Esprits Invocations ») puis la
## liste de ce qui est sorti. La flèche en bas à droite mène à la Stèle des Fusions (`next_room`).

signal next_room

const JDIR := MageRoom.DIR
const ESPRITS_DIR := MageRoom.DIR + "esprits/"

var altar := Vector2(960, 740)
var spirit_feet := Vector2(960, 740)
var _bg: TextureRect
var _keeper: MageRoom.Sheet
var _glows: MageRoom.Sheet
var _nest: MageRoom.Sheet
var _corners: Dictionary = {}  # élément -> Sheet
var _add: CanvasItemMaterial
var _dim: ColorRect
var _flies: Array = []  # [ColorRect, phase, centre]
var _t := 0.0
var _shown: Array[CanvasItem] = []


static func available() -> bool:
	return ResourceLoader.exists(JDIR + "jardin/jardin_esprits.png")


static func layout() -> Dictionary:
	var f := FileAccess.open(JDIR + "jardin_esprits.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}


## Les planches du pack (schéma en français) au format de MageRoom.Sheet.
static func sheets() -> Dictionary:
	var out := {}
	var P: Dictionary = layout().get("planches", {})
	for k: String in P:
		var p: Dictionary = P[k]
		out[k] = {"file": p.fichier, "frame_size": p.taille_image, "frame_count": int(p.nombre),
			"duration_ms": int(p.duree_ms), "loop": bool(p.boucle), "pivot": p.pivot, "position": p.position}
	return out


## Animation d'invocation d'un Esprit (`esprit_<stade>_<élément>`) : un Sheet prêt à jouer
## « invocation », pieds au point d'origine ; null si l'animation manque.
static func spirit_sheet(item: String) -> MageRoom.Sheet:
	var key := item.trim_prefix("esprit_")
	var f := FileAccess.open(ESPRITS_DIR + "invocations.json", FileAccess.READ)
	if f == null:
		return null
	var a: Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary).get("animations", {}).get(key, {})
	if a.is_empty() or not ResourceLoader.exists(ESPRITS_DIR + key + ".png"):
		return null
	var s := MageRoom.Sheet.new()
	s.base_dir = ESPRITS_DIR
	s.anims = {"invocation": {"file": key + ".png", "frame_size": a.taille_image, "frame_count": int(a.images),
		"frame_durations_ms": a.durees_ms, "loop": false, "pivot": a.pivot}}
	s.set_meta("scale", float(a.get("echelle_jardin", 3.0)))
	return s


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var J: Dictionary = layout().get("positions", {}).get("jardin", {})
	altar = MageRoom._vec(J.get("nid", {}).get("pieds_esprit", [960, 740]))
	spirit_feet = altar
	_bg = TextureRect.new()
	_bg.texture = MageRoom.tex("jardin/jardin_esprits.png")
	_bg.size = size
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.06, 0.0)
	_dim.size = size
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	for elem: String in Progression.ELEMENTS:
		var s := _sheet("eveil_" + elem)
		s.material = _add
		s.visible = false
		_corners[elem] = s
	_nest = _sheet("nid_ouverture")
	_nest.visible = false
	_glows = _sheet("lueurs_montantes")
	_glows.material = _add
	_glows.visible = false
	_keeper = _sheet("gardien_repos")
	_keeper.play("gardien_repos")
	for i in 30:
		var f := ColorRect.new()
		f.size = Vector2(3, 3)
		f.color = [Color("d8ff8a"), Color("ffe08a"), Color("9fe8ff")][i % 3]
		f.material = _add
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(f)
		_flies.append([f, randf() * TAU, Vector2(randf_range(120, 1500), randf_range(200, 900))])
	# Flèche vers la Stèle des Fusions.
	var arrow := TextureButton.new()
	arrow.texture_normal = MageRoom.tex("jardin/fleche_salle_suivante_normal.png")
	arrow.texture_hover = MageRoom.tex("jardin/fleche_salle_suivante_survol.png")
	var ar: Array = J.get("fleche_suivante", {}).get("rect", [1700, 930, 160, 120])
	arrow.position = Vector2(ar[0], ar[1])
	arrow.tooltip_text = "Stèle des Fusions"
	arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arrow.pressed.connect(func() -> void: next_room.emit())
	add_child(arrow)


func _process(delta: float) -> void:
	_t += delta
	for fl: Array in _flies:
		var f: ColorRect = fl[0]
		var ph: float = fl[1]
		f.position = fl[2] + Vector2(cos(_t * 0.5 + ph) * 40.0, sin(_t * 0.8 + ph * 1.7) * 26.0)
		f.modulate.a = 0.35 + 0.65 * maxf(0.0, sin(_t * 2.0 + ph))


func reset() -> void:
	for c in _shown:
		if is_instance_valid(c):
			c.queue_free()
	_shown.clear()
	for s: MageRoom.Sheet in _corners.values():
		s.visible = false
	_nest.visible = false
	_glows.visible = false
	_bg.texture = MageRoom.tex("jardin/jardin_esprits.png")
	_dim.color.a = 0.0
	_keeper.play("gardien_repos")


## L'appel (~2,5 s) ; `elements` : les éléments des Esprits obtenus (leurs coins s'éveillent).
func ceremony(elements: Array) -> void:
	reset()
	create_tween().tween_property(_dim, "color:a", 0.35, 0.4)
	_keeper.play("gardien_appel", "gardien_repos")
	await get_tree().create_timer(0.45).timeout
	_glows.visible = true
	_glows.play("lueurs_montantes")
	var seen := {}
	for e: String in elements:
		if seen.has(e) or not _corners.has(e):
			continue
		seen[e] = true
		var s: MageRoom.Sheet = _corners[e]
		s.visible = true
		s.play("eveil_" + e)
	await get_tree().create_timer(0.8).timeout
	_glows.visible = false
	# La fleur du décor est remplacée par la planche qui s'ouvre (elle reste ouverte ensuite).
	_bg.texture = MageRoom.tex("jardin/jardin_sans_nid.png")
	_nest.visible = true
	_nest.play("nid_ouverture")
	await get_tree().create_timer(1.2).timeout
	create_tween().tween_property(_dim, "color:a", 0.0, 0.5)


## L'Esprit le plus rare jaillit de la fleur, puis la rangée de tout ce qui est sorti apparaît en haut.
func show_esprits(got: Dictionary) -> void:
	var ids := got.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return Progression.ESPRIT_STAGES.find(a.get_slice("_", 1)) > Progression.ESPRIT_STAGES.find(b.get_slice("_", 1)))
	if ids.is_empty():
		return
	var hero := spirit_sheet(ids[0])
	if hero:
		hero.position = spirit_feet
		hero.scale = Vector2.ONE * float(hero.get_meta("scale"))
		add_child(hero)
		_shown.append(hero)
		hero.play("invocation")
		await get_tree().create_timer(1.4).timeout
		if not is_instance_valid(hero):
			return
	var w := 150.0
	var per_row := mini(ids.size(), 8)
	for i in ids.size():
		var id: String = ids[i]
		var row := i / per_row
		var col := i % per_row
		var n_row := mini(per_row, ids.size() - row * per_row)
		var box := Control.new()
		box.position = Vector2(altar.x - n_row * w / 2.0 + col * w, 172 + row * 176)
		box.size = Vector2(w, 170)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_shown.append(box)
		var frame := TextureRect.new()
		frame.texture = ChestReveal.esprit_frame(id)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.position = Vector2(w / 2.0 - 48, 0)
		frame.size = Vector2(96, 96)
		box.add_child(frame)
		var ic := TextureRect.new()
		ic.texture = ChestReveal.esprit_icon(id, 128)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.position = Vector2(w / 2.0 - 40, 8)
		ic.size = Vector2(80, 80)
		box.add_child(ic)
		ScreenPack.shadow(ScreenPack.text(box, "×%d" % int(got[id]), Rect2(0, 96, w, 32), 26, Color("ffd27a"),
			HORIZONTAL_ALIGNMENT_CENTER), 3)
		ScreenPack.shadow(ScreenPack.text(box, HeroesScreen.esprit_name(id, int(got[id]) > 1), Rect2(-10, 128, w + 20, 30), 16,
			UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
		UiKit.pop_in(box, 0.06 * i)


func _sheet(anim: String) -> MageRoom.Sheet:
	var s := MageRoom.Sheet.new()
	s.anims = sheets()
	s.load_anim(anim)
	var a: Dictionary = s.anims.get(anim, {})
	if a.has("position"):
		s.position = MageRoom._vec(a.position)
	add_child(s)
	return s
