class_name SteleRoom
extends Control
## La Stèle des Fusions (pack « Jardin des Esprits », assets/ui/invocateurs/stele/) : 5 Esprits
## identiques posés sur les coupelles → 1 Esprit du stade suivant au sommet, contre de l'or.
## `show_offer()` pose l'Esprit choisi ; `ceremony(stade)` : les runes se chargent, les coupelles
## envoient leur lumière au sommet, éclat de la couleur du stade ; `show_result()` y fait apparaître
## l'Esprit obtenu. Flèche en bas à gauche : retour au Jardin (`previous_room`).

signal previous_room

var _P: Dictionary
var _runes: MageRoom.Sheet
var _fx: MageRoom.Sheet
var _add: CanvasItemMaterial
var _offer: Array[Control] = []
var _top: Control
var _shown: Array[CanvasItem] = []


static func available() -> bool:
	return ResourceLoader.exists(MageRoom.DIR + "stele/salle_stele.png")


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_P = DruidRoom.layout().get("positions", {}).get("stele", {})
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var bg := TextureRect.new()
	bg.texture = MageRoom.tex("stele/salle_stele.png")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_runes = _sheet("stele_repos")
	_runes.material = _add
	_runes.play("stele_repos")
	_fx = _sheet("stele_fusion")
	_fx.material = _add
	_fx.visible = false
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	var arrow := TextureButton.new()
	arrow.texture_normal = MageRoom.tex("stele/fleche_salle_precedente_normal.png")
	arrow.texture_hover = MageRoom.tex("stele/fleche_salle_precedente_survol.png")
	var ar: Array = _P.get("commandes", {}).get("precedente", [90, 900, 160, 120])
	arrow.position = Vector2(ar[0], ar[1])
	arrow.tooltip_text = "Jardin des Esprits"
	arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	arrow.pressed.connect(func() -> void: previous_room.emit())
	add_child(arrow)


## Pose l'Esprit `item` sur les 5 coupelles (grisées au-delà de `have`) et `up` au sommet.
func show_offer(item: String, have: int, up: String) -> void:
	_clear()
	if item == "":
		return
	var cups: Array = _P.get("coupelles", [])
	for i in cups.size():
		var feet := MageRoom._vec(cups[i].pieds_esprit)
		var ic := _icon(item, Rect2(feet - Vector2(52, 100), Vector2(104, 104)))
		if i >= have:
			ic.modulate = Color(0.12, 0.12, 0.18, 0.55)
		_offer.append(ic)
	var top := _top_rect()
	var res := _icon(up, Rect2(top.get_center() - Vector2(56, 56), Vector2(112, 112)))
	res.modulate = Color(1, 1, 1, 0.9) if have >= cups.size() else Color(0.35, 0.33, 0.42, 0.75)
	_offer.append(res)


## La fusion (~2,6 s) ; `stage` : stade obtenu (petit, grand, celeste) pour la couleur de l'éclat.
func ceremony(stage: String) -> void:
	for s in _shown:
		if is_instance_valid(s):
			s.queue_free()
	_shown.clear()
	_fx.visible = true
	_fx.play("stele_charge")
	await get_tree().create_timer(0.9).timeout
	_fx.play("stele_fusion")
	var top := _top_rect().get_center()
	for i in _offer.size() - 1:
		var c: Control = _offer[i]
		var tw := create_tween().set_parallel()
		tw.tween_property(c, "position", top - c.size / 2.0, 0.9).set_delay(0.2 + 0.05 * i).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(c, "modulate:a", 0.0, 0.3).set_delay(0.85 + 0.05 * i)
	if _offer.size() > 0:
		create_tween().tween_property(_offer[-1], "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(1.26).timeout
	var key := "eclat_stade_" + stage
	_fx.play(key if _fx.anims.has(key) else "eclat_stade_petit")
	await get_tree().create_timer(0.5).timeout


## L'Esprit obtenu apparaît dans la niche du sommet, avec sa quantité.
func show_result(up: String, count: int) -> void:
	_fx.finished.connect(func() -> void: _fx.visible = false, CONNECT_ONE_SHOT)
	var top: Dictionary = _P.get("sommet", {})
	var s := DruidRoom.spirit_sheet(up)
	if s:
		s.position = MageRoom._vec(top.get("pieds_esprit", [960, 410]))
		s.scale = Vector2.ONE * 0.75 * float(s.get_meta("scale")) / 2.3
		add_child(s)
		_shown.append(s)
		s.play("invocation")
	var l := ScreenPack.shadow(ScreenPack.text(self, "×%d %s" % [count, HeroesScreen.esprit_name(up, count > 1)],
		Rect2(_top_rect().position + Vector2(-220, -70), Vector2(600, 40)), 30, Color("ffd27a"), HORIZONTAL_ALIGNMENT_CENTER), 3)
	_shown.append(l)
	UiKit.pop_in(l, 0.3)


func reset() -> void:
	for s in _shown:
		if is_instance_valid(s):
			s.queue_free()
	_shown.clear()
	_fx.visible = false


func _clear() -> void:
	for c in _offer:
		c.queue_free()
	_offer.clear()


func _top_rect() -> Rect2:
	var r: Array = _P.get("sommet", {}).get("rect", [880, 260, 160, 160])
	return Rect2(r[0], r[1], r[2], r[3])


func _icon(item: String, r: Rect2) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = ChestReveal.esprit_icon(item, 128)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.position = r.position
	ic.size = r.size
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(ic)
	return ic


func _sheet(anim: String) -> MageRoom.Sheet:
	var s := MageRoom.Sheet.new()
	s.anims = DruidRoom.sheets()
	s.load_anim(anim)
	s.position = MageRoom._vec(s.anims.get(anim, {}).get("position", [560, 130]))
	add_child(s)
	return s
