class_name HeroLodge
extends Control
## Écran « Loge des héros » : la liste des chasseurs, le héros choisi en 3D (on peut voir ses
## 3 attaques), ses stats à son niveau, ses attaques, et le choix de l'équipe de chasse (4 max).

signal closed
signal ui_sound(sfx_name: String)

const ATTACK_ICON_DIR := "res://assets/ui/attacks/"
const STAT_NAMES := [["hp", "Points de vie"], ["atk", "Attaque"], ["def", "Défense"],
	["res", "Résistance"], ["spd", "Vitesse"], ["crit", "Critique"]]

var selected := ""

var _list: VBoxContainer
var _rows: Dictionary = {}  # id -> PanelContainer
var _preview: HeroPreview
var _attack_buttons: HBoxContainer
var _info: VBoxContainer
var _team_strip: HBoxContainer
var _team_count: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Palette.make_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	# En-tête
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	page.add_child(head)
	var back := Button.new()
	back.text = "Retour au port"
	back.custom_minimum_size = Vector2(220, 56)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		closed.emit())
	head.add_child(back)
	var title := _label("Loge des héros", 40, Palette.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_team_count = _label("", 24, Palette.TEXT)
	head.add_child(_team_count)

	# Corps : liste | héros en 3D | fiche
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	page.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	body.add_child(center)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(vpc)
	_preview = HeroPreview.new()
	vpc.add_child(_preview)
	var hint := _label("Touche une attaque pour la voir", 18, Palette.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint)
	_attack_buttons = HBoxContainer.new()
	_attack_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_attack_buttons.add_theme_constant_override("separation", 24)
	center.add_child(_attack_buttons)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(500, 0)
	body.add_child(info_panel)
	var im := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		im.add_theme_constant_override("margin_" + side, 22)
	info_panel.add_child(im)
	var info_scroll := ScrollContainer.new()
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	im.add_child(info_scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 10)
	info_scroll.add_child(_info)

	# Bas : l'équipe de chasse
	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 18)
	page.add_child(team_row)
	team_row.add_child(_label("Équipe de chasse", 24, Palette.GOLD))
	_team_strip = HBoxContainer.new()
	_team_strip.add_theme_constant_override("separation", 14)
	team_row.add_child(_team_strip)

	PlayerData.changed.connect(_refresh_all)


func open() -> void:
	visible = true
	_build_list()
	var team := PlayerData.team()
	select(team[0] if not team.is_empty() else PlayerData.owned_heroes()[0])
	_refresh_team()


func select(id: String) -> void:
	selected = id
	var hero := GameData.hero(id)
	_preview.show_hero(hero)
	for rid: String in _rows:
		var row: PanelContainer = _rows[rid]
		var color := Palette.element_color(GameData.hero(rid).element)
		row.add_theme_stylebox_override("panel", Palette.stylebox(
			Color(color.darkened(0.6), 0.85) if rid == id else Color(0, 0, 0, 0.45),
			color if rid == id else Color(1, 1, 1, 0.1), 16, 3 if rid == id else 2))
	_build_attack_buttons(hero)
	_build_info(hero)


# --- Construction ---------------------------------------------------------------

func _build_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	for id: String in PlayerData.owned_heroes():
		var hero := GameData.hero(id)
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var m := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 8)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(m)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(h)
		h.add_child(RoundPortrait.new().setup(hero, 72))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(col)
		col.add_child(_label(hero.name, 22, Palette.TEXT))
		col.add_child(_label("Niv. %d · %s" % [PlayerData.hero_level(id), Palette.CLASS_NAMES.get(hero.get("class"), "")], 17, Palette.TEXT_DIM))
		if PlayerData.in_team(id):
			col.add_child(_label("DANS L'ÉQUIPE", 15, Palette.GOLD))
		row.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				ui_sound.emit("ui_click")
				select(id))
		_list.add_child(row)
		_rows[id] = row


func _build_attack_buttons(hero: Dictionary) -> void:
	for c in _attack_buttons.get_children():
		c.queue_free()
	var color := Palette.element_color(hero.element)
	for a: Dictionary in hero.get("attacks", []):
		var b := IconButton.new().setup(_attack_icon(a), a.get("name", ""), 40.0, color)
		var anim: String = a.get("anim", "")
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_preview.play(anim))
		_attack_buttons.add_child(b)


