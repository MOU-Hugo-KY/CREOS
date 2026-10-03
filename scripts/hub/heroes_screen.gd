class_name HeroesScreen
extends Control
## « Loge des héros » : la collection (cartes filtrables par rôle) et la fiche d'un héros
## (héros animé, statistiques, Force, amélioration contre de l'or, onglets Aptitudes /
## Équipement / Étoiles, place dans l'équipe de chasse). Style de la maquette CREOS : fond
## d'encre, panneaux ivoire cerclés d'encre, bordeaux, laiton et turquoise.

signal closed
signal ui_sound(sfx_name: String)

const ATTACK_ICON_DIR := "res://assets/ui/attacks/"
const BG := Color("19181e")
const CARD := Color("34323c")
const STAT_NAMES := [["hp", "Vie"], ["atk", "Attaque"], ["def", "Défense"], ["res", "Résistance"],
	["spd", "Vitesse"], ["crit", "Critique"]]
const TABS := ["Aptitudes", "Équipement", "Étoiles"]

var selected := ""
var _filter := ""  # classe affichée ("" = toutes)
var _tab := "Aptitudes"

var _title: Label
var _count: Label
var _back: Button
var _collection: VBoxContainer
var _filters: HBoxContainer
var _grid: GridContainer
var _team_strip: HBoxContainer
var _detail: HBoxContainer
var _preview: HeroPreview
var _left_info: VBoxContainer
var _stats_box: VBoxContainer
var _tabs_row: HBoxContainer
var _tab_box: VBoxContainer
var _confirm: UiWindow
var _confirm_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(BG, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)

	# En-tête
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	page.add_child(head)
	_back = UiKit.button("Retour au port", "wood", 22, Vector2(230, 58))
	_back.pressed.connect(_on_back)
	head.add_child(_back)
	_title = UiKit.title("Loge des héros", 44, UiKit.PARCHMENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = UiKit.label("", 24, UiKit.PARCHMENT_DARK)
	head.add_child(_count)

	_build_collection(page)
	_build_detail(page)
	_build_confirm()
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	visible = true
	_show_collection()


func refresh() -> void:
	_count.text = "%d / %d héros" % [PlayerData.owned_heroes().size(), GameData.heroes.size()]
	if _detail.visible:
		_fill_detail()
	else:
		_fill_collection()


# --- Collection ---------------------------------------------------------------------

func _build_collection(page: VBoxContainer) -> void:
	_collection = VBoxContainer.new()
	_collection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection.add_theme_constant_override("separation", 16)
	page.add_child(_collection)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 10)
	_collection.add_child(_filters)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(_grid)
	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 18)
	_collection.add_child(team_row)
	team_row.add_child(UiKit.title("Équipe de chasse", 26, UiKit.WOOD_LIGHT))
	_team_strip = HBoxContainer.new()
	_team_strip.add_theme_constant_override("separation", 14)
	team_row.add_child(_team_strip)


func _show_collection() -> void:
	_detail.visible = false
	_collection.visible = true
	_back.text = "Retour au port"
	_title.text = "Loge des héros"
	refresh()


func _fill_collection() -> void:
	for c in _filters.get_children():
		c.queue_free()
	var classes: Array = []
	for id: String in PlayerData.owned_heroes():
		var cl: String = GameData.hero(id).get("class", "")
		if cl not in classes:
			classes.append(cl)
	classes.sort()
	_filters.add_child(_tab_button("Tous", _filter == "", func() -> void: _set_filter("")))
	for cl: String in classes:
		var name := String(Palette.CLASS_NAMES.get(cl, cl)) + "s"
		_filters.add_child(_tab_button(name, _filter == cl, func() -> void: _set_filter(cl)))
	for c in _grid.get_children():
		c.queue_free()
	for id: String in PlayerData.owned_heroes():
		var hero := GameData.hero(id)
		if _filter == "" or hero.get("class", "") == _filter:
			_grid.add_child(_hero_card(hero))
	for c in _team_strip.get_children():
		c.queue_free()
	var team := PlayerData.team()
	for i in PlayerData.TEAM_SIZE:
		if i < team.size():
			var p := RoundPortrait.new().setup(GameData.hero(team[i]), 72)
			_team_strip.add_child(p)
		else:
			var empty := Panel.new()
			empty.custom_minimum_size = Vector2(72, 72)
			empty.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.2), 36, 2))
			_team_strip.add_child(empty)


func _set_filter(cl: String) -> void:
	ui_sound.emit("ui_click")
	_filter = cl
	_fill_collection()


