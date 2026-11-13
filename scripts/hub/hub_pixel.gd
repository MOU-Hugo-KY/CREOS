class_name HubPixel
extends Node2D
## Le hub en pixel art (vue de dessus inclinée), d'après `assets/hub_px/hub_layout.json` (carte 1280 × 720) :
## sol, bâtiments et objets triés par leur pied, effets animés (cristal, flammes, fumée, bannières,
## étincelles), lumières, jour/nuit. Les héros de l'équipe (planches 4 directions dans `heroes/`) se
## promènent seuls sur la place en contournant les bâtiments ; toucher un bâtiment ouvre son service.

signal service_requested(service_id: String)

const DIR := "res://assets/hub_px/"
const SIZE := Vector2(1280, 720)
const SPEED := 130.0
const MAX_WALKERS := 6

var layout: Dictionary = {}
var buildings: Dictionary = {}  # id -> {node, hitbox: Rect2, approach: Vector2, label}
var _walkers: Array[Dictionary] = []  # héros qui se promènent : {node, sprite, path, rest, facing}
var avatar: Node2D  # le premier promeneur (Corbin si possible)
var _world: Node2D
var _ground: Sprite2D
var _ambient: CanvasModulate
var _lights: Array[Dictionary] = []
var _fx: Array[AnimatedSprite2D] = []
var _nav := AStarGrid2D.new()
var _clock := 0.0
var _hour_override := -1.0
var _hovered := ""
var fx_layer: HubFx  # effets pixelfx (data/pixelfx_hub.json)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hub_layout.json"))
	_ground = Sprite2D.new()
	_ground.texture = load(layout.background)
	_ground.centered = false
	add_child(_ground)
	_ambient = CanvasModulate.new()
	add_child(_ambient)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	for item: Dictionary in layout.buildings:
		var node := _add_object(item)
		var h: Array = item.hitbox
		buildings[item.id] = {"node": node, "hitbox": Rect2(h[0], h[1], h[2], h[3]), "label": item.label,
			"approach": Vector2(item.approach[0], item.approach[1])}
	for item: Dictionary in layout.props:
		_add_object(item)
	for item: Dictionary in layout.effects:
		_add_effect(item)
	for item: Dictionary in layout.lights:
		_add_light(item)
	fx_layer = HubFx.new()
	add_child(fx_layer)
	_build_navigation()
	_build_walkers()
	set_hour(-1.0)


func _add_object(item: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.position = Vector2(item.position[0], item.position[1])
	_world.add_child(node)
	var sprite := Sprite2D.new()
	sprite.texture = load(item.file)
	sprite.centered = false
	sprite.position = -Vector2(item.pivot[0], item.pivot[1])
	node.add_child(sprite)
	return node


func _add_effect(item: Dictionary) -> void:
	var data: Dictionary = layout.animations[item.animation]
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", data.fps)
	frames.set_animation_loop("default", data.loop)
	var tex: Texture2D = load(data.sheet)
	for r: Array in data.rects:
		var tile := AtlasTexture.new()
		tile.atlas = tex
		tile.region = Rect2(r[0], r[1], r[2], r[3])
		frames.add_frame("default", tile)
	var fx := AnimatedSprite2D.new()
	fx.position = Vector2(item.position[0], item.position[1])
	fx.sprite_frames = frames
	fx.centered = false
	fx.offset = -Vector2(data.pivot[0], data.pivot[1])
	fx.z_index = 4
	var mat := CanvasItemMaterial.new()
	if item.animation in ["crystal", "flame", "violet_motes", "gold_glint"]:
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # restent vives la nuit
	if item.get("additive", false):
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx.material = mat
	add_child(fx)
	fx.play()
	fx.frame = int(item.get("phase", 0)) % int(data.frame_count)
	_fx.append(fx)


func _add_light(item: Dictionary) -> void:
	var light := PointLight2D.new()
	light.position = Vector2(item.position[0], item.position[1])
	light.color = Color(item.color)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var radial := GradientTexture2D.new()
	radial.gradient = g
	radial.width = 256
	radial.height = 256
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1, 0.5)
	light.texture = radial
	light.texture_scale = float(item.radius) / 128.0
	light.shadow_enabled = false
	add_child(light)
	_lights.append({"node": light, "energy": float(item.energy), "phase": float(item.phase)})


# --- Déplacement ---------------------------------------------------------------------

