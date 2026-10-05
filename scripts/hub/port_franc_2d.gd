class_name PortFranc2D
extends Node2D
## Port-Franc, le hub, entièrement en 2D dessinée : une scène de 3840 × 1080 px faite de calques
## (ciel, horizon, ville, place, premier plan) qui glissent à des vitesses différentes quand on
## fait défiler (parallaxe), des bâtiments cliquables (image « survol » quand on passe dessus),
## des animations en planches de sprites (fumées, flammes, fanions, eau, bateau, mouettes, cristal
## de la Lanterne, feuillage) et les héros qui se promènent sur la place avec leurs vraies
## animations de marche. Tout est décrit dans `assets/hub2d/port/Scene.json`.

signal building_clicked(building_id: String)

const DIR := "res://assets/hub2d/port/"
const SIZE := Vector2(3840, 1080)

var scene: Dictionary = {}
var layer_sprites: Array[Sprite2D] = []  # un par calque de Scene.json, dans l'ordre
var ambience: PortAmbience
var buildings: Dictionary = {}  # id -> {node, sprite, tex, hover, mask, rect}
var hovered := ""

var _planes: Array[Dictionary] = []  # {node, parallax}
var _objects: Node2D  # objets posés sur la place, triés par leur point au sol
var _anims: Array[Dictionary] = []  # {sprite, fps, frames, phase}
var _sways: Array[Dictionary] = []  # images qui se balancent {node, rot, bob, speed, ph, base}
var _gulls: Array[Dictionary] = []
var _walkers: Array[Dictionary] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "Scene.json"))
	scene = parsed if parsed is Dictionary else {}
	var z := -100
	for layer: Dictionary in scene.get("layers", []):
		var front: bool = layer.get("front", false)
		var plane := _plane(float(layer.get("parallax", 1.0)), 100 if front else z)
		var s := Sprite2D.new()
		s.texture = load(DIR + String(layer.file))
		s.centered = false
		plane.add_child(s)
		layer_sprites.append(s)
		if float(layer.get("parallax", 1.0)) == 1.0 and not front:
			_objects = Node2D.new()
			_objects.y_sort_enabled = true
			_objects.z_index = 1
			plane.add_child(_objects)
		z += 10
	for b: Dictionary in scene.get("buildings", []):
		_add_building(b)
	for a: Dictionary in scene.get("anims", []):
		_add_anim(a)
	_add_gulls(scene.get("gulls", {}))
	_add_merchant(scene.get("merchant", {}))
	_add_heroes()
	ambience = PortAmbience.new()
	add_child(ambience)
	ambience.setup(self)


## Le hub place la caméra : `left` = bord gauche visible (en px de la scène).
func set_view_left(left: float) -> void:
	for p: Dictionary in _planes:
		var f: float = p.parallax
		p.node.position.x = (left - 960.0) * (1.0 - f)


## Gardé pour compatibilité : les bâtiments n'ont plus d'étiquette (les images parlent d'elles-mêmes).
func set_labels_visible(_on: bool) -> void:
	pass


## Bâtiment sous un point de l'écran (test sur la transparence de l'image), ou "".
func building_at(global_pos: Vector2) -> String:
	var best := ""
	var best_y := -INF
	for id: String in buildings:
		var b: Dictionary = buildings[id]
		var sprite: Sprite2D = b.sprite
		var local := sprite.get_global_transform().affine_inverse() * global_pos
		var mask: BitMap = b.mask
		var px := Vector2i(local)
		if px.x < 0 or px.y < 0 or px.x >= mask.get_size().x or px.y >= mask.get_size().y:
			continue
		if mask.get_bitv(px) and float(b.ground) > best_y:
			best = id
			best_y = b.ground
	return best


func set_hovered(id: String) -> void:
	if id == hovered:
		return
	if buildings.has(hovered):
		var old: Dictionary = buildings[hovered]
		(old.sprite as Sprite2D).texture = old.tex
	hovered = id
	if buildings.has(id):
		var b: Dictionary = buildings[id]
		if b.hover:
			(b.sprite as Sprite2D).texture = b.hover


func bounce(id: String) -> void:
	if not buildings.has(id):
		return
	var node: Node2D = buildings[id].node
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.04, 0.95), 0.07)
	tw.tween_property(node, "scale", Vector2(0.98, 1.04), 0.1)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)


