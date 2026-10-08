class_name MageRoom
extends Control
## Salle du Mage runique (invocation de héros), pack « Invocateurs » (assets/ui/invocateurs/,
## positions dans invocateurs.json). Repère 1920 × 1080. Au repos : le mage respire, le cercle
## du sol luit et des runes montent doucement. `ceremony(rareté)` : le mage incante, le cercle du
## sol prend la couleur de la rareté, des cercles runiques s'ouvrent et tournent au-dessus, les
## runes jaillissent, puis éclats, colonne de lumière et flash d'apparition sur le cercle.

const DIR := "res://assets/ui/invocateurs/"
const COLORS := {2: "bleu", 3: "violet", 4: "or"}
const MAGE_SCALE := 1.6  # le mage du pack (~200 px) agrandi pour la salle
const COLUMNS := {2: "colonne_rune_rare", 3: "colonne_rune_epique", 4: "colonne_rune_legendaire"}

static var _data: Dictionary = {}

var hero_feet := Vector2(1080, 735)
var _circle_center := Vector2(1080, 710)
var _mage: Sheet
var _floor: TextureRect
var _floor_glow: TextureRect
var _front: Array[TextureRect] = []  # grand, moyen, petit (au-dessus du cercle)
var _staff_circle: TextureRect
var _fx: Dictionary = {}  # nom -> Sheet (éclats, colonnes, apparition)
var _runes: Array[Texture2D] = []
var _motes: Array = []  # [TextureRect, vitesse, dérive]
var _t := 0.0
var _casting := false
var _add: CanvasItemMaterial


static func available() -> bool:
	return ResourceLoader.exists(DIR + "mage/salle_mage.png")


static func data() -> Dictionary:
	if _data.is_empty():
		_data = GameData.load_json(DIR + "invocateurs.json")
	return _data


static func tex(path: String) -> Texture2D:
	return load(DIR + path) if ResourceLoader.exists(DIR + path) else null


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var room: Dictionary = data().get("salles", {}).get("mage", {})
	hero_feet = _vec(room.get("sol_heros", [1080, 735]))
	_circle_center = _vec(room.get("centre_cercle", [1080, 710]))
	_image(tex("mage/salle_mage.png"), Rect2(0, 0, 1920, 1080))
	# Cercle au sol (calque aplati) : or au repos, couleur de la rareté pendant l'invocation.
	_floor = _image(tex("mage/cercle_sol_perspective_or.png"), Rect2(_circle_center - Vector2(384, 128), Vector2(768, 256)))
	_floor.material = _add
	_floor_glow = _image(null, Rect2(_circle_center - Vector2(384, 128), Vector2(768, 256)))
	_floor_glow.material = _add
	_floor_glow.modulate.a = 0.0
	for i in 8:
		_runes.append(tex("mage/runes/rune_%02d.png" % (i + 1)))
	# Le mage, à gauche.
	_mage = _sheet("mage_repos")
	_mage.position = _vec(room.get("sol_personnage", [420, 830]))
	_mage.play("mage_repos")
	_mage.scale = Vector2.ONE * MAGE_SCALE
	# Cercles frontaux (cachés au repos), effets.
	var zone: Array = room.get("zone_apparition", [880, 310, 400, 430])
	var mid := Vector2(zone[0] + zone[2] / 2.0, zone[1] + zone[3] * 0.42)
	for s: int in [512, 256, 128]:
		var c := _image(null, Rect2(mid - Vector2(s, s) / 2.0, Vector2(s, s)))
		c.pivot_offset = Vector2(s, s) / 2.0
		c.material = _add
		c.visible = false
		_front.append(c)
	_staff_circle = _image(tex("mage/cercle_runique_petit_blanc.png"), Rect2(_mage.position + Vector2(30, -330), Vector2(128, 128)))
	_staff_circle.pivot_offset = Vector2(64, 64)
	_staff_circle.material = _add
	_staff_circle.visible = false
	for n: String in ["eclats_runiques", "apparition_finale"] + COLUMNS.values():
		var fx := _sheet(n)
		fx.position = hero_feet
		fx.material = _add
		fx.visible = false
		_fx[n] = fx


func _process(delta: float) -> void:
	_t += delta
	if not _casting:
		_floor.modulate.a = 0.45 + 0.2 * sin(_t * 1.6)
	for i in _front.size():
		_front[i].rotation += delta * (0.5 if i % 2 == 0 else -0.8) * (1.0 + i * 0.4)
	_staff_circle.rotation += delta * 1.6
	# Runes qui montent du cercle (peu au repos, beaucoup pendant l'incantation).
	if randf() < delta * (14.0 if _casting else 1.2):
		_spawn_rune()
	for m: Array in _motes.duplicate():
		var r: TextureRect = m[0]
		r.position.y -= m[1] * delta
		r.position.x += sin(_t * 2.0 + m[2]) * 10.0 * delta
		r.modulate.a -= delta * 0.35
		if r.modulate.a <= 0.0:
			r.queue_free()
			_motes.erase(m)


