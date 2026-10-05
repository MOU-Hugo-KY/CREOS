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
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


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
	_quartet_scroll.visible = _tab == "Quatuors"
	for c in _grid.get_children():
		c.queue_free()
	for c in _quartets.get_children():
		c.queue_free()
	if _tab == "Reliques":
		for id: String in GameData.heroes:
			_grid.add_child(_relic_card(id))
	else:
		for qid: String in GameData.quartets():
			_quartets.add_child(_quartet_card(GameData.quartets()[qid]))


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
	var s := UiKit.label(st_text, 15, UiKit.WOOD if owned else UiKit.TEXT_SOFT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	b.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		hero_relic_requested.emit(id))
	return b


func _quartet_card(q: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.card())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	p.add_child(row)
	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", 6)
	row.add_child(faces)
	var all_owned := true
	for m: String in q.members:
		var portrait := RoundPortrait.new().setup(GameData.hero(m), 76)
		if not PlayerData.state.heroes.has(m):
			portrait.set_grey(true)
			all_owned = false
		faces.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := UiKit.label("%s  ·  %s" % [q.get("name", ""), q.get("attack", "")], 22, UiKit.INK)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	col.add_child(t)
	for line: String in [String(q.get("effect", "")), "Bonus de formation : " + String(q.get("bonus", ""))]:
		var l := UiKit.label(line, 16, UiKit.TEXT_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	var hint := "Mets les quatre dans ton équipe : quand chacun a lancé son ultime, le bouton QUATUOR apparaît (une fois par combat)."
	if not all_owned:
		hint = "Recrute les quatre membres à la Lanterne pour débloquer cette attaque combinée."
	var h := UiKit.label(hint, 16, UiKit.WOOD)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(h)
	return p
