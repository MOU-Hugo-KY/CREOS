class_name BattleHud
extends CanvasLayer
## Interface du combat, volontairement épurée pour laisser voir le décor :
## vague en haut à gauche, Auto et ×2 en haut à droite, barre du boss, barres fines au-dessus
## des personnages, et les 3 icônes d'attaque seulement quand c'est au tour d'un héros.

signal attack_requested(uid: int, slot: int)
signal auto_toggled(on: bool)
signal speed_toggled(fast: bool)
signal restart_requested
signal ui_sound(sfx_name: String)

var camera: Camera3D
var end_screen: EndScreen
var attack_bar: AttackBar

var _root: Control
var _overhead_layer: Control
var _overheads: Dictionary = {}  # uid -> OverheadBar
var _wave_label: Label
var _auto_button: Button
var _speed_button: Button
var _boss_box: Control
var _boss_bar: StatBar
var _boss_name: Label
var _boss_view: UnitView
var _banner: Label
var _banner_sub: Label
var _callout: Label
var _turn_uid := -1


func _ready() -> void:
	_root = Control.new()
	_root.theme = Palette.make_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overhead_layer = Control.new()
	_overhead_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overhead_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overhead_layer)

	_build_header()
	_build_boss_bar()
	_build_banner()

	attack_bar = AttackBar.new()
	attack_bar.attack_chosen.connect(func(slot: int) -> void:
		if _turn_uid != -1:
			attack_requested.emit(_turn_uid, slot))
	_root.add_child(attack_bar)

	end_screen = EndScreen.new()
	end_screen.visible = false
	end_screen.restart_pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		restart_requested.emit())
	end_screen.sound.connect(func(s: String) -> void: ui_sound.emit(s))
	_root.add_child(end_screen)


# --- API appelée par la scène ----------------------------------------------------

func reset() -> void:
	clear_overheads()
	end_screen.visible = false
	end_turn()


func add_overhead(view: UnitView) -> void:
	var bar := OverheadBar.new()
	bar.setup(view)
	_overhead_layer.add_child(bar)
	_overheads[view.unit.uid] = bar
	if view.unit.is_boss:
		_boss_view = view
		_boss_name.text = view.unit.display_name
		_boss_box.visible = true


func remove_overhead(uid: int) -> void:
	if _overheads.has(uid):
		_overheads[uid].queue_free()
		_overheads.erase(uid)


func clear_overheads() -> void:
	for uid in _overheads.keys():
		remove_overhead(uid)
	_boss_view = null
	_boss_box.visible = false


func set_auto(on: bool) -> void:
	_auto_button.set_pressed_no_signal(on)


func set_wave(index: int, count: int) -> void:
	_wave_label.text = "Vague %d / %d" % [index + 1, count]


## Au tour du héros `unit` : flèche au-dessus de lui et ses 3 attaques en bas.
func begin_turn(unit: BattleUnit) -> void:
	end_turn()
	_turn_uid = unit.uid
	if _overheads.has(unit.uid):
		_overheads[unit.uid].active = true
	attack_bar.show_for(unit)


func end_turn(chosen_slot := -1) -> void:
	if _overheads.has(_turn_uid):
		_overheads[_turn_uid].active = false
	_turn_uid = -1
	attack_bar.hide_bar(chosen_slot)


func refresh(delta: float) -> void:
	for uid in _overheads:
		_overheads[uid].follow(camera, delta)
	attack_bar.refresh()
	if _boss_view:
		var u := _boss_view.unit
		_boss_bar.set_values(_boss_view.shown_hp / u.max_hp, u.shield / u.max_hp)
		_boss_box.visible = _boss_view.shown_hp > 0.0


## Grande annonce au centre (« Vague 2 / 3 », « Le boss arrive ! »…).
func banner(text: String, sub := "", duration := 1.4) -> void:
	_banner.text = text
	_banner_sub.text = sub
	for l: Label in [_banner, _banner_sub]:
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		tw.tween_interval(duration)
		tw.tween_property(l, "modulate:a", 0.0, 0.5)


## Nom d'une attaque ultime, affiché brièvement en haut au centre.
func callout(attack_name: String, _caster_name: String, color: Color, _from_left: bool) -> void:
	_callout.text = attack_name
	_callout.add_theme_color_override("font_color", color.lightened(0.4))
	_callout.modulate.a = 0.0
	_callout.scale = Vector2.ONE * 1.3
	var tw := create_tween().set_parallel()
	tw.tween_property(_callout, "modulate:a", 1.0, 0.12)
	tw.tween_property(_callout, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(_callout, "modulate:a", 0.0, 0.3)


func show_end(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String) -> void:
	end_turn()
	end_screen.show_result(won, stars, rewards, hero_stats, dungeon_name)


# --- Construction ---------------------------------------------------------------

func _label(size: int, outline := 8) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_header() -> void:
	_wave_label = _label(26)
	_wave_label.position = Vector2(32, 22)
	_wave_label.modulate = Color(1, 1, 1, 0.85)
	_root.add_child(_wave_label)

	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -24
	right.offset_top = 18
	right.add_theme_constant_override("separation", 10)
	_root.add_child(right)
	_auto_button = _round_button("AUTO")
	_auto_button.toggled.connect(func(on: bool) -> void:
		ui_sound.emit("ui_toggle")
		auto_toggled.emit(on))
	right.add_child(_auto_button)
	_speed_button = _round_button("×2")
	_speed_button.toggled.connect(func(on: bool) -> void:
		ui_sound.emit("ui_toggle")
		speed_toggled.emit(on))
	right.add_child(_speed_button)


func _round_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(78, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Palette.stylebox(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.25), 26, 2))
	b.add_theme_stylebox_override("hover", Palette.stylebox(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.5), 26, 2))
	b.add_theme_stylebox_override("pressed", Palette.stylebox(Color(Palette.GOLD, 0.3), Palette.GOLD, 26, 2))
	b.add_theme_color_override("font_pressed_color", Palette.GOLD.lightened(0.3))
	return b


func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_top = 24
	_boss_box.offset_left = -300
	_boss_box.offset_right = 300
	_boss_box.offset_bottom = 70
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	_root.add_child(_boss_box)
	_boss_name = _label(22)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_color_override("font_color", Color(0.86, 0.74, 1.0))
	_boss_name.size = Vector2(600, 28)
	_boss_box.add_child(_boss_name)
	_boss_bar = StatBar.new()
	_boss_bar.fill_color = Color(0.68, 0.3, 0.88)
	_boss_bar.position = Vector2(0, 32)
	_boss_bar.size = Vector2(600, 12)
	_boss_box.add_child(_boss_bar)


func _build_banner() -> void:
	_banner = _label(64, 16)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = -250
	_banner.offset_bottom = -170
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", Palette.GOLD)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)
	_banner_sub = _label(28)
	_banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_sub.offset_top = -170
	_banner_sub.offset_bottom = -130
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.modulate.a = 0.0
	_root.add_child(_banner_sub)

	_callout = _label(46, 12)
	_callout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_callout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_callout.offset_top = 96
	_callout.offset_bottom = 156
	_callout.offset_left = -500
	_callout.offset_right = 500
	_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callout.pivot_offset = Vector2(500, 30)
	_callout.modulate.a = 0.0
	_root.add_child(_callout)
