class_name ClipPlayer
extends Node2D
## Joue les animations 2D en pièces détachées livrées par ChatGPT (héros, ennemis), converties par
## `tools/import_creos_packs.py` : chaque image du clip est une liste de commandes de dessin
## (pièce PNG avec position/rotation/transparence, trait, anneau). L'origine (0, 0) est le point
## au sol de l'acteur ; le clip regarde vers la droite (héros) ou la gauche (ennemis), `facing`
## le retourne. Aucun effet de jeu ici : `cue` signale seulement les instants d'impact dessinés.

signal finished(clip_id: String)
signal cue(cue_name: String)

const FLASH_SHADER := """
shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, flash * COLOR.a);
}
"""

static var _clips: Dictionary = {}  # chemin -> clip (Dictionary)
static var _textures: Dictionary = {}  # chemin -> Texture2D
static var _sounds: Dictionary = {}
static var _shader: Shader

var bundle := ""  # ex. "res://assets/anim/heroes/"
var clip_id := ""
var idle_clip := ""  # rejoué en boucle après une animation qui ne boucle pas ("" = garde la dernière image)
var speed := 1.0
var show_actor := true
var show_effects := true
var sound_enabled := true
var sound_volume_db := -8.0
var facing := 1.0:
	set(v):
		facing = v
		scale.x = absf(scale.x) * signf(v)

var _clip: Dictionary = {}
var _tex: Array[Texture2D] = []
var _t := 0.0
var _frame := -1
var _cue_i := 0
var _snd_i := 0
var _running := false
var _flash := 0.0
var _mat: ShaderMaterial
var _voices: Array[AudioStreamPlayer] = []
var _rig: Rig  # squelette du personnage : remplace les pièces du clip quand il a cette animation
var _rig_anim := ""
var _pixel: PixelSheet  # héros en pixel art : ses images remplacent pièces et squelette
var _pixel_anim := ""
var _clip_hit := -1.0
var _phase := randf() * 4.0
var effect_color := Color(1.0, 0.95, 0.8)  # couleur des traînées et de l'aura (élément du héros)
var _charge_until := 0.0
## Cible de l'attaque (repère local). Les effets des clips de héros ont été dessinés pour un ennemi à
## une distance fixe (CLIP_IMPACT) : ils sont recalés sur la vraie cible, d'autant plus qu'ils sont loin
## du héros (l'aura reste sur lui, le projectile file vers l'ennemi, l'impact tombe dessus).
var target_local := Vector2.INF
const CLIP_IMPACT := Vector2(850, -190)  # aura de charge (ultime, technique secrète) jusqu'à cet instant du clip
var _freeze := 0.0  # arrêt sur image (impact) : le clip ne avance plus pendant ce temps


func _init() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	material = _mat


## Lance un clip (`<bundle>/clips/<id>.json`). Renvoie false s'il n'existe pas.
func play(id: String, then_idle := true) -> bool:
	var clip := load_clip(bundle, id)
	if clip.is_empty():
		return false
	clip_id = id
	_clip = clip
	_tex.clear()
	for name: String in clip.tex:
		_tex.append(texture(bundle + "tex/" + name))
	_t = randf() * float(clip.dur) if clip.loop else 0.0  # boucles décalées : personne ne respire en même temps
	_frame = -1
	_cue_i = 0
	_snd_i = 0
	_running = true
	var cut := id.rfind("_")
	_rig = Rig.for_actor(id.substr(0, cut)) if cut > 0 and bundle.ends_with("heroes/") else null
	_rig_anim = id.substr(cut + 1) if _rig and _rig.has_anim(id.substr(cut + 1)) else ""
	_pixel = PixelSheet.for_actor(id.substr(0, cut)) if cut > 0 and _pixel_bundle() else null
	_pixel_anim = _pixel.anim_for(id.substr(cut + 1)) if _pixel else ""
	if _pixel_anim != "":
		_rig_anim = ""
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_clip_hit = float(clip.cue[0][0]) if not clip.cue.is_empty() else -1.0
	else:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # pièces illustrées : lissées
	_charge_until = 0.0
	if _rig_anim in ["2", "3", "4", "5"] and not clip.cue.is_empty():
		_charge_until = float(clip.cue[0][0])
	if not then_idle:
		idle_clip = ""
	queue_redraw()
	return true


func has_clip(id: String) -> bool:
	return ResourceLoader.exists(bundle + "clips/" + id + ".json") or FileAccess.file_exists(bundle + "clips/" + id + ".json")


func duration(id := "") -> float:
	var c := _clip if id == "" else load_clip(bundle, id)
	return float(c.get("dur", 0.0))


## Instants des repères visuels (impacts) d'un clip, en secondes.
func cue_times(id: String) -> Array[float]:
	var out: Array[float] = []
	for c: Array in load_clip(bundle, id).get("cue", []):
		out.append(float(c[0]))
	return out


## Fige l'animation un court instant (sensation d'impact).
func freeze(seconds: float) -> void:
	_freeze = maxf(_freeze, seconds)


