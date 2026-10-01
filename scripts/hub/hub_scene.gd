extends Node3D
## Scène du hub : Port-Franc. Relie le décor (bâtiments cliquables), les héros qui se promènent,
## l'interface et la navigation (la Table des chasses lance le combat).

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const CAMERA_POS := Vector3(0, 12.5, 19.5)
const CAMERA_LOOK := Vector3(0, 2.2, -9.0)
const PAN_LIMIT := 7.0
const DRAG_THRESHOLD := 12.0

var town: PortFranc
var hud: HubHud
var audio: BattleAudio
var camera: Camera3D
var wanderers: Array[Wanderer] = []

var _pan := 0.0
var _pan_target := 0.0
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_moved := false


func _ready() -> void:
	Engine.time_scale = 1.0
	town = PortFranc.new()
	add_child(town)
	town.building_clicked.connect(_on_building_clicked)

	camera = Camera3D.new()
	camera.fov = 46
	add_child(camera)
	_update_camera()

	var i := 0
	for id: String in GameData.heroes:
		var w := Wanderer.new()
		add_child(w)
		w.setup(GameData.hero(id), 100 + i)
		wanderers.append(w)
		i += 1

	audio = BattleAudio.new()
	add_child(audio)
	audio.play_music("town_loop")

	hud = HubHud.new()
	add_child(hud)
	hud.action.connect(_do_action)
	hud.ui_sound.connect(func(s: String) -> void: audio.play(s, -4.0, 0.0))


func _process(delta: float) -> void:
	_pan = lerpf(_pan, _pan_target, 1.0 - exp(-delta * 8.0))
	_update_camera()


## Glisser horizontalement pour regarder la ville (le clic sur un bâtiment reste possible).
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		if mb.pressed:
			_drag_start = mb.position
			_drag_moved = false
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		if mm.position.distance_to(_drag_start) > DRAG_THRESHOLD:
			_drag_moved = true
		if _drag_moved:
			_pan_target = clampf(_pan_target - mm.relative.x * 0.02, -PAN_LIMIT, PAN_LIMIT)


func _update_camera() -> void:
	var off := Vector3(_pan, 0, 0)
	camera.position = CAMERA_POS + off
	camera.look_at(CAMERA_LOOK + off, Vector3.UP)


func _on_building_clicked(id: String) -> void:
	if _drag_moved:
		return  # c'était un glissement, pas un clic
	var info: Dictionary = GameData.hub.get("buildings", {}).get(id, {})
	audio.play("ui_click", -4.0, 0.0)
	_do_action(info.get("action", ""), id)


func _do_action(action_name: String, id: String) -> void:
	match action_name:
		"campaign":
			go_to_battle()
		_:
			var name := _name_of(id)
			hud.toast("%s — bientôt disponible !" % name)


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
