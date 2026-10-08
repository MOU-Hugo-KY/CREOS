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
	_relic_scroll.visible = _tab == "Reliques"
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
