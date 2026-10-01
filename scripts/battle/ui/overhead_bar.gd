class_name OverheadBar
extends Control
## Petite barre de vie qui suit une unité à l'écran (projection de sa tête).

var view: UnitView
var _bar: StatBar
var _name: Label
var _status: Label


func setup(p_view: UnitView) -> void:
	view = p_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_hero := view.unit.team == 0
	size = Vector2(150, 50)
	_name = Label.new()
	_name.text = view.unit.display_name
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 17)
	_name.add_theme_color_override("font_color", Color(1, 0.85, 0.8) if not is_hero else Palette.TEXT)
	_name.size = Vector2(220, 22)
	_name.position = Vector2(-35, -2)
	_name.visible = not is_hero  # les héros ont déjà leur nom sur leur carte
	add_child(_name)
	_bar = StatBar.new()
	_bar.fill_color = Palette.HP_HERO if is_hero else Palette.HP_ENEMY
	_bar.size = Vector2(150, 14)
	_bar.position = Vector2(0, 22)
	add_child(_bar)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Palette.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(150, 20)
	_status.position = Vector2(0, 36)
	add_child(_status)


func follow(camera: Camera3D) -> void:
	var u := view.unit
	var alive := view.shown_hp > 0.0 and view.visible
	var head := view.head_position()
	visible = alive and not camera.is_position_behind(head)
	if not visible:
		return
	position = camera.unproject_position(head) - Vector2(size.x / 2.0, size.y)
	_bar.set_values(view.shown_hp / u.max_hp, u.shield / u.max_hp)
	var tags: Array[String] = []
	if u.stun_time > 0.0:
		tags.append("ÉTOURDI")
	if u.taunt_time > 0.0:
		tags.append("PROVOC.")
	if not u.dots.is_empty():
		tags.append("BRÛLURE")
	_status.text = " ".join(tags)
