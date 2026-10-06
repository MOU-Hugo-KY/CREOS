extends Node2D
## Scène du hub : la place en pixel art (HubPixel). Relie la carte (le joueur marche jusqu'au bâtiment
## touché), l'interface et la navigation (la Table des chasses ouvre la carte des mondes, puis la chasse).

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
## Bâtiment de la carte -> action du hub (menus existants).
const SERVICES := {
	"hunt_table": "campaign", "hero_lodge": "heroes", "oath_lantern": "altar",
	"relics": "relics", "merchant": "shop", "private_lodge": "lodge",
}

var town: HubPixel
var hud: HubHud
var audio: BattleAudio
var camera: Camera2D


func _ready() -> void:
	Engine.time_scale = 1.0
	town = HubPixel.new()
	add_child(town)
	town.service_requested.connect(_on_building_clicked)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()
	get_viewport().size_changed.connect(_fit)
	_fit()

	audio = BattleAudio.new()
	add_child(audio)
	audio.play_music("town_loop")

	hud = HubHud.new()
	add_child(hud)
	hud.action.connect(_do_action)
	hud.ui_sound.connect(func(s: String) -> void: audio.play(s, -4.0, 0.0))
	hud.hunt_prep.start_requested.connect(start_hunt)
	hud.time_of_day_requested.connect(func(h: float) -> void: town.set_hour(h))


## Toute la place tient à l'écran : zoom pour la faire rentrer, centrée (bandes si le format diffère).
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var z := maxf(vs.x / HubPixel.SIZE.x, vs.y / HubPixel.SIZE.y)  # remplit l'écran, rogne un peu les bords
	camera.zoom = Vector2(z, z)
	camera.position = (HubPixel.SIZE - vs / z) / 2.0


## Toucher un bâtiment l'ouvre.
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		town.tap(get_global_mouse_position())
	var mm := event as InputEventMouseMotion
	if mm:
		var id := town.building_at(get_global_mouse_position())
		town.set_hovered(id)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if id != "" else Input.CURSOR_ARROW)


func _on_building_clicked(id: String) -> void:
	audio.play("ui_click", -4.0, 0.0)
	_do_action(String(SERVICES.get(id, "")), id)


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
	if town.buildings.has(id):
		return String(town.buildings[id].label)
	for key in ["side_left", "side_right"]:
		for item: Dictionary in GameData.hub.get(key, []):
			if item.get("id") == id:
				return item.get("name", id)
	return id
