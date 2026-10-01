extends Node
## Autoload « PlayerData » : la sauvegarde du joueur (user://save.json).
## Or, gemmes, énergie, niveau de la loge, héros possédés (niveau, XP), équipe de chasse,
## butin (essences…) et meilleures étoiles par donjon. Les règles sont dans `Progression`.

signal changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const TEAM_SIZE := 4

var state: Dictionary = {}
var current_dungeon := ""
var persist := true  # false = rien n'est écrit sur le disque (tests, captures)

var _start: Dictionary = {}
var _config: Dictionary = {}
var _dungeons: Dictionary = {}


func _ready() -> void:
	if persist:
		_autoconfigure()
		load_game()


## Lit les données de départ dans l'autoload GameData (même s'il n'est pas encore « prêt »).
func _autoconfigure() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gd: Node = tree.root.get_node_or_null("GameData") if tree else null
	if gd == null:
		return
	if gd.player_start.is_empty():
		gd.reload()
	configure(gd.player_start, gd.progression, gd.dungeons)


func configure(start: Dictionary, config: Dictionary, dungeons: Dictionary) -> void:
	_start = start
	_config = config
	_dungeons = dungeons


## Mode test : partie neuve en mémoire, jamais enregistrée.
func use_memory_only() -> void:
	persist = false
	if _start.is_empty():
		_autoconfigure()
	reset()


func reset() -> void:
	state = _start.duplicate(true)
	state["version"] = SAVE_VERSION
	state["energy_time"] = Time.get_unix_time_from_system()
	save_game()
	changed.emit()


func load_game() -> void:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		reset()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Sauvegarde illisible : nouvelle partie.")
		reset()
		return
	state = _start.duplicate(true)
	state.merge(parsed, true)
	# Nouveaux héros ajoutés au jeu depuis la dernière sauvegarde.
	for id: String in _start.get("heroes", {}):
		if not state.heroes.has(id):
			state.heroes[id] = _start.heroes[id].duplicate()
	update_energy()


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state, "  "))


# --- Lecture ---------------------------------------------------------------------

func gold() -> int:
	return int(state.get("gold", 0))


func gems() -> int:
	return int(state.get("gems", 0))


func energy() -> int:
	update_energy()
	return int(state.get("energy", 0))


func energy_max() -> int:
	return int(state.get("energy_max", 60))


func level() -> int:
	return int(state.get("level", 1))


func xp() -> int:
	return int(state.get("xp", 0))


func xp_to_next() -> int:
	return Progression.xp_to_next(_config.get("player_xp", {}), level())


func owned_heroes() -> Array:
	return state.get("heroes", {}).keys()


func hero_level(id: String) -> int:
	return int(state.get("heroes", {}).get(id, {}).get("level", 1))


func hero_xp(id: String) -> int:
	return int(state.get("heroes", {}).get(id, {}).get("xp", 0))


func hero_xp_to_next(id: String) -> int:
	return Progression.xp_to_next(_config.get("hero_xp", {}), hero_level(id))


func team() -> Array:
	return state.get("team", []).filter(func(id: String) -> bool: return state.heroes.has(id))


func in_team(id: String) -> bool:
	return id in team()


func best_stars(dungeon_id: String) -> int:
	return int(state.get("dungeons", {}).get(dungeon_id, {}).get("stars", 0))


func item_count(item: String) -> int:
	return int(state.get("items", {}).get(item, 0))


func hunt_cost(dungeon_id: String) -> int:
	return int(_dungeons.get(dungeon_id, {}).get("energy_cost", 0))


# --- Équipe ------------------------------------------------------------------------

## Ajoute ou retire un héros de l'équipe (4 au plus, au moins 1). Renvoie vrai si ça a changé.
func toggle_team(id: String) -> bool:
	var t: Array = team()
	if id in t:
		if t.size() <= 1:
			return false
		t.erase(id)
	else:
		if t.size() >= TEAM_SIZE or not state.heroes.has(id):
			return false
		t.append(id)
	state["team"] = t
	save_game()
	changed.emit()
	return true


# --- Chasses -----------------------------------------------------------------------

func can_start_hunt(dungeon_id: String) -> bool:
	return energy() >= hunt_cost(dungeon_id) and not team().is_empty()


## Paie l'énergie et retient le donjon choisi. Faux si pas assez d'énergie.
func start_hunt(dungeon_id: String) -> bool:
	if not can_start_hunt(dungeon_id):
		return false
	var was_full := energy() >= energy_max()
	state["energy"] = energy() - hunt_cost(dungeon_id)
	if was_full:
		state["energy_time"] = Time.get_unix_time_from_system()
	current_dungeon = dungeon_id
	save_game()
	changed.emit()
	return true


## Applique le résultat d'un combat. Renvoie le détail pour l'écran de fin :
## {gold, player_xp, player_level_up, heroes: {id: {xp, level, gained_levels}}, best_stars}
func finish_hunt(dungeon_id: String, won: bool, stars: int, rewards: Dictionary, team_ids: Array) -> Dictionary:
	var result := {"gold": 0, "player_xp": 0, "player_level_up": false, "heroes": {}, "best_stars": false}
	if not won:
		save_game()
		return result
	var split := Progression.split_rewards(rewards, _config)
	var max_level: int = _config.get("max_level", 30)
	for id: String in team_ids:
		if not state.heroes.has(id):
			continue
		var h: Dictionary = state.heroes[id]
		var r := Progression.add_xp(int(h.level), int(h.xp), split.hero_xp, _config.get("hero_xp", {}), max_level)
		h.level = r.level
		h.xp = r.xp
		result.heroes[id] = {"xp": split.hero_xp, "level": r.level, "gained_levels": r.gained_levels}
	var p := Progression.add_xp(level(), xp(), split.player_xp, _config.get("player_xp", {}), max_level)
	state.level = p.level
	state.xp = p.xp
	result.player_xp = split.player_xp
	result.player_level_up = p.gained_levels > 0
	for key: String in split.loot:
		if key == "gold":
			state.gold = gold() + int(split.loot.gold)
			result.gold = int(split.loot.gold)
		else:
			state.items[key] = item_count(key) + int(split.loot[key])
	if stars > best_stars(dungeon_id):
		state.dungeons[dungeon_id] = {"stars": stars}
		result.best_stars = true
	save_game()
	changed.emit()
	return result


## Recharge l'énergie selon le temps écoulé (même jeu fermé).
func update_energy() -> void:
	if state.is_empty():
		return
	var r := Progression.regen_energy(int(state.get("energy", 0)), energy_max(),
		float(state.get("energy_time", 0.0)), Time.get_unix_time_from_system(),
		float(_config.get("energy_regen_seconds", 300)))
	if int(r.energy) != int(state.get("energy", 0)):
		state.energy = r.energy
		state.energy_time = r.last_time
		save_game()
		changed.emit()
	else:
		state.energy_time = r.last_time


## Secondes avant le prochain point d'énergie (0 si plein).
func seconds_to_next_energy() -> int:
	if energy() >= energy_max():
		return 0
	var regen := float(_config.get("energy_regen_seconds", 300))
	return int(ceil(regen - (Time.get_unix_time_from_system() - float(state.get("energy_time", 0.0)))))
