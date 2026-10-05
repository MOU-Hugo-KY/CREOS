class_name BattleFx
extends Node2D
## Petits effets de combat en 2D, en plus de ceux dessinés dans les clips d'attaque :
## tremblement de l'écran, éclats d'impact, anneaux et halos. Repère : cadre 1280 × 720.

var camera: Camera2D
var _shake := 0.0
var _bursts: Array[Dictionary] = []  # {pos, color, t, life, big, kind, radius}


func setup(p_camera: Camera2D) -> void:
	camera = p_camera
	z_index = 30


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func burst(pos: Vector2, color: Color, big := false) -> void:
	_bursts.append({"pos": pos, "color": color, "t": 0.0, "life": 0.35 if not big else 0.5, "big": big, "kind": "burst",
		"seed": randf() * TAU})


func ring(pos: Vector2, color: Color, radius := 120.0) -> void:
	_bursts.append({"pos": pos, "color": color, "t": 0.0, "life": 0.6, "kind": "ring", "radius": radius})


func aura(pos: Vector2, color: Color) -> void:
	_bursts.append({"pos": pos, "color": color, "t": 0.0, "life": 0.8, "kind": "aura"})


func _process(delta: float) -> void:
	if camera:
		if _shake > 0.0:
			_shake = maxf(0.0, _shake - delta * 2.2)
			var s := _shake * 14.0
			camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		else:
			camera.offset = Vector2.ZERO
	for b: Dictionary in _bursts.duplicate():
		b.t += delta
		if b.t >= b.life:
			_bursts.erase(b)
	queue_redraw()


func _draw() -> void:
	for b: Dictionary in _bursts:
		var k: float = b.t / b.life
		var c: Color = b.color
		match b.kind:
			"burst":
				var n := 9 if b.big else 6
				var r := lerpf(10.0, 70.0 if b.big else 46.0, k)
				for i in n:
					var a: float = b.seed + TAU * i / n
					var dir := Vector2(cos(a), sin(a))
					draw_line(b.pos + dir * r * 0.45, b.pos + dir * r, Color(c, 1.0 - k), 5.0 * (1.0 - k) + 1.0, true)
				draw_circle(b.pos, 18.0 * (1.0 - k), Color(1, 1, 1, 0.7 * (1.0 - k)))
			"ring":
				var r: float = lerpf(20.0, b.radius, k)
				var pts := PackedVector2Array()
				for i in 41:
					var a := TAU * i / 40.0
					pts.append(b.pos + Vector2(cos(a) * r, sin(a) * r * 0.3))
				draw_polyline(pts, Color(c, 1.0 - k), 6.0 * (1.0 - k) + 1.0, true)
			"aura":
				var h := 160.0
				for i in 6:
					var x := (i - 2.5) * 16.0
					var y := -fmod(k * h + i * 23.0, h)
					draw_circle(b.pos + Vector2(x, y), 5.0, Color(c, (1.0 - k) * 0.8))
