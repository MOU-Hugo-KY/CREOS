class_name AttackIcon
extends Control
## Petite icône ronde d'une attaque. Grisée si elle n'est pas disponible :
## recharge (secondes restantes) ou énergie (anneau qui se remplit).

signal pressed

const ICON_DIR := "res://assets/ui/attacks/"

var slot := 0
var attack: Dictionary = {}
var accent := Palette.GOLD
var available := false
var progress := 1.0  # 0..1 (recharge ou énergie)
var corner_text := ""

var _icon: Texture2D
var _name: Label
var _hover := false


func setup(p_slot: int, p_attack: Dictionary, p_accent: Color) -> void:
	slot = p_slot
	attack = p_attack
	accent = p_accent
	var path: String = ICON_DIR + String(attack.get("id", "")) + ".png"
	_icon = load(path) if ResourceLoader.exists(path) else null
	tooltip_text = "%s\n%s" % [attack.get("name", ""), attack.get("description", "")]
	if _name:
		_name.text = attack.get("name", "")
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(112, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_name = Label.new()
	_name.text = attack.get("name", "")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 16)
	_name.add_theme_constant_override("outline_size", 6)
	_name.add_theme_constant_override("line_spacing", -3)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name.position = Vector2(-4, 110)
	_name.size = Vector2(120, 40)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	pivot_offset = Vector2(56, 56)


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func set_state(p_available: bool, p_progress: float, p_corner: String) -> void:
	available = p_available
	progress = clampf(p_progress, 0.0, 1.0)
	corner_text = p_corner
	_name.modulate = Color(1, 1, 1) if available else Color(1, 1, 1, 0.45)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and available:
		accept_event()
		pressed.emit()


func press_feedback() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 0.88, 0.05)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


func _draw() -> void:
	var c := Vector2(56, 56)
	var r := 50.0
	# Fond : disque sombre teinté de la couleur de l'élément.
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Color(accent.darkened(0.75), 0.92))
	draw_circle(c, r * 0.82, Color(accent.darkened(0.6), 0.6))
	if _icon:
		var s := r * 1.45
		draw_texture_rect(_icon, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false,
			Color(1, 1, 1) if available else Color(0.6, 0.6, 0.65))
	if not available:
		draw_circle(c, r, Color(0, 0, 0, 0.25))
	# Anneau : plein et coloré si disponible, sinon progression (recharge / énergie).
	draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.12), 4.0, true)
	if available:
		var w := 5.0 if not _hover else 7.0
		draw_arc(c, r, 0, TAU, 64, accent.lightened(0.25), w, true)
	elif progress > 0.0:
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * progress, 64, Color(accent, 0.8), 4.0, true)
	# Numéro de touche (1, 2, 3) et texte de recharge.
	var font := get_theme_default_font()
	draw_circle(c + Vector2(-38, -38), 13, Color(0, 0, 0, 0.75))
	draw_string(font, c + Vector2(-43, -32), str(slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.TEXT)
	if corner_text != "":
		var ts := font.get_string_size(corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var pos := c + Vector2(-ts.x / 2.0, r * 0.75)
		draw_string_outline(font, pos, corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.95))
		draw_string(font, pos, corner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.TEXT)
