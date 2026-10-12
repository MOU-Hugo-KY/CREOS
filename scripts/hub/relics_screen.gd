class_name RelicsScreen
extends UiWindow
## Les reliques anciennes des 19 héros (une par héros, 5 paliers) et les 4 quatuors (attaque
## combinée quand les quatre membres sont dans l'équipe et ont chacun lancé leur ultime).
## Toucher une relique ouvre la fiche du héros sur l'onglet Relique.

signal ui_sound(sfx_name: String)
signal hero_relic_requested(hero_id: String)

var _grid: GridContainer
var _quartets: VBoxContainer
var _tab := "Reliques"
var _tabs: HBoxContainer
var _relic_scroll: ScrollContainer
var _quartet_scroll: ScrollContainer
var _quartet_page: Control  # écran Quatuors en pixel (pack partie 2, assets/ui/ecrans/quatuors)
var _quartet_box: Control
var _q_title: Label
var _q_desc: Label
var _reliquary: Control  # le Reliquaire en plein écran (pack « Échoppe et Reliquaire »)
var _niches: Control
var _lectern: Label
var _lectern_sub: Label


func _init() -> void:
	setup("Reliques et quatuors", Vector2(1460, 880))


func _ready() -> void:
	super._ready()
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	content.add_child(_tabs)
	_relic_scroll = ScrollContainer.new()
	_relic_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_relic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_relic_scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_relic_scroll.add_child(_grid)
	_quartet_scroll = ScrollContainer.new()
	_quartet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quartet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_quartet_scroll)
	_quartets = VBoxContainer.new()
	_quartets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quartets.add_theme_constant_override("separation", 14)
	_quartet_scroll.add_child(_quartets)
	_build_quartet_page()
	_build_reliquary()
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


const Q := "quatuors"


