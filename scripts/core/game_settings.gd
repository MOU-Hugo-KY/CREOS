extends Node
## Autoload « GameSettings » : réglages du joueur (volumes), enregistrés dans user://settings.cfg.
## Crée les bus audio « Musique » et « Effets » et applique les volumes au démarrage.

signal changed

const PATH := "user://settings.cfg"
const BUS_MUSIC := "Musique"
const BUS_SFX := "Effets"

# Volumes de 0 à 1. Valeurs de départ volontairement basses.
var master_volume := 0.5
var music_volume := 0.45
var sfx_volume := 0.6
var muted := false


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	load_settings()
	apply()


func set_volume(bus_name: String, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus_name:
		"Master":
			master_volume = value
		BUS_MUSIC:
			music_volume = value
		BUS_SFX:
			sfx_volume = value
	apply()
	save_settings()


func get_volume(bus_name: String) -> float:
	match bus_name:
		BUS_MUSIC:
			return music_volume
		BUS_SFX:
			return sfx_volume
	return master_volume


func set_muted(on: bool) -> void:
	muted = on
	apply()
	save_settings()


func apply() -> void:
	_set_bus("Master", master_volume)
	_set_bus(BUS_MUSIC, music_volume)
	_set_bus(BUS_SFX, sfx_volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	changed.emit()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("son", "general", master_volume)
	music_volume = cfg.get_value("son", "musique", music_volume)
	sfx_volume = cfg.get_value("son", "effets", sfx_volume)
	muted = cfg.get_value("son", "coupe", muted)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("son", "general", master_volume)
	cfg.set_value("son", "musique", music_volume)
	cfg.set_value("son", "effets", sfx_volume)
	cfg.set_value("son", "coupe", muted)
	cfg.save(PATH)


func _set_bus(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	# Courbe au carré : le curseur paraît plus régulier à l'oreille qu'une échelle linéaire.
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value * value, 0.0001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
