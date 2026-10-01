extends Node
## Autoload « GameData » : charge les fichiers JSON de `data/`.

var heroes: Dictionary = {}
var monsters: Dictionary = {}
var dungeons: Dictionary = {}
var regions: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	heroes = load_json("res://data/heroes.json")
	monsters = load_json("res://data/monsters.json")
	dungeons = load_json("res://data/dungeons.json")
	regions = load_json("res://data/regions.json")


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON invalide : %s" % path)
		return {}
	return parsed


## Données d'un héros, prêtes pour BattleEngine.setup().
func hero(id: String) -> Dictionary:
	var d: Dictionary = heroes[id].duplicate(true)
	d["id"] = id
	return d


func monster(id: String) -> Dictionary:
	var d: Dictionary = monsters[id].duplicate(true)
	d["id"] = id
	return d


## Vagues d'un donjon, prêtes pour BattleEngine.setup().
func dungeon_waves(id: String) -> Array:
	var waves: Array = []
	for wave: Array in dungeons[id]["waves"]:
		waves.append(wave.map(func(mid: String) -> Dictionary: return monster(mid)))
	return waves