func _process(delta: float) -> void:
	_time += delta
	for a: Dictionary in _anims:
		(a.sprite as Sprite2D).frame = int((_time + float(a.phase)) * float(a.fps)) % int(a.frames)
	for sw: Dictionary in _sways:
		var t := _time * float(sw.speed) * TAU * 0.5 + float(sw.ph)
		var node: Node2D = sw.node
		node.rotation = sin(t) * float(sw.rot)
		node.position = sw.base + Vector2(0, sin(t * 0.8 + 1.3) * float(sw.bob))
	var g: Dictionary = scene.get("gulls", {})
	for i in _gulls.size():
		var gull: Dictionary = _gulls[i]
		var ang := _time * (0.1 + i * 0.025) + i * 1.9
		var c: Array = g.get("center", [2700, 230])
		var r: Array = g.get("radius", [1000, 70])
		var s: Sprite2D = gull.sprite
		s.position = Vector2(float(c[0]) + cos(ang) * float(r[0]), float(c[1]) + sin(ang * 2.0) * float(r[1]) + i * 30)
		s.flip_h = sin(ang) < 0.0  # la mouette est dessinée tournée vers la gauche
	for w: Dictionary in _walkers:
		_walk(w, delta)


# --- Construction -------------------------------------------------------------------

func _plane(parallax: float, z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	add_child(n)
	_planes.append({"node": n, "parallax": parallax})
	return n


func planes() -> Array[Dictionary]:
	return _planes


func plane_for(parallax: float) -> Node2D:
	return _plane_for(parallax)


func _plane_for(parallax: float) -> Node2D:
	for p: Dictionary in _planes:
		if is_equal_approx(float(p.parallax), parallax):
			return p.node
	return _plane(parallax, -85)


func _add_building(b: Dictionary) -> void:
	var tex: Texture2D = load(DIR + String(b.file) + ".png")
	if tex == null:
		return
	var hover_path := DIR + String(b.file) + "_Survol.png"
	var img := tex.get_image()
	var used := img.get_used_rect()
	var s := float(b.w) / tex.get_width()
	var node := Node2D.new()
	node.position = Vector2(b.x, b.y)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(s, s)
	# Le bas du dessin (pas de l'image) touche le sol.
	sprite.position = Vector2(-tex.get_width() * s / 2.0, -used.end.y * s)
	node.add_child(sprite)
	var parallax := float(b.get("parallax", 1.0))
	if parallax == 1.0:
		_objects.add_child(node)
	else:
		var plane := _plane_for(parallax)
		node.z_index = 5
		plane.add_child(node)
	var mask := BitMap.new()
	mask.create_from_image_alpha(img, 0.3)
	buildings[b.id] = {"node": node, "sprite": sprite, "tex": tex, "mask": mask, "ground": float(b.y),
		"hover": load(hover_path) if ResourceLoader.exists(hover_path) else null}


func _add_anim(a: Dictionary) -> void:
	var file := String(a.file)
	var parts := file.get_basename().split("_")
	var frames := 1
	var fps := 0.0
	if parts.size() >= 3 and parts[parts.size() - 2].ends_with("f") and parts[parts.size() - 1].ends_with("fps"):
		frames = int(parts[parts.size() - 2].trim_suffix("f"))
		fps = float(parts[parts.size() - 1].trim_suffix("fps"))
	var tex: Texture2D = load(DIR + file)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = frames
	var size := float(a.size)
	sprite.scale = Vector2.ONE * size / float(tex.get_height())
	sprite.flip_h = a.get("flip", false)
	if a.has("cut_bottom"):
		# Coupe le bas du dessin (la coque « entre » dans l'eau).
		var keep := 1.0 - float(a.cut_bottom)
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, tex.get_width(), tex.get_height() * keep)
		sprite.offset = Vector2(0, -tex.get_height() * (1.0 - keep) / 2.0)  # le haut ne bouge pas
	var visual: Node2D = sprite
	if a.has("sway"):
		# Image fixe qui se balance doucement (les planches qui « sautent » d'une image à l'autre
		# sont remplacées par ce mouvement continu) : autour de son haut (lierre) ou de son bas (bateau).
		var sw: Dictionary = a.sway
		var pivot := Node2D.new()
		var down := String(sw.get("pivot", "bottom")) == "bottom"
		sprite.position = Vector2(0, -size / 2.0 if down else size / 2.0)
		pivot.add_child(sprite)
		visual = pivot
		_sways.append({"node": pivot, "rot": deg_to_rad(float(sw.get("rot", 2.0))), "bob": float(sw.get("bob", 0.0)),
			"speed": float(sw.get("speed", 0.6)), "ph": _rng.randf() * TAU, "offset": size / 2.0 * (1.0 if down else -1.0)})
	elif frames > 1:
		_anims.append({"sprite": sprite, "fps": fps, "frames": frames, "phase": _rng.randf() * 3.0})
	var at := Vector2(a.x, a.y)
	var parent: Node2D
	var local := at
	if a.get("front", false):
		parent = _plane_for(1.15)
		visual.z_index = 1
	elif a.has("parallax"):
		parent = _plane_for(float(a.parallax))
		visual.z_index = 2
	else:
		# Posée sur la place : triée par son point au sol (ou juste devant le bâtiment qu'elle orne).
		var ground := float(a.get("ground", at.y + size / 2.0))
		if a.has("above") and buildings.has(String(a.above)):
			ground = float(buildings[String(a.above)].ground) + 0.5
		parent = Node2D.new()
		parent.position = Vector2(at.x, ground)
		_objects.add_child(parent)
		local = Vector2(0, at.y - ground)
	parent.add_child(visual)
	if visual == sprite:
		sprite.position = local
	else:
		var sw_entry: Dictionary = _sways[-1]
		visual.position = local + Vector2(0, float(sw_entry.offset))
		sw_entry["base"] = visual.position


