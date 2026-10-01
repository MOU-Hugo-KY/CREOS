extends Node3D
## Vitrine : tous les héros et monstres côte à côte, qui tournent sur eux-mêmes et enchaînent
## leurs animations. Sert à juger le style 3D pixel art.

const ROW_HEROES := ["brannoc", "kaela", "ysolde", "fennir", "aubeline"]
const ROW_MONSTERS := ["squelette_serviteur", "squelette_guerrier", "squelette_rodeur", "acolyte_noir", "vel_zareth"]
const FLOOR_TILE := "res://assets/kaykit/dungeon/Assets/floor_tile_large.gltf.glb"
const CYCLE := ["Idle", "attack", "Idle", "skill", "Idle", "Hit_A"]

var _models: Array[Node3D] = []
var _anims: Array[Dictionary] = []
var _players: Array[AnimationPlayer] = []
var _t := 0.0
var _step := 0


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.09, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.8)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.5
	cam.position = Vector3(0, 6, 10)
	cam.rotation_degrees = Vector3(-25, 0, 0)
	add_child(cam)

	var tile: PackedScene = load(FLOOR_TILE)
	for x in range(-4, 4):
		for z in range(-2, 1):
			var t := tile.instantiate() as Node3D
			t.position = Vector3(x * 4 + 2, 0, z * 4 + 2)
			add_child(t)
			PixelStyle.apply(t, false, Color(0.45, 0.42, 0.55))

	_row(ROW_HEROES, true, 2.4)
	_row(ROW_MONSTERS, false, -2.4)


func _row(ids: Array, heroes: bool, z: float) -> void:
	for i in ids.size():
		var data: Dictionary = GameData.hero(ids[i]) if heroes else GameData.monster(ids[i])
		var model: Node3D = load(data.model).instantiate()
		var s: float = data.get("scale", 1.0)
		model.scale = Vector3.ONE * (s * 0.75 if s > 1.0 else 1.0)
		model.position = Vector3((i - 2) * 2.4, 0, z)
		model.rotation_degrees.y = i * 40.0
		add_child(model)
		PixelStyle.apply(model)
		_models.append(model)
		_anims.append(data.get("anim", {}))
		_players.append(model.find_child("AnimationPlayer", true, false))
	_play_all()


func _process(delta: float) -> void:
	for m in _models:
		m.rotation.y += delta * 0.8
	_t += delta
	if _t > 1.6:
		_t = 0.0
		_step = (_step + 1) % CYCLE.size()
		_play_all()


func _play_all() -> void:
	for i in _players.size():
		var p := _players[i]
		if p == null:
			continue
		var name: String = CYCLE[_step]
		if name in ["attack", "skill"]:
			name = _anims[i].get(name, _anims[i].get("attack", "Idle"))
		if p.has_animation(name):
			p.play(name, 0.15)