func is_playing() -> bool:
	return _running


## Éclair de couleur sur le personnage (coup reçu, soin).
func flash(color: Color, strength := 0.8) -> void:
	_mat.set_shader_parameter("flash_color", color)
	_flash = strength


## Héros et monstres peuvent avoir une version pixel art (`PixelSheet`).
func _pixel_bundle() -> bool:
	return bundle.ends_with("heroes/") or bundle.contains("/enemies/")


## Rectangle (local, avant retournement) occupé par l'acteur dans la première image du clip
## (ou par son squelette au repos).
func actor_rect(id := "") -> Rect2:
	var cid := clip_id if id == "" else id
	var cut := cid.rfind("_")
	if cut > 0 and _pixel_bundle() and PixelSheet.for_actor(cid.substr(0, cut)):
		var ps := PixelSheet.for_actor(cid.substr(0, cut))
		return ps.body_rect()  # taille réelle du dessin (héros et monstres)
	if cut > 0 and bundle.ends_with("heroes/"):
		var rig := Rig.for_actor(cid.substr(0, cut))
		if rig:
			return rig.rest_rect()
	var c := _clip if id == "" else load_clip(bundle, id)
	var rect := Rect2()
	var first := true
	if c.is_empty() or c.f.is_empty():
		return rect
	for cmd: Array in c.f[0]:
		if int(cmd[0]) < 0 or int(cmd[8]) != 0:
			continue
		var r := Rect2(cmd[1] - cmd[3] * 0.5, cmd[2] - cmd[4] * 0.5, cmd[3], cmd[4])
		rect = r if first else rect.merge(r)
		first = false
	return rect


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.5)
		_mat.set_shader_parameter("flash", _flash)
	if _freeze > 0.0:
		_freeze -= delta
		return
	if not _running:
		return
	_t += delta * speed
	if _rig_anim != "" or _pixel_anim != "":
		queue_redraw()  # le squelette (ou les images pixel) avance en continu, pas au rythme du clip
	var snd: Array = _clip.snd
	while _snd_i < snd.size() and _t >= float(snd[_snd_i][0]):
		_play_sound(String(snd[_snd_i][1]))
		_snd_i += 1
	var cues: Array = _clip.cue
	while _cue_i < cues.size() and _t >= float(cues[_cue_i][0]):
		cue.emit(String(cues[_cue_i][1]))
		_cue_i += 1
	var dur := float(_clip.dur)
	if _t >= dur:
		if _clip.loop:
			_t = fmod(_t, dur)
			_cue_i = 0
			_snd_i = 0
		else:
			_running = false
			var done := clip_id
			finished.emit(done)
			if clip_id == done and idle_clip != "" and idle_clip != done:
				play(idle_clip)
			return
	var f := mini(int(_t * float(_clip.fps)), _clip.f.size() - 1)
	if f != _frame:
		_frame = f
		queue_redraw()


func _draw() -> void:
	if _clip.is_empty():
		return
	var frames: Array = _clip.f
	var f := clampi(_frame, 0, frames.size() - 1)
	if _pixel_anim != "":
		if show_actor:
			var s := _pixel.scale
			var pt := _t + (_phase if _pixel_anim == "idle" else 0.0)  # respirations décalées entre héros
			var tex := _pixel.frame_at(_pixel_anim, pt, float(_clip.dur), _clip_hit)
			var dx := _pixel.lunge(_t, float(_clip.dur), _clip_hit) if _pixel_anim.begins_with("attack") or _pixel_anim == "skill" and _pixel.facing < 0.0 else 0.0
			draw_set_transform(Vector2(dx, 0) - _pixel.anchor * s, 0.0, Vector2(s, s))
			draw_texture(tex, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
		return  # les effets sont dessinés dans les images pixel
	var rigged := _rig_anim != ""
	if rigged and show_actor:
		var attacking := _rig_anim.is_valid_int()
		if attacking and _charge_until > 0.0 and _t < _charge_until:
			_draw_charge(_t / _charge_until)
		if attacking:
			_draw_afterimages()
		_rig.draw_pose(self, _rig_anim, _t)
		if attacking:
			_draw_trails()
	for cmd: Array in frames[f]:
		var layer := int(cmd[8])
		if (layer == 0 and (rigged or not show_actor)) or (layer == 1 and not show_effects):
			continue
		var kind := int(cmd[0])
		if kind >= 0:
			var tex := _tex[kind]
			if tex == null:
				continue
			var size := Vector2(cmd[3], cmd[4])
			var at := Vector2(cmd[1], cmd[2])
			if layer == 1:
				at = _retarget(at)
			draw_set_transform(at, float(cmd[5]), Vector2(-1.0 if int(cmd[7]) == 1 else 1.0, 1.0))
			draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color(1, 1, 1, float(cmd[6])))
			draw_set_transform(Vector2.ZERO)
		elif kind == -1:
			var c := Color(String(cmd[5]))
			c.a *= float(cmd[7])
			draw_line(_retarget(Vector2(cmd[1], cmd[2])), _retarget(Vector2(cmd[3], cmd[4])), c, float(cmd[6]), true)
		else:
			var c := Color(String(cmd[5]))
			c.a *= float(cmd[7])
			var pts := PackedVector2Array()
			var r := float(cmd[3])
			var ratio := float(cmd[4])
			var o := _retarget(Vector2(cmd[1], cmd[2]))
			for s in 41:
				var a := TAU * float(s) / 40.0
				pts.append(Vector2(o.x + cos(a) * r, o.y + sin(a) * r * ratio))
			draw_polyline(pts, c, float(cmd[6]), true)


