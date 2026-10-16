class_name BattleHud
extends CanvasLayer
## Interface du combat, volontairement épurée pour laisser voir le décor :
## vague en haut à gauche, Auto et ×2 en haut à droite, barre du boss, barres fines au-dessus
## des personnages, et les 3 icônes d'attaque seulement quand c'est au tour d'un héros.

signal attack_requested(uid: int, slot: int)
signal quartet_requested
signal combo_requested(combo_id: String)
signal auto_toggled(on: bool)
signal speed_toggled(fast: bool)
signal restart_requested
signal hub_requested
signal draw_requested
signal ui_sound(sfx_name: String)

var end_screen: EndScreen
var attack_bar: AttackBar
var turn_order: TurnOrder

var _root: Control
var _overhead_layer: Control
var _overheads: Dictionary = {}  # uid -> OverheadBar
var _wave_label: Label
var _auto_button: Button
var _speed_button: Button
var _boss_box: Control
var _boss_bar: StatBar
var _boss_name: Label
var _boss_portrait: TextureRect
var _boss_hp: Control
var _boss_ratio := 1.0
var _banner_bg: Panel
var _boss_view: UnitView
var _banner: Label
var _banner_sub: Label
var _callout: Label
var _turn_uid := -1
var _sound_button: Button
var draw_button: Button
var _sound_panel: SoundPanel
var _quartet_button: Button
var _combo_box: VBoxContainer  # boutons des combos prêts (quatuor, trios, duos)
var _combo_ids: Array = []


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

	turn_order = TurnOrder.new()
	_root.add_child(turn_order)
	attack_bar = AttackBar.new()
	attack_bar.attack_chosen.connect(func(slot: int) -> void:
		if _turn_uid != -1:
			attack_requested.emit(_turn_uid, slot))
	_root.add_child(attack_bar)

	# Attaque combinée du quatuor : apparaît au-dessus des attaques quand elle est prête.
	_quartet_button = UiKit.button("QUATUOR", "gold", 26, Vector2(420, 64))
	_quartet_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_quartet_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_quartet_button.offset_top = -300
	_quartet_button.offset_bottom = -236
	_quartet_button.offset_left = -210
	_quartet_button.offset_right = 210
	_quartet_button.visible = false
	_quartet_button.pressed.connect(func() -> void: quartet_requested.emit())
	_root.add_child(_quartet_button)
	_combo_box = VBoxContainer.new()
	_combo_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_combo_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_combo_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_combo_box.offset_right = -28
	_combo_box.offset_bottom = -26
	_combo_box.offset_left = -264
	_combo_box.alignment = BoxContainer.ALIGNMENT_END
	_combo_box.add_theme_constant_override("separation", 12)
	_root.add_child(_combo_box)

	end_screen = EndScreen.new()
	end_screen.visible = false
	end_screen.restart_pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		restart_requested.emit())
	end_screen.sound.connect(func(s: String) -> void: ui_sound.emit(s))
	end_screen.continue_pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		hub_requested.emit())
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
		_boss_portrait.texture = TurnOrder.head(view.unit.def_id)
		_boss_box.visible = true
		turn_order.offset_top = 156.0  # la frise des tours passe sous le cartouche du boss
		turn_order.offset_bottom = 156.0 + 94.0


func remove_overhead(uid: int) -> void:
	if _overheads.has(uid):
		_overheads[uid].queue_free()
		_overheads.erase(uid)


func clear_overheads() -> void:
	for uid in _overheads.keys():
		remove_overhead(uid)
	_boss_view = null
	_boss_box.visible = false
	if turn_order:
		turn_order.offset_top = 24.0
		turn_order.offset_bottom = 24.0 + 94.0


func set_auto(on: bool) -> void:
	_auto_button.set_pressed_no_signal(on)