## Remet la salle au repos.
func reset() -> void:
	_casting = false
	_floor.texture = tex("mage/cercle_sol_perspective_or.png")
	_floor_glow.modulate.a = 0.0
	for c in _front:
		c.visible = false
	_staff_circle.visible = false
	for fx: Sheet in _fx.values():
		fx.visible = false
	_mage.play("mage_repos")


## L'invocation (~2,4 s), à attendre avec `await`.
func ceremony(rarity: int) -> void:
	var col: String = COLORS.get(rarity, "bleu")
	_casting = true
	_mage.play("mage_incantation", "mage_repos")
	_staff_circle.texture = tex("mage/cercle_runique_petit_%s.png" % col)
	_staff_circle.visible = false  # retiré : seuls les cercles au-dessus du grand cercle
	_floor.texture = tex("mage/cercle_sol_perspective_%s.png" % col)
	_floor_glow.texture = _floor.texture
	create_tween().tween_property(_floor_glow, "modulate:a", 0.9, 0.8)
	_floor.modulate.a = 1.0
	await get_tree().create_timer(0.35).timeout
	# Les cercles runiques s'ouvrent au-dessus du cercle du sol.
	var names := ["grand", "moyen", "petit"]
	for i in _front.size():
		var c := _front[i]
		c.texture = tex("mage/cercle_runique_%s_%s.png" % [names[i], col])
		c.visible = true
		c.scale = Vector2.ZERO
		c.modulate.a = 0.85
		create_tween().tween_property(c, "scale", Vector2.ONE, 0.45).set_delay(i * 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.55).timeout
	_play_fx("eclats_runiques")
	await get_tree().create_timer(0.25).timeout
	_play_fx(COLUMNS.get(rarity, COLUMNS[2]))
	await get_tree().create_timer(0.85).timeout
	for c in _front:
		create_tween().tween_property(c, "modulate:a", 0.0, 0.3)
	_play_fx("apparition_finale")
	await get_tree().create_timer(0.4).timeout
	_staff_circle.visible = false
	_casting = false


func _play_fx(name: String) -> void:
	var fx: Sheet = _fx.get(name)
	if fx:
		fx.visible = true
		fx.play(name)
		fx.finished.connect(func() -> void: fx.visible = false, CONNECT_ONE_SHOT)


func _spawn_rune() -> void:
	if _runes.is_empty():
		return
	var r := TextureRect.new()
	r.texture = _runes[randi() % _runes.size()]
	r.size = Vector2(32, 32)
	var a := randf() * TAU
	r.position = _circle_center + Vector2(cos(a) * 300.0, sin(a) * 80.0) - Vector2(16, 16)
	r.modulate = Color(1, 1, 1, 0.9)
	r.material = _add
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	_motes.append([r, randf_range(40.0, 90.0) * (2.0 if _casting else 1.0), randf() * TAU])


func _sheet(anim: String) -> Sheet:
	var s := Sheet.new()
	s.anims = data().get("animations", {})
	s.load_anim(anim)
	add_child(s)
	return s


func _image(t: Texture2D, r: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


static func _vec(a: Array) -> Vector2:
	return Vector2(a[0], a[1])


## Planche d'animation horizontale du pack (invocateurs.json : taille d'image, nombre, durées,
## pivot). Le nœud est placé sur le pivot (les pieds) ; `then` : animation enchaînée à la fin.
class Sheet extends Node2D:
	signal finished
	var anims: Dictionary = {}
	var _a: Dictionary = {}
	var _tex: Texture2D
	var _frame := 0
	var _acc := 0.0
	var _then := ""
	var _playing := false

	func load_anim(name: String) -> void:
		_a = anims.get(name, {})
		_tex = MageRoom.tex(String(_a.get("file", "")).trim_prefix(""))
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func play(name: String, then := "") -> void:
		load_anim(name)
		_then = then
		_frame = 0
		_acc = 0.0
		_playing = true
		queue_redraw()

	func _process(delta: float) -> void:
		if not _playing or _a.is_empty():
			return
		_acc += delta * 1000.0
		var durs: Array = _a.get("frame_durations_ms", [])
		var count := int(_a.get("frame_count", 1))
		var d := float(durs[_frame]) if _frame < durs.size() else float(_a.get("duration_ms", 100))
		while _acc >= d:
			_acc -= d
			_frame += 1
			if _frame >= count:
				if bool(_a.get("loop", false)):
					_frame = 0
				else:
					_frame = count - 1
					_playing = false
					finished.emit()
					if _then != "":
						play(_then)
					return
			d = float(durs[_frame]) if _frame < durs.size() else float(_a.get("duration_ms", 100))
		queue_redraw()

	func _draw() -> void:
		if _tex == null or _a.is_empty():
			return
		var fs := Vector2(_a.frame_size[0], _a.frame_size[1])
		var pivot := Vector2(_a.pivot[0], _a.pivot[1])
		draw_texture_rect_region(_tex, Rect2(-pivot, fs), Rect2(Vector2(_frame * fs.x, 0), fs))
