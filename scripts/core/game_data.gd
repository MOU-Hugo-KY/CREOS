extends Node
## Autoload « GameData » : charge les fichiers JSON de `data/`.

var heroes: Dictionary = {}
var monsters: Dictionary = {}
var dungeons: Dictionary = {}
var regions: Dictionary = {}
var hub: Dictionary = {}
var player_start: Dictionary = {}
var progression: Dictionary = {}
var summon: Dictionary = {}
var quests: Dictionary = {}
var relics: Dictionary = {}  # reliques, quatuors et Échos (data/relics.json)
var combos_data: Dictionary = {}  # duos, trios et synergies (data/combos.json)
var lodge: Dictionary = {}  # Ma Loge : salles, pièges, mises (data/lodge.json)


func _ready() -> void:
	reload()


func reload() -> void:
	heroes = load_json("res://data/heroes.json")
	monsters = load_json("res://data/monsters.json")
	dungeons = load_json("res://data/dungeons.json")
	regions = load_json("res://data/regions.json")
	hub = load_json("res://data/hub.json")
	player_start = load_json("res://data/player_start.json")
	progression = load_json("res://data/progression.json")
	summon = load_json("res://data/summon.json")
	quests = load_json("res://data/quests.json")
	relics = load_json("res://data/relics.json")
	combos_data = load_json("res://data/combos.json")
	lodge = load_json("res://data/lodge.json")


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


func dungeon(id: String) -> Dictionary:
	return dungeons.get(id, {})


## Butin d'un donjon selon les étoiles obtenues (rien en cas de défaite).
func dungeon_rewards(id: String, stars: int) -> Dictionary:
	if stars <= 0:
		return {}
	return dungeon(id).get("rewards", {}).duplicate()


func quartets() -> Dictionary:
	return relics.get("quartets", {})


## Tous les combos d'équipe : quatuors, trios et duos.
func team_combos() -> Dictionary:
	var out: Dictionary = quartets().duplicate()
	out.merge(combos_data.get("combos", {}))
	return out


func synergies() -> Dictionary:
	return combos_data.get("synergies", {})


## Vagues d'un donjon pour une équipe de `team_size` héros : au-delà de 4, chaque vague reçoit des
## ennemis en plus (copies des siens, jusqu'à 8) et le boss plus de points de vie.
func dungeon_waves_for(id: String, team_size: int) -> Array:
	var waves := dungeon_waves(id)
	if team_size <= 4:
		return waves
	var factor := team_size / 4.0
	var out: Array = []
	for wave: Array in waves:
		var grown: Array = []
		var minions: Array = []
		for m: Dictionary in wave:
			if m.get("boss", false):
				var boss := m.duplicate(true)
				if boss.has("stats"):
					boss.stats["hp"] = float(boss.stats.get("hp", 100)) * factor
				grown.append(boss)
			else:
				grown.append(m)
				minions.append(m)
		var want := mini(PlayerData.TEAM_SIZE, roundi(minions.size() * factor))
		var i := 0
		while minions.size() > 0 and grown.size() - (wave.size() - minions.size()) < want:
			grown.append(minions[i % minions.size()])
			i += 1
		out.append(grown)
	return out


## Niveaux (donjons) d'un monde, dans l'ordre.
func region_dungeons(region_id: String) -> Array:
	var out: Array = []
	for id: String in dungeons:
		if dungeons[id].get("region", "") == region_id:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return int(dungeons[a].get("level", 0)) < int(dungeons[b].get("level", 0)))
	return out


## Mondes de la campagne, dans l'ordre.
func region_ids() -> Array:
	var ids: Array = regions.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(regions[a].get("order", 0)) < int(regions[b].get("order", 0)))
	return ids
