class_name PixelSheet
extends RefCounted
## Héros et monstres en pixel art : une suite d'images par animation (`assets/anim/pixel/<id>/sheet.json`,
## importé par `tools/import_pixel_*.py`). Remplace les pièces de l'acteur quand il en a une. Les animations sont
## reliées aux clips du jeu (`map`) et étirées pour que leur image de frappe tombe sur l'impact du clip.

const DIR := "res://assets/anim/pixel/"

static var _cache: Dictionary = {}

var scale := 4.8
var facing := 1.0  # 1 : dessiné vers la droite (héros), -1 : vers la gauche (monstres)
var _body := Rect2()
var anchor := Vector2(96, 146)
var map: Dictionary = {}  # clip du jeu ("0", "idle"…) -> animation du pack
var anims: Dictionary = {}  # nom -> {loop, frames: [[Texture2D, durée]], hit_frame, total, hit_time}
var _originals: Dictionary = {}
var _original_cache: Dictionary = {}
var _source_dir := ""
var effect: SpriteFrames  # effet « signature » joué sur la cible à l'impact (null si aucun)
var effect_pivot := Vector2(64, 64)
var effect_scale: Dictionary = {}  # animation d'attaque -> taille conseillée


## Interrupteur de la couche pixel art. À `false`, héros et monstres sont dessinés avec leurs pièces
## illustrées (squelette des héros, clips des monstres) et l'interface prend portraits et fiches dessinés.
static var enabled := false


static func for_actor(id: String) -> PixelSheet:
	if not enabled:
		return null
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
	_source_dir = dir
	scale = float(data.get("scale", 4.8))
	facing = float(data.get("facing", 1))
	anchor = Vector2(data.anchor[0], data.anchor[1])
	map = data.get("map", {})
	for name: String in data.anims:
		var a: Dictionary = data.anims[name]
		if data.get("redesign", false) and name.ends_with("_original"):
			_originals[name] = a
			continue
		anims[name] = _load_animation(a, dir)
	_center_on_feet()
	var fx: Variant = data.get("effect")
	if fx is Dictionary:
		effect = SpriteFrames.new()
		effect.set_animation_loop("default", false)
		effect.set_animation_speed("default", 1.0)
		for f: Array in fx.frames:
			effect.add_frame("default", ClipPlayer.texture(dir + String(f[0])), float(f[1]))
		effect_pivot = Vector2(fx.pivot[0], fx.pivot[1])
		effect_scale = fx.get("scale", {})