## Bouton du quatuor : visible quand l'attaque combinée peut partir (pendant le tour d'un héros).
func set_quartet(ready: bool, attack_name: String) -> void:
	if ready and not _quartet_button.visible:
		_quartet_button.text = "QUATUOR : %s" % attack_name
		_quartet_button.visible = true
		_quartet_button.pivot_offset = _quartet_button.size / 2.0
		_quartet_button.scale = Vector2.ONE * 0.7
		_quartet_button.create_tween().tween_property(_quartet_button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not ready:
		_quartet_button.visible = false


## Boutons des combos d'équipe prêts : [{id, title, attack, size}] (au plus 3 affichés).
func set_combos(list: Array) -> void:
	var ids := list.map(func(c: Dictionary) -> String: return c.id)
	if ids == _combo_ids:
		return
	_combo_ids = ids
	for child in _combo_box.get_children():
		child.queue_free()
	for c: Dictionary in list.slice(0, 3):
		var b := _combo_button(c)
		_combo_box.add_child(b)
		b.pivot_offset = Vector2(118, 35)
		b.scale = Vector2.ONE * 0.7
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Bouton de combo du pack (304 × 100) : doré (quatuor), vert (trio) ou turquoise (duo), mini-portraits
## des membres, nom de l'attaque, et lueur animée par-dessus tant qu'il est prêt.
func _combo_button(c: Dictionary) -> Button:
	var kind: String = {4: "quatuor", 3: "trio", 2: "duo"}.get(int(c.size), "duo")
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(236, 70)
	b.tooltip_text = "%s : %s" % [kind.capitalize(), c.attack]
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for st: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, AttackBar._nine("combo_%s_%s" % [kind, st], 24))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cid: String = c.id
	b.pressed.connect(func() -> void: combo_requested.emit(cid))
	var members: Array = c.get("members", [])
	for i in members.size():  # têtes carrées des membres, comme la maquette
		var h := TextureRect.new()
		h.texture = RoundPortrait.portrait_texture(GameData.hero(String(members[i])))
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		h.position = Vector2(16 + i * 52, 12)
		h.size = Vector2(46, 46)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
	var glow := TextureRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glow)
	var frame := [0]
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		frame[0] = (frame[0] + 1) % 8
		glow.texture = OverheadBar.tex("anim/combo_%s_ready/%02d" % [kind, frame[0]]))
	b.add_child(timer)
	return b


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
		_overheads[uid].follow(delta)
	attack_bar.refresh()
	if _boss_view:
		var u := _boss_view.unit
		_boss_bar.set_values(_boss_view.shown_hp / u.max_hp, u.shield / u.max_hp)
		_boss_ratio = clampf(_boss_view.shown_hp / u.max_hp, 0.0, 1.0)
		_boss_hp.queue_redraw()
		_boss_box.visible = _boss_view.shown_hp > 0.0


## Grande annonce au centre (« Vague 2 / 3 », « Le boss arrive ! »…).
func banner(text: String, sub := "", duration := 1.4) -> void:
	if FinPack.available("combat"):
		_pack_banner(text, sub, duration)
		return
	_banner.text = text
	_banner_sub.text = sub
	_banner_bg.add_theme_stylebox_override("panel", ScreenPack.nine("combat", "banner_special" if text.length() > 14 else "banner_wave"))
	_banner_bg.offset_left = -450.0 if text.length() > 14 else -350.0
	_banner_bg.offset_right = -_banner_bg.offset_left
	for l: Control in [_banner_bg, _banner, _banner_sub]:
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		tw.tween_interval(duration)
		tw.tween_property(l, "modulate:a", 0.0, 0.5)


## Bannière du pack « Finitions » : ruban de vague, ou arrivée du boss (crâne) quand `sub` l'annonce.
var _pack_banner_node: Control


