class_name BattleAudio
extends Node
## Sons et musique du combat. Les fichiers sont dans `assets/audio/` (packs CC0, voir CREDITS.md).
## Un son = un nom court ; s'il existe plusieurs variantes (`hit_1`, `hit_2`…), une est tirée au hasard.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 12
const MUSIC_DB := -14.0
const MUSIC_FADE_IN := 2.5  # la musique monte doucement au lieu d'arriver d'un coup
# Correction de volume par son (dB), mesurée pour que tous aient à peu près le même niveau.
const SFX_GAIN := {
	"magic_cast": -12.0, "magic_shot": -12.0, "shield": -8.0, "ui_toggle": -8.0, "ui_click": -6.0,
	"ui_ready": -3.0, "heal": -5.0, "ultimate_impact": -6.0, "death": -4.0, "wave_start": -6.0,
	"hit": 0.0, "hit_heavy": -3.0, "swing": -2.0, "throw": 12.0,
}

var _sfx: Dictionary = {}  # nom -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	_load_sfx()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Effets"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musique"
	_music.volume_db = MUSIC_DB
	add_child(_music)


## Joue un bruitage. `pitch_jitter` varie un peu la hauteur pour éviter la répétition.
func play(sfx_name: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	var list: Array = _sfx.get(sfx_name, [])
	if list.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db + float(SFX_GAIN.get(sfx_name, 0.0))
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Lance une musique en boucle (fondu enchaîné si une autre jouait déjà).
func play_music(music_name: String, loop := true) -> void:
	if music_name == _music_name and _music.playing:
		return
	var path := MUSIC_DIR + music_name + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_music_name = music_name
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, 0.6)
	tw.tween_callback(func() -> void:
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", MUSIC_DB if loop else MUSIC_DB + 4.0, MUSIC_FADE_IN if loop else 0.3)


func stop_music(fade := 0.5) -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func _load_sfx() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		# Après export, les fichiers apparaissent en `.ogg.import` / `.ogg.remap`.
		file = file.trim_suffix(".import").trim_suffix(".remap")
		if not file.ends_with(".ogg"):
			continue
		var base := file.get_basename()
		var key := base
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			key = parts[0]
		if not _sfx.has(key):
			_sfx[key] = []
		var stream: AudioStream = load(SFX_DIR + file)
		if stream and stream not in _sfx[key]:
			_sfx[key].append(stream)
