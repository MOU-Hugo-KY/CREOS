class_name AttackButton
extends Control
## Bouton d'une attaque de héros. Se remplit du bas vers le haut (jauge d'action, recharge ou
## énergie) et brille quand l'attaque est prête. L'attaque 1 est automatique : son bouton montre
## seulement la jauge d'action.

signal pressed

var slot := 0
var title := ""
var description := ""
var fill := 0.0  # 0..1
var is_ready := false
var corner_text := ""  # ex. « 4 s » pendant une recharge
var accent := Palette.GOLD
var disabled := false  # héros mort ou étourdi

var _title_label: Label
var _corner_label: Label
var _time := 0.0
var _was_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = description
	_title_label = Label.new()
	_title_label.text = title
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16 if title.length() <= 18 else 14)
	_title_label.add_theme_constant_override("line_spacing", -4)
	_title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_label.offset_left = 3
	_title_label.offset_right = -3
	_title_label.offset_top = 14
	_title_label.offset_bottom = -4
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)
	_corner_label = Label.new()
	_corner_label.add_theme_font_size_override("font_size", 16)
	_corner_label.position = Vector2(8, 2)
	_corner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corner_label)
	pivot_offset = custom_minimum_size / 2.0


func set_state(p_fill: float, p_ready: bool, p_corner: String, p_disabled: bool) -> void:
	fill = clampf(p_fill, 0.0, 1.0)
	is_ready = p_ready
	disabled = p_disabled
	corner_text = p_corner
	if is_ready and not _was_ready and slot > 0:
		# Petit « pop » quand l'attaque devient prête.
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 1.12, 0.1)
		tw.tween_property(self, "scale", Vector2.ONE, 0.15)
	_was_ready = is_ready
	_corner_label.text = corner_text
	_title_label.modulate = Color(1, 1, 1) if (is_ready or slot == 0) and not disabled else Color(0.75, 0.75, 0.78)
	queue_redraw()


func _process(delta: float) -> void:
	if is_ready:
		_time += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var released := mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	if released and slot > 0 and is_ready and not disabled:
		accept_event()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 0.9, 0.05)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12)
		pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(0.1, 0.11, 0.14, 0.95) if slot > 0 else Color(0.08, 0.08, 0.1, 0.8)
	draw_style_box(Palette.stylebox(bg, Color(0, 0, 0, 0.6), 12, 2), r)
	# Remplissage du bas vers le haut.
	if fill > 0.0 and not disabled:
		var h := r.size.y * fill
		var fill_rect := Rect2(Vector2(2, r.size.y - h), Vector2(r.size.x - 4, h - 2))
		var sb := Palette.stylebox(Color(accent, 0.35 if not is_ready else 0.55), Color.TRANSPARENT, 10)
		if fill < 0.97:
			sb.corner_radius_top_left = 0
			sb.corner_radius_top_right = 0
		draw_style_box(sb, fill_rect)
	# Bordure : dorée et pulsante quand l'attaque est prête.
	var border := Color(1, 1, 1, 0.12)
	var width := 2
	if is_ready and not disabled:
		var pulse := 0.65 + 0.35 * sin(_time * 6.0)
		border = Color(accent.lightened(0.3), pulse)
		width = 4
	var sb_border := Palette.stylebox(Color.TRANSPARENT, border, 12, width)
	sb_border.draw_center = false
	draw_style_box(sb_border, r)
	# Pastille avec le numéro de l'attaque.
	var badge_center := Vector2(r.size.x - 15, 15)
	draw_circle(badge_center, 12, Color(0, 0, 0, 0.7))
	draw_circle(badge_center, 12, accent if is_ready or slot == 0 else Color(0.4, 0.4, 0.45), false, 2.0, true)
	var font := get_theme_default_font()
	var num := str(slot + 1)
	draw_string(font, badge_center + Vector2(-5, 6), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.TEXT)
