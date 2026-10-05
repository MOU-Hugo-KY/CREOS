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
	var by_id := {}
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
	draw_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z", 0)) < int(b.get("z", 0)))
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
	for alias: String in data.get("alias", {}):
		if anims.has(String(data.alias[alias])):
			anims[alias] = anims[String(data.alias[alias])]


func has_anim(name: String) -> bool:
	return anims.has(name)


## Dessine la pose de l'animation `name` à l'instant `t` sur `canvas` (un CanvasItem en cours de _draw).
func draw_pose(canvas: CanvasItem, name: String, t: float, modulate := Color.WHITE) -> void:
	var anim: Dictionary = anims[name]
	var dur: float = anim.dur
	t = fmod(t, dur) if anim.loop else minf(t, dur)
	var world := {}
	var alpha := {}
	for p: Dictionary in parts:
		var v: Dictionary = _sample(anim.keys.get(p.id, []), t)
		var local := Transform2D(deg_to_rad(v.r), Vector2(v.sx, v.sy), 0.0, p.offset + Vector2(v.x, v.y))
		var parent := String(p.get("parent", ""))
		world[p.id] = world[parent] * local if world.has(parent) else local
		alpha[p.id] = float(v.a) * float(alpha.get(parent, 1.0))
	for p: Dictionary in draw_order:
		if p.texture == null:
			continue
		canvas.draw_set_transform_matrix(world[p.id])
		canvas.draw_texture_rect(p.texture, p.rect, false, Color(modulate, modulate.a * alpha[p.id]))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


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
