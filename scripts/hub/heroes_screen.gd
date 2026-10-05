class_name HeroesScreen
extends Control
## « Loge des héros » : la collection (cartes filtrables par rôle, héros à recruter grisés) et la
## fiche d'un héros (héros animé, statistiques, Force, amélioration contre de l'or, onglets
## Techniques / Voies / Relique / Échos, place dans l'équipe de chasse). Style de la maquette CREOS : fond
## d'encre, panneaux ivoire cerclés d'encre, bordeaux, laiton et turquoise.

signal closed
signal ui_sound(sfx_name: String)

const ATTACK_ICON_DIR := "res://assets/ui/attacks/"
const BG := Color("19181e")
const CARD := Color("34323c")
const STAT_NAMES := [["hp", "Vie"], ["atk", "Attaque"], ["mag", "Magie"], ["def", "Défense"],
	["spd", "Vitesse"], ["crit", "Critique"]]
const TABS := ["Techniques", "Voies", "Relique", "Échos"]

var selected := ""
var _filter := ""  # classe affichée ("" = toutes)
var _tab := "Techniques"

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
	var ids: Array = PlayerData.owned_heroes()
	for id: String in GameData.heroes:
		if id not in ids:
			ids.append(id)  # les héros à recruter, après ceux qu'on possède
	for id: String in ids:
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
	var owned: bool = PlayerData.state.heroes.has(id)
	card.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		show_hero(id))
	if not owned:
		card.modulate = Color(0.55, 0.55, 0.6)
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
	if not owned:
		v.add_child(UiKit.label("À recruter à la Lanterne", 19, UiKit.WOOD_LIGHT))
		return card
	v.add_child(UiKit.label(_echo_marks(id), 22, UiKit.WOOD_LIGHT))
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


