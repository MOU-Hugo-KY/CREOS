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
	_t = 0.0
	_frame = -1
	_cue_i = 0
	_snd_i = 0
	_running = true
	var cut := id.rfind("_")
	_rig = Rig.for_actor(id.substr(0, cut)) if cut > 0 and bundle.ends_with("heroes/") else null
	_rig_anim = id.substr(cut + 1) if _rig and _rig.has_anim(id.substr(cut + 1)) else ""
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


## Rectangle (local, avant retournement) occupé par l'acteur dans la première image du clip.
func actor_rect(id := "") -> Rect2:
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
		_flash = maxf(0.0, _flash - delta * 3.0)
		_mat.set_shader_parameter("flash", _flash)
	if _freeze > 0.0:
		_freeze -= delta
		return
	if not _running:
		return
	_t += delta * speed
	if _rig_anim != "":
		queue_redraw()  # le squelette bouge en continu, pas image par image
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
	var rigged := _rig_anim != ""
	if rigged and show_actor:
		_rig.draw_pose(self, _rig_anim, _t)
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
			draw_set_transform(Vector2(cmd[1], cmd[2]), float(cmd[5]), Vector2(-1.0 if int(cmd[7]) == 1 else 1.0, 1.0))
			draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color(1, 1, 1, float(cmd[6])))
			draw_set_transform(Vector2.ZERO)
		elif kind == -1:
			var c := Color(String(cmd[5]))
			c.a *= float(cmd[7])
			draw_line(Vector2(cmd[1], cmd[2]), Vector2(cmd[3], cmd[4]), c, float(cmd[6]), true)
		else:
			var c := Color(String(cmd[5]))
			c.a *= float(cmd[7])
			var pts := PackedVector2Array()
			var r := float(cmd[3])
			var ratio := float(cmd[4])
			for s in 41:
				var a := TAU * float(s) / 40.0
				pts.append(Vector2(float(cmd[1]) + cos(a) * r, float(cmd[2]) + sin(a) * r * ratio))
			draw_polyline(pts, c, float(cmd[6]), true)


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
