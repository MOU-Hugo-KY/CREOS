class_name HubHud
extends CanvasLayer
## Interface du hub, épurée : profil en haut à gauche, ressources en haut à droite,
## 5 grands boutons en bas, quelques petits boutons sur les côtés, et un message « bientôt ».

signal action(action_name: String, id: String)
signal ui_sound(sfx_name: String)
signal screen_opened(open: bool)  # un écran plein (Loge…) s'ouvre ou se ferme

const ICON_DIR := "res://assets/ui/hub/"
# Bouton « Y aller » des primes : action -> bâtiment ou bouton concerné
const ACTION_TARGETS := {"campaign": "table_des_chasses", "altar": "autel", "heroes": "loge_des_heros",
	"shop": "marche", "guild": "guilde", "tower": "tour"}

var _root: Control
var _toast: Label
var _toast_tween: Tween
var _sound_button: Button
var _sound_panel: SoundPanel
var _title: Label
var _level_label: Label
var _lodge_label: Label
var _xp_bar: ProgressBar
var _name_label: Label
var _avatar_holder: Control
var _avatar_id := ""
var _side_buttons: Dictionary = {}  # id -> IconButton
var _values: Dictionary = {}  # "or" / "gemmes" / "energie" -> Label
var lodge: HeroesScreen
var altar: SummonAltar
var profile: ProfileScreen
var quests: QuestsScreen
var hunt_prep: HuntPrepScreen


func _ready() -> void:
	_root = Control.new()
	_root.theme = Palette.make_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_profile()
	_build_resources()
	_build_main_buttons()
	_build_side("side_left", true)
	_build_side("side_right", false)
	_build_toast()
	_build_title()
	lodge = HeroesScreen.new()
	lodge.visible = false
	lodge.closed.connect(close_lodge)
	lodge.ui_sound.connect(func(s: String) -> void: ui_sound.emit(s))
	_root.add_child(lodge)
	altar = SummonAltar.new()
	altar.visible = false
	altar.closed.connect(close_altar)
	altar.ui_sound.connect(func(s: String) -> void: ui_sound.emit(s))
	_root.add_child(altar)
	profile = ProfileScreen.new()
	profile.closed.connect(func() -> void: _set_menus_visible(true))
	profile.ui_sound.connect(func(s: String) -> void: ui_sound.emit(s))
	_root.add_child(profile)
	quests = QuestsScreen.new()
	quests.closed.connect(func() -> void: _set_menus_visible(true))
	quests.ui_sound.connect(func(s: String) -> void: ui_sound.emit(s))
	quests.go_to.connect(func(act: String) -> void: action.emit(act, ACTION_TARGETS.get(act, "")))
	_root.add_child(quests)
	hunt_prep = HuntPrepScreen.new()
	hunt_prep.closed.connect(func() -> void: _set_menus_visible(true))
	hunt_prep.ui_sound.connect(func(s: String) -> void: ui_sound.emit(s))
	_root.add_child(hunt_prep)
	PlayerData.changed.connect(refresh)
	refresh()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)


## Met à jour le profil et les ressources depuis la sauvegarde.
func refresh() -> void:
	_level_label.text = str(PlayerData.level())
	_name_label.text = PlayerData.player_name()
	_lodge_label.text = PlayerData.lodge_name()
	_xp_bar.max_value = maxf(1.0, PlayerData.xp_to_next())
	_xp_bar.value = PlayerData.xp()
	if PlayerData.avatar() != _avatar_id:
		_avatar_id = PlayerData.avatar()
		for c in _avatar_holder.get_children():
			if c is RoundPortrait:
				c.queue_free()
		if _avatar_id != "":
			var p := RoundPortrait.new().setup(GameData.hero(_avatar_id), 84, 0.08)
			_avatar_holder.add_child(p)
			_avatar_holder.move_child(p, 0)
	if _side_buttons.has("primes"):
		var n := PlayerData.claimable_quests()
		var b: IconButton = _side_buttons.primes
		if b.badge != n:
			b.badge = n
			b.queue_redraw()
	_values["or"].text = _fmt(PlayerData.gold()) + "  "
	_values["gemmes"].text = str(PlayerData.gems()) + "  "
	_values["energie"].text = "%d/%d  " % [PlayerData.energy(), PlayerData.energy_max()]
	var next := PlayerData.seconds_to_next_energy()
	_values["energie"].get_parent().get_parent().tooltip_text = "Énergie pleine" if next <= 0 else 		"+1 énergie dans %d min %02d s" % [next / 60, next % 60]


func open_lodge() -> void:
	_set_menus_visible(false)
	lodge.open()


func close_lodge() -> void:
	lodge.visible = false
	_set_menus_visible(true)


func open_profile() -> void:
	_set_menus_visible(false)
	profile.open()


func open_hunt_prep(dungeon_id: String) -> void:
	_set_menus_visible(false)
	hunt_prep.open_for(dungeon_id)


func open_quests() -> void:
	_set_menus_visible(false)
	quests.open()


func open_altar() -> void:
	_set_menus_visible(false)
	altar.open()


func close_altar() -> void:
	altar.visible = false
	_set_menus_visible(true)


## Cache les menus du port pendant qu'un écran plein (comme la Loge) est ouvert.
func _set_menus_visible(on: bool) -> void:
	screen_opened.emit(not on)
	for c in _root.get_children():
		if c not in [lodge, altar, profile, quests, hunt_prep, _toast]:
			c.visible = on
	if on and _sound_panel:
		_sound_panel.visible = _sound_button.button_pressed


