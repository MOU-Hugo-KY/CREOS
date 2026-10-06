class_name PixelSheet
extends RefCounted
## Héros en pixel art : une suite d'images par animation (`assets/anim/pixel/<id>/sheet.json`, importé par
## `tools/import_pixel_hero.py`). Remplace les pièces du héros quand il en a une. Les animations sont
## reliées aux clips du jeu (`map`) et étirées pour que leur image de frappe tombe sur l'impact du clip.

const DIR := "res://assets/anim/pixel/"

static var _cache: Dictionary = {}

var scale := 4.8
var anchor := Vector2(96, 146)
var map: Dictionary = {}  # clip du jeu ("0", "idle"…) -> animation du pack
var anims: Dictionary = {}  # nom -> {loop, frames: [[Texture2D, durée]], hit_frame, total, hit_time}


static func for_actor(id: String) -> PixelSheet:
	if _cache.has(id):
		return _cache[id]
	var sheet: PixelSheet = null
	var path := DIR + id + "/sheet.json"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			sheet = PixelSheet.new()
			sheet._build(data, DIR + id + "/")
	_cache[id] = sheet
	return sheet


func _build(data: Dictionary, dir: String) -> void:
	scale = float(data.get("scale", 4.8))
	anchor = Vector2(data.anchor[0], data.anchor[1])
	map = data.get("map", {})
	for name: String in data.anims:
		var a: Dictionary = data.anims[name]
		var frames: Array = []
		var total := 0.0
		var hit_time := -1.0
		var i := 0
		for f: Array in a.frames:
			if a.get("hit_frame") != null and i == int(a.hit_frame):
				hit_time = total
			frames.append([ClipPlayer.texture(dir + String(f[0])), float(f[1])])
			total += float(f[1])
			i += 1
		anims[name] = {"loop": bool(a.loop), "frames": frames, "total": total, "hit_time": hit_time}


## Animation pixel qui joue le clip `clip` du jeu ("" si aucune).
func anim_for(clip: String) -> String:
	var name := String(map.get(clip, ""))
	return name if anims.has(name) else ""


## Image à montrer à l'instant `t` du clip. `clip_dur` et `clip_hit` (instant d'impact du clip, ou -1)
## servent à étirer l'animation : sa frappe tombe sur l'impact, puis elle finit avant la fin du clip.
func frame_at(name: String, t: float, clip_dur: float, clip_hit: float) -> Texture2D:
	var a: Dictionary = anims[name]
	var total: float = a.total
	var p := t
	if a.loop:
		p = fposmod(t, total)
	else:
		var hit: float = a.hit_time
		if hit > 0.0 and clip_hit > 0.0:
			var after_clip := maxf(0.05, clip_dur - clip_hit)
			if t <= clip_hit:
				p = t / clip_hit * hit
			else:
				p = hit + (t - clip_hit) / after_clip * (total - hit) * 1.4
		elif clip_dur > total:
			p = t * total / clip_dur
		p = minf(p, total - 0.001)
	var acc := 0.0
	for f: Array in a.frames:
		acc += float(f[1])
		if p < acc:
			return f[0]
	return a.frames[-1][0]


## Petit bond en avant pendant les attaques (les images ne font pas avancer le personnage).
func lunge(t: float, clip_dur: float, clip_hit: float) -> float:
	if clip_hit <= 0.0:
		return 0.0
	var out := clip_hit + maxf(0.2, (clip_dur - clip_hit) * 0.5)
	if t < clip_hit * 0.6:
		return 0.0
	if t < clip_hit:
		return smoothstep(clip_hit * 0.6, clip_hit, t) * 70.0
	return (1.0 - smoothstep(clip_hit, out, t)) * 70.0
