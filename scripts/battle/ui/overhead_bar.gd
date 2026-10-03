class_name OverheadBar
extends Control
## Barre fine qui suit une unité à l'écran : vie (+ énergie pour les héros), états,
## et une flèche qui pulse au-dessus du héros dont c'est le tour.

const WIDTH := 112.0

var view: UnitView
var active := false  # c'est au tour de ce héros

var _hp: StatBar
var _energy: StatBar
var _status: Label
var _time := 0.0


func setup(p_view: UnitView) -> void:
	view = p_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_hero := view.unit.team == 0
	size = Vector2(WIDTH, 44)
	_hp = StatBar.new()
	_hp.fill_color = Palette.HP_HERO if is_hero else Palette.HP_ENEMY
	_hp.size = Vector2(WIDTH, 11)
	_hp.position = Vector2(0, 22)
	add_child(_hp)
	if is_hero:
		_energy = StatBar.new()
		_energy.fill_color = Palette.ENERGY
		_energy.size = Vector2(WIDTH * 0.8, 6)
		_energy.position = Vector2(WIDTH * 0.1, 35)
		add_child(_energy)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_constant_override("outline_size", 5)
	_status.add_theme_color_override("font_color", Palette.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(WIDTH + 60, 18)
	_status.position = Vector2(-30, 3)
	add_child(_status)


func follow(camera: Camera3D, delta: float) -> void:
	_time += delta
	var u := view.unit
	var alive := view.shown_hp > 0.0 and view.visible
	var head := view.head_position()
	visible = alive and not camera.is_position_behind(head)
	if not visible:
		return
	position = camera.unproject_position(head) - Vector2(size.x / 2.0, size.y)
	_hp.set_values(view.shown_hp / u.max_hp, u.shield / u.max_hp)
	if _energy:
		_energy.set_values(u.energy / BattleUnit.ENERGY_MAX)
	var tags: Array[String] = []
	if u.stun_time > 0.0:
		tags.append("ÉTOURDI")
	if u.taunt_time > 0.0:
		tags.append("PROVOC.")
	if not u.dots.is_empty():
		tags.append("POISON")
	_status.text = " · ".join(tags)
	_status.visible = not active
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	# Flèche dorée qui rebondit au-dessus de la barre.
	var bob := sin(_time * 6.0) * 4.0
	var c := Vector2(size.x / 2.0, 6 + bob)
	var pts := PackedVector2Array([c + Vector2(-13, -10), c + Vector2(13, -10), c + Vector2(0, 6)])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
	var inner := PackedVector2Array([c + Vector2(-9, -8), c + Vector2(9, -8), c + Vector2(0, 3)])
	draw_colored_polygon(inner, Palette.GOLD)