func _retarget(p: Vector2) -> Vector2:
	if target_local == Vector2.INF or p.x <= 0.0:
		return p
	var w := clampf(p.x / CLIP_IMPACT.x, 0.0, 1.25)
	return p + (target_local - CLIP_IMPACT) * w


## Images rémanentes : quand le personnage se rue, deux silhouettes colorées le suivent.
func _draw_afterimages() -> void:
	var speed := _rig.root_at(_rig_anim, _t).distance_to(_rig.root_at(_rig_anim, _t - 0.05)) / 0.05
	if speed < 260.0:
		return
	var k := clampf((speed - 260.0) / 500.0, 0.0, 1.0)
	for i in [2, 1]:
		_rig.draw_pose(self, _rig_anim, _t - 0.045 * i, Color(effect_color.lightened(0.3), 0.22 * k / i))


## Traînées des armes : ruban qui suit la pointe pendant un geste rapide, couleur de l'élément.
func _draw_trails() -> void:
	const N := 9
	const STEP := 0.017
	var samples: Array[PackedVector2Array] = []
	for i in N:
		samples.append(_rig.tips(_rig_anim, _t - i * STEP))
	for w in samples[0].size():
		var length := 0.0
		for i in N - 1:
			length += samples[i][w].distance_to(samples[i + 1][w])
		if length < 70.0:
			continue
		var k := clampf((length - 70.0) / 160.0, 0.0, 1.0)
		for i in N - 1:
			var f := 1.0 - float(i) / (N - 1)
			var a: Vector2 = samples[i][w]
			var b: Vector2 = samples[i + 1][w]
			draw_line(a, b, Color(effect_color, 0.55 * f * k), 26.0 * f + 2.0, true)
			draw_line(a, b, Color(1, 1, 1, 0.85 * f * k), 8.0 * f + 1.0, true)


## Aura de charge (ultime, technique secrète) : anneau au sol qui pulse et étincelles qui montent.
func _draw_charge(progress: float) -> void:
	var c := effect_color
	var pulse := 0.5 + 0.5 * sin(_t * 18.0)
	var r := 120.0 + 30.0 * progress
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.28))
	draw_polyline(pts, Color(c, (0.35 + 0.35 * pulse) * minf(1.0, progress * 3.0)), 6.0, true)
	draw_circle(Vector2(0, -150), 150.0 * (0.6 + 0.4 * progress), Color(c, 0.07 + 0.06 * pulse))
	for i in 14:
		var seed := float(i) * 12.9898
		var x := (fposmod(sin(seed) * 437.58, 1.0) - 0.5) * 2.0 * r * 0.9
		var cycle := fposmod(_t * (0.9 + fposmod(seed, 0.6)) + fposmod(seed * 0.37, 1.0), 1.0)
		var y := -cycle * 320.0
		draw_circle(Vector2(x, y), 5.0 * (1.0 - cycle) + 1.5, Color(c.lightened(0.4), (1.0 - cycle) * 0.9 * minf(1.0, progress * 2.5)))


func _play_sound(file: String) -> void:
	if not sound_enabled:
		return
	var path := bundle + "audio/" + file
	if not _sounds.has(path):
		_sounds[path] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sounds[path]
	if stream == null:
		return
	var voice: AudioStreamPlayer = null
	for v in _voices:
		if not v.playing:
			voice = v
			break
	if voice == null:
		if _voices.size() >= 3:
			voice = _voices[0]
		else:
			voice = AudioStreamPlayer.new()
			voice.bus = "Effets" if AudioServer.get_bus_index("Effets") >= 0 else "Master"
			add_child(voice)
			_voices.append(voice)
	voice.stream = stream
	voice.volume_db = sound_volume_db
	voice.play()


# --- Cache partagé ----------------------------------------------------------------

static func load_clip(dir: String, id: String) -> Dictionary:
	var path := dir + "clips/" + id + ".json"
	if _clips.has(path):
		return _clips[path]
	var clip: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			clip = parsed
	_clips[path] = clip
	return clip


## Charge à l'avance un clip et ses images (évite un à-coup la première fois qu'il est joué).
static func warm(dir: String, id: String) -> void:
	var clip := load_clip(dir, id)
	for name: String in clip.get("tex", []):
		texture(dir + "tex/" + name)


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]
