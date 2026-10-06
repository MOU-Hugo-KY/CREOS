class_name HubPixel
extends Node2D
## Le hub en pixel art (vue de dessus inclinée), d'après `assets/hub_px/hub_layout.json` (carte 1280 × 720) :
## sol, bâtiments et objets triés par leur pied, effets animés (cristal, flammes, fumée, bannières,
## étincelles), lumières, jour/nuit. Corbin se promène tout seul sur la place en contournant les
## bâtiments ; toucher un bâtiment ouvre son service.

signal service_requested(service_id: String)

const DIR := "res://assets/hub_px/"
const SIZE := Vector2(1280, 720)
const SPEED := 130.0

var layout: Dictionary = {}
var buildings: Dictionary = {}  # id -> {node, hitbox: Rect2, approach: Vector2, label}
var _walkers: Array = []  # personnages qui marchent (le joueur)
var avatar: Node2D
var _sprite: AnimatedSprite2D
var _world: Node2D
var _ground: Sprite2D
var _ambient: CanvasModulate
var _lights: Array[Dictionary] = []
var _fx: Array[AnimatedSprite2D] = []
var _nav := AStarGrid2D.new()
var _path := PackedVector2Array()
var _rest := 1.0
var _clock := 0.0
var _hour_override := -1.0
var _hovered := ""


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
	_build_navigation()
	_build_avatar()
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


func _build_avatar() -> void:
	avatar = Node2D.new()
	avatar.position = Vector2(layout.spawn[0], layout.spawn[1])
	_world.add_child(avatar)
	_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ["idle", "walk"]:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8 if anim == "idle" else 10)
		var tex: Texture2D = load(DIR + "avatar/corbin_" + anim + ".png")
		for i in 8:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * 192, 0, 192, 192)
			frames.add_frame(anim, atlas)
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.offset = Vector2(-96, -146)
	_sprite.scale = Vector2(0.7, 0.7)
	avatar.add_child(_sprite)
	_sprite.play("idle")
	_walkers.append(avatar)


## Toucher la carte : si c'est un bâtiment, il s'ouvre tout de suite (le joueur ne dirige pas Corbin).
func tap(point: Vector2) -> void:
	var id := building_at(point)
	if id != "":
		bounce(id)
		service_requested.emit(id)


## Corbin se promène tout seul : il choisit un endroit libre de la place, y marche, s'arrête un moment.
func _wander_next() -> void:
	for attempt in 20:
		var p := Vector2(randf_range(200, 1080), randf_range(300, 660))
		var cell := _nearest_walkable(p)
		var path := _nav.get_point_path(_nearest_walkable(avatar.position), cell)
		if path.size() > 2:
			_path = path
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
	var dir := Vector2.ZERO
	if not _path.is_empty():
		dir = _path[0] - avatar.position
		avatar.position = avatar.position.move_toward(_path[0], SPEED * 0.6 * delta)
		if avatar.position.distance_to(_path[0]) < 1.0:
			_path.remove_at(0)
			if _path.is_empty():
				_rest = randf_range(1.5, 4.0)  # pause avant la prochaine balade
	else:
		_rest -= delta
		if _rest <= 0.0:
			_wander_next()
	if dir.length() > 0.1:
		_sprite.play("walk")
		_sprite.flip_h = dir.x < 0.0
	else:
		_sprite.play("idle")


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
	_light_level = 0.0
	if h < 5.5 or h >= 21.0:  # nuit
		tint = Color(0.42, 0.45, 0.66)
		_light_level = 1.2
	elif h < 8.0:  # aube
		tint = Color(0.95, 0.82, 0.8)
		_light_level = 0.5
	elif h >= 18.5:  # crépuscule
		tint = Color(0.96, 0.74, 0.62)
		_light_level = 0.8
	# Teinte du sol, des bâtiments et des objets (les effets lumineux et les lumières restent vifs).
	for node: CanvasItem in [_ground, _world]:
		create_tween().tween_property(node, "modulate", tint, 0.6)
