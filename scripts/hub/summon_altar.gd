class_name SummonAltar
extends Control
## Écran « Autel des Reliques » : invoquer des héros avec des Fragments de Relique (gagnés en
## chasse) ou des gemmes. Les taux et la garantie sont affichés ; chaque héros de la réserve
## montre s'il est déjà réveillé. Règles dans `Summon` et `PlayerData.summon()`.

signal closed
signal ui_sound(sfx_name: String)

const ICON_DIR := "res://assets/ui/hub/"
const CURRENCIES := [["fragments_relique", "autel"], ["gems", "gemmes"]]

var _stage: SummonStage
var _balance: Dictionary = {}  # monnaie -> Label
var _buttons: Dictionary = {}  # monnaie -> Button
var _odds: VBoxContainer
var _pity: Label
var _pool: VBoxContainer
var _result: PanelContainer
var _result_rarity: Label
var _result_name: Label
var _result_detail: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Palette.make_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.06, 0.96)
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

	# En-tête : retour, titre, soldes
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	page.add_child(head)
	var back := Button.new()
	back.text = "Retour au port"
	back.custom_minimum_size = Vector2(220, 56)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void:
		if _stage.busy:
			return
		ui_sound.emit("ui_click")
		closed.emit())
	head.add_child(back)
	var title := _label(GameData.summon.get("name", "Autel des Reliques"), 40, Palette.RARITIES[3][1].lightened(0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for c: Array in CURRENCIES:
		head.add_child(_pill(c[0], c[1]))

	# Corps : informations | sanctuaire 3D | réserve des héros
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	page.add_child(body)

	var left := _panel(body, 330)
	left.add_child(_label("Réveille un chasseur", 26, Palette.GOLD))
	var desc := _label(GameData.summon.get("description", ""), 18, Palette.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(desc)
	left.add_child(HSeparator.new())
	left.add_child(_label("Taux", 22, Palette.TEXT))
	_odds = VBoxContainer.new()
	left.add_child(_odds)
	_pity = _label("", 18, Palette.RARITIES[4][1])
	_pity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_pity)
	left.add_child(HSeparator.new())
	var tip := _label("Les Fragments de Relique se gagnent en chasse. Un héros déjà réveillé donne ses propres fragments (pour ses étoiles).", 16, Palette.TEXT_DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(tip)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	body.add_child(center)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(vpc)
	_stage = SummonStage.new()
	vpc.add_child(_stage)
	_build_result(vpc)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	center.add_child(row)
	for c: Array in CURRENCIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(340, 74)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = _icon(c[1])
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 40)
		b.add_theme_font_size_override("font_size", 22)
		var currency: String = c[0]
		b.pressed.connect(func() -> void: _summon(currency))
		row.add_child(b)
		_buttons[currency] = b

	var right := _panel(body, 330)
	right.add_child(_label("Héros de l'Autel", 26, Palette.GOLD))
	_pool = VBoxContainer.new()
	_pool.add_theme_constant_override("separation", 8)
	right.add_child(_pool)

	PlayerData.changed.connect(_refresh)


func open() -> void:
	visible = true
	_result.visible = false
	_stage.reset_stage()
	_refresh()


func _summon(currency: String) -> void:
	if _stage.busy:
		return
	var cfg: Dictionary = GameData.summon
	if not PlayerData.can_summon(currency, cfg):
		ui_sound.emit("ui_toggle")
		return
	_stage.busy = true  # avant summon() : son signal « changed » ne doit pas montrer le résultat
	var r := PlayerData.summon(currency, cfg, GameData.heroes, _rng)
	if r.is_empty():
		_stage.busy = false
		return
	_result.visible = false
	_set_buttons_enabled(false)
	ui_sound.emit("magic_cast")
	var hero := GameData.hero(r.id)
	await _stage.ceremony(hero, r.rarity)
	ui_sound.emit("ultimate_impact")
	_show_result(hero, r)
	_refresh()


func _show_result(hero: Dictionary, r: Dictionary) -> void:
	var rarity: Array = Palette.RARITIES.get(int(r.rarity), Palette.RARITIES[3])
	_result_rarity.text = String(rarity[0]).to_upper()
	_result_rarity.add_theme_color_override("font_color", rarity[1])
	_result_name.text = hero.name
	if r.new:
		_result_detail.text = "Nouveau héros ! Il t'attend dans la Loge."
		_result_detail.add_theme_color_override("font_color", Palette.GOLD)
	else:
		_result_detail.text = "Déjà réveillé : +%d fragments de %s" % [r.shards, hero.name]
		_result_detail.add_theme_color_override("font_color", Palette.TEXT)
	_result.add_theme_stylebox_override("panel", Palette.stylebox(Color(0, 0, 0, 0.6), rarity[1], 18, 3))
	_result.visible = true
	_result.modulate.a = 0.0
	_result.scale = Vector2.ONE * 0.85
	var tw := create_tween().set_parallel()
	tw.tween_property(_result, "modulate:a", 1.0, 0.25)
	tw.tween_property(_result, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func _refresh() -> void:
	if not is_inside_tree() or _stage.busy:
		return  # pendant la cérémonie, rien ne doit trahir le résultat
	var cfg: Dictionary = GameData.summon
	for c: Array in CURRENCIES:
		var currency: String = c[0]
		_balance[currency].text = str(PlayerData.summon_balance(currency)) + "  "
		var info: Dictionary = cfg.get("currencies", {}).get(currency, {})
		_buttons[currency].text = "Invoquer  ·  %d %s" % [int(info.get("cost", 0)),
			"fragments" if currency == "fragments_relique" else "gemmes"]
	_set_buttons_enabled(not _stage.busy)
	for c in _odds.get_children():
		c.queue_free()
	var odds := Summon.odds(GameData.heroes, cfg)
	var keys := odds.keys()
	keys.sort()
	keys.reverse()
	for r: int in keys:
		var rarity: Array = Palette.RARITIES.get(r, ["?", Color.WHITE])
		var line := HBoxContainer.new()
		var name := _label(rarity[0], 20, rarity[1])
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		line.add_child(_label("%.0f %%" % odds[r], 20, Palette.TEXT))
		_odds.add_child(line)
	var left := PlayerData.summons_to_pity(cfg)
	_pity.text = "Légendaire garanti dans %d invocation%s." % [left, "s" if left > 1 else ""]
	for c in _pool.get_children():
		c.queue_free()
	var ids := GameData.heroes.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(GameData.heroes[a].get("rarity", 1)) > int(GameData.heroes[b].get("rarity", 1)))
	for id: String in ids:
		_pool.add_child(_pool_row(GameData.hero(id)))


func _pool_row(hero: Dictionary) -> Control:
	var owned := PlayerData.owned_heroes().has(hero.id)
	var rarity: Array = Palette.RARITIES.get(int(hero.get("rarity", 1)), Palette.RARITIES[1])
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Palette.stylebox(Color(0, 0, 0, 0.4), Color(rarity[1], 0.6), 14, 2))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	row.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	var portrait := RoundPortrait.new().setup(hero, 56)
	if not owned:
		portrait.modulate = Color(0.35, 0.35, 0.4)
	h.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	col.add_child(_label(hero.name, 19, Palette.TEXT if owned else Palette.TEXT_DIM))
	var status := "Réveillé" if owned else "Endormi"
	var shards := PlayerData.hero_shards(hero.id)
	if shards > 0:
		status += "  ·  %d fragments" % shards
	col.add_child(_label("%s  ·  %s" % [rarity[0], status], 15, rarity[1] if owned else Palette.TEXT_DIM))
	return row


func _set_buttons_enabled(on: bool) -> void:
	for currency: String in _buttons:
		_buttons[currency].disabled = not on or not PlayerData.can_summon(currency, GameData.summon)


func _build_result(parent: Control) -> void:
	_result = PanelContainer.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_result.offset_bottom = -10
	_result.custom_minimum_size = Vector2(520, 0)
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_result)
	_result.resized.connect(func() -> void: _result.pivot_offset = _result.size / 2.0)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	_result.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	_result_rarity = _label("", 22, Palette.GOLD)
	_result_name = _label("", 40, Palette.TEXT)
	_result_detail = _label("", 20, Palette.TEXT)
	for l in [_result_rarity, _result_name, _result_detail]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	_result.visible = false


func _panel(parent: Control, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.add_theme_stylebox_override("panel", Palette.stylebox(Color(0.08, 0.06, 0.12, 0.9), Color(1, 1, 1, 0.08), 16, 2))
	parent.add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


func _pill(currency: String, icon_name: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Palette.stylebox(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.12), 24, 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var icon := TextureRect.new()
	icon.texture = _icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(44, 44)
	h.add_child(icon)
	var l := _label("", 24, Palette.TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	_balance[currency] = l
	return p


func _icon(name: String) -> Texture2D:
	var path := ICON_DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
