class_name IconButton
extends Control
## Bouton rond avec une icône dessinée et un nom dessous (menus du hub) : médaillon ivoire
## cerclé d'encre et de laiton, avec une ombre franche, comme le reste de l'interface.

signal pressed

var icon: Texture2D
var title := ""
var accent := Palette.GOLD
var radius := 46.0
var badge := 0  # petit nombre rouge (0 = rien)

var _label: Label
var _hover := false


func setup(p_icon: Texture2D, p_title: String, p_radius := 46.0, p_accent := Palette.GOLD) -> IconButton:
	icon = p_icon
	title = p_title
	radius = p_radius
	accent = p_accent
	return self


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0 + 16.0, radius * 2.0 + (48.0 if radius > 40 else 30.0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = Vector2(custom_minimum_size.x / 2.0, radius + 4.0)
	_label = Label.new()
	_label.text = title
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 17 if radius > 40 else 15)
	_label.add_theme_constant_override("outline_size", 7)
	_label.add_theme_constant_override("line_spacing", -4)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.position = Vector2(-6, radius * 2.0 + 6.0)
	_label.size = Vector2(custom_minimum_size.x + 12.0, 44)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			scale = Vector2.ONE * 0.9
		else:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			accept_event()
			pressed.emit()


func _draw() -> void:
	var c := Vector2(custom_minimum_size.x / 2.0, radius + 4.0)
	var hover := _hover
	# Médaillon : ombre franche d'encre, cercle d'encre, anneau de laiton, disque ivoire.
	draw_circle(c + Vector2(0, 7), radius, Color(0, 0, 0, 0.35))
	draw_circle(c + Vector2(0, 4), radius, UiKit.INK)
	draw_circle(c, radius, UiKit.INK)
	draw_circle(c, radius - 3.0, Color("c6a66c").lightened(0.15 if hover else 0.0))
	draw_circle(c, radius - 8.0, UiKit.INK)
	draw_circle(c, radius - 10.0, Color("f3ead6") if hover else UiKit.PARCHMENT)
	# Lumière douce en haut, ombre en bas du disque.
	draw_circle(c + Vector2(0, radius * 0.35), radius * 0.62, Color(0.55, 0.45, 0.3, 0.12))
	draw_circle(c - Vector2(0, radius * 0.3), radius * 0.55, Color(1, 1, 1, 0.25))
	if icon:
		var s := radius * 1.62
		draw_texture_rect(icon, Rect2(c - Vector2(s, s) / 2.0 - Vector2(0, 2), Vector2(s, s)), false)
	if hover:
		draw_arc(c, radius + 3.0, 0, TAU, 64, accent.lightened(0.3), 4.0, true)
	if badge > 0:
		var b := c + Vector2(radius * 0.74, -radius * 0.74)
		draw_circle(b, 16, UiKit.INK)
		draw_circle(b, 13, Color("c8453c"))
		var font := get_theme_default_font()
		draw_string(font, b + Vector2(-5 if badge < 10 else -9, 6), str(badge), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
