class_name Rig
extends RefCounted
## Squelette 2D d'un personnage (`assets/anim/rigs/<id>.json`) : les pièces détachées du dessin
## sont accrochées à des os (pivots aux articulations) et animées par quelques poses clés ;
## le mouvement entre deux poses est calculé à chaque image (fluide, quelle que soit la cadence).
## Même calcul que `tools/render_rig.py` (aperçu sans Godot).

const DIR := "res://assets/anim/rigs/"
const DEFAULT := {"r": 0.0, "x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "a": 1.0}

static var _cache: Dictionary = {}  # id -> Rig (ou null)

var parts: Array[Dictionary] = []  # dans l'ordre parent avant enfant
var draw_order: Array[Dictionary] = []  # pièces dessinées, triées par z
var anims: Dictionary = {}  # nom -> {dur, loop, keys: {os: [[t, valeurs complètes, courbe]]}}
var by_id: Dictionary = {}
var followers: Dictionary = {}  # pièce libre -> force du retard
var trail_tips: Dictionary = {}  # pièce -> pointe (locale) qui laisse une traînée

const FOLLOW_LAG := 0.07
## Pièces du corps ; toutes les autres (cape, queue, ailes, oreilles, cheveux…) flottent.
const BODY := ["root", "hip", "pelvis", "torso", "head", "upper_arm_front", "forearm_front", "hand_front",
	"weapon_front", "upper_arm_back", "forearm_hand_back", "weapon_back", "thigh_front", "shin_front",
	"thigh_back", "shin_back", "shield", "leg_front", "leg_back", "arm", "arm_f", "arm_b"]


## Squelette d'un personnage, ou null s'il n'en a pas.
static func for_actor(id: String) -> Rig:
	if _cache.has(id):
		return _cache[id]
	var rig: Rig = null
	var path := DIR + id + ".json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			rig = Rig.new()
			rig._build(data, "res://assets/anim/heroes/tex/")
	_cache[id] = rig
	return rig


func _build(data: Dictionary, tex_dir: String) -> void:
	for p: Dictionary in data.get("parts", []):
		var part := p.duplicate()
		var parent: Dictionary = by_id.get(String(p.get("parent", "")), {})
		var pivot := Vector2(p.pivot[0], p.pivot[1])
		var parent_pivot := Vector2(parent.pivot[0], parent.pivot[1]) if not parent.is_empty() else Vector2.ZERO
		part.offset = pivot - parent_pivot
		if p.has("tex"):
			part.texture = ClipPlayer.texture(tex_dir + String(p.tex))
			var size := Vector2(p.size[0], p.size[1])
			part.rect = Rect2(Vector2(p.pos[0], p.pos[1]) - pivot - size / 2.0, size)
			draw_order.append(part)
		parts.append(part)
		by_id[String(p.id)] = part
		var id := String(p.id)
		if p.has("tex") and not BODY.has(id) and not id.begins_with("tentacle"):
			var loose := false
			for prefix: String in ["cape", "tail", "sash", "coat", "scarf", "wing"]:
				loose = loose or id.begins_with(prefix)
			followers[id] = 1.4 if loose else 0.8
		if id.begins_with("weapon") and p.has("tex"):
			var far := Vector2.ZERO
			for c: Vector2 in [part.rect.position, part.rect.end, Vector2(part.rect.position.x, part.rect.end.y), Vector2(part.rect.end.x, part.rect.position.y)]:
				if c.length() > far.length():
					far = c
			trail_tips[id] = far * 0.92
	draw_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("z", 0)) < float(b.get("z", 0)))
	for name: String in data.get("anims", {}):
		var a: Dictionary = data.anims[name]
		var keys := {}
		for bone: String in a.get("keys", {}):
			var cur := DEFAULT.duplicate()
			var full: Array = []
			for k: Array in a.keys[bone]:
				cur = cur.duplicate()
				cur.merge(k[1], true)
				full.append([float(k[0]), cur, String(k[2]) if k.size() > 2 else "s"])
			keys[bone] = full
		anims[name] = {"dur": float(a.get("dur", 1.0)), "loop": bool(a.get("loop", false)), "keys": keys}
	if trail_tips.is_empty():  # sans arme : les poings laissent la traînée
		for id: String in ["hand_front", "forearm_hand_back", "arm_f", "arm"]:
			if by_id.has(id) and by_id[id].has("rect"):
				var r: Rect2 = by_id[id].rect
				trail_tips[id] = r.get_center() + (r.get_center().normalized() * r.size.length() * 0.3)
	for alias: String in data.get("alias", {}):
		if anims.has(String(data.alias[alias])):
			anims[alias] = anims[String(data.alias[alias])]


