class_name StarIcon
extends Control
## Étoile dessinée (allumée = dorée, éteinte = grise).

var lit := false


func _draw() -> void:
	var c := size / 2.0
	var outer := minf(size.x, size.y) / 2.0
	var inner := outer * 0.45
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	var fill := Palette.GOLD if lit else Color(0.18, 0.18, 0.22)
	var border := Color(1, 0.95, 0.7) if lit else Color(0.35, 0.35, 0.4)
	if lit:
		draw_circle(c, outer * 0.9, Color(1, 0.8, 0.3, 0.18))
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, border, 4.0, true)
