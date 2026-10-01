class_name HuntPrepScreen
extends UiWindow
## « Préparer la chasse » : avant chaque combat, le donjon choisi, son coût en énergie, les 4
## places de l'équipe et tous les héros possédés (toucher un héros l'ajoute ou le retire).

signal start_requested(dungeon_id: String)
signal ui_sound(sfx_name: String)

var dungeon_id := ""
var _info: Label
var _slots: HBoxContainer
var _pool: GridContainer
var _go: Button


func _init() -> void:
	setup("Préparer la chasse", Vector2(1240, 800))


func _ready() -> void:
	super._ready()
	_info = UiKit.label("", 22, UiKit.TEXT_SOFT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_info)
	content.add_child(_section("Équipe de chasse"))
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 24)
	content.add_child(_slots)
	content.add_child(_section("Tes héros  ·  touche un héros pour l'ajouter ou le retirer"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_pool = GridContainer.new()
	_pool.columns = 6
	_pool.add_theme_constant_override("h_separation", 16)
	_pool.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_pool)
	_go = UiKit.button("", "red", 28, Vector2(460, 72))
	_go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_go.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		start_requested.emit(dungeon_id))
	content.add_child(_go)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


func open_for(p_dungeon: String) -> void:
	dungeon_id = p_dungeon
	open()
	refresh()


func refresh() -> void:
	var d := GameData.dungeon(dungeon_id)
	var cost := PlayerData.hunt_cost(dungeon_id)
	_info.text = "%s  ·  %d vagues  ·  meilleur score : %s" % [d.get("name", dungeon_id),
		d.get("waves", []).size(), "★".repeat(PlayerData.best_stars(dungeon_id)) if PlayerData.best_stars(dungeon_id) > 0 else "aucun"]
	for c in _slots.get_children():
		c.queue_free()
	var team := PlayerData.team()
	for i in PlayerData.TEAM_SIZE:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(170, 0)
		_slots.add_child(col)
		var center := CenterContainer.new()
		col.add_child(center)
		if i < team.size():
			var id: String = team[i]
			center.add_child(_portrait_button(id, 130, true))
			var n := UiKit.label(String(GameData.hero(id).get("short", GameData.hero(id).name)), 21, UiKit.INK)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(n)
			var lv := UiKit.label("Niv. %d" % PlayerData.hero_level(id), 17, UiKit.TEXT_SOFT)
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(lv)
		else:
			var empty := Panel.new()
			empty.custom_minimum_size = Vector2(130, 130)
			empty.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.08), UiKit.PARCHMENT_DARK.darkened(0.2), 65, 3))
			center.add_child(empty)
			var n := UiKit.label("Place libre", 19, UiKit.TEXT_SOFT)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(n)
	for c in _pool.get_children():
		c.queue_free()
	for id: String in PlayerData.owned_heroes():
		var col := VBoxContainer.new()
		var center := CenterContainer.new()
		center.add_child(_portrait_button(id, 96, false))
		col.add_child(center)
		var n := UiKit.label(String(GameData.hero(id).get("short", GameData.hero(id).name)), 18, UiKit.INK if PlayerData.in_team(id) else UiKit.TEXT_SOFT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		_pool.add_child(col)
	_go.text = "Partir en chasse  ·  %d énergie" % cost
	_go.disabled = team.is_empty() or not PlayerData.can_start_hunt(dungeon_id)
	if PlayerData.energy() < cost:
		_go.text = "Pas assez d'énergie (%d / %d)" % [PlayerData.energy(), cost]


func _portrait_button(id: String, size: float, in_slot: bool) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	var p := RoundPortrait.new().setup(GameData.hero(id), size, 0.09 if (in_slot or PlayerData.in_team(id)) else 0.05)
	if not in_slot and PlayerData.in_team(id):
		p.modulate = Color(1, 1, 1, 0.45)
	b.add_child(p)
	b.pressed.connect(func() -> void:
		if PlayerData.toggle_team(id):
			ui_sound.emit("ui_toggle"))
	return b


func _section(text: String) -> Label:
	var l := UiKit.label(text, 24, UiKit.WOOD)
	l.add_theme_font_override("font", UiKit.FONT_BOLD)
	return l
