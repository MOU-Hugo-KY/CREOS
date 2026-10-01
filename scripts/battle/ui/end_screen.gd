class_name EndScreen
extends Control
## Écran de fin de combat : titre, étoiles (0 à 3), butin et bilan de chaque héros.

signal restart_pressed
signal sound(sfx_name: String)

const REWARD_NAMES := {
	"gold": "Or",
	"xp": "Expérience",
	"essence_ombre": "Essence d'ombre",
	"essence_feu": "Essence de feu",
	"essence_eau": "Essence d'eau",
	"essence_nature": "Essence de nature",
	"essence_lumiere": "Essence de lumière",
}
const REWARD_COLORS := {
	"gold": Color(1.0, 0.82, 0.3),
	"xp": Color(0.55, 0.85, 1.0),
}

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _stars: Array[StarIcon] = []
var _rewards_box: VBoxContainer
var _heroes_box: HBoxContainer
var _restart: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.04, 0.7)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(_panel)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 30)
	_panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 80)
	_title.add_theme_constant_override("outline_size", 18)
	v.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.add_theme_color_override("font_color", Palette.TEXT_DIM)
	v.add_child(_subtitle)

	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 18)
	v.add_child(stars_row)
	for i in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(110, 110) if i != 1 else Vector2(140, 140)
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		stars_row.add_child(s)
		_stars.append(s)

	v.add_child(_section_title("Butin"))
	_rewards_box = VBoxContainer.new()
	_rewards_box.add_theme_constant_override("separation", 4)
	v.add_child(_rewards_box)

	v.add_child(_section_title("Chasseurs"))
	_heroes_box = HBoxContainer.new()
	_heroes_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_heroes_box.add_theme_constant_override("separation", 14)
	v.add_child(_heroes_box)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	v.add_child(buttons)
	_restart = Button.new()
	_restart.text = "Rejouer"
	_restart.custom_minimum_size = Vector2(260, 76)
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	buttons.add_child(_restart)
	_next = Button.new()
	_next.text = "Continuer"
	_next.custom_minimum_size = Vector2(260, 76)
	_next.disabled = true
	_next.tooltip_text = "La carte de la région arrive à l'Étape 2."
	buttons.add_child(_next)


## hero_stats : Array de {name, element, alive, damage, healing}
func show_result(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String) -> void:
	_title.text = "VICTOIRE !" if won else "DÉFAITE…"
	_title.add_theme_color_override("font_color", Palette.GOLD if won else Color(0.85, 0.35, 0.35))
	_subtitle.text = dungeon_name + ("  ·  Brumenoire recule…" if won else "  ·  Morvath gagne du terrain.")

	for c in _rewards_box.get_children():
		c.queue_free()
	if rewards.is_empty():
		_rewards_box.add_child(_reward_row("Aucun butin", "", Palette.TEXT_DIM))
	for key: String in rewards:
		_rewards_box.add_child(_reward_row(REWARD_NAMES.get(key, key.capitalize()), "+%d" % int(rewards[key]),
			REWARD_COLORS.get(key, Color(0.8, 0.6, 1.0))))

	for c in _heroes_box.get_children():
		c.queue_free()
	var best_damage := 0.0
	for h: Dictionary in hero_stats:
		best_damage = maxf(best_damage, h.damage)
	for h: Dictionary in hero_stats:
		_heroes_box.add_child(_hero_tile(h, h.damage > 0.0 and h.damage == best_damage))

	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.85
	_panel.pivot_offset = _panel.size / 2.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Les étoiles apparaissent une par une.
	for i in _stars.size():
		_stars[i].lit = false
		_stars[i].scale = Vector2.ONE
		_stars[i].queue_redraw()
	var seq := create_tween()
	seq.tween_interval(0.5)
	for i in stars:
		var star := _stars[i]
		seq.tween_callback(func() -> void:
			star.pivot_offset = star.size / 2.0
			star.lit = true
			star.scale = Vector2.ONE * 1.6
			star.queue_redraw()
			sound.emit("ui_ready"))
		seq.tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		seq.tween_interval(0.15)


func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Palette.GOLD)
	return l


func _reward_row(label: String, amount: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(22, 22)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", Palette.stylebox(color, color.darkened(0.5), 11, 2))
	row.add_child(dot)
	var name_label := Label.new()
	name_label.text = "  " + label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var amount_label := Label.new()
	amount_label.text = amount
	amount_label.add_theme_color_override("font_color", color)
	row.add_child(amount_label)
	return row


func _hero_tile(h: Dictionary, mvp: bool) -> Control:
	var p := PanelContainer.new()
	var color := Palette.element_color(h.element)
	p.add_theme_stylebox_override("panel", Palette.stylebox(Palette.PANEL_LIGHT, Color(color, 0.7 if h.alive else 0.2), 12, 2))
	p.custom_minimum_size = Vector2(205, 0)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	p.add_child(m)
	var v := VBoxContainer.new()
	m.add_child(v)
	var name_label := Label.new()
	name_label.text = h.name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.clip_text = true
	v.add_child(name_label)
	var dmg := Label.new()
	dmg.text = "Dégâts : %d" % int(h.damage)
	dmg.add_theme_font_size_override("font_size", 18)
	v.add_child(dmg)
	if h.healing > 0.0:
		var heal := Label.new()
		heal.text = "Soins : %d" % int(h.healing)
		heal.add_theme_font_size_override("font_size", 18)
		heal.add_theme_color_override("font_color", Palette.HEAL)
		v.add_child(heal)
	var state := Label.new()
	state.text = ("MEILLEUR CHASSEUR" if mvp else "Debout") if h.alive else "K.O."
	state.add_theme_font_size_override("font_size", 16)
	state.add_theme_color_override("font_color", Palette.GOLD if mvp else (Palette.TEXT_DIM if h.alive else Color(0.9, 0.4, 0.4)))
	v.add_child(state)
	if not h.alive:
		p.modulate = Color(0.7, 0.7, 0.7)
	return p
