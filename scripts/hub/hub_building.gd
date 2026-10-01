class_name HubBuilding
extends Node3D
## Bâtiment cliquable du hub : zone de clic, étiquette flottante avec son nom,
## et léger rebond quand on le survole ou le touche.

signal clicked(building_id: String)

var building_id := ""
var label_height := 6.0
var _label: Label3D
var _area: Area3D
var _hover := false
var _base_scale := Vector3.ONE


## `size` = taille de la zone cliquable (centrée au-dessus du sol).
func setup(p_id: String, display_name: String, size: Vector3, p_label_height: float) -> void:
	building_id = p_id
	label_height = p_label_height
	_base_scale = scale
	_area = Area3D.new()
	_area.input_ray_pickable = true
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position.y = size.y / 2.0
	_area.add_child(shape)
	add_child(_area)
	_area.input_event.connect(_on_input)
	_area.mouse_entered.connect(func() -> void: _set_hover(true))
	_area.mouse_exited.connect(func() -> void: _set_hover(false))

	_label = Label3D.new()
	_label.text = display_name
	_label.font_size = 40
	_label.outline_size = 12
	_label.outline_modulate = Color(0.08, 0.05, 0.03, 0.9)
	_label.modulate = Color(1.0, 0.93, 0.75)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	_label.render_priority = 5
	_label.position = Vector3(0, label_height, 0)
	add_child(_label)


func _on_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _idx: int) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		bounce()
		clicked.emit(building_id)


func bounce() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", _base_scale * Vector3(1.04, 0.95, 1.04), 0.07)
	tw.tween_property(self, "scale", _base_scale * Vector3(0.98, 1.04, 0.98), 0.1)
	tw.tween_property(self, "scale", _base_scale, 0.12)


func _set_hover(on: bool) -> void:
	_hover = on
	_label.modulate = Color(1.0, 0.85, 0.35) if on else Color(1.0, 0.93, 0.75)
	_label.outline_size = 16 if on else 12