## Petit message en bas de l'écran (« Bientôt : … »).
func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


# --- Construction ---------------------------------------------------------------

func _icon(name: String) -> Texture2D:
	var path := ICON_DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


func _label(size: int, outline := 7) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Profil en haut à gauche : héros fétiche, niveau, nom, loge et XP. Un clic ouvre le profil.
func _build_profile() -> void:
	var panel := PanelContainer.new()
	var sb := UiKit.pill()
	sb.content_margin_left = 6
	sb.content_margin_right = 20
	sb.set_corner_radius_all(48)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(22, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "Voir mon profil"
	panel.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			ui_sound.emit("ui_click")
			open_profile())
	_root.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_avatar_holder = Control.new()
	_avatar_holder.custom_minimum_size = Vector2(84, 84)
	_avatar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_avatar_holder)
	var lvl := PanelContainer.new()
	var lsb := UiKit.box(Color("c6a66c"), UiKit.INK, 18, 3)
	lsb.border_width_bottom = 5
	lsb.content_margin_left = 8
	lsb.content_margin_right = 8
	lvl.add_theme_stylebox_override("panel", lsb)
	lvl.position = Vector2(-4, 52)
	lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_holder.add_child(lvl)
	_level_label = UiKit.title("1", 24)
	lvl.add_child(_level_label)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	_name_label = UiKit.title("", 28)
	col.add_child(_name_label)
	_lodge_label = UiKit.label("", 18, Color(1, 0.93, 0.8), 5, UiKit.INK)
	col.add_child(_lodge_label)
	_xp_bar = UiKit.progress(Color("63c8be"), 12)
	_xp_bar.custom_minimum_size.x = 200
	col.add_child(_xp_bar)


func _build_resources() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -24
	row.offset_top = 22
	row.add_theme_constant_override("separation", 12)
	_root.add_child(row)
	for r in ["or", "gemmes", "energie"]:
		row.add_child(_pill(r, ""))
	_sound_button = Button.new()
	_sound_button.text = "SON"
	_sound_button.toggle_mode = true
	_sound_button.focus_mode = Control.FOCUS_NONE
	_sound_button.custom_minimum_size = Vector2(78, 52)
	_sound_button.add_theme_font_size_override("font_size", 20)
	_sound_button.add_theme_stylebox_override("normal", Palette.stylebox(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.25), 26, 2))
	_sound_button.add_theme_stylebox_override("hover", Palette.stylebox(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.5), 26, 2))
	_sound_button.add_theme_stylebox_override("pressed", Palette.stylebox(Color(Palette.GOLD, 0.3), Palette.GOLD, 26, 2))
	_sound_button.toggled.connect(_toggle_sound)
	row.add_child(_sound_button)


func _pill(icon_name: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.pill())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var icon := TextureRect.new()
	icon.texture = _icon(icon_name)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(44, 44)
	h.add_child(icon)
	var l := UiKit.title(value + "  ", 24)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	_values[icon_name] = l
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


func _build_main_buttons() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -18
	row.add_theme_constant_override("separation", 22)
	_root.add_child(row)
	var buildings: Dictionary = GameData.hub.get("buildings", {})
	for id: String in GameData.hub.get("main_buttons", []):
		var info: Dictionary = buildings.get(id, {})
		var b := IconButton.new().setup(_icon(info.get("icon", "")), info.get("name", id), 50.0)
		var act: String = info.get("action", "")
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			action.emit(act, id))
		row.add_child(b)


func _build_side(key: String, left: bool) -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if left else Control.PRESET_CENTER_RIGHT)
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	if left:
		col.offset_left = 18
	else:
		col.offset_right = -18
	col.offset_top = -120
	col.add_theme_constant_override("separation", 6)
	_root.add_child(col)
	for item: Dictionary in GameData.hub.get(key, []):
		var b := IconButton.new().setup(_icon(item.get("icon", "")), item.get("name", ""), 34.0)
		var act: String = item.get("action", "")
		var id: String = item.get("id", "")
		_side_buttons[id] = b
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			action.emit(act, id))
		col.add_child(b)


func _build_toast() -> void:
	_toast = _label(26, 8)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -205
	_toast.offset_bottom = -170
	_toast.offset_left = -600
	_toast.offset_right = 600
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


## Nom de la ville au centre, qui s'efface après l'arrivée.
func _build_title() -> void:
	_title = _label(64, 16)
	_title.text = GameData.hub.get("name", "")
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.offset_top = 110
	_title.offset_left = -500
	_title.offset_right = 500
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Palette.GOLD)
	_root.add_child(_title)
	var sub := _label(26)
	sub.text = GameData.hub.get("subtitle", "")
	sub.position = Vector2(0, 80)
	sub.size = Vector2(1000, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_child(sub)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_title, "modulate:a", 0.0, 1.0)


func _toggle_sound(on: bool) -> void:
	ui_sound.emit("ui_toggle")
	if on and _sound_panel == null:
		_sound_panel = SoundPanel.new()
		_sound_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_sound_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_sound_panel.offset_right = -24
		_sound_panel.offset_top = 90
		_sound_panel.closed.connect(func() -> void: _sound_button.button_pressed = false)
		_sound_panel.test_sound.connect(func() -> void: ui_sound.emit("ui_click"))
		_root.add_child(_sound_panel)
	if _sound_panel:
		_sound_panel.visible = on


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
