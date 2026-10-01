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
var quests_config: Dictionary = {}  # data/quests.json
var known_heroes: Array = []  # héros existant dans le jeu (les anciens sont retirés de la sauvegarde)
var debug_day := ""  # tests : impose la date du jour ("" = la vraie date)


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
	quests_config = gd.quests
	known_heroes = gd.heroes.keys()


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
	# Héros retirés du jeu (changement de direction artistique) : on les enlève de la sauvegarde.
	if not known_heroes.is_empty():
		for id: String in state.heroes.keys():
			if id not in known_heroes:
				state.heroes.erase(id)
		state.team = state.get("team", []).filter(func(id: String) -> bool: return id in known_heroes)
	# Nouveaux héros ajoutés au jeu depuis la dernière sauvegarde.
	for id: String in _start.get("heroes", {}):
		if not state.heroes.has(id):
			state.heroes[id] = _start.heroes[id].duplicate()
	if state.team.is_empty():
		state.team = _start.get("team", []).duplicate()
	update_energy()


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state, "  "))


# --- Profil et statistiques ------------------------------------------------------

func player_name() -> String:
	return String(state.get("name", "Chasseur"))


func lodge_name() -> String:
	return String(state.get("lodge", "Ma loge"))


## Renomme le joueur et sa loge (textes nettoyés, 3 à 16 caractères).
func rename(new_name: String, new_lodge: String) -> bool:
	var n := new_name.strip_edges()
	var l := new_lodge.strip_edges()
	if n.length() < 3 or n.length() > 16 or l.length() < 3 or l.length() > 24:
		return false
	state.name = n
	state.lodge = l
	save_game()
	changed.emit()
	return true


## Héros affiché sur le profil (par défaut, le premier de l'équipe).
func avatar() -> String:
	var a := String(state.get("avatar", ""))
	if state.get("heroes", {}).has(a):
		return a
	var t := team()
	return t[0] if not t.is_empty() else ""


func set_avatar(id: String) -> void:
	if state.heroes.has(id):
		state.avatar = id
		save_game()
		changed.emit()


func stat(key: String) -> int:
	return int(state.get("stats", {}).get(key, 0))


func _add_stat(key: String, amount := 1) -> void:
	if not state.has("stats"):
		state.stats = {}
	state.stats[key] = stat(key) + amount


func total_stars() -> int:
	var n := 0
	for id: String in state.get("dungeons", {}):
		n += best_stars(id)
	return n


# --- Primes du jour --------------------------------------------------------------

func today() -> String:
	return debug_day if debug_day != "" else Time.get_date_string_from_system()


## Le suivi des primes du jour (remis à zéro chaque jour ; compte la connexion).
func daily() -> Dictionary:
	var before := String(state.get("daily", {}).get("day", ""))
	state.daily = Quests.refresh(state.get("daily", {}), today())
	if before != today():
		Quests.record(state.daily, "login")
		_add_stat("days_played")
		save_game()
	return state.daily


## Note un événement de jeu pour les primes (« hunt_win », « ultimate », « summon »…).
func record_event(event: String, amount := 1) -> void:
	Quests.record(daily(), event, amount)


func quest(id: String) -> Dictionary:
	for q: Dictionary in quests_config.get("quests", []):
		if q.get("id") == id:
			return q
	return {}


func claimable_quests() -> int:
	return Quests.claimable_count(daily(), quests_config)


## Récupère la récompense d'une prime terminée. Renvoie les récompenses ({} si impossible).
func claim_quest(id: String) -> Dictionary:
	var q := quest(id)
	if q.is_empty() or not Quests.can_claim(daily(), q):
		return {}
	state.daily.claimed.append(id)
	return _grant(q.get("rewards", {}))


func open_chest(index: int) -> Dictionary:
	if not Quests.can_open_chest(daily(), quests_config, index):
		return {}
	state.daily.chests.append(index)
	return _grant(quests_config.chests[index].get("rewards", {}))


## Donne des récompenses : or, gemmes, énergie (peut dépasser le maximum), objets.
func _grant(rewards: Dictionary) -> Dictionary:
	for key: String in rewards:
		var n := int(rewards[key])
		match key:
			"gold":
				state.gold = gold() + n
				_add_stat("gold_earned", n)
			"gems":
				state.gems = gems() + n
			"energy":
				state.energy = energy() + n
			_:
				if not state.has("items"):
					state.items = {}
				state.items[key] = item_count(key) + n
	save_game()
	changed.emit()
	return rewards


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


