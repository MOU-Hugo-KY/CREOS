class_name Projectile
extends Node2D
## Projectile d'une attaque à distance (affichage seulement) : il part de l'attaquant et arrive sur la
## cible à l'instant d'impact. Orbe lumineuse avec traînée (magie) ou carreau (physique), à la couleur
## de l'élément de l'attaquant. Légère courbe pour la vue en plongée.

var from := Vector2.ZERO
var to := Vector2.ZERO
var duration := 0.25
var color := Color.WHITE
var magic := true

var _t := 0.0
var _trail: Array[Vector2] = []


func setup(p_from: Vector2, p_to: Vector2, p_duration: float, p_color: Color, p_magic: bool) -> Projectile:
	from = p_from
	to = p_to
	duration = maxf(0.08, p_duration)
	color = p_color
	magic = p_magic
	position = from
	z_index = 45
	return self


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	var arc := -sin(k * PI) * minf(90.0, from.distance_to(to) * 0.12)  # petite cloche
	position = from.lerp(to, k) + Vector2(0, arc)
	_trail.push_front(position)
	if _trail.size() > (10 if magic else 6):
		_trail.pop_back()
	queue_redraw()
	if k >= 1.0:
		queue_free()


func _draw() -> void:
	# Traînée (dans le repère local : les points sont en coordonnées de la scène).
	for i in range(_trail.size() - 1, 0, -1):
		var a := _trail[i] - position
		var b := _trail[i - 1] - position
		var f := 1.0 - float(i) / _trail.size()
		var c := color
		c.a = 0.65 * f
		draw_line(a, b, c, (10.0 if magic else 5.0) * f + 1.0)
	if magic:
		draw_circle(Vector2.ZERO, 11.0, Color(color, 0.35))
		draw_circle(Vector2.ZERO, 7.0, color.lightened(0.3))
		draw_circle(Vector2.ZERO, 3.5, Color(1, 1, 1, 0.95))
	else:
		var dir := Vector2.RIGHT
		if _trail.size() > 1:
			dir = (position - _trail[1]).normalized()
		var tail := -dir * 26.0
		draw_line(tail, Vector2.ZERO, Color("3a2a1e"), 4.0)
		draw_line(tail, Vector2.ZERO, color.lightened(0.4), 2.0)
		var side := dir.orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([dir * 8.0, side, -side]), Color("e8e2d0"))
