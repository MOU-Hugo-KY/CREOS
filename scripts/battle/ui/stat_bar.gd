class_name StatBar
extends Control
## Barre arrondie (PV, énergie…) avec une traînée qui descend doucement après un coup
## et un bouclier optionnel par-dessus.

var ratio := 1.0
var shield_ratio := 0.0
var fill_color := Palette.HP_HERO
var text := ""
var font_size := 18

var _trail := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(p_ratio: float, p_shield := 0.0, p_text := "") -> void:
	p_ratio = clampf(p_ratio, 0.0, 1.0)
	if p_ratio > _trail:
		_trail = p_ratio
	ratio = p_ratio
	shield_ratio = clampf(p_shield, 0.0, 1.0)
	text = p_text
	queue_redraw()


func _process(delta: float) -> void:
	if _trail > ratio:
		_trail = maxf(ratio, _trail - delta * 0.6)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := int(size.y / 2.0)
	draw_style_box(Palette.stylebox(Color(0, 0, 0, 0.65), Color(0, 0, 0, 0.9), radius, 2), r)
	var inner := r.grow(-2)
	if _trail > ratio:
		_draw_fill(inner, _trail, Color(1, 0.95, 0.8, 0.85), radius)
	var color := fill_color
	if fill_color == Palette.HP_HERO and ratio < 0.3:
		color = Palette.HP_LOW
	_draw_fill(inner, ratio, color, radius)
	if shield_ratio > 0.0:
		_draw_fill(inner, shield_ratio, Color(Palette.SHIELD, 0.7), radius)
	# Reflet en haut de la barre.
	if ratio > 0.0:
		var shine := Rect2(inner.position + Vector2(2, 1), Vector2(maxf(0.0, inner.size.x * ratio - 4), inner.size.y * 0.35))
		draw_rect(shine, Color(1, 1, 1, 0.18))
	if text != "":
		var font := get_theme_default_font()
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - ts.x) / 2.0, (size.y + font_size * 0.72) / 2.0)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.TEXT)


func _draw_fill(inner: Rect2, value: float, color: Color, radius: int) -> void:
	if value <= 0.0:
		return
	var w := maxf(inner.size.y, inner.size.x * value)
	draw_style_box(Palette.stylebox(color, Color.TRANSPARENT, radius - 2), Rect2(inner.position, Vector2(w, inner.size.y)))