## Table des Quatuors (pack « Table des Quatuors ») : salle du conseil, 4 formations posées sur
## la table ; chaque formation = un blason (allumé si les quatre héros sont recrutés), 4 médaillons
## reliés par des fils, et le parchemin du bas décrit la formation survolée.
func _build_quartet_page() -> void:
	_quartet_page = Control.new()
	_quartet_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quartet_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_quartet_page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_quartet_page)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quartet_page.add_child(bg)
	var root := ScreenPack.frame(_quartet_page)
	var T: Dictionary = ShopScreen.L().get("quatuors", {})
	ScreenPack.image(root, _rtex(String(T.get("background", "quatuors/table_quatuors_fond.png"))), Rect2(0, 0, 1920, 1080))
	_quartet_box = Control.new()
	_quartet_box.size = Vector2(1920, 1080)
	_quartet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_quartet_box)
	var back := TextureButton.new()
	back.texture_normal = _rtex("commun/retour_normal.png")
	back.texture_hover = _rtex("commun/retour_survol.png")
	back.texture_pressed = _rtex("commun/retour_appuye.png")
	var br := _r(T.get("return_rect", [40, 30, 220, 80]))
	back.position = br.position
	back.size = br.size
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_SCALE
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_tab = "Reliques"
		refresh())
	root.add_child(back)
	ScreenPack.shadow(ScreenPack.text(back, "Reliques", Rect2(64, 0, 150, br.size.y), 24, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var tr := _r(T.get("title_rect", [610, 24, 700, 90]))
	root.add_child(_nine("commun/bandeau_titre.png", [130, 24, 130, 28], tr))
	ScreenPack.shadow(ScreenPack.text(root, "TABLE DES QUATUORS", Rect2(tr.position + Vector2(0, 24), Vector2(tr.size.x, 36)), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	# Parchemin agrandi pour que la description se lise bien.
	var dr := Rect2(300, 836, 1320, 236)
	root.add_child(_nine("quatuors/parchemin_quatuor.png", [140, 24, 140, 24], dr))
	var wr := Rect2(470, 866, 980, 180)
	_q_title = ScreenPack.text(root, "", Rect2(wr.position, Vector2(wr.size.x, 34)), 25, Color("793b49"), HORIZONTAL_ALIGNMENT_CENTER)
	_q_desc = ScreenPack.text(root, "", Rect2(wr.position + Vector2(0, 40), Vector2(wr.size.x, wr.size.y - 44)), 19, UiKit.INK,
		HORIZONTAL_ALIGNMENT_CENTER, true)


func _nine(path: String, m: Array, r: Rect2) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = _rtex(path)
	np.patch_margin_left = m[0]
	np.patch_margin_top = m[1]
	np.patch_margin_right = m[2]
	np.patch_margin_bottom = m[3]
	np.position = r.position
	np.size = r.size
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np


func _fill_quartet_page() -> void:
	for c in _quartet_box.get_children():
		_quartet_box.remove_child(c)
		c.queue_free()
	var forms: Dictionary = ShopScreen.L().get("quatuors", {}).get("formations", {})
	_describe_quartet("")
	for fid: String in forms:
		var f: Dictionary = forms[fid]
		var q: Dictionary = GameData.quartets().get(fid, {})
		var complete := true
		for m: Dictionary in f.medallions:
			if not PlayerData.state.heroes.has(String(m.hero)):
				complete = false
		# Fils entre les médaillons (allumés si la formation est complète).
		for l: Dictionary in f.links:
			var a := Vector2(l.from[0], l.from[1])
			var b := Vector2(l.to[0], l.to[1])
			var w := _nine("quatuors/fil_liaison.png", [24, 6, 24, 6], Rect2(Vector2.ZERO, Vector2(a.distance_to(b), 24)))
			w.position = a + Vector2(0, -12).rotated(a.angle_to_point(b))
			w.rotation = a.angle_to_point(b)
			w.modulate = Color(1.2, 1.1, 0.8) if complete else Color(0.55, 0.5, 0.5, 0.6)
			_quartet_box.add_child(w)
		for m: Dictionary in f.medallions:
			var hid := String(m.hero)
			var owned: bool = PlayerData.state.heroes.has(hid)
			ScreenPack.image(_quartet_box, _rtex("quatuors/siege_heros_%s.png" % ("present" if owned else "vide")), _r(m.rect))
			var pr := _r(m.portrait_rect)
			var portrait := RoundPortrait.new().setup(GameData.hero(hid), pr.size.x)
			portrait.position = pr.position
			portrait.size = pr.size
			portrait.set_grey(not owned)
			if not owned:
				portrait.modulate.a = 0.55
			portrait.tooltip_text = String(GameData.hero(hid).get("name", hid)) + ("" if owned else " · à recruter")
			_quartet_box.add_child(portrait)
		var crest := ScreenPack.image(_quartet_box, _rtex("quatuors/blason_%s_%s.png" % [fid, "allume" if complete else "eteint"]),
			_r(f.crest.rect))
		crest.mouse_filter = Control.MOUSE_FILTER_STOP
		crest.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		crest.mouse_entered.connect(_describe_quartet.bind(fid))
		ScreenPack.shadow(ScreenPack.text(_quartet_box, String(q.get("name", f.name)),
			Rect2(_r(f.crest.rect).get_center() + Vector2(-220, -96), Vector2(440, 30)), 21, Color("fff1cf") if complete else Color("cbbfae"),
			HORIZONTAL_ALIGNMENT_CENTER), 2)
		if complete:
			var spark := MageRoom.Sheet.new()
			spark.base_dir = RDIR
			spark.anims = {"etincelle": {"file": "quatuors/etincelle_quatuor.png", "frame_size": [256, 256], "frame_count": 10,
				"frame_durations_ms": [100, 100, 100, 90, 90, 110, 100, 100, 110, 140], "loop": false, "pivot": [128, 128]}}
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			spark.material = mat
			spark.position = _r(f.crest.rect).get_center()
			_quartet_box.add_child(spark)
			spark.play("etincelle")
			spark.finished.connect(func() -> void: spark.visible = false, CONNECT_ONE_SHOT)


## Le parchemin du bas : la formation survolée (ou une aide si rien n'est survolé).
func _describe_quartet(fid: String) -> void:
	if fid == "":
		_q_title.text = "Quatre héros, une attaque"
		_q_desc.text = "Les quatre membres dans l'équipe, chacun lance son ultime : l'attaque combinée se débloque. Survole un blason."
		return
	var q: Dictionary = GameData.quartets().get(fid, {})
	var names: Array = (q.get("members", []) as Array).map(func(h: String) -> String: return String(GameData.hero(h).get("name", h)))
	_q_title.text = "%s · %s" % [q.get("name", fid), q.get("attack", "")]
	_q_desc.text = " · ".join(names) + "
" + String(q.get("effect", "")).get_slice(".", 0) + "."


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for t: String in ["Reliques", "Quatuors"]:
		var b := UiKit.button(t, "red" if t == _tab else "wood", 20, Vector2(200, 52))
		var tab := t
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_tab = tab
			refresh())
		_tabs.add_child(b)
	_relic_scroll.visible = false
	_reliquary.visible = _tab == "Reliques"
	if _tab == "Reliques":
		_fill_reliquary()
		return
	_quartet_scroll.visible = false
	_quartet_page.visible = _tab == "Quatuors"
	for c in _grid.get_children():
		c.queue_free()
	for c in _quartets.get_children():
		c.queue_free()
	if _tab == "Reliques":
		for id: String in GameData.heroes:
			_grid.add_child(_relic_card(id))
	else:
		_fill_quartet_page()


func _relic_card(id: String) -> Control:
	var relic: Dictionary = GameData.relics.get("relics", {}).get(id, {})
	var tier := PlayerData.relic_tier(id)
	var owned: bool = PlayerData.state.heroes.has(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UiKit.card(UiKit.WOOD_LIGHT if tier > 0 else Color.TRANSPARENT)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var img := TextureRect.new()
	var icon := String(relic.get("sprite", ""))
	img.texture = load(icon) if ResourceLoader.exists(icon) else null
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(0, 130)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tier == 0:
		img.modulate = Color(0.3, 0.28, 0.33)
	v.add_child(img)
	var n := UiKit.label(String(relic.get("name", id)), 16, UiKit.INK)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(n)
	var hero_name := String(GameData.hero(id).get("short", id))
	var st_text := "%s · %s" % [hero_name, "◆".repeat(tier) + "◇".repeat(5 - tier)]
	if tier == 0:
		st_text = "%s · %d / 100 fragments" % [hero_name, PlayerData.relic_fragments(id)]
	if not PlayerData.relics_unlocked():
		st_text = "%s · scellée" % hero_name
		b.tooltip_text = "Les reliques s'éveillent après la Campagne 1 (dernier niveau du monde 10)."
	var s := UiKit.label(st_text, 15, UiKit.WOOD if owned else UiKit.TEXT_SOFT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	b.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		hero_relic_requested.emit(id))
	return b


# --- Le Reliquaire --------------------------------------------------------------------------

const RDIR := "res://assets/ui/echoppe/"


func _rtex(path: String) -> Texture2D:
	return load(RDIR + path) if ResourceLoader.exists(RDIR + path) else null


func _r(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


## Crypte aux 19 niches (une par héros, dans l'ordre du jeu), lutrin à droite pour le détail de la
## relique survolée. Toucher une niche ouvre la fiche du héros sur l'onglet Relique.
func _build_reliquary() -> void:
	_reliquary = Control.new()
	_reliquary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reliquary.mouse_filter = Control.MOUSE_FILTER_STOP
	_reliquary.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_reliquary)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reliquary.add_child(bg)
	var root := ScreenPack.frame(_reliquary)
	var R: Dictionary = ShopScreen.L().get("reliquaire", {})
	ScreenPack.image(root, _rtex(String(R.get("background", "reliquaire/reliquaire_fond.png"))), Rect2(0, 0, 1920, 1080))
	var dust := MageRoom.Sheet.new()
	dust.base_dir = RDIR
	dust.anims = {"poussiere": {"file": "reliquaire/poussiere_lumiere.png", "frame_size": [384, 384], "frame_count": 8,
		"duration_ms": 180, "loop": true, "pivot": [0, 0]}}
	dust.position = Vector2(500, 120)
	dust.scale = Vector2(2, 2)
	dust.modulate.a = 0.16
	root.add_child(dust)
	dust.play("poussiere")
	_niches = Control.new()
	_niches.size = Vector2(1920, 1080)
	_niches.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_niches)
	ScreenPack.image(root, _rtex("reliquaire/lutrin_relique.png"), _r(R.get("lutrin_rect", [1330, 260, 560, 760])))
	var wr := _r(R.get("lutrin_writing_rect", [1440, 335, 340, 225]))
	_lectern = ScreenPack.text(root, "", Rect2(wr.position, Vector2(wr.size.x, 64)), 22, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_lectern_sub = ScreenPack.text(root, "", Rect2(wr.position + Vector2(0, 66), wr.size - Vector2(0, 66)), 17, UiKit.TEXT_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	# Haut : retour (ferme l'écran), titre, accès aux quatuors.
	var back := TextureButton.new()
	back.texture_normal = _rtex("commun/retour_normal.png")
	back.texture_hover = _rtex("commun/retour_survol.png")
	back.texture_pressed = _rtex("commun/retour_appuye.png")
	var br := _r(R.get("return_rect", [30, 28, 220, 80]))
	back.position = br.position
	back.size = br.size
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_SCALE
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		close_window())
	root.add_child(back)
	ScreenPack.shadow(ScreenPack.text(back, "Port", Rect2(70, 0, 140, br.size.y), 26, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var tr := _r(R.get("title_rect", [610, 24, 700, 90]))
	var np := NinePatchRect.new()
	np.texture = _rtex("commun/bandeau_titre.png")
	np.patch_margin_left = 130
	np.patch_margin_right = 130
	np.patch_margin_top = 24
	np.patch_margin_bottom = 28
	np.position = tr.position
	np.size = tr.size
	root.add_child(np)
	ScreenPack.shadow(ScreenPack.text(root, "LE RELIQUAIRE", _r(R.get("title_writing_rect", [745, 48, 430, 34])), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var q := ScreenPack.button(root, Q, "return", "Quatuors →", Rect2(1560, 30, 320, 76), 26)
	q.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_tab = "Quatuors"
		refresh())


func _fill_reliquary() -> void:
	for c in _niches.get_children():
		_niches.remove_child(c)
		c.queue_free()
	var R: Dictionary = ShopScreen.L().get("reliquaire", {})
	var niches: Array = R.get("niches", [])
	var ids: Array = GameData.heroes.keys()
	var unlocked := PlayerData.relics_unlocked()
	_lectern.text = "Les reliques" if unlocked else "Reliques scellées"
	_lectern_sub.text = ("Survole une niche pour lire sa relique ; touche-la pour l'améliorer." if unlocked else
		"Elles s'éveillent après la Campagne 1 : bats Morvath au dernier niveau du monde 10.")
	for i in mini(ids.size(), niches.size()):
		var id: String = ids[i]
		var n: Dictionary = niches[i]
		var relic: Dictionary = GameData.relics.get("relics", {}).get(id, {})
		var tier := PlayerData.relic_tier(id)
		var rr := _r(n.rect)
		if tier > 0:
			ScreenPack.image(_niches, _rtex("reliquaire/niche_eveillee.png"), rr)
		var icon := String(relic.get("sprite", ""))
		var img := ScreenPack.image(_niches, load(icon) if ResourceLoader.exists(icon) else null, _r(n.relic_rect))
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tier == 0:
			img.modulate = Color(0.45, 0.42, 0.5)
		if not unlocked or tier == 0:
			ScreenPack.image(_niches, _rtex("reliquaire/niche_scellee.png"), rr)
		var pr: Array = n.palier_rects
		for k in pr.size():
			ScreenPack.image(_niches, _rtex("reliquaire/palier_%d.png" % (5 if k < tier else 1)), _r(pr[k]))
		var hover := ScreenPack.image(_niches, _rtex("reliquaire/niche_survol.png"), rr)
		hover.visible = false
		var hit := Control.new()
		hit.position = rr.position
		hit.size = rr.size
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_niches.add_child(hit)
		var hero := GameData.hero(id)
		hit.mouse_entered.connect(func() -> void:
			hover.visible = true
			_lectern.text = String(relic.get("name", id))
			var state := "Scellée" if not unlocked else ("Pas encore retrouvée · %d fragments" % PlayerData.relic_fragments(id)
				if tier == 0 else "Palier %d / 5" % tier)
			_lectern_sub.text = "%s
%s

%s" % [hero.get("name", id), state, relic.get("dungeon", "")])
		hit.mouse_exited.connect(func() -> void: hover.visible = false)
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				ui_sound.emit("ui_click")
				hero_relic_requested.emit(id))
