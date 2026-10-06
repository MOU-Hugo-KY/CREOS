class_name CampaignScreen
extends UiWindow
## « Table des chasses » : les 10 mondes de l'acte I et leurs 8 niveaux. À gauche les mondes
## (verrouillés tant que le premier niveau n'est pas ouvert), à droite le décor du monde choisi et
## ses niveaux avec leurs étoiles. Un niveau s'ouvre quand on a gagné celui d'avant.

signal hunt_chosen(dungeon_id: String)
signal ui_sound(sfx_name: String)

var region := ""
var _worlds: VBoxContainer
var _banner: TextureRect
var _world_name: Label
var _world_info: Label
var _levels: GridContainer


func _init() -> void:
	setup("Table des chasses", Vector2(1560, 900))


func _ready() -> void:
	super._ready()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	content.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_worlds = VBoxContainer.new()
	_worlds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_worlds.add_theme_constant_override("separation", 8)
	scroll.add_child(_worlds)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var frame := PanelContainer.new()
	var fsb := UiKit.box(UiKit.INK, UiKit.INK, 14, 3)
	frame.add_theme_stylebox_override("panel", fsb)
	right.add_child(frame)
	_banner = TextureRect.new()
	_banner.custom_minimum_size = Vector2(0, 250)
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_banner.clip_contents = true
	frame.add_child(_banner)
	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_END
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(over)
	_world_name = UiKit.title("", 40)
	_world_name.add_theme_constant_override("outline_size", 12)
	over.add_child(_world_name)
	_world_info = UiKit.label("", 20, UiKit.WHITE, 6, UiKit.INK)
	over.add_child(_world_info)
	_levels = GridContainer.new()
	_levels.columns = 4
	_levels.add_theme_constant_override("h_separation", 14)
	_levels.add_theme_constant_override("v_separation", 14)
	right.add_child(_levels)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


## Ouvre la carte sur le monde où en est le joueur.
func open_current() -> void:
	var current := PlayerData.current_campaign_level()
	region = String(GameData.dungeon(current).get("region", GameData.region_ids()[0]))
	open()
	refresh()


func refresh() -> void:
	for c in _worlds.get_children():
		c.queue_free()
	for rid: String in GameData.region_ids():
		_worlds.add_child(_world_button(rid))
	var info: Dictionary = GameData.regions.get(region, {})
	var fond := String(info.get("decor", "")) + "fond1.jpg"
	_banner.texture = load(fond) if ResourceLoader.exists(fond) else null
	_world_name.text = "Monde %d · %s" % [int(info.get("order", 0)), info.get("name", "")]
	var ids := GameData.region_dungeons(region)
	var stars := 0
	for id: String in ids:
		stars += PlayerData.best_stars(id)
	_world_info.text = "%d niveaux · %d / %d étoiles" % [ids.size(), stars, ids.size() * 3]
	for c in _levels.get_children():
		c.queue_free()
	for id: String in ids:
		_levels.add_child(_level_card(id))


func _world_button(rid: String) -> Button:
	var info: Dictionary = GameData.regions[rid]
	var ids := GameData.region_dungeons(rid)
	var open := not ids.is_empty() and PlayerData.dungeon_unlocked(ids[0])
	var stars := 0
	for id: String in ids:
		stars += PlayerData.best_stars(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 74)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "  %d · %s\n      %s" % [int(info.order), info.name, ("★ %d / %d" % [stars, ids.size() * 3]) if open else "🔒 verrouillé"]
	var active := rid == region
	var kind := "danger" if active else ("secondary" if open else "disabled")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := UiKit.kit("button_%s_%s" % [kind, "normal" if st == "disabled" else st], Color.WHITE, true)
		sb.content_margin_left = 14
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 19)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(st, UiKit.WHITE)
	b.disabled = not open
	b.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		region = rid
		refresh())
	return b


func _level_card(id: String) -> Control:
	var d := GameData.dungeon(id)
	var open := PlayerData.dungeon_unlocked(id)
	var stars := PlayerData.best_stars(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := id == PlayerData.current_campaign_level()
	var sb := UiKit.card(UiKit.TEAL if current else Color.TRANSPARENT)
	if not open:
		sb.modulate_color = Color(0.72, 0.68, 0.62)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not open
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 16
	v.offset_right = -24
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var level := int(d.get("level", 0))
	var t := UiKit.label("Niveau %d%s" % [level, "  ·  BOSS" if level == 8 else ""], 22, UiKit.INK)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(t)
	var waves: Array = d.get("waves", [])
	var boss_id := String(waves[-1][1]) if not waves.is_empty() and waves[-1].size() > 1 else ""  # [n, boss, n]
	var boss := String(GameData.monsters.get(boss_id, {}).get("name", ""))
	var bl := UiKit.label(boss if open else "???", 18, UiKit.TEXT_SOFT)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bl)
	v.add_child(UiKit.label("★".repeat(stars) + "☆".repeat(3 - stars) if open else "🔒", 24, UiKit.WOOD_LIGHT if open else UiKit.TEXT_SOFT))
	v.add_child(UiKit.label("⚡ %d énergie" % int(d.get("energy_cost", 0)), 16, UiKit.SLATE))
	b.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		hunt_chosen.emit(id))
	return b
