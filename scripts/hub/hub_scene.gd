extends Node2D
## Scène du hub : Port-Franc en 2D. Relie le décor (bâtiments cliquables, héros qui se promènent),
## l'interface et la navigation (la Table des chasses ouvre la carte des mondes, puis la chasse).

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const DRAG_THRESHOLD := 12.0

var town: PortFranc2D
var hud: HubHud
var audio: BattleAudio
var camera: Camera2D

var _view_left := 0.0  # bord gauche visible, en px de la scène
var _view_target := 0.0
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_moved := false


func _ready() -> void:
	Engine.time_scale = 1.0
	town = PortFranc2D.new()
	add_child(town)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	_add_vignette()
	get_viewport().size_changed.connect(_fit)
	_fit()
	# On arrive sur la place, la Lanterne et la Loge des héros au centre.
	_view_left = clampf(1350.0 - _visible_width() / 2.0, 0.0, _max_left())
	_view_target = _view_left
	_update_camera()

	audio = BattleAudio.new()
	add_child(audio)
	audio.play_music("town_loop")

	hud = HubHud.new()
	add_child(hud)
	hud.action.connect(_do_action)
	hud.ui_sound.connect(func(s: String) -> void: audio.play(s, -4.0, 0.0))
	hud.hunt_prep.start_requested.connect(start_hunt)
	hud.time_of_day_requested.connect(func(h: float) -> void: town.ambience.hour_override = h)


## Bords de l'écran légèrement assombris et chauds : cadre l'image et attire l'œil au centre.
func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.4, 0.9, length(d));
	COLOR = vec4(0.12, 0.06, 0.08, v * 0.45);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)


func _process(delta: float) -> void:
	_view_left = lerpf(_view_left, _view_target, 1.0 - exp(-delta * 8.0))
	_update_camera()


## Glisser horizontalement pour regarder la ville ; toucher un bâtiment l'ouvre.
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = true
			_drag_start = mb.position
			_drag_moved = false
		else:
			_dragging = false
			if not _drag_moved:
				var id := town.building_at(get_global_mouse_position())
				if id != "":
					_on_building_clicked(id)
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var dir := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
		_view_target = clampf(_view_target + dir * 160.0, 0.0, _max_left())
	var mm := event as InputEventMouseMotion
	if mm:
		if _dragging:
			if mm.position.distance_to(_drag_start) > DRAG_THRESHOLD:
				_drag_moved = true
			if _drag_moved:
				_view_target = clampf(_view_target - mm.relative.x / camera.zoom.x, 0.0, _max_left())
		else:
			var id := town.building_at(get_global_mouse_position())
			town.set_hovered(id)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var z := vs.y / PortFranc2D.SIZE.y
	camera.zoom = Vector2(z, z)
	_view_target = clampf(_view_target, 0.0, _max_left())


func _visible_width() -> float:
	return get_viewport().get_visible_rect().size.x / maxf(0.01, camera.zoom.x)


func _max_left() -> float:
	return maxf(0.0, PortFranc2D.SIZE.x - _visible_width())


func _update_camera() -> void:
	camera.position = Vector2(_view_left, 0)
	town.set_view_left(_view_left)


func _on_building_clicked(id: String) -> void:
	var info: Dictionary = GameData.hub.get("buildings", {}).get(id, {})
	town.bounce(id)
	audio.play("ui_click", -4.0, 0.0)
	_do_action(info.get("action", ""), id)


func _do_action(action_name: String, id: String) -> void:
	match action_name:
		"campaign":
			# D'abord la carte des mondes et l'écran « Préparer la chasse », puis le combat.
			hud.open_campaign()
		"heroes":
			hud.open_lodge()
		"altar":
			hud.open_altar()
		"quests":
			hud.open_quests()
		"shop":
			hud.open_shop()
		"relics":
			hud.open_relics()
		_:
			hud.toast("%s — bientôt disponible !" % _name_of(id))


func start_hunt(hunt: String) -> void:
	if PlayerData.start_hunt(hunt):
		go_to_battle()
	else:
		hud.toast("Pas assez d'énergie : il en faut %d (tu as %d)." % [PlayerData.hunt_cost(hunt), PlayerData.energy()])


func go_to_battle() -> void:
	audio.stop_music(0.3)
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _name_of(id: String) -> String:
	var buildings: Dictionary = GameData.hub.get("buildings", {})
	if buildings.has(id):
		return buildings[id].get("name", id)
	for key in ["side_left", "side_right"]:
		for item: Dictionary in GameData.hub.get(key, []):
			if item.get("id") == id:
				return item.get("name", id)
	return id
