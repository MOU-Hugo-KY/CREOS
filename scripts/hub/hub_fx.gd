class_name HubFx
extends Node2D
## Effets pixelfx de la place du hub (affichage seulement), d'après data/pixelfx_hub.json : papillons et
## oiseaux le jour, feux follets et chauve-souris la nuit, effets plein écran (lucioles la nuit, rayons à
## l'aube, averse de temps en temps). Rien de cliquable : les clics passent aux bâtiments (HubPixel.tap).
## Les planches (chargées ici, sans cache : une planche météo est libérée quand l'effet s'arrête) viennent de `node tools/export_pixelfx.mjs --data=data/pixelfx_hub.json` (assets/pixelfx/).

const DATA_PATH := "res://data/pixelfx_hub.json"
const DIR := "res://assets/pixelfx/"
const MAP := Vector2(1280, 720)
const FADE := 1.2

var _items: Array[Dictionary] = []  # {e, spr, home, t}
var _weather_defs: Array = []
var _weather: Dictionary = {}  # effet plein écran en cours : {e, spr, left}
var _phase := ""
var _tint := Color.WHITE
var _roll := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_weather_defs = data.get("weather", [])
	for e: Dictionary in data.get("effects", []):
		var home := Vector2(e.pos[0], e.pos[1])
		var spr := _spawn(self, e, home, float(e.get("k", 1)), 5)
		if spr == null:
			continue
		spr.visible = false
		spr.modulate.a = 0.0
		_items.append({"e": e, "spr": spr, "home": home, "t": randf() * 100.0})


## Moment de la journée (dawn, day, dusk, night) et teinte de la place : chaque effet apparaît ou s'efface.
func set_phase(phase: String, tint: Color) -> void:
	var changed := phase != _phase
	_phase = phase
	_tint = tint
	for it: Dictionary in _items:
		_show(it.spr, it.e, phase in it.e.get("when", []))
	if changed:
		_end_weather()
		_roll = 0.0
		_pick_weather(true)


func _color(e: Dictionary, on: bool) -> Color:
	var c := Color.WHITE if bool(e.get("glow", false)) else _tint
	c.a = float(e.get("alpha", 1.0)) if on else 0.0
	return c


func _show(spr: CanvasItem, e: Dictionary, on: bool) -> void:
	if on:
		spr.visible = true
	var tw := spr.create_tween()
	tw.tween_property(spr, "modulate", _color(e, on), FADE)
	if not on:
		tw.tween_callback(func() -> void: spr.visible = false)