func _build_info(hero: Dictionary) -> void:
	for c in _info.get_children():
		c.queue_free()
	var id: String = hero.id
	var level := PlayerData.hero_level(id)
	var color := Palette.element_color(hero.element)
	var rarity: Array = Palette.RARITIES.get(int(hero.get("rarity", 1)), ["", Color.WHITE])

	_info.add_child(_label(hero.name, 34, Palette.TEXT))
	var line := _label("%s · %s · %s" % [Palette.CLASS_NAMES.get(hero.get("class"), ""),
		Palette.ELEMENT_NAMES.get(hero.element, ""), rarity[0]], 20, color.lightened(0.3))
	_info.add_child(line)
	var stars := _label("★".repeat(int(hero.get("rarity", 1))), 22, rarity[1])
	_info.add_child(stars)

	# Niveau et XP
	var lv := HBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	_info.add_child(lv)
	lv.add_child(_label("Niveau %d" % level, 24, Palette.GOLD))
	var xp_bar := StatBar.new()
	xp_bar.fill_color = Palette.ENERGY
	xp_bar.custom_minimum_size = Vector2(0, 20)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.font_size = 14
	var need := PlayerData.hero_xp_to_next(id)
	xp_bar.set_values(float(PlayerData.hero_xp(id)) / maxf(1.0, need), 0.0, "%d / %d XP" % [PlayerData.hero_xp(id), need])
	lv.add_child(xp_bar)

	# Stats au niveau actuel
	var stats := Progression.stats_at_level(hero.stats, level, GameData.progression.get("stat_growth", {}))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	_info.add_child(grid)
	for s: Array in STAT_NAMES:
		grid.add_child(_label(s[1], 18, Palette.TEXT_DIM))
		var v: float = stats.get(s[0], 0)
		grid.add_child(_label("%d %%" % int(v * 100) if s[0] == "crit" else str(int(v)), 20, Palette.TEXT))

	# Attaques
	_info.add_child(_label("Attaques", 24, Palette.GOLD))
	var attacks: Array = hero.get("attacks", [])
	for i in attacks.size():
		var a: Dictionary = attacks[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_info.add_child(row)
		var icon := TextureRect.new()
		icon.texture = _attack_icon(a)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(56, 56)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var kind := "Attaque de base"
		if i == BattleUnit.SLOT_COOLDOWN:
			kind = "Recharge : %d s" % int(a.get("cooldown", 0))
		elif i == BattleUnit.SLOT_ULTIMATE:
			kind = "Ultime : %d énergie" % int(a.get("energy", 100))
		col.add_child(_label("%s   ·   %s" % [a.get("name", ""), kind], 20, Palette.TEXT))
		var desc := _label(a.get("description", ""), 17, Palette.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)

	# Bouton équipe
	var in_team := PlayerData.in_team(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	var full := PlayerData.team().size() >= PlayerData.TEAM_SIZE
	if in_team:
		b.text = "Retirer de l'équipe"
		b.disabled = PlayerData.team().size() <= 1
	else:
		b.text = "Ajouter à l'équipe" if not full else "Équipe complète (4)"
		b.disabled = full
	b.pressed.connect(func() -> void:
		if PlayerData.toggle_team(id):
			ui_sound.emit("ui_toggle"))
	_info.add_child(b)


func _refresh_team() -> void:
	for c in _team_strip.get_children():
		c.queue_free()
	var team := PlayerData.team()
	for i in PlayerData.TEAM_SIZE:
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)
		_team_strip.add_child(slot)
		if i < team.size():
			var hero := GameData.hero(team[i])
			var p := RoundPortrait.new().setup(hero, 64)
			p.mouse_filter = Control.MOUSE_FILTER_STOP
			var tid: String = team[i]
			p.gui_input.connect(func(e: InputEvent) -> void:
				var mb := e as InputEventMouseButton
				if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
					select(tid))
			slot.add_child(p)
		else:
			var empty := Panel.new()
			empty.custom_minimum_size = Vector2(64, 64)
			empty.add_theme_stylebox_override("panel", Palette.stylebox(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.2), 32, 2))
			slot.add_child(empty)
	_team_count.text = "%d / %d héros" % [team.size(), PlayerData.TEAM_SIZE]


func _refresh_all() -> void:
	if not visible or selected == "":
		return
	var keep := selected
	_build_list()
	select(keep)
	_refresh_team()


func _attack_icon(a: Dictionary) -> Texture2D:
	var path := ATTACK_ICON_DIR + String(a.get("id", "")) + ".png"
	return load(path) if ResourceLoader.exists(path) else null


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
