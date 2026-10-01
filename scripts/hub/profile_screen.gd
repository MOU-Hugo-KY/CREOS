class_name ProfileScreen
extends UiWindow
## Profil du chasseur : son héros fétiche, son nom et celui de sa loge (modifiables), son niveau,
## ses statistiques et son équipe de chasse.

signal ui_sound(sfx_name: String)

var _avatar_box: CenterContainer
var _level_label: Label
var _name_label: Label
var _lodge_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _edit_box: VBoxContainer
var _name_edit: LineEdit
var _lodge_edit: LineEdit
var _edit_error: Label
var _view_box: VBoxContainer
var _picker: GridContainer
var _stats: GridContainer
var _team: HBoxContainer
var _badges: HBoxContainer

# Succès : [titre, explication, icône, condition (Callable sur PlayerData)]
const BADGES := [
	["Premier sang", "Gagner une chasse", "chasses"],
	["Sans faute", "Gagner une chasse avec 3 étoiles", "classement"],
	["Invocateur", "Faire une invocation", "autel"],
	["Collectionneur", "Réveiller 5 héros", "heros"],
	["Fidèle", "Venir au port 7 jours", "primes"],
]


func _init() -> void:
	setup("Profil du chasseur", Vector2(1260, 800), Color("505e75"))


func _ready() -> void:
	super._ready()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	content.add_child(body)

	# --- Colonne de gauche : le chasseur -------------------------------------------
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_stylebox_override("panel", UiKit.card())
	body.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(lv)
	_avatar_box = CenterContainer.new()
	_avatar_box.custom_minimum_size = Vector2(0, 230)
	lv.add_child(_avatar_box)
	var change := UiKit.button("Changer de héros", "wood", 20, Vector2(0, 52))
	change.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_picker.visible = not _picker.visible
		_view_box.visible = not _picker.visible)
	lv.add_child(change)
	_picker = GridContainer.new()
	_picker.columns = 3
	_picker.add_theme_constant_override("h_separation", 14)
	_picker.add_theme_constant_override("v_separation", 14)
	_picker.visible = false
	lv.add_child(_picker)

	_view_box = VBoxContainer.new()
	_view_box.add_theme_constant_override("separation", 6)
	lv.add_child(_view_box)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	_view_box.add_child(name_row)
	_name_label = UiKit.label("", 36, UiKit.TEXT_ON_PARCHMENT)
	_name_label.add_theme_font_override("font", UiKit.FONT_BOLD)
	name_row.add_child(_name_label)
	var pencil := UiKit.button("✎", "gold", 24, Vector2(52, 52))
	pencil.tooltip_text = "Changer de nom"
	pencil.pressed.connect(func() -> void: _set_editing(true))
	name_row.add_child(pencil)
	_lodge_label = UiKit.label("", 22, UiKit.TEXT_SOFT)
	_lodge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_box.add_child(_lodge_label)
	_xp_bar = UiKit.progress(Color("63c8be"), 24)
	_view_box.add_child(_xp_bar)
	_xp_label = UiKit.label("", 18, UiKit.TEXT_SOFT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_box.add_child(_xp_label)

	_edit_box = VBoxContainer.new()
	_edit_box.add_theme_constant_override("separation", 8)
	_edit_box.visible = false
	lv.add_child(_edit_box)
	_edit_box.add_child(UiKit.label("Ton nom", 20, UiKit.TEXT_SOFT))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_edit_box.add_child(_name_edit)
	_edit_box.add_child(UiKit.label("Nom de ta loge", 20, UiKit.TEXT_SOFT))
	_lodge_edit = LineEdit.new()
	_lodge_edit.max_length = 24
	_edit_box.add_child(_lodge_edit)
	_edit_error = UiKit.label("", 17, Color("b8462e"))
	_edit_box.add_child(_edit_error)
	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 10)
	_edit_box.add_child(edit_row)
	var cancel := UiKit.button("Annuler", "grey", 20, Vector2(150, 54))
	cancel.pressed.connect(func() -> void: _set_editing(false))
	edit_row.add_child(cancel)
	var ok := UiKit.button("Valider", "green", 20, Vector2(0, 54))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_save_names)
	edit_row.add_child(ok)

	# --- Colonne de droite : statistiques et équipe ---------------------------------
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	right.add_child(_section_title("Statistiques"))
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 12)
	_stats.add_theme_constant_override("v_separation", 12)
	right.add_child(_stats)
	right.add_child(_section_title("Équipe de chasse"))
	_team = HBoxContainer.new()
	_team.add_theme_constant_override("separation", 12)
	right.add_child(_team)
	right.add_child(_section_title("Succès"))
	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", 12)
	right.add_child(_badges)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	super.open()
	_picker.visible = false
	_view_box.visible = true
	_set_editing(false)
	refresh()