## Pose un effet en boucle (planche exportée de pixelfx). `k` entier : pixels nets. null si la planche manque.
func _spawn(parent: Node, e: Dictionary, pos: Vector2, k: float, z: int) -> AnimatedSprite2D:
	var key := String(e.fx).replace("/", "-") + ("-" + String(e.pal) if e.has("pal") else "")
	if not FileAccess.file_exists(DIR + key + ".json") or not ResourceLoader.exists(DIR + key + ".png"):
		return null
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + key + ".json"))
	var tex: Texture2D = load(DIR + key + ".png")
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", true)
	sf.set_animation_speed("default", float(info.fps))
	var w := int(info.size[0])
	var h := int(info.size[1])
	var cols := int(info.columns)
	# Les planches météo ont une bande de sol (herbe, flaques) en bas : on la coupe (`crop_bottom` lignes).
	var keep := h - int(e.get("crop_bottom", 0))
	for i in int(info.frames):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % cols) * w, (i / cols) * h, w, keep)
		sf.add_frame("default", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var flip := bool(e.get("flip", false))
	spr.flip_h = flip
	var px := float(info.pivot[0])
	spr.offset = Vector2(-(float(w) - px) if flip else -px, -float(info.pivot[1]))
	spr.scale = Vector2(k, k)
	spr.position = pos
	spr.z_index = z
	spr.speed_scale = float(e.get("speed", 1.0))
	spr.modulate.a = float(e.get("alpha", 1.0))
	parent.add_child(spr)
	spr.play()
	spr.frame = randi() % maxi(1, int(info.frames))  # deux effets pareils ne battent pas ensemble
	return spr


# --- Effets plein écran ------------------------------------------------------------------

## Tire au sort un effet plein écran pour ce moment de la journée (un seul à la fois : les planches sont lourdes).
func _pick_weather(_first: bool) -> void:
	for w: Dictionary in _weather_defs:
		if not (_phase in w.get("when", [])):
			continue
		if randf() >= float(w.get("chance", 1.0)):
			continue
		var spr := _spawn_weather(w)
		if spr == null:
			continue
		spr.modulate.a = 0.0
		_show(spr, w, true)
		_weather = {"e": w, "spr": spr, "left": float(w.get("duration", -1.0))}
		return


## Effet plein écran : couvre toute la carte (la hauteur est étirée pour compenser la bande de sol coupée).
func _spawn_weather(w: Dictionary) -> AnimatedSprite2D:
	var spr := _spawn(self, w, Vector2.ZERO, float(w.get("k", 4)), 4)
	if spr == null:
		return null
	spr.centered = false
	spr.offset = Vector2.ZERO
	var size := spr.sprite_frames.get_frame_texture("default", 0).get_size()
	spr.scale = MAP / size
	return spr


func _end_weather() -> void:
	if _weather.is_empty():
		return
	var spr: AnimatedSprite2D = _weather.spr
	var tw := spr.create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, FADE)
	tw.tween_callback(spr.queue_free)  # la planche n'est plus gardée en mémoire
	_weather = {}


## Force un effet plein écran (outil de capture) : `id` de data/pixelfx_hub.json "weather".
func force_weather(id: String) -> void:
	_end_weather()
	for w: Dictionary in _weather_defs:
		if w.id == id:
			var spr := _spawn_weather(w)
			if spr:
				spr.modulate = _color(w, true)
				_weather = {"e": w, "spr": spr, "left": float(w.get("duration", -1.0))}


func _process(delta: float) -> void:
	for it: Dictionary in _items:
		var spr: AnimatedSprite2D = it.spr
		if not spr.visible:
			continue
		var e: Dictionary = it.e
		it.t += delta
		if e.has("drift"):
			# traverse la carte et revient de l'autre côté
			spr.position += Vector2(e.drift[0], e.drift[1]) * delta
			if spr.position.x > MAP.x + 80.0:
				spr.position = Vector2(-80.0, it.home.y)
			elif spr.position.x < -80.0:
				spr.position = Vector2(MAP.x + 80.0, it.home.y)
		elif e.has("wander"):
			# promenade : vole doucement vers un point au hasard autour de son ancrage, puis en choisit un autre
			var r := float(e.wander)
			var p: Vector2 = it.get("p", it.home)
			var v: Vector2 = it.get("v", Vector2.ZERO)
			var goal: Vector2 = it.get("goal", it.home)
			if p.distance_to(goal) < 6.0:
				goal = it.home + Vector2(randf_range(-r, r), randf_range(-r, r) * 0.6)
			var speed := float(e.get("fly", 16.0))
			v = v.lerp((goal - p).normalized() * speed, minf(1.0, delta * 1.2))  # virages souples
			p += v * delta
			it.p = p
			it.v = v
			it.goal = goal
			spr.position = p
		spr.position = spr.position.round()  # pixels nets
	if not _weather.is_empty() and float(_weather.left) > 0.0:
		_weather.left -= delta
		if _weather.left <= 0.0:
			_end_weather()
	if _weather.is_empty():
		_roll += delta
		var every := 90.0
		for w: Dictionary in _weather_defs:
			if _phase in w.get("when", []):
				every = float(w.get("every", 90.0))
		if _roll >= every:
			_roll = 0.0
			_pick_weather(false)