func _pack_banner(text: String, sub: String, duration: float) -> void:
	if is_instance_valid(_pack_banner_node):
		_pack_banner_node.queue_free()
	var boss := sub.to_lower().contains("boss")
	var a: Dictionary = FinPack.data("combat").get("animations", {}).get("arrivee_boss" if boss else "arrivee_vague", {})
	var vs := get_viewport().get_visible_rect().size
	var k := vs.y / 1080.0
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fs := Vector2(a.frame_size[0], a.frame_size[1])
	box.size = fs
	box.scale = Vector2.ONE * k
	box.position = Vector2(vs.x / 2.0, vs.y * (330.0 if boss else 250.0) / 1080.0) - fs * k / 2.0
	add_child(box)
	_pack_banner_node = box
	var s := FinPack.sheet(a)
	s.position = Vector2(a.pivot[0], a.pivot[1])
	box.add_child(s)
	s.play("a")
	var tr: Array = a.get("text_rect", [215, 78, 470, 55])
	var t := ScreenPack.shadow(ScreenPack.text(box, text, Rect2(tr[0], tr[1] - 4, tr[2], tr[3]), 38, Color("f3d9a0"),
		HORIZONTAL_ALIGNMENT_CENTER), 3)
	var parts: Array[Control] = [t]
	if sub != "" and not boss:
		parts.append(ScreenPack.shadow(ScreenPack.text(box, sub, Rect2(tr[0], tr[1] + tr[3], tr[2], 34), 22, UiKit.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER), 2))
	elif boss:
		parts.append(ScreenPack.shadow(ScreenPack.text(box, "Le boss arrive !", Rect2(tr[0], tr[1] + tr[3] + 4, tr[2], 34), 24,
			Color("ffb070"), HORIZONTAL_ALIGNMENT_CENTER), 2))
	for p in parts:
		p.modulate.a = 0.0
		create_tween().tween_property(p, "modulate:a", 1.0, 0.25).set_delay(0.35)
	var tw := create_tween()
	tw.tween_interval(0.8 + duration)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)


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


func show_end(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String, replay := {}) -> void:
	end_turn()
	end_screen.show_result(won, stars, rewards, hero_stats, dungeon_name, replay)


# --- Construction ---------------------------------------------------------------

func _label(size: int, outline := 8) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_header() -> void:
	var cart := PanelContainer.new()
	var cart_box := AttackBar._nine("wave_cartouche", 20)
	cart_box.modulate_color = Color(0.7, 0.7, 0.76)  # plus sombre, comme la maquette
	cart.add_theme_stylebox_override("panel", cart_box)
	cart.position = Vector2(32, 28)
	cart.custom_minimum_size = Vector2(230, 64)
	cart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cart)
	_wave_label = _label(26, 6)
	_wave_label.add_theme_color_override("font_color", Color("f6efdf"))
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cart.add_child(_wave_label)

	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -40
	right.offset_top = 28
	right.add_theme_constant_override("separation", 8)
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
	_sound_button = _round_button("SON")
	_sound_button.toggled.connect(_toggle_sound_panel)
	right.add_child(_sound_button)
	# Combat qui s'éternise : « Arrêter » apparaît (égalité, l'énergie est rendue). Caché au début.
	draw_button = _round_button("ARRÊTER")
	draw_button.toggle_mode = false
	draw_button.tooltip_text = "Le combat s'éternise : l'arrêter sur une égalité (pas de butin, énergie rendue)."
	draw_button.visible = false
	draw_button.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		draw_requested.emit())
	right.add_child(draw_button)
	right.move_child(draw_button, 0)


func _toggle_sound_panel(on: bool) -> void:
	ui_sound.emit("ui_toggle")
	if on and _sound_panel == null:
		_sound_panel = SoundPanel.new()
		_sound_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_sound_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_sound_panel.offset_right = -24
		_sound_panel.offset_top = 84
		_sound_panel.closed.connect(func() -> void: _sound_button.button_pressed = false)
		_sound_panel.test_sound.connect(func() -> void: ui_sound.emit("hit"))
		_root.add_child(_sound_panel)
	if _sound_panel:
		_sound_panel.visible = on


## Bouton rectangulaire (maquette) : cartouche sombre du pack, glyphe à gauche et texte ; doré quand il est actif.
const GLYPHS := {"AUTO": "glyph_auto", "×2": "glyph_speed", "SON": "glyph_sound"}