func _build_navigation() -> void:
	_nav.region = Rect2i(0, 0, 80, 45)
	_nav.cell_size = Vector2(16, 16)
	_nav.offset = Vector2(8, 8)
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.update()
	for y in 45:
		for x in 80:
			var p := Vector2(x * 16 + 8, y * 16 + 8)
			var solid := not Rect2(60, 180, 1160, 510).has_point(p)
			for r: Array in layout.collisions:
				if Rect2(r[0], r[1], r[2], r[3]).grow(9).has_point(p):
					solid = true
			_nav.set_point_solid(Vector2i(x, y), solid)


func _nearest_walkable(p: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var dist := INF
	for y in 45:
		for x in 80:
			var id := Vector2i(x, y)
			if _nav.is_point_solid(id):
				continue
			var d := p.distance_squared_to(_nav.get_point_position(id))
			if d < dist:
				dist = d
				best = id
	return best


## Héros sur la place : l'équipe de chasse (sinon les héros possédés), Corbin d'abord, 6 au plus.
func _build_walkers() -> void:
	var ids: Array = PlayerData.team().duplicate()
	if ids.is_empty():
		ids = PlayerData.owned_heroes().duplicate()
	ids.erase("corbin")
	ids.push_front("corbin")
	var spawn := Vector2(layout.spawn[0], layout.spawn[1])
	for id: String in ids:
		if _walkers.size() >= MAX_WALKERS:
			break
		var frames := _hero_frames(id)
		if frames == null:
			continue
		var node := Node2D.new()
		node.position = spawn if _walkers.is_empty() else _nav.get_point_position(
			_nearest_walkable(Vector2(randf_range(250, 1030), randf_range(320, 640))))
		_world.add_child(node)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.centered = false
		sprite.offset = Vector2(-96, -146)
		sprite.scale = Vector2(0.7, 0.7)
		node.add_child(sprite)
		sprite.play("idle_down")
		sprite.frame = randi() % frames.get_frame_count("idle_down")
		var sheet := PixelSheet.for_actor(id)
		if sheet and sheet.anims.idle.frames[0][0].has_meta("pixel_anchor"):
			sprite.frame_changed.connect(_calibrate_walker.bind(sprite, sheet))
			sprite.animation_changed.connect(_calibrate_walker.bind(sprite, sheet))
			_calibrate_walker(sprite, sheet)
		_walkers.append({"id": id, "node": node, "sprite": sprite, "path": PackedVector2Array(),
			"rest": randf_range(0.5, 3.0), "facing": "down"})
	if not _walkers.is_empty():
		avatar = _walkers[0].node


## Planches 4 directions d'un héros (`heroes/<id>/<id>_hub.json`), ou null s'il n'en a pas.
func _hero_frames(id: String) -> SpriteFrames:
	var sheet := PixelSheet.for_actor(id)
	if sheet and sheet.anims.idle.frames[0][0].has_meta("pixel_anchor"):
		var updated := SpriteFrames.new()
		updated.remove_animation("default")
		for direction: String in ["left", "right", "up", "down"]:
			for state: String in ["idle", "walk"]:
				var anim := state + "_" + direction
				updated.add_animation(anim)
				updated.set_animation_speed(anim, 1.0)
				updated.set_animation_loop(anim, true)
				for f: Array in sheet.anims[state].frames:
					updated.add_frame(anim, f[0], float(f[1]))
		return updated
	var path := DIR + "heroes/%s/%s_hub.json" % [id, id]
	if not FileAccess.file_exists(path):
		return null
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in data.animations:
		var a: Dictionary = data.animations[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(a.fps))
		frames.set_animation_loop(anim, bool(a.loop))
		var tex: Texture2D = load(DIR + "heroes/%s/%s" % [id, a.sheet])
		for f: Dictionary in a.frames:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			var r: Array = f.rect
			atlas.region = Rect2(r[0], r[1], r[2], r[3])
			frames.add_frame(anim, atlas)
	return frames


## Toucher la carte : si c'est un bâtiment, il s'ouvre tout de suite (le joueur ne dirige pas Corbin).
func tap(point: Vector2) -> void:
	var id := building_at(point)
	if id != "":
		bounce(id)
		service_requested.emit(id)


## Un héros se promène tout seul : il choisit un endroit libre de la place, y marche, s'arrête un moment.
func _wander_next(w: Dictionary) -> void:
	for attempt in 20:
		var p := Vector2(randf_range(200, 1080), randf_range(300, 660))
		var cell := _nearest_walkable(p)
		var path := _nav.get_point_path(_nearest_walkable(w.node.position), cell)
		if path.size() > 2:
			w.path = path
			return


func building_at(point: Vector2) -> String:
	for id: String in buildings:
		if (buildings[id].hitbox as Rect2).has_point(point):
			return id
	return ""


## Survol : le bâtiment s'éclaire un peu.
func set_hovered(id: String) -> void:
	if id == _hovered:
		return
	if _hovered != "" and buildings.has(_hovered):
		buildings[_hovered].node.modulate = Color.WHITE
	_hovered = id
	if id != "":
		buildings[id].node.modulate = Color(1.12, 1.08, 1.0)


func bounce(id: String) -> void:
	var node: Node2D = buildings[id].node
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.04, 0.97), 0.07)
	tw.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_clock += delta
	if _hour_override < 0.0 and _clock >= _next_check:
		_next_check = _clock + 30.0
		set_hour(-1.0)  # heure réelle : on suit l'horloge
	for l: Dictionary in _lights:
		l.node.energy = l.energy * _light_level * (1.0 + 0.06 * sin(_clock * 3.1 + l.phase) + 0.025 * sin(_clock * 7.3 + l.phase))
	for w: Dictionary in _walkers:
		_walk(w, delta)