## Recentre l'ancre sur les pieds réels (milieu des rangées du bas de la première image de repos) :
## certains dessins ne sont pas centrés dans leur case et paraîtraient à côté de leur cercle au sol.
func _center_on_feet() -> void:
	if not anims.has("idle"):
		return
	var first: Texture2D = anims.idle.frames[0][0]
	if first.has_meta("pixel_anchor"):
		return
	var img: Image = first.get_image()
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var sum := 0
	var n := 0
	for y in range(maxi(used.position.y, used.end.y - 10), used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > 0.5:
				sum += x
				n += 1
	if n > 0:
		anchor.x = round(float(sum) / n)


## Animation pixel qui joue le clip `clip` du jeu ("" si aucune).
func anim_for(clip: String) -> String:
	var name := String(map.get(clip, ""))
	return name if anims.has(name) else ""


## Image à montrer à l'instant `t` du clip. `clip_dur` et `clip_hit` (instant d'impact du clip, ou -1)
## servent à étirer l'animation : sa frappe tombe sur l'impact, puis elle finit avant la fin du clip.
func frame_at(name: String, t: float, clip_dur: float, clip_hit: float) -> Texture2D:
	if name == "idle":
		return idle_still()
	var a: Dictionary = anims[name]
	var total: float = a.total
	var p := t
	if a.loop:
		p = fposmod(t, total)
	else:
		# Vitesse proche de celle du dessin (au plus 25 % plus lente) : si le clip du jeu est plus
		# long, l'animation démarre plus tard (le héros respire en attendant) pour que sa frappe
		# tombe sur l'impact, et il revient au repos une fois finie.
		var hit: float = a.hit_time
		var k := 1.0
		var start := 0.0
		if hit > 0.0 and clip_hit > 0.0:
			k = clampf(clip_hit / hit, 0.6, 1.25)
			start = maxf(0.0, clip_hit - hit * k)
		elif clip_dur > total:
			k = minf(clip_dur / total, 1.25)
		p = (t - start) / k
		if (p < 0.0 or p >= total) and anims.has("idle") and name != "death":
			return idle_still()
		p = clampf(p, 0.0, total - 0.001)
	return _frame_in(a, p)


## Repos : une seule pose, que `ClipPlayer` fait respirer (`breath`). Les poses de repos étant
## redessinées une à une, les enchaîner faisait clignoter le personnage.
func idle_still() -> Texture2D:
	return anims.idle.frames[0][0]


## Respiration du repos à l'instant `t` : 1 ± 1,8 % en hauteur, un souffle toutes les 2,4 s.
static func breath(t: float) -> float:
	return 1.0 + 0.018 * sin(t * TAU / 2.4)


func _frame_in(a: Dictionary, p: float) -> Texture2D:
	var acc := 0.0
	for f: Array in a.frames:
		acc += float(f[1])
		if p < acc:
			return f[0]
	return a.frames[-1][0]


## Calage de la pose choisie : les nouvelles planches peuvent avoir une autre résolution.
## Le repos renvoyé avant/après une attaque garde automatiquement son propre calage.
func frame_anchor(texture: Texture2D) -> Vector2:
	return texture.get_meta("pixel_anchor", anchor)


func frame_scale(texture: Texture2D) -> float:
	return float(texture.get_meta("pixel_scale", scale))


## Rectangle du corps (repère local de l'acteur, pieds en 0) d'après la première image de repos.
func body_rect() -> Rect2:
	if _body.size == Vector2.ZERO and anims.has("idle"):
		var tex: Texture2D = anims.idle.frames[0][0]
		var used := frame_rect(tex)
		_body = Rect2((Vector2(used.position) - frame_anchor(tex)) * frame_scale(tex), Vector2(used.size) * frame_scale(tex))
	return _body


## Petit bond en avant pendant les attaques (les images ne font pas avancer le personnage).
func lunge(t: float, clip_dur: float, clip_hit: float) -> float:
	if clip_hit <= 0.0:
		return 0.0
	var out := clip_hit + maxf(0.2, (clip_dur - clip_hit) * 0.5)
	if t < clip_hit * 0.6:
		return 0.0
	if t < clip_hit:
		return smoothstep(clip_hit * 0.6, clip_hit, t) * 70.0 * facing
	return (1.0 - smoothstep(clip_hit, out, t)) * 70.0 * facing


## Limites opaques fournies à l'import : exclure les pixels presque transparents du cadrage.
func frame_rect(texture: Texture2D) -> Rect2i:
	return texture.get_meta("pixel_bounds", texture.get_image().get_used_rect())


## Charger les anciens dessins seulement pour un diagnostic, pas pour chaque héros affiché.
func original_animation(state: String) -> Dictionary:
	var key := state + "_original"
	if anims.has(key):
		return anims[key]
	if not _original_cache.has(key) and _originals.has(key):
		_original_cache[key] = _load_animation(_originals[key], _source_dir)
	return _original_cache.get(key, {})


func has_original(state: String) -> bool:
	return _originals.has(state + "_original") or anims.has(state + "_original")


func _load_animation(a: Dictionary, dir: String) -> Dictionary:
	var frames: Array = []
	var total := 0.0
	var hit_time := -1.0
	var i := 0
	for f: Array in a.frames:
		if a.get("hit_frame") != null and i == int(a.hit_frame):
			hit_time = total
		var texture: Texture2D = ClipPlayer.texture(dir + String(f[0]))
		if f.size() > 2 and f[2] is Dictionary:
			# Une planche conserve ses pixels natifs ; seules ses régions sont découpées.
			var layout: Dictionary = f[2]
			var region: Array = layout.region
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(region[0], region[1], region[2], region[3])
			atlas.filter_clip = true
			var origin: Array = layout.get("anchor", [anchor.x, anchor.y])
			atlas.set_meta("pixel_anchor", Vector2(origin[0], origin[1]))
			atlas.set_meta("pixel_scale", float(layout.get("scale", scale)))
			if layout.has("bounds"):
				var b: Array = layout.bounds
				atlas.set_meta("pixel_bounds", Rect2i(b[0], b[1], b[2], b[3]))
			texture = atlas
		frames.append([texture, float(f[1])])
		total += float(f[1])
		i += 1
	return {"loop": bool(a.loop), "frames": frames, "total": total, "hit_time": hit_time}