func _hero_card(hero: Dictionary) -> Control:
	var id: String = hero.id
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 430)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UiKit.box(CARD, UiKit.INK, 16, 3)
	sb.border_width_bottom = 10
	card.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.border_color = UiKit.WOOD_LIGHT
	hover.border_width_bottom = 10
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		show_hero(id))
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_theme_constant_override("margin_bottom", 20)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var art := TextureRect.new()
	art.texture = _fiche(hero)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	var rarity: Array = Palette.RARITIES.get(int(hero.get("rarity", 1)), ["", Color.WHITE])
	var badge := _badge(rarity[0], UiKit.WOOD)
	badge.position = Vector2(14, 14)
	card.add_child(badge)
	if PlayerData.in_team(id):
		var t := _badge("ÉQUIPE", Color("1f5f59"))
		t.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		t.offset_left = -110
		t.offset_right = -14
		t.offset_top = 14
		card.add_child(t)
	var name := UiKit.title(String(hero.name), 28, UiKit.PARCHMENT)
	v.add_child(name)
	v.add_child(UiKit.label(_role(hero), 19, UiKit.TEAL))
	v.add_child(UiKit.label(_stars(PlayerData.hero_stars(id)), 24, UiKit.WOOD_LIGHT))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var lv := UiKit.label("Niv. %d" % PlayerData.hero_level(id), 20, UiKit.PARCHMENT)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lv)
	row.add_child(UiKit.label("Force %d" % _power(id), 20, UiKit.PARCHMENT))
	return card


# --- Fiche d'un héros ---------------------------------------------------------------

func _build_detail(page: VBoxContainer) -> void:
	_detail = HBoxContainer.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 24)
	_detail.visible = false
	page.add_child(_detail)
	# Gauche : le héros animé
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(700, 0)
	var lsb := UiKit.box(CARD, UiKit.INK, 18, 3)
	lsb.border_width_bottom = 11
	lsb.set_content_margin_all(22)
	left.add_theme_stylebox_override("panel", lsb)
	_detail.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	_left_info = VBoxContainer.new()
	_left_info.add_theme_constant_override("separation", 2)
	lv.add_child(_left_info)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(vpc)
	_preview = HeroPreview.new()
	vpc.add_child(_preview)
	_left_info.set_meta("bottom", VBoxContainer.new())
	lv.add_child(_left_info.get_meta("bottom"))
	# Droite : stats, onglets
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	scroll.add_child(right)
	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", UiKit.parchment())
	right.add_child(stats_panel)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 6)
	stats_panel.add_child(_stats_box)
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 10)
	right.add_child(_tabs_row)
	var tab_panel := PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", UiKit.parchment())
	right.add_child(tab_panel)
	_tab_box = VBoxContainer.new()
	_tab_box.add_theme_constant_override("separation", 10)
	tab_panel.add_child(_tab_box)


func show_hero(id: String) -> void:
	selected = id
	_tab = "Aptitudes"
	_collection.visible = false
	_detail.visible = true
	_back.text = "← Collection"
	_preview.show_hero(GameData.hero(id))
	refresh()