func _walk(w: Dictionary, delta: float) -> void:
	var node: Node2D = w.node
	var sprite: AnimatedSprite2D = w.sprite
	var path: PackedVector2Array = w.path
	var dir := Vector2.ZERO
	if not path.is_empty():
		dir = path[0] - node.position
		node.position = node.position.move_toward(path[0], SPEED * 0.6 * delta)
		if node.position.distance_to(path[0]) < 1.0:
			path.remove_at(0)
			w.path = path
			if path.is_empty():
				w.rest = randf_range(1.5, 5.0)  # pause avant la prochaine balade
	else:
		w.rest -= delta
		if w.rest <= 0.0:
			_wander_next(w)
	if dir.length() > 0.1:
		# Axe dominant : face, dos, droite ou gauche.
		if absf(dir.x) >= absf(dir.y):
			w.facing = "right" if dir.x > 0.0 else "left"
		else:
			w.facing = "down" if dir.y > 0.0 else "up"
		_play_keep_phase(sprite, "walk_" + w.facing)
	else:
		sprite.play("idle_" + w.facing)


## Change de direction de marche sans repartir de la première image.
func _play_keep_phase(sprite: AnimatedSprite2D, anim: String) -> void:
	if sprite.animation == anim:
		return
	var was_walking := String(sprite.animation).begins_with("walk")
	var phase := float(sprite.frame) / float(sprite.sprite_frames.get_frame_count(sprite.animation))
	sprite.play(anim)
	if was_walking:
		sprite.frame = int(phase * sprite.sprite_frames.get_frame_count(anim))


# --- Jour et nuit ------------------------------------------------------------------------

var _light_level := 0.0
var _next_check := 30.0

## Heure du hub (-1 = heure réelle) : teinte générale et lanternes allumées le soir et la nuit.
func set_hour(hour: float) -> void:
	_hour_override = hour
	var h := hour
	if h < 0.0:
		var t := Time.get_time_dict_from_system()
		h = float(t.hour) + float(t.minute) / 60.0
	var tint := Color.WHITE
	var phase := "day"
	_light_level = 0.0
	if h < 5.5 or h >= 21.0:  # nuit
		tint = Color(0.42, 0.45, 0.66)
		_light_level = 1.2
		phase = "night"
	elif h < 8.0:  # aube
		tint = Color(0.95, 0.82, 0.8)
		_light_level = 0.5
		phase = "dawn"
	elif h >= 18.5:  # crépuscule
		tint = Color(0.96, 0.74, 0.62)
		_light_level = 0.8
		phase = "dusk"
	if fx_layer:
		fx_layer.set_phase(phase, tint)
	# Teinte du sol, des bâtiments et des objets (les effets lumineux et les lumières restent vifs).
	for node: CanvasItem in [_ground, _world]:
		create_tween().tween_property(node, "modulate", tint, 0.6)


## Reprendre les mêmes dessins au port ; les nouvelles vues restent de trois quarts.
func _calibrate_walker(sprite: AnimatedSprite2D, sheet: PixelSheet) -> void:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var origin := sheet.frame_anchor(texture)
	sprite.flip_h = String(sprite.animation).ends_with("left")
	if sprite.flip_h:
		origin.x = texture.get_width() - origin.x
	sprite.offset = -origin
	sprite.scale = Vector2.ONE * 0.7 * sheet.frame_scale(texture) / sheet.scale