func _round_button(text: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170 if text == "AUTO" else 150, 64)
	b.tooltip_text = text
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBox = AttackBar._nine("wave_cartouche", 20)
		if FinPack.available("port_franc"):  # cartouche laiton du Port-Franc, glyphe dans le médaillon
			var t := StyleBoxTexture.new()
			t.texture = FinPack.tex("port_franc/cartouche_ressource.png")
			t.texture_margin_left = 74
			t.texture_margin_top = 18
			t.texture_margin_right = 22
			t.texture_margin_bottom = 18
			sb = t
		(sb as StyleBoxTexture).modulate_color = Color(1.25, 1.1, 0.7) if st.contains("pressed") else (Color(1.1, 1.1, 1.1) if st == "hover" else Color.WHITE)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var glyph := TextureRect.new()
	glyph.texture = OverheadBar.tex(GLYPHS.get(text, "glyph_pause"))
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.position = Vector2(20, 17)
	glyph.size = Vector2(30, 30)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glyph)
	var cap := _label(22, 5)
	cap.text = text
	cap.position = Vector2(66, 0)
	cap.size = Vector2(b.custom_minimum_size.x - 80, 64)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_color_override("font_color", Color("f6efdf"))
	b.add_child(cap)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b


## Cartouche du boss (pack de combat) : portrait dans son anneau, blason, nom, barre de vie.
func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -380
	_boss_box.offset_right = 380
	_boss_box.offset_top = 18
	_boss_box.offset_bottom = 148
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss_box.visible = false
	_root.add_child(_boss_box)
	ScreenPack.panel(_boss_box, "combat", "boss_cartouche", Rect2(0, 0, 760, 130))
	_boss_portrait = TextureRect.new()
	_boss_portrait.position = Vector2(26, 20)
	_boss_portrait.size = Vector2(92, 92)
	_boss_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_boss_portrait.flip_h = true
	_boss_box.add_child(_boss_portrait)
	ScreenPack.image(_boss_box, ScreenPack.tex("combat", "portrait_ring_boss"), Rect2(10, 4, 124, 124))
	ScreenPack.image(_boss_box, ScreenPack.tex("combat", "boss_crest"), Rect2(348, -22, 64, 64))
	_boss_name = ScreenPack.text(_boss_box, "", Rect2(144, 22, 560, 44), 30, UiKit.WHITE)
	_boss_bar = StatBar.new()
	_boss_bar.visible = false  # gardé pour l'API ; la barre affichée est dessinée par _boss_hp
	_boss_box.add_child(_boss_bar)
	_boss_hp = Control.new()
	_boss_hp.position = Vector2(144, 76)
	_boss_hp.size = Vector2(570, 26)
	_boss_box.add_child(_boss_hp)
	_boss_hp.draw.connect(func() -> void:
		var frame := ScreenPack.tex("combat", "hp_boss_frame")
		var fill := ScreenPack.tex("combat", "hp_boss_fill")
		if frame:
			_boss_hp.draw_texture_rect(frame, Rect2(Vector2.ZERO, _boss_hp.size), false)
		if fill and _boss_ratio > 0.0:
			var r := Rect2(4, 4, (_boss_hp.size.x - 8) * _boss_ratio, _boss_hp.size.y - 8)
			_boss_hp.draw_texture_rect_region(fill, r, Rect2(0, 0, fill.get_width() * _boss_ratio, fill.get_height())))


func _build_banner() -> void:
	_banner_bg = ScreenPack.panel(_root, "combat", "banner_wave", Rect2(0, 0, 700, 96))
	_banner_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_bg.offset_left = -350
	_banner_bg.offset_right = 350
	_banner_bg.offset_top = -258
	_banner_bg.offset_bottom = -162
	_banner_bg.modulate.a = 0.0
	_banner = _label(56, 0)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = -250
	_banner.offset_bottom = -170
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", UiKit.WHITE)
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