func hero_stars(id: String) -> int:
	return int(state.get("heroes", {}).get(id, {}).get("stars", _config.get("stars", {}).get("start", 1)))


func hero_level_up_cost(id: String) -> int:
	return Progression.level_up_cost(hero_level(id), _config)


## Fait monter un héros d'un niveau contre de l'or (pas au-delà du niveau maximum).
func level_up_hero(id: String) -> bool:
	if not state.heroes.has(id) or hero_level(id) >= int(_config.get("max_level", 30)):
		return false
	var cost := hero_level_up_cost(id)
	if gold() < cost:
		return false
	state.gold = gold() - cost
	state.heroes[id].level = hero_level(id) + 1
	state.heroes[id].xp = 0
	record_event("hero_level_up")
	save_game()
	changed.emit()
	return true


## Fragments du héros pour gagner une étoile (-1 = déjà au maximum).
func hero_star_cost(id: String) -> int:
	return Progression.star_cost(hero_stars(id), _config)


## Évolution : une étoile de plus contre des fragments du héros.
func evolve_hero(id: String) -> bool:
	var cost := hero_star_cost(id)
	if not state.heroes.has(id) or cost < 0 or hero_shards(id) < cost:
		return false
	state.hero_shards[id] = hero_shards(id) - cost
	state.heroes[id].stars = hero_stars(id) + 1
	save_game()
	changed.emit()
	return true


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


## Fragments d'un héros (gagnés quand on invoque un héros déjà possédé ; serviront aux étoiles).
func hero_shards(id: String) -> int:
	return int(state.get("hero_shards", {}).get(id, 0))


## Prix d'une invocation avec `currency` ("fragments_relique" ou "gems").
func summon_cost(currency: String, config: Dictionary) -> int:
	return int(config.get("currencies", {}).get(currency, {}).get("cost", 0))


func summon_balance(currency: String) -> int:
	return gems() if currency == "gems" else item_count(currency)


func can_summon(currency: String, config: Dictionary) -> bool:
	var cost := summon_cost(currency, config)
	return cost > 0 and summon_balance(currency) >= cost


## Invoque un héros de `pool` (heroes.json). Renvoie {id, rarity, new, shards}, ou {} si
## le joueur n'a pas de quoi payer. Un héros déjà possédé donne des fragments de ce héros.
func summon(currency: String, config: Dictionary, pool: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not can_summon(currency, config):
		return {}
	var count := int(state.get("summon_count", 0))
	var pity := int(state.get("summon_pity", 0))
	var r := Summon.roll(pool, config, count, pity, rng)
	if r.id == "":
		return {}
	var cost := summon_cost(currency, config)
	if currency == "gems":
		state.gems = gems() - cost
	else:
		state.items[currency] = item_count(currency) - cost
	state.summon_count = count + 1
	record_event("summon")
	state.summon_pity = 0 if r.rarity >= int(config.get("pity_min_rarity", 4)) else pity + 1
	var result := {"id": r.id, "rarity": r.rarity, "new": not state.heroes.has(r.id), "shards": 0}
	if result.new:
		state.heroes[r.id] = {"level": 1, "xp": 0}
	else:
		result.shards = int(config.get("duplicate_shards", {}).get(str(r.rarity), 10))
		if not state.has("hero_shards"):
			state.hero_shards = {}
		state.hero_shards[r.id] = hero_shards(r.id) + result.shards
	save_game()
	changed.emit()
	return result


## Invocations restantes avant le Légendaire garanti.
func summons_to_pity(config: Dictionary) -> int:
	return int(config.get("pity_every", 10)) - int(state.get("summon_pity", 0))


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
	record_event("energy_spent", hunt_cost(dungeon_id))
	_add_stat("hunts_played")
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
		if r.gained_levels > 0:
			record_event("hero_level_up", r.gained_levels)
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
			_add_stat("gold_earned", result.gold)
		else:
			state.items[key] = item_count(key) + int(split.loot[key])
	record_event("hunt_win")
	_add_stat("hunts_won")
	if stars >= 3:
		record_event("three_stars")
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
