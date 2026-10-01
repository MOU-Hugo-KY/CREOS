class_name BattleHud
extends CanvasLayer
## Interface du combat : en-tête (donjon, vagues, Auto, ×2), barre du boss, cartes des héros,
## barres au-dessus des têtes, annonces et écran de fin. Affichage seulement.

signal attack_requested(uid: int, slot: int)
signal auto_toggled(on: bool)
signal speed_toggled(fast: bool)
signal restart_requested
signal ui_sound(sfx_name: String)

var camera: Camera3D
var end_screen: EndScreen

var _root: Control
var _overhead_layer: Control
var _cards_row: HBoxContainer
var _cards: Array[HeroCard] = []
var _overheads: Dictionary = {}  # uid -> OverheadBar
var _wave_label: Label
var _wave_pips: Array[Panel] = []
var _auto_button: Button
var _speed_button: Button
var _boss_panel: PanelContainer
var _boss_bar: StatBar
var _boss_name: Label
var _boss_view: UnitView
var _banner: Label
var _banner_sub: Label
var _callout: PanelContainer
var _callout_label: Label


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
	_build_callout()

	_cards_row = HBoxContainer.new()
	_cards_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_cards_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cards_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cards_row.offset_bottom = -14
	_cards_row.add_theme_constant_override("separation", 12)
	_root.add_child(_cards_row)

	end_screen = EndScreen.new()
	end_screen.visible = false
	end_screen.restart_pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		restart_requested.emit())
	end_screen.sound.connect(func(s: String) -> void: ui_sound.emit(s))
	_root.add_child(end_screen)


# --- API appelée par la scène ----------------------------------------------------

func setup_heroes(heroes: Array[BattleUnit], views: Dictionary, unit_data: Dictionary) -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	for h in heroes:
		var card := HeroCard.new()
		card.setup(h, views[h.uid], unit_data[h.uid])
		var uid := h.uid
		card.attack_pressed.connect(func(slot: int) -> void: attack_requested.emit(uid, slot))
		_cards_row.add_child(card)
		_cards.append(card)
	end_screen.visible = false


func add_overhead(view: UnitView) -> void:
	var bar := OverheadBar.new()
	bar.setup(view)
	_overhead_layer.add_child(bar)
	_overheads[view.unit.uid] = bar
	if view.unit.is_boss:
		_boss_view = view
		_boss_name.text = view.unit.display_name
		_boss_panel.visible = true
		bar.visible = false


func remove_overhead(uid: int) -> void:
	if _overheads.has(uid):
		_overheads[uid].queue_free()
		_overheads.erase(uid)


func clear_overheads() -> void:
	for uid in _overheads.keys():
		remove_overhead(uid)
	_boss_view = null
	_boss_panel.visible = false


func set_auto(on: bool) -> void:
	_auto_button.set_pressed_no_signal(on)


func set_wave(index: int, count: int) -> void:
	_wave_label.text = "Vague %d / %d" % [index + 1, count]
	for i in _wave_pips.size():
		var p := _wave_pips[i]
		p.visible = i < count
		var color := Palette.GOLD if i <= index else Color(0.3, 0.3, 0.33)
		p.add_theme_stylebox_override("panel", Palette.stylebox(color, Color(0, 0, 0, 0.8), 9, 2))


func refresh() -> void:
	for c in _cards:
		c.refresh()
	for uid in _overheads:
		var bar: OverheadBar = _overheads[uid]
		if bar.view.unit.is_boss:
			continue
		bar.follow(camera)
	if _boss_view:
		var u := _boss_view.unit
		_boss_bar.set_values(_boss_view.shown_hp / u.max_hp, u.shield / u.max_hp,
			"%d / %d" % [int(ceil(_boss_view.shown_hp)), int(u.max_hp)])
		_boss_panel.visible = _boss_view.shown_hp > 0.0


## Grande annonce au centre (« Vague 2 / 3 », « Le boss arrive ! »…).
func banner(text: String, sub := "", duration := 1.6) -> void:
	_banner.text = text
	_banner_sub.text = sub
	for l: Label in [_banner, _banner_sub]:
		l.modulate.a = 0.0
		l.scale = Vector2.ONE * 1.4
		var tw := create_tween().set_parallel()
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(duration)
		tw.chain().tween_property(l, "modulate:a", 0.0, 0.4)


