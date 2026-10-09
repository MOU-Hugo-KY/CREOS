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


func _build_quartet_page() -> void:
	_quartet_page = Control.new()
	_quartet_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quartet_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_quartet_page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_quartet_page)
	var bg := ColorRect.new()
	bg.color = Color("2a2530")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quartet_page.add_child(bg)
	var root := ScreenPack.frame(_quartet_page)
	var L := ScreenPack.layout(Q)
	var tr := ScreenPack.rect(L.title_rect)
	ScreenPack.image(root, ScreenPack.tex(Q, "title"), tr)
	ScreenPack.text(root, "RELIQUES ET QUATUORS", tr, 36, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var back := ScreenPack.button(root, Q, "return", "← Reliques", ScreenPack.rect(L.return_rect), 28)
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_tab = "Reliques"
		refresh())
	var wr := ScreenPack.rect(L.main_window_rect)
	ScreenPack.panel(root, Q, "main_window", wr)
	ScreenPack.text(root, "QUATUORS · QUATRE HÉROS, UNE ATTAQUE", Rect2(wr.position + Vector2(42, 14), Vector2(1200, 44)), 28)
	_quartet_box = Control.new()
	_quartet_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_quartet_box)


func _fill_quartet_page() -> void:
	for c in _quartet_box.get_children():
		c.queue_free()
	var C: Dictionary = ScreenPack.layout(Q).cards
	var forms: Array = ScreenPack.data(Q).get("formations", [])
	for i in mini(forms.size(), C.rects.size()):
		var f: Dictionary = forms[i]
		var q: Dictionary = GameData.quartets().get(f.id, {})
		var r := ScreenPack.rect(C.rects[i])
		var card := ScreenPack.panel(_quartet_box, Q, "formation_card", r)
		var at := func(o: Array) -> Rect2: return Rect2(Vector2(o[0], o[1]), Vector2(o[2], o[3]))
		ScreenPack.image(card, ScreenPack.tex(Q, "blason_%s_128" % f.id), at.call(C.crest_offset))
		ScreenPack.text(card, String(q.get("name", f.name)), at.call(C.name_offset), 30)
		ScreenPack.text(card, String(q.get("attack", f.attack)), at.call(C.attack_name_offset), 24, UiKit.TEXT_SOFT)
		var members: Array = q.get("members", f.heroes)
		var all_owned := true
		for k in mini(members.size(), 4):
			var pr: Rect2 = at.call(C.portraits_offsets[k])
			var portrait := RoundPortrait.new().setup(GameData.hero(members[k]), pr.size.x)
			portrait.position = pr.position
			portrait.size = pr.size
			if not PlayerData.state.heroes.has(members[k]):
				portrait.set_grey(true)
				all_owned = false
			card.add_child(portrait)
		ScreenPack.image(card, ScreenPack.tex(Q, "vignette_" + f.id), at.call(C.vignette_offset))
		var d := ScreenPack.text(card, " ".join(f.description), at.call(C.description_offset), 21, UiKit.INK, 0, true)
		d.tooltip_text = String(q.get("effect", ""))
		d.mouse_filter = Control.MOUSE_FILTER_PASS
		for row: Array in [["bonus_rect", "bonus_panel", "Bonus · " + ("prêt" if all_owned else "recrute les quatre"), "bonus"],
				["resonance_rect", "resonance_panel", "Résonance · reliques au palier V", "resonance"]]:
			var rr: Rect2 = at.call(C[row[0]])
			var box := ScreenPack.panel(card, Q, row[1], rr)
			box.mouse_filter = Control.MOUSE_FILTER_PASS
			box.tooltip_text = String(q.get(row[3], ""))
			ScreenPack.text(box, row[2], Rect2(30, 0, rr.size.x - 60, rr.size.y), 21, UiKit.WHITE)


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