func show_hero(id: String, tab := "Techniques") -> void:
	selected = id
	_tab = tab
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
	var desc := UiKit.label(String(hero.get("species", hero.get("description", ""))), 18, UiKit.PARCHMENT_DARK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left_info.add_child(desc)
	var bottom: VBoxContainer = _left_info.get_meta("bottom")
	for c in bottom.get_children():
		c.queue_free()
	var owned: bool = PlayerData.state.heroes.has(id)
	if not owned:
		bottom.add_child(UiKit.title("À recruter à la Lanterne des Serments", 24, UiKit.WOOD_LIGHT))
	bottom.add_child(UiKit.label(_echo_marks(id), 28, UiKit.WOOD_LIGHT))
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
	var stats := PlayerData.hero_stats(id, hero)
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
	var evo := UiKit.button("Relique", "gold", 21, Vector2(180, 60))
	evo.pressed.connect(func() -> void: _set_tab("Relique"))
	actions.add_child(evo)
	var in_team := PlayerData.in_team(id)
	var full := PlayerData.team().size() >= PlayerData.TEAM_SIZE
	up.disabled = up.disabled or not owned
	var team_b := UiKit.button("Retirer de l'équipe" if in_team else ("Équipe complète" if full else "Dans l'équipe"),
		"blue" if in_team else "green", 21, Vector2(0, 60))
	team_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_b.disabled = (in_team and PlayerData.team().size() <= 1) or (not in_team and full) or not owned
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
		"Techniques":
			_fill_skills(hero)
		"Voies":
			_fill_paths(id, hero)
		"Relique":
			_fill_relic(id, hero)
		_:
			_fill_echoes(id, hero)


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
		var anim: String = a.get("clip", a.get("anim", ""))
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


## Les trois voies d'Héritage : une seule active (changement gratuit hors combat), toutes
## progressent ensemble avec les Échos. Au palier 3 (6 Échos), une quatrième technique.
func _fill_paths(id: String, hero: Dictionary) -> void:
	var tier := PlayerData.hero_echo_tier(id)
	var active := PlayerData.hero_path(id)
	var thresholds: Array = GameData.progression.get("echoes", {}).get("thresholds", [1, 3, 6, 9, 12])
	var paths: Array = hero.get("paths", [])
	var secrets: Array = hero.get("secret_techniques", [])
	for i in paths.size():
		var path: Dictionary = paths[i]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiKit.card(UiKit.TEAL if i == active else Color.TRANSPARENT))
		_tab_box.add_child(p)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		p.add_child(col)
		var head := HBoxContainer.new()
		col.add_child(head)
		var t := UiKit.label("%s  ·  %s" % [path.get("name", ""), path.get("focus", "")], 22, UiKit.INK)
		t.add_theme_font_override("font", UiKit.FONT_BOLD)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if i < secrets.size():
			var clip := String(secrets[i].get("clip", ""))
			var see := UiKit.button("Voir", "blue", 16, Vector2(80, 40))
			see.tooltip_text = String(secrets[i].get("name", ""))
			see.pressed.connect(func() -> void:
				ui_sound.emit("ui_click")
				_preview.play(clip))
			head.add_child(see)
		var choose := UiKit.button("Active" if i == active else "Choisir", "green" if i == active else "wood", 16, Vector2(110, 40))
		choose.disabled = i == active or not PlayerData.state.heroes.has(id)
		var path_index := i
		choose.pressed.connect(func() -> void:
			ui_sound.emit("ui_toggle")
			PlayerData.set_hero_path(id, path_index))
		head.add_child(choose)
		var stages: Dictionary = path.get("stages", {})
		for k in thresholds.size():
			var key := str(int(thresholds[k]))
			var reached := tier > k
			var line := UiKit.label("%s %s Échos : %s" % ["◆" if reached else "◇", key, stages.get(key, "")], 17,
				UiKit.INK if reached else UiKit.TEXT_SOFT)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(line)
	var note := UiKit.label("Les Échos viennent uniquement des doublons du même héros, obtenus à la Lanterne.", 16, UiKit.TEXT_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_box.add_child(note)


## La relique ancienne du héros : cinq paliers (statistiques et effets), fragments gagnés en chasse.
func _fill_relic(id: String, hero: Dictionary) -> void:
	var relic: Dictionary = GameData.relics.get("relics", {}).get(id, {})
	if relic.is_empty():
		_tab_box.add_child(UiKit.label("Pas de relique connue.", 20, UiKit.TEXT_SOFT))
		return
	var tier := PlayerData.relic_tier(id)
	var tiers: Array = GameData.progression.get("relic_tiers", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_tab_box.add_child(row)
	var img := TextureRect.new()
	img.texture = load(String(relic.sprite)) if ResourceLoader.exists(String(relic.get("sprite", ""))) else null
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(170, 170)
	if tier == 0:
		img.modulate = Color(0.35, 0.33, 0.38)
	row.add_child(img)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := UiKit.label(String(relic.name), 26, UiKit.INK)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	col.add_child(t)
	var state_name := "Pas encore retrouvée" if tier == 0 else "Palier %d · %s" % [tier, tiers[tier - 1].get("name", "")]
	col.add_child(UiKit.label(state_name, 21, UiKit.WOOD))
	if tier > 0:
		var tt: Dictionary = tiers[tier - 1]
		col.add_child(UiKit.label("+%d %% %s · +%d %% %s" % [int(float(tt.primary) * 100), hero.get("primary", ""),
			int(float(tt.secondary) * 100), hero.get("secondary", "")], 19, UiKit.INK))
	col.add_child(UiKit.label("Fragments : %d   ·   Matériaux : %d" % [PlayerData.relic_fragments(id), PlayerData.item_count("materiaux_relique")], 18, UiKit.TEXT_SOFT))
	var see := UiKit.button("Voir la relique", "blue", 18, Vector2(0, 46))
	see.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_preview.play("cheer"))
	col.add_child(see)
	var cost := PlayerData.relic_next_cost(id)
	if not cost.is_empty():
		var label := "Retrouver" if tier == 0 else "Améliorer"
		var b := UiKit.button("%s · %d fragments%s" % [label, int(cost.fragments),
			"" if int(cost.materials) == 0 else " + %d matériaux" % int(cost.materials)], "green", 20, Vector2(0, 58))
		b.disabled = not PlayerData.can_upgrade_relic(id)
		b.pressed.connect(func() -> void:
			if PlayerData.upgrade_relic(id):
				ui_sound.emit("ultimate_impact")
				_preview.play("cheer"))
		_tab_box.add_child(b)
	for line: Array in [["Où la trouver", "%s (%s)" % [relic.get("dungeon", ""), relic.get("material", "")]],
			["III · Éveillée", relic.get("awakening", "")], ["IV · Accordée", relic.get("accord", "")],
			["V · Héritage", relic.get("contribution", "")], ["Épreuve du palier V", relic.get("trial", "")]]:
		var l := UiKit.label("%s : %s" % line, 17, UiKit.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tab_box.add_child(l)
	var note := UiKit.label("Chaque niveau de la campagne garde la relique d'un héros : 3 fragments par victoire.", 16, UiKit.TEXT_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_box.add_child(note)


## Les Échos (doublons du même héros) : paliers 1, 3, 6, 9, 12 et leurs gains de statistiques.
func _fill_echoes(id: String, hero: Dictionary) -> void:
	var e: Dictionary = GameData.progression.get("echoes", {})
	var echoes := PlayerData.hero_echoes(id)
	var tier := PlayerData.hero_echo_tier(id)
	var next := Progression.next_echo_threshold(echoes, GameData.progression)
	_tab_box.add_child(_section("Échos : %d" % echoes))
	if next > 0:
		_tab_box.add_child(UiKit.label("Prochain palier à %d Échos" % next, 21, UiKit.INK))
		var bar := UiKit.progress(UiKit.TEAL, 18)
		bar.max_value = next
		bar.value = echoes
		_tab_box.add_child(bar)
	else:
		_tab_box.add_child(UiKit.label("Tous les paliers sont atteints.", 21, UiKit.INK))
	var thresholds: Array = e.get("thresholds", [])
	var unlocks: Array = e.get("unlocks", [])
	for k in thresholds.size():
		var reached := tier > k
		var l := UiKit.label("%s %d Échos · %s · +%d %% %s, +%d %% %s, +%d %% autres" % [
			"◆" if reached else "◇", int(thresholds[k]), unlocks[k] if k < unlocks.size() else "",
			int(float(e.primary[k]) * 100), hero.get("primary", ""), int(float(e.secondary[k]) * 100),
			hero.get("secondary", ""), int(float(e.other[k]) * 100)], 18, UiKit.INK if reached else UiKit.TEXT_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tab_box.add_child(l)
	var note := UiKit.label("Un héros déjà recruté qui revient à la Lanterne donne un Écho. Aucune autre source.", 16, UiKit.TEXT_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tab_box.add_child(note)


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
	var role := String(hero.get("role", Palette.CLASS_NAMES.get(hero.get("class"), "")))
	return "%s · %s" % [role, Palette.ELEMENT_NAMES.get(hero.get("element"), "")]


## Paliers d'Échos atteints : ◆ plein par palier (5 au plus), et le nombre d'Échos.
func _echo_marks(id: String) -> String:
	var tier := PlayerData.hero_echo_tier(id)
	return "%s  %d Écho%s" % ["◆".repeat(tier) + "◇".repeat(5 - tier), PlayerData.hero_echoes(id),
		"s" if PlayerData.hero_echoes(id) > 1 else ""]


func _power(id: String) -> int:
	return Progression.power(PlayerData.hero_stats(id, GameData.hero(id)))


func _fiche(hero: Dictionary) -> Texture2D:
	if ResourceLoader.exists(String(hero.get("fiche", ""))):
		return load(String(hero.fiche))
	if hero.has("puppet"):
		var path := String(hero.puppet).path_join("fiche.png")
		if ResourceLoader.exists(path):
			return load(path)
	return RoundPortrait.portrait_texture(hero)


func _attack_icon(a: Dictionary) -> Texture2D:
	var path := ATTACK_ICON_DIR + String(a.get("id", "")) + ".png"
	return load(path) if ResourceLoader.exists(path) else null