func has_anim(name: String) -> bool:
	return anims.has(name)


## Dessine la pose de l'animation `name` à l'instant `t` sur `canvas` (un CanvasItem en cours de _draw).
func draw_pose(canvas: CanvasItem, name: String, t: float, modulate := Color.WHITE) -> void:
	var world := pose(name, t)
	for p: Dictionary in draw_order:
		if p.texture == null:
			continue
		canvas.draw_set_transform_matrix(world[p.id])
		canvas.draw_texture_rect(p.texture, p.rect, false, Color(modulate, modulate.a * float(world.get(p.id + "#a", 1.0))))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Transformations de toutes les pièces à l'instant t. Les pièces libres (capes, queues, ailes,
## oreilles, cheveux…) suivent le corps en retard : elles prennent l'angle et la vitesse que leur
## parent avait un instant plus tôt (mouvement secondaire, sans état à garder).
func pose(name: String, t: float) -> Dictionary:
	var now := _raw(name, t, {})
	if followers.is_empty():
		return now
	var before := _raw(name, t - FOLLOW_LAG, {})
	var extra := {}
	for id: String in followers:
		var parent := String(by_id[id].get("parent", ""))
		if not now.has(parent):
			continue
		var a: Transform2D = now[parent]
		var b: Transform2D = before[parent]
		var turn := rad_to_deg(angle_difference(a.get_rotation(), b.get_rotation()))
		var move: Vector2 = b.origin - a.origin  # vers où le parent vient de partir : la pièce traîne derrière
		var amount: float = followers[id]
		extra[id] = clampf((turn * 0.9 + move.x * 0.35 - move.y * 0.15) * amount, -38.0, 38.0)
	return _raw(name, t, extra)


func _raw(name: String, t: float, extra: Dictionary) -> Dictionary:
	var anim: Dictionary = anims[name]
	var dur: float = anim.dur
	t = fposmod(t, dur) if anim.loop else clampf(t, 0.0, dur)
	var world := {}
	for p: Dictionary in parts:
		var v: Dictionary = _sample(anim.keys.get(p.id, []), t)
		var r: float = v.r + float(extra.get(p.id, 0.0))
		var local := Transform2D(deg_to_rad(r), Vector2(v.sx, v.sy), 0.0, p.offset + Vector2(v.x, v.y))
		var parent := String(p.get("parent", ""))
		world[p.id] = world[parent] * local if world.has(parent) else local
		world[p.id + "#a"] = float(v.a) * float(world.get(parent + "#a", 1.0))
	return world


## Pointes des armes (ou des mains) à l'instant t, pour les traînées.
func tips(name: String, t: float) -> PackedVector2Array:
	var world := pose(name, t)
	var out := PackedVector2Array()
	for id: String in trail_tips:
		var w: Transform2D = world[id]
		out.append(w * trail_tips[id])
	return out


## Position du personnage (os racine) à l'instant t : sert à savoir s'il se rue (images rémanentes).
func root_at(name: String, t: float) -> Vector2:
	var world := _raw(name, t, {})
	return (world["root"] as Transform2D).origin if world.has("root") else Vector2.ZERO


static func _sample(keys: Array, t: float) -> Dictionary:
	if keys.is_empty():
		return DEFAULT
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		var k1: Array = keys[i]
		if t <= k1[0]:
			var k0: Array = keys[i - 1]
			var u := _ease(k1[2], (t - k0[0]) / maxf(0.000001, k1[0] - k0[0]))
			var out := {}
			for c: String in DEFAULT:
				out[c] = lerpf(k0[1][c], k1[1][c], u)
			return out
	return keys[-1][1]


static func _ease(kind: String, u: float) -> float:
	match kind:
		"l":
			return u
		"o":
			return 1.0 - pow(1.0 - u, 3.0)
		"i":
			return u * u * u
		"b":
			var c := 1.70158
			return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)
	return u * u * (3.0 - 2.0 * u)
