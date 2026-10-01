class_name UiWindow
extends Control
## Fenêtre de jeu : fond assombri, parchemin centré, ruban de titre à cheval sur le bord
## et croix rouge en haut à droite. On remplit `content` (une VBoxContainer).

signal closed

var content: VBoxContainer
var window_size := Vector2(1240, 820)
var ribbon_color := Color("793b49")

var _title_text := ""
var _frame: PanelContainer


func setup(p_title: String, p_size := Vector2(1240, 820), p_ribbon := Color("793b49")) -> UiWindow:
	_title_text = p_title
	window_size = p_size
	ribbon_color = p_ribbon
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var holder := Control.new()
	holder.custom_minimum_size = window_size
	center.add_child(holder)

	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := UiKit.parchment(26, 6)
	sb.content_margin_top = 58
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_bottom = 26
	_frame.add_theme_stylebox_override("panel", sb)
	holder.add_child(_frame)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_frame.add_child(content)

	# Ruban du titre, à cheval sur le bord haut
	var ribbon := PanelContainer.new()
	var rb := UiKit.box(ribbon_color, UiKit.INK, 18, 5, 6, Vector2(0, 5))
	rb.border_width_bottom = 9
	rb.content_margin_left = 54
	rb.content_margin_right = 54
	rb.content_margin_top = 4
	rb.content_margin_bottom = 6
	ribbon.add_theme_stylebox_override("panel", rb)
	ribbon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.offset_top = -34
	holder.add_child(ribbon)
	var t := UiKit.title(_title_text, 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(t)

	var close := UiKit.close_button()
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -44
	close.offset_right = 18
	close.offset_top = -22
	close.offset_bottom = 40
	close.pressed.connect(close_window)
	holder.add_child(close)
	visible = false


func open() -> void:
	visible = true
	UiKit.pop_in(_frame.get_parent() as Control)


func close_window() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()