func refresh() -> void:
	for c in _avatar_box.get_children():
		c.queue_free()
	var avatar := PlayerData.avatar()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(220, 220)
	_avatar_box.add_child(holder)
	if avatar != "":
		holder.add_child(RoundPortrait.new().setup(GameData.hero(avatar), 220, 0.06))
	var lvl := PanelContainer.new()
	var lsb := UiKit.box(Color("c6a66c"), UiKit.INK, 32, 4)
	lsb.border_width_bottom = 8
	lsb.content_margin_left = 14
	lsb.content_margin_right = 14
	lvl.add_theme_stylebox_override("panel", lsb)
	lvl.position = Vector2(-4, 150)
	_level_label = UiKit.title(str(PlayerData.level()), 40)
	lvl.add_child(_level_label)
	holder.add_child(lvl)

	_name_label.text = PlayerData.player_name()
	_lodge_label.text = PlayerData.lodge_name()
	_xp_bar.max_value = maxf(1.0, PlayerData.xp_to_next())
	_xp_bar.value = PlayerData.xp()
	_xp_label.text = "Niveau %d  ·  %d / %d XP" % [PlayerData.level(), PlayerData.xp(), PlayerData.xp_to_next()]

	for c in _picker.get_children():
		c.queue_free()
	for id: String in PlayerData.owned_heroes():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(108, 108)
		var p := RoundPortrait.new().setup(GameData.hero(id), 100, 0.1 if id == avatar else 0.05)
		p.position = Vector2(4, 4)
		b.add_child(p)
		var hero_id := id
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			PlayerData.set_avatar(hero_id)
			_picker.visible = false
			_view_box.visible = true)
		_picker.add_child(b)

	for c in _stats.get_children():
		c.queue_free()
	var stats := [
		["heros", str(PlayerData.owned_heroes().size()) + " / " + str(GameData.heroes.size()), "Héros réveillés"],
		["chasses", str(PlayerData.stat("hunts_won")), "Chasses gagnées"],
		["classement", str(PlayerData.total_stars()), "Étoiles gagnées"],
		["autel", str(int(PlayerData.state.get("summon_count", 0))), "Invocations"],
		["or", _fmt(PlayerData.stat("gold_earned")), "Or gagné"],
		["primes", str(maxi(1, PlayerData.stat("days_played"))), "Jours au port"],
	]
	for s: Array in stats:
		_stats.add_child(_stat_card(s[0], s[1], s[2]))

	for c in _team.get_children():
		c.queue_free()
	for id: String in PlayerData.team():
		var hero := GameData.hero(id)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.custom_minimum_size = Vector2(170, 0)
		var pc := CenterContainer.new()
		pc.add_child(RoundPortrait.new().setup(hero, 104))
		col.add_child(pc)
		var n := UiKit.label(String(hero.get("short", hero.name)), 20, UiKit.TEXT_ON_PARCHMENT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var l := UiKit.label("Niv. %d" % PlayerData.hero_level(id), 17, UiKit.TEXT_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		_team.add_child(col)

	for c in _badges.get_children():
		c.queue_free()
	for i in BADGES.size():
		_badges.add_child(_badge(i))


func _badge_unlocked(index: int) -> bool:
	match index:
		0: return PlayerData.stat("hunts_won") >= 1
		1: return PlayerData.total_stars() >= 3
		2: return int(PlayerData.state.get("summon_count", 0)) >= 1
		3: return PlayerData.owned_heroes().size() >= 5
		4: return PlayerData.stat("days_played") >= 7
	return false


func _badge(index: int) -> Control:
	var info: Array = BADGES[index]
	var on := _badge_unlocked(index)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(108, 0)
	col.tooltip_text = "%s : %s" % [info[0], info[1]]
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	var medal := PanelContainer.new()
	var sb := UiKit.box(Color("c6a66c") if on else Color("cfc6b8"), UiKit.INK if on else Color("9b9286"), 40, 4)
	sb.border_width_bottom = 8
	sb.set_content_margin_all(10)
	medal.add_theme_stylebox_override("panel", sb)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(info[2], 52)
	if not on:
		ic.modulate = Color(0.35, 0.33, 0.3, 0.6)
	medal.add_child(ic)
	col.add_child(medal)
	var l := UiKit.label(info[0], 16, UiKit.TEXT_ON_PARCHMENT if on else UiKit.TEXT_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


func _stat_card(icon_name: String, value: String, caption: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(UiKit.icon(icon_name, 54))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	h.add_child(v)
	var big := UiKit.label(value, 32, UiKit.TEXT_ON_PARCHMENT)
	big.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(big)
	v.add_child(UiKit.label(caption, 17, UiKit.TEXT_SOFT))
	return card


func _section_title(text: String) -> Label:
	var l := UiKit.label(text, 26, UiKit.WOOD)
	l.add_theme_font_override("font", UiKit.FONT_BOLD)
	return l


func _set_editing(on: bool) -> void:
	_edit_box.visible = on
	_view_box.visible = not on
	_edit_error.text = ""
	if on:
		_picker.visible = false
		_name_edit.text = PlayerData.player_name()
		_lodge_edit.text = PlayerData.lodge_name()


func _save_names() -> void:
	if PlayerData.rename(_name_edit.text, _lodge_edit.text):
		ui_sound.emit("ui_ready")
		_set_editing(false)
	else:
		ui_sound.emit("ui_toggle")
		_edit_error.text = "Nom : 3 à 16 lettres. Loge : 3 à 24 lettres."


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
