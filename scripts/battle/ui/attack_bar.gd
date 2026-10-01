class_name AttackBar
extends Control
## Les 3 icônes d'attaque du héros dont c'est le tour, en bas de l'écran.
## Invisible le reste du temps.

signal attack_chosen(slot: int)

var unit: BattleUnit
var _icons: Array[AttackIcon] = []
var _title: Label
var _row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_top = -215
	offset_bottom = -18
	offset_left = -260
	offset_right = 260
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_constant_override("outline_size", 8)
	v.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 30)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_row)
	for i in 3:
		var icon := AttackIcon.new()
		var slot := i
		icon.pressed.connect(func() -> void: attack_chosen.emit(slot))
		_row.add_child(icon)
		_icons.append(icon)
	visible = false


func show_for(p_unit: BattleUnit) -> void:
	unit = p_unit
	var color := Palette.element_color(unit.element)
	_title.text = "Au tour de %s" % unit.display_name
	_title.add_theme_color_override("font_color", color.lightened(0.35))
	for i in _icons.size():
		var icon := _icons[i]
		icon.visible = unit.has_attack(i)
		if icon.visible:
			icon.setup(i, unit.attacks[i], color)
	refresh()
	visible = true
	modulate.a = 0.0
	_row.scale = Vector2.ONE * 0.85
	_row.pivot_offset = _row.size / 2.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.tween_property(_row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_bar(chosen := -1) -> void:
	if not visible:
		return
	if chosen >= 0 and chosen < _icons.size():
		_icons[chosen].press_feedback()
	unit = null
	var tw := create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		if unit == null:
			visible = false)


func refresh() -> void:
	if unit == null:
		return
	for i in _icons.size():
		if not unit.has_attack(i):
			continue
		var corner := ""
		var progress := 1.0
		match i:
			BattleUnit.SLOT_COOLDOWN:
				var cd: float = unit.attacks[i].get("cooldown", 1.0)
				var left := unit.cooldowns[i]
				progress = 1.0 - left / maxf(cd, 0.01)
				if left > 0.0:
					corner = "%d s" % int(ceil(left))
			BattleUnit.SLOT_ULTIMATE:
				var cost := unit.energy_cost(i)
				progress = unit.energy / maxf(cost, 1.0)
				if unit.energy < cost:
					corner = "%d%%" % int(progress * 100.0)
		_icons[i].set_state(unit.can_use(i), progress, corner)


func icon_rect(slot: int) -> Rect2:
	return _icons[slot].get_global_rect()
