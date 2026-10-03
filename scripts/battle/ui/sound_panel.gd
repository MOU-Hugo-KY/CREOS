class_name SoundPanel
extends PanelContainer
## Petit panneau de réglage du son : Général, Musique, Effets, et couper le son.

signal closed
signal test_sound

var _sliders: Dictionary = {}  # bus -> HSlider
var _values: Dictionary = {}  # bus -> Label
var _mute: CheckButton


func _ready() -> void:
	add_theme_stylebox_override("panel", Palette.stylebox(Color(0.05, 0.06, 0.08, 0.9), Color(1, 1, 1, 0.15), 18, 2))
	custom_minimum_size = Vector2(440, 0)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "Son"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "OK"
	close.custom_minimum_size = Vector2(70, 44)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: closed.emit())
	head.add_child(close)

	_add_slider(v, "Général", "Master")
	_add_slider(v, "Musique", GameSettings.BUS_MUSIC)
	_add_slider(v, "Effets", GameSettings.BUS_SFX)

	_mute = CheckButton.new()
	_mute.text = "Couper le son"
	_mute.focus_mode = Control.FOCUS_NONE
	_mute.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_mute.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_mute.button_pressed = GameSettings.muted
	_mute.toggled.connect(func(on: bool) -> void: GameSettings.set_muted(on))
	v.add_child(_mute)


func _add_slider(parent: Control, label: String, bus: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = GameSettings.get_volume(bus)
	s.custom_minimum_size = Vector2(190, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var value := Label.new()
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 20)
	value.text = "%d %%" % int(round(s.value * 100))
	row.add_child(value)
	s.value_changed.connect(func(x: float) -> void:
		GameSettings.set_volume(bus, x)
		value.text = "%d %%" % int(round(x * 100)))
	# Un petit son quand on relâche le curseur des effets, pour entendre le niveau.
	if bus != GameSettings.BUS_MUSIC:
		s.drag_ended.connect(func(_changed: bool) -> void: test_sound.emit())
	_sliders[bus] = s
	_values[bus] = value