func _add_gulls(g: Dictionary) -> void:
	var tex: Texture2D = load(DIR + "Mouette_8f_10fps.png")
	if tex == null:
		return
	var plane := _plane(0.6, -75)
	for i in int(g.get("count", 3)):
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 8
		s.scale = Vector2.ONE * float(g.get("size", 90)) / tex.get_height() * (1.0 - i * 0.1)
		plane.add_child(s)
		_gulls.append({"sprite": s})
		_anims.append({"sprite": s, "fps": 10.0, "frames": 8, "phase": i * 0.37})


func _add_merchant(m: Dictionary) -> void:
	var folder := String(m.get("folder", ""))
	if folder == "" or not FileAccess.file_exists(folder.path_join("puppet.json")):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("puppet.json")))
	var cfg: Dictionary = parsed if parsed is Dictionary else {}
	var doll := PaperDoll.new().setup(folder)
	var px_height := float(cfg.get("height", 2.25)) / float(cfg.get("pixel_size", 0.0017))
	var s := float(m.get("height", 230)) / px_height
	doll.scale = Vector2(s * float(m.get("facing", 1)), s)
	doll.position = Vector2(m.get("x", 800), m.get("y", 920))
	_objects.add_child(doll)
	_objects.add_child(_shadow(doll.position, 70.0))


## Les héros possédés se promènent sur la place, s'arrêtent, et montrent parfois leur relique.
func _add_heroes() -> void:
	var area: Array = scene.get("walk_area", [780, 880, 1900, 130])
	var rect := Rect2(area[0], area[1], area[2], area[3])
	var ids: Array = PlayerData.team().duplicate()
	for id: String in PlayerData.owned_heroes():
		if ids.size() >= 7:
			break
		if id not in ids:
			ids.append(id)
	var i := 0
	for id: String in ids:
		var hero := GameData.hero(id)
		if not hero.has("anim"):
			continue
		var holder := Node2D.new()
		var shadow := _shadow(Vector2.ZERO, 46.0)
		holder.add_child(shadow)
		var p := ClipPlayer.new()
		p.bundle = String(hero.anim)
		p.idle_clip = id + "_idle"
		p.sound_enabled = false
		holder.add_child(p)
		p.play(id + "_idle")
		var h := maxf(200.0, -p.actor_rect(id + "_idle").position.y)
		var base := float(scene.get("hero_height", 230)) / h
		_objects.add_child(holder)
		var at := Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
		var w := {"id": id, "node": holder, "p": p, "at": at, "target": at, "base": base, "rect": rect,
			"wait": _rng.randf_range(0.5, 3.0) + i * 0.6, "moving": false}
		_place_walker(w)
		_walkers.append(w)
		i += 1


func _walk(w: Dictionary, delta: float) -> void:
	var p: ClipPlayer = w.p
	var rect: Rect2 = w.rect
	if w.wait > 0.0:
		w.wait -= delta
		if w.wait <= 0.0:
			w.target = Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
			w.moving = true
			p.play(String(w.id) + "_walk")
		return
	var to: Vector2 = w.target - w.at
	if to.length() < 6.0:
		w.moving = false
		w.wait = _rng.randf_range(2.5, 6.0)
		if _rng.randf() < 0.18 and p.has_clip(String(w.id) + "_relic"):
			p.play(String(w.id) + "_relic")
		else:
			p.play(String(w.id) + "_idle")
		return
	var step := to.normalized() * minf(110.0 * delta, to.length())
	w.at += step
	if absf(step.x) > 0.1:
		p.facing = signf(step.x)
	_place_walker(w)


func _place_walker(w: Dictionary) -> void:
	var node: Node2D = w.node
	var rect: Rect2 = w.rect
	node.position = w.at
	# Plus haut sur la place = plus loin = un peu plus petit.
	var depth := lerpf(0.86, 1.0, clampf((float(w.at.y) - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0))
	var p: ClipPlayer = w.p
	p.scale = Vector2(float(w.base) * depth * signf(p.facing), float(w.base) * depth)


func _shadow(at: Vector2, radius: float) -> Node2D:
	var n := Node2D.new()
	n.position = at
	n.z_index = -1
	n.draw.connect(func() -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.25))
		n.draw_colored_polygon(pts, Color(0.1, 0.06, 0.05, 0.25)))
	return n