func _fill_detail() -> void:
	var id := selected
	var hero := GameData.hero(id)
	var rarity: Array = Palette.RARITIES.get(int(hero.get("rarity", 1)), ["", Color.WHITE])
	_title.text = String(hero.name)
	# Gauche
	for c in _left_info.get_children():
		c.queue_free()
	var top := HBoxContainer.new()
	_left_info.add_child(top)
	var role := UiKit.label(_role(hero), 22, UiKit.TEAL)
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(role)
	top.add_child(_badge(rarity[0], UiKit.WOOD))
	var desc := UiKit.label(String(hero.get("description", "")), 18, UiKit.PARCHMENT_DARK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_info.add_child(desc)
	var bottom: VBoxContainer = _left_info.get_meta("bottom")
	for c in bottom.get_children():
		c.queue_free()
	bottom.add_child(UiKit.label(_stars(PlayerData.hero_stars(id)), 30, UiKit.WOOD_LIGHT))
	var lrow := HBoxContainer.new()
	bottom.add_child(lrow)
	var lvl := UiKit.title("Niveau %d / %d" % [PlayerData.hero_level(id), int(GameData.progression.get("max_level", 30))], 26, UiKit.PARCHMENT)
	lvl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(lvl)
	lrow.add_child(UiKit.title("Force %d" % _power(id), 26, UiKit.WOOD_LIGHT))
	var bar := UiKit.progress(UiKit.TEAL, 14)
	bar.max_value = maxf(1.0, PlayerData.hero_xp_to_next(id))
	bar.value = PlayerData.hero_xp(id)
	bottom.add_child(bar)
	bottom.add_child(UiKit.label("Expérience %d / %d · gagnée en chasse" % [PlayerData.hero_xp(id), PlayerData.hero_xp_to_next(id)], 17, UiKit.PARCHMENT_DARK))

	# Statistiques et actions
	for c in _stats_box.get_children():
		c.queue_free()
	_stats_box.add_child(_section("Statistiques"))
	var stats := Progression.hero_stats(hero, PlayerData.hero_level(id), PlayerData.hero_stars(id), GameData.progression)
	for s: Array in STAT_NAMES:
		var row := HBoxContainer.new()
		_stats_box.add_child(row)
		var n := UiKit.label(s[1], 21, UiKit.TEXT_SOFT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var v: float = stats.get(s[0], 0)
		var val := UiKit.label("%d %%" % int(v * 100) if s[0] == "crit" else str(int(v)), 22, UiKit.INK)
		val.add_theme_font_override("font", UiKit.FONT_BOLD)
		row.add_child(val)
		var line := ColorRect.new()
		line.color = Color(UiKit.WOOD_LIGHT, 0.5)
		line.custom_minimum_size = Vector2(0, 1)
		_stats_box.add_child(line)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_stats_box.add_child(actions)
	var max_level := PlayerData.hero_level(id) >= int(GameData.progression.get("max_level", 30))
	var cost := PlayerData.hero_level_up_cost(id)
	var up := UiKit.button("Niveau max" if max_level else "Améliorer · %d or" % cost, "red", 21, Vector2(0, 60))
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.disabled = max_level or PlayerData.gold() < cost
	up.pressed.connect(_ask_level_up)
	actions.add_child(up)
	var evo := UiKit.button("Évolution", "gold", 21, Vector2(180, 60))
	evo.pressed.connect(func() -> void: _set_tab("Étoiles"))
	actions.add_child(evo)
	var in_team := PlayerData.in_team(id)
	var full := PlayerData.team().size() >= PlayerData.TEAM_SIZE
	var team_b := UiKit.button("Retirer de l'équipe" if in_team else ("Équipe complète" if full else "Dans l'équipe"),
		"blue" if in_team else "green", 21, Vector2(0, 60))
	team_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_b.disabled = (in_team and PlayerData.team().size() <= 1) or (not in_team and full)
	team_b.pressed.connect(func() -> void:
		if PlayerData.toggle_team(id):
			ui_sound.emit("ui_toggle"))
	_stats_box.add_child(team_b)

	# Onglets
	for c in _tabs_row.get_children():
		c.queue_free()
	for t: String in TABS:
		var tab := t
		_tabs_row.add_child(_tab_button(t, _tab == t, func() -> void: _set_tab(tab)))
	for c in _tab_box.get_children():
		c.queue_free()
	match _tab:
		"Aptitudes":
			_fill_skills(hero)
		"Équipement":
			_fill_equipment()
		_:
			_fill_stars(id)


func _fill_skills(hero: Dictionary) -> void:
	var attacks: Array = hero.get("attacks", [])
	for i in attacks.size():
		var a: Dictionary = attacks[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_tab_box.add_child(row)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.icon = _attack_icon(a)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(68, 68)
		b.tooltip_text = "Voir l'attaque"
		var anim: String = a.get("anim", "")
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_preview.play(anim))
		row.add_child(b)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var kind := "Attaque de base"
		if i == BattleUnit.SLOT_COOLDOWN:
			kind = "Recharge %d s" % int(a.get("cooldown", 0))
		elif i == BattleUnit.SLOT_ULTIMATE:
			kind = "Ultime · %d énergie" % int(a.get("energy", 100))
		var t := UiKit.label("%s   ·   %s" % [a.get("name", ""), kind], 22, UiKit.INK)
		t.add_theme_font_override("font", UiKit.FONT_BOLD)
		col.add_child(t)
		var d := UiKit.label(String(a.get("description", "")), 18, UiKit.TEXT_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
	_tab_box.add_child(UiKit.label("Touche une icône pour voir l'attaque.", 16, UiKit.TEXT_SOFT))


func _fill_equipment() -> void:
	for slot in ["Arme ou focus", "Protection", "Relique"]:
		var p := PanelContainer.new()
		var sb := UiKit.box(UiKit.PARCHMENT_DARK, Color("9c8a68"), 12, 2)
		sb.set_content_margin_all(18)
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(UiKit.label("%s · emplacement libre" % slot, 20, UiKit.TEXT_SOFT))
		_tab_box.add_child(p)
	_tab_box.add_child(UiKit.label("L'équipement arrive avec le butin des chasses (bientôt).", 16, UiKit.TEXT_SOFT))


func _fill_stars(id: String) -> void:
	var stars := PlayerData.hero_stars(id)
	var cost := PlayerData.hero_star_cost(id)
	if cost < 0:
		_tab_box.add_child(_section("%d étoiles : évolution maximale" % stars))
		return
	_tab_box.add_child(_section("Évolution  %d → %d étoiles" % [stars, stars + 1]))
	var have := PlayerData.hero_shards(id)
	_tab_box.add_child(UiKit.label("Fragments : %d / %d" % [have, cost], 21, UiKit.INK))
	var bar := UiKit.progress(UiKit.TEAL, 18)
	bar.max_value = cost
	bar.value = mini(have, cost)
	_tab_box.add_child(bar)
	var bonus := int(round(float(GameData.progression.get("stars", {}).get("bonus_per_star", 0.1)) * 100.0))
	var note := UiKit.label("Chaque étoile donne +%d %% de vie, attaque, défense et résistance. Les fragments d'un héros s'obtiennent en l'invoquant de nouveau à la Lanterne. La rareté reste une information à part." % bonus, 17, UiKit.TEXT_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_box.add_child(note)
	var b := UiKit.button("Faire évoluer" if have >= cost else "Fragments insuffisants", "green", 22, Vector2(0, 60))
	b.disabled = have < cost
	b.pressed.connect(func() -> void:
		if PlayerData.evolve_hero(id):
			ui_sound.emit("ultimate_impact"))
	_tab_box.add_child(b)


func _set_tab(t: String) -> void:
	ui_sound.emit("ui_click")
	_tab = t
	_fill_detail()


# --- Confirmation de l'amélioration -----------------------------------------------

func _build_confirm() -> void:
	_confirm = UiWindow.new().setup("Améliorer", Vector2(620, 330))
	add_child(_confirm)
	_confirm_text = UiKit.label("", 24, UiKit.INK)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm.content.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_confirm.content.add_child(row)
	var ok := UiKit.button("Améliorer", "red", 22, Vector2(220, 60))
	ok.pressed.connect(func() -> void:
		_confirm.close_window()
		if PlayerData.level_up_hero(selected):
			ui_sound.emit("ui_ready")
			_preview.play("cheer"))
	row.add_child(ok)
	var cancel := UiKit.button("Annuler", "grey", 22, Vector2(180, 60))
	cancel.pressed.connect(_confirm.close_window)
	row.add_child(cancel)


func _ask_level_up() -> void:
	ui_sound.emit("ui_click")
	var hero := GameData.hero(selected)
	var lv := PlayerData.hero_level(selected)
	_confirm_text.text = "Passer %s du niveau %d au niveau %d pour %d or ?" % [hero.name, lv, lv + 1, PlayerData.hero_level_up_cost(selected)]
	_confirm.open()


# --- Petits éléments ----------------------------------------------------------------

func _on_back() -> void:
	ui_sound.emit("ui_click")
	if _detail.visible:
		_show_collection()
	else:
		closed.emit()


func _tab_button(text: String, active: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	var sb := UiKit.box(UiKit.PARCHMENT if active else CARD, UiKit.INK if active else Color("726552"), 10, 2)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, UiKit.INK if active else UiKit.PARCHMENT)
	b.pressed.connect(on_press)
	return b


func _badge(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.box(color, UiKit.INK, 8, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label(text, 16, UiKit.WHITE))
	return p


func _section(text: String) -> Label:
	var l := UiKit.title(text, 28, UiKit.WOOD)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _role(hero: Dictionary) -> String:
	return "%s · %s" % [Palette.CLASS_NAMES.get(hero.get("class"), ""), Palette.ELEMENT_NAMES.get(hero.get("element"), "")]


func _stars(n: int) -> String:
	var max_stars := int(GameData.progression.get("stars", {}).get("max", 6))
	return "★".repeat(n) + "☆".repeat(maxi(0, max_stars - n))


func _power(id: String) -> int:
	var hero := GameData.hero(id)
	return Progression.power(Progression.hero_stats(hero, PlayerData.hero_level(id), PlayerData.hero_stars(id), GameData.progression))


func _fiche(hero: Dictionary) -> Texture2D:
	if hero.has("puppet"):
		var path := String(hero.puppet).path_join("fiche.png")
		if ResourceLoader.exists(path):
			return load(path)
	return RoundPortrait.portrait_texture(hero)


func _attack_icon(a: Dictionary) -> Texture2D:
	var path := ATTACK_ICON_DIR + String(a.get("id", "")) + ".png"
	return load(path) if ResourceLoader.exists(path) else null
