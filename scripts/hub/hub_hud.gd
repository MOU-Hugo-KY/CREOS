class_name HubHud
extends CanvasLayer
## Interface du hub, épurée : profil en haut à gauche, ressources en haut à droite,
## 5 grands boutons en bas, quelques petits boutons sur les côtés, et un message « bientôt ».

signal action(action_name: String, id: String)
signal ui_sound(sfx_name: String)

const ICON_DIR := "res://assets/ui/hub/"

var _root: Control
var _toast: Label
var _toast_tween: Tween
var _sound_button: Button
var _sound_panel: SoundPanel
var _title: Label


func _ready() -> void:
	_root = Control.new()
	_root.theme = Palette.make_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_profile(GameData.player_start)
	_build_resources(GameData.player_start)
	_build_main_buttons()
	_build_side("side_left", true)
	_build_side("side_right", false)
	_build_toast()
	_build_title()


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


func _build_profile(p: Dictionary) -> void:
	var box := HBoxContainer.new()
	box.position = Vector2(26, 20)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	# Pastille de niveau
	var lvl := Panel.new()
	lvl.custom_minimum_size = Vector2(62, 62)
	lvl.add_theme_stylebox_override("panel", Palette.stylebox(Palette.GOLD_DARK, Palette.GOLD, 31, 3))
	lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lvl)
	var n := _label(28, 6)
	n.text = str(int(p.get("level", 1)))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lvl.add_child(n)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var name_label := _label(26)
	name_label.text = p.get("lodge", p.get("name", "Chasseur"))
	col.add_child(name_label)
	var xp := StatBar.new()
	xp.fill_color = Palette.GOLD
	xp.custom_minimum_size = Vector2(190, 9)
	xp.set_values(float(p.get("xp", 0)) / maxf(1.0, float(p.get("xp_next", 100))))
	col.add_child(xp)


func _build_resources(p: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -24
	row.offset_top = 22
	row.add_theme_constant_override("separation", 12)
	_root.add_child(row)
	var energy := "%d/%d" % [int(p.get("energy", 0)), int(p.get("energy_max", 0))]
	for r: Array in [["or", _fmt(int(p.get("gold", 0)))], ["gemmes", str(int(p.get("gems", 0)))], ["energie", energy]]:
		row.add_child(_pill(r[0], r[1]))
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
	p.add_theme_stylebox_override("panel", Palette.stylebox(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.12), 24, 2))
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
	var l := _label(24, 6)
	l.text = value + "  "
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
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