## Bandeau qui traverse l'écran avec le nom d'une attaque ultime.
func callout(attack_name: String, caster_name: String, color: Color, from_left: bool) -> void:
	_callout_label.text = "%s  —  %s" % [attack_name.to_upper(), caster_name]
	_callout.add_theme_stylebox_override("panel", Palette.stylebox(Color(color.darkened(0.55), 0.92), color, 0, 3))
	var w := get_viewport().get_visible_rect().size.x
	_callout.reset_size()
	var target_x := (w - _callout.size.x) / 2.0
	_callout.position = Vector2(-_callout.size.x if from_left else w, 300)
	_callout.modulate.a = 1.0
	_callout.visible = true
	var tw := create_tween()
	tw.tween_property(_callout, "position:x", target_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(_callout, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void: _callout.visible = false)


func show_end(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String) -> void:
	end_screen.show_result(won, stars, rewards, hero_stats, dungeon_name)


# --- Construction ---------------------------------------------------------------

func _build_header() -> void:
	var left := PanelContainer.new()
	left.position = Vector2(24, 20)
	_root.add_child(left)
	var lm := MarginContainer.new()
	for side in ["left", "right"]:
		lm.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		lm.add_theme_constant_override("margin_" + side, 8)
	left.add_child(lm)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	lm.add_child(lv)
	var title := Label.new()
	title.text = "Brumenoire — Le Gué des Noyés"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.GOLD)
	lv.add_child(title)
	var wave_row := HBoxContainer.new()
	wave_row.add_theme_constant_override("separation", 8)
	lv.add_child(wave_row)
	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 20)
	wave_row.add_child(_wave_label)
	for i in 5:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(18, 18)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wave_row.add_child(pip)
		_wave_pips.append(pip)

	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -24
	right.offset_top = 20
	right.add_theme_constant_override("separation", 12)
	_root.add_child(right)
	_auto_button = _toggle_button("AUTO")
	_auto_button.toggled.connect(func(on: bool) -> void:
		ui_sound.emit("ui_toggle")
		auto_toggled.emit(on))
	right.add_child(_auto_button)
	_speed_button = _toggle_button("×2")
	_speed_button.toggled.connect(func(on: bool) -> void:
		ui_sound.emit("ui_toggle")
		speed_toggled.emit(on))
	right.add_child(_speed_button)


func _toggle_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(120, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("pressed", Palette.stylebox(Palette.GOLD_DARK, Palette.GOLD, 12, 3))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b


func _build_boss_bar() -> void:
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_panel.offset_top = 110
	_boss_panel.custom_minimum_size = Vector2(760, 0)
	_boss_panel.add_theme_stylebox_override("panel", Palette.stylebox(Palette.PANEL, Color(Palette.element_color("ombre"), 0.7), 14, 2))
	_boss_panel.visible = false
	_root.add_child(_boss_panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	_boss_panel.add_child(m)
	var v := VBoxContainer.new()
	m.add_child(v)
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 24)
	_boss_name.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	v.add_child(_boss_name)
	_boss_bar = StatBar.new()
	_boss_bar.fill_color = Color(0.7, 0.25, 0.85)
	_boss_bar.custom_minimum_size = Vector2(0, 26)
	_boss_bar.font_size = 17
	v.add_child(_boss_bar)


func _build_banner() -> void:
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = -260
	_banner.offset_bottom = -170
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 72)
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.add_theme_color_override("font_color", Palette.GOLD)
	_banner.modulate.a = 0.0
	_banner.resized.connect(func() -> void: _banner.pivot_offset = _banner.size / 2.0)
	_root.add_child(_banner)
	_banner_sub = Label.new()
	_banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_sub.offset_top = -170
	_banner_sub.offset_bottom = -120
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 30)
	_banner_sub.modulate.a = 0.0
	_banner_sub.resized.connect(func() -> void: _banner_sub.pivot_offset = _banner_sub.size / 2.0)
	_root.add_child(_banner_sub)


func _build_callout() -> void:
	_callout = PanelContainer.new()
	_callout.visible = false
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_callout)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 60)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	_callout.add_child(m)
	_callout_label = Label.new()
	_callout_label.add_theme_font_size_override("font_size", 40)
	_callout_label.add_theme_constant_override("outline_size", 10)
	m.add_child(_callout_label)
