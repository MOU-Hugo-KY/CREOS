extends Node
## Autoload « PlayerData » : la sauvegarde du joueur (user://save.json).
## Or, gemmes, énergie, niveau de la loge, héros possédés (niveau, XP), équipe de chasse,
## butin (essences…) et meilleures étoiles par donjon. Les règles sont dans `Progression`.

signal changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const TEAM_SIZE := 7  # formation : 2 devant, 3 au milieu, 2 à l'arrière

var state: Dictionary = {}
var current_dungeon := ""
## Combat de Loge en cours (non enregistré) : {kind: "own"/"rival", name, rooms, traps, stake, fee, levels}
var current_lodge_battle: Dictionary = {}
var persist := true  # false = rien n'est écrit sur le disque (tests, captures)

var _start: Dictionary = {}
var _config: Dictionary = {}
var _dungeons: Dictionary = {}
var quests_config: Dictionary = {}  # data/quests.json
var known_heroes: Array = []  # héros existant dans le jeu (les anciens sont retirés de la sauvegarde)
var debug_day := ""  # tests : impose la date du jour ("" = la vraie date)


const RELIC_UNLOCK_DUNGEON := "monde10_8"

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
		state.team = state.team.slice(0, TEAM_SIZE)  # anciennes équipes de 8
	# Nouveaux héros ajoutés au jeu depuis la dernière sauvegarde.
	for id: String in _start.get("heroes", {}):
		if not state.heroes.has(id):
			state.heroes[id] = _start.heroes[id].duplicate()
	# Équipe incomplète (héros retirés du jeu) : on la complète avec les héros possédés.
	for id: String in state.heroes:
		if state.team.size() >= TEAM_SIZE:
			break
		if id not in state.team:
			state.team.append(id)
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
	var n := String(state.get("lodge", "Mon donjon"))
	return "Donjon de " + n.trim_prefix("Loge de ") if n.begins_with("Loge de ") else n


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


## Échos d'un héros : un par doublon obtenu à la Lanterne (jamais d'autre source).
func hero_echoes(id: String) -> int:
	return int(state.get("heroes", {}).get(id, {}).get("echoes", 0))


## Palier d'Échos (0 à 5 : seuils 1, 3, 6, 9, 12).
func hero_echo_tier(id: String) -> int:
	return Progression.echo_tier(hero_echoes(id), _config)


## Voie d'Héritage active (0, 1 ou 2), changeable gratuitement hors combat.
func hero_path(id: String) -> int:
	return int(state.get("heroes", {}).get(id, {}).get("path", 0))


func set_hero_path(id: String, path: int) -> void:
	if state.heroes.has(id) and path >= 0 and path <= 2:
		state.heroes[id].path = path
		save_game()
		changed.emit()


## Stats d'un héros possédé (niveau, Échos, relique).
func hero_stats(id: String, hero: Dictionary) -> Dictionary:
	return Progression.hero_stats(hero, hero_level(id), hero_echoes(id), _config, relic_tier(id))


## Données d'un héros prêtes pour le combat : stats à son niveau, avec ses Échos et sa relique.
func hero_for_battle(id: String) -> Dictionary:
	var gd: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	return Progression.hero_for_battle(gd.hero(id), hero_level(id), _config, hero_echoes(id), relic_tier(id),
		hero_path(id))


# --- Reliques ----------------------------------------------------------------------

## Palier de la relique d'un héros (0 = pas encore retrouvée, 5 = Héritage).
func relic_tier(id: String) -> int:
	return int(state.get("relics", {}).get(id, 0))


func relic_fragments(id: String) -> int:
	return item_count("relique_" + id)


## Coût du palier suivant : {fragments, materials, name} ({} au maximum).
func relic_next_cost(id: String) -> Dictionary:
	return Progression.relic_cost(relic_tier(id), _config)


## Les reliques s'ouvrent après la Campagne 1 (dernier niveau du monde 10 gagné).
func relics_unlocked() -> bool:
	return best_stars(RELIC_UNLOCK_DUNGEON) > 0


## Butin de la Campagne 1 : jamais de fragments ni de matériaux de relique (ils tombent seulement
## dans la Campagne 2, « Héroïque », niveaux « mondeNN_hN »). Finir la Campagne 1 ouvre les reliques,
## pas leur butin.
func filter_locked_loot(rewards: Dictionary, dungeon_id := "") -> Dictionary:
	if dungeon_id.contains("_h"):
		return rewards
	var out := {}
	for key: String in rewards:
		if not key.begins_with("relique_") and key != "materiaux_relique":
			out[key] = rewards[key]
	return out


func can_upgrade_relic(id: String) -> bool:
	var c := relic_next_cost(id)
	return relics_unlocked() and state.heroes.has(id) and not c.is_empty() and relic_fragments(id) >= int(c.fragments) \
		and item_count("materiaux_relique") >= int(c.materials)


## Retrouve ou améliore la relique d'un héros possédé contre ses fragments et des matériaux.
func upgrade_relic(id: String) -> bool:
	if not can_upgrade_relic(id):
		return false
	var c := relic_next_cost(id)
	state.items["relique_" + id] = relic_fragments(id) - int(c.fragments)
	state.items["materiaux_relique"] = item_count("materiaux_relique") - int(c.materials)
	if not state.has("relics"):
		state.relics = {}
	state.relics[id] = relic_tier(id) + 1
	save_game()
	changed.emit()
	return true


func hero_level_up_cost(id: String) -> int:
	return Progression.level_up_cost(hero_level(id), _config)


## Dernier palier d'éveil franchi (0, 10, 20…). Les héros d'avant les éveils gardent leurs niveaux.
func hero_awakened(id: String) -> int:
	var h: Dictionary = state.get("heroes", {}).get(id, {})
	if not h.has("awakened"):
		return int(h.get("level", 1)) / 10 * 10
	return int(h.awakened)


## Niveau que le héros ne peut pas dépasser avant son prochain éveil.
func hero_level_cap(id: String) -> int:
	return Progression.level_cap(hero_awakened(id), _config)


## Le héros attend un éveil : il est au palier (10, 20…) et n'a pas encore nourri ses Esprits.
func hero_needs_awakening(id: String) -> bool:
	var lv := hero_level(id)
	return state.heroes.has(id) and lv == hero_level_cap(id) and lv < int(_config.get("max_level", 150))


## Esprits demandés par le prochain éveil du héros : {objet: nombre}.
func awaken_cost(id: String, hero: Dictionary) -> Dictionary:
	return Progression.awaken_cost(hero_level_cap(id), String(hero.get("element", "")), _config)


func can_awaken(id: String, hero: Dictionary) -> bool:
	if not hero_needs_awakening(id):
		return false
	var cost := awaken_cost(id, hero)
	for item: String in cost:
		if item_count(item) < int(cost[item]):
			return false
	return true


## Éveille le héros : consomme les Esprits et ouvre les 10 niveaux suivants.
func awaken_hero(id: String, hero: Dictionary) -> bool:
	if not can_awaken(id, hero):
		return false
	var cost := awaken_cost(id, hero)
	for item: String in cost:
		state.items[item] = item_count(item) - int(cost[item])
	state.heroes[id]["awakened"] = hero_level_cap(id)
	record_event("hero_awakened")
	save_game()
	changed.emit()
	return true


## Fusion chez le Marchand : 5 Esprits d'un stade donnent 1 Esprit du stade suivant (même élément).
const FUSION_COUNT := 5
const FUSION_GOLD := 100


func fuse_esprit(item: String) -> bool:
	var parts := item.split("_")
	if parts.size() < 3 or parts[0] != "esprit":
		return false
	var stage := Progression.ESPRIT_STAGES.find(parts[1])
	if stage < 0 or stage >= Progression.ESPRIT_STAGES.size() - 1:
		return false
	if item_count(item) < FUSION_COUNT or gold() < FUSION_GOLD:
		return false
	state.items[item] = item_count(item) - FUSION_COUNT
	var up := Progression.esprit_id(Progression.ESPRIT_STAGES[stage + 1], parts[2])
	state.items[up] = item_count(up) + 1
	state.gold = gold() - FUSION_GOLD
	save_game()
	changed.emit()
	return true


## Fait monter un héros d'un niveau contre de l'or (pas au-delà de son palier d'éveil).
func level_up_hero(id: String) -> bool:
	if not state.heroes.has(id) or hero_level(id) >= hero_level_cap(id):
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


## Prix d'une invocation avec `currency` ("fragments_relique" ou "gems").
func summon_cost(currency: String, config: Dictionary) -> int:
	return int(config.get("currencies", {}).get(currency, {}).get("cost", 0))


func summon_balance(currency: String) -> int:
	return gems() if currency == "gems" else item_count(currency)


func can_summon(currency: String, config: Dictionary) -> bool:
	var cost := summon_cost(currency, config)
	return cost > 0 and summon_balance(currency) >= cost


## Prix d'un paquet de `count` invocations (data/summon.json "packs" : le ×10 en offre une).
func summon_pack_cost(currency: String, config: Dictionary, count: int) -> int:
	var pay := count
	for p: Dictionary in config.get("packs", []):
		if int(p.get("count", 0)) == count:
			pay = int(p.get("pay", count))
	return summon_cost(currency, config) * pay


func can_summon_pack(currency: String, config: Dictionary, count: int) -> bool:
	var cost := summon_pack_cost(currency, config, count)
	return cost > 0 and summon_balance(currency) >= cost


## `count` invocations d'un coup (la garantie compte chacune) ; le rabais du paquet est rendu
## à la fin. Renvoie la liste des résultats de `summon()`, vide si le joueur n'a pas de quoi payer.
func summon_pack(currency: String, config: Dictionary, pool: Dictionary, rng: RandomNumberGenerator,
		count: int) -> Array:
	if not can_summon_pack(currency, config, count):
		return []
	var refund := summon_cost(currency, config) * count - summon_pack_cost(currency, config, count)
	var out: Array = []
	for i in count:
		var r := summon(currency, config, pool, rng)
		if r.is_empty():
			break
		out.append(r)
	if refund > 0:
		if currency == "gems":
			state.gems = gems() + refund
		else:
			state.items[currency] = item_count(currency) + refund
		save_game()
	return out


## Invoque un héros de `pool` (heroes.json). Renvoie {id, rarity, new, echoes}, ou {} si
## le joueur n'a pas de quoi payer. Un héros déjà possédé revient en Écho (+1 Écho).
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
	var result := {"id": r.id, "rarity": r.rarity, "new": not state.heroes.has(r.id), "echoes": 0, "traps": []}
	# Chaque invocation donne aussi des pièges pour Ma Loge (consommables).
	var trap_ids: Array = _lodge_cfg().get("traps", {}).keys()
	trap_ids.sort()
	for _i in int(config.get("trap_bonus", {}).get("count", 0)):
		if not trap_ids.is_empty():
			var t: String = trap_ids[rng.randi_range(0, trap_ids.size() - 1)]
			_add_trap_item(t, 1)
			result.traps.append(t)
	if result.new:
		state.heroes[r.id] = {"level": 1, "xp": 0}
	else:
		state.heroes[r.id].echoes = hero_echoes(r.id) + 1
		result.echoes = hero_echoes(r.id)
	save_game()
	changed.emit()
	return result


## Invocations restantes avant le Légendaire garanti.
func summons_to_pity(config: Dictionary) -> int:
	return int(config.get("pity_every", 10)) - int(state.get("summon_pity", 0))


## Niveaux de la campagne dans l'ordre (monde puis niveau).
func campaign_order() -> Array:
	var ids: Array = _dungeons.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: Dictionary = _dungeons[a]
		var db: Dictionary = _dungeons[b]
		if da.get("region", "") != db.get("region", ""):
			return String(da.get("region", "")) < String(db.get("region", ""))
		return int(da.get("level", 0)) < int(db.get("level", 0)))
	return ids


## Un niveau est ouvert si c'est le premier, ou si le niveau d'avant a été gagné.
func dungeon_unlocked(dungeon_id: String) -> bool:
	var order := campaign_order()
	var i := order.find(dungeon_id)
	return i == 0 or (i > 0 and best_stars(order[i - 1]) > 0)


## Dernier niveau ouvert de la campagne (là où le joueur en est).
func current_campaign_level() -> String:
	var order := campaign_order()
	var last := String(order[0]) if not order.is_empty() else ""
	for id: String in order:
		if not dungeon_unlocked(id):
			break
		last = id
	return last


# --- Marchand ----------------------------------------------------------------------

## Achète une offre du Marchand ({cost: {...}, gives: {...}}). Faux si pas de quoi payer.
func buy(offer: Dictionary) -> bool:
	var cost: Dictionary = offer.get("cost", {})
	for key: String in cost:
		if _balance(key) < int(cost[key]):
			return false
	for key: String in cost:
		_spend(key, int(cost[key]))
	_grant(offer.get("gives", {}))
	return true


## Vend `amount` matériaux de chasse au Marchand contre de l'or.
func sell(item: String, amount: int, price: int) -> bool:
	if amount <= 0 or item_count(item) < amount:
		return false
	state.items[item] = item_count(item) - amount
	_grant({"gold": amount * price})
	return true


func _balance(key: String) -> int:
	match key:
		"gold":
			return gold()
		"gems":
			return gems()
		"energy":
			return energy()
	return item_count(key)


func _spend(key: String, n: int) -> void:
	match key:
		"gold":
			state.gold = gold() - n
		"gems":
			state.gems = gems() - n
		"energy":
			state.energy = energy() - n
		_:
			state.items[key] = item_count(key) - n


func hunt_cost(dungeon_id: String) -> int:
	return int(_dungeons.get(dungeon_id, {}).get("energy_cost", 0))


# --- Équipe ------------------------------------------------------------------------

## Ajoute ou retire un héros de l'équipe (4 au plus, au moins 1). Renvoie vrai si ça a changé.
## Avance (dir = -1) ou recule (dir = +1) un héros d'une place dans la formation (sa place décide
## de sa ligne : 0-1 devant, 2-4 milieu, 5-6 arrière).
func move_in_team(id: String, dir: int) -> bool:
	var t: Array = team()
	var i := t.find(id)
	var j := i + dir
	if i < 0 or j < 0 or j >= t.size():
		return false
	t[i] = t[j]
	t[j] = id
	state["team"] = t
	save_game()
	changed.emit()
	return true


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
	var split := Progression.split_rewards(filter_locked_loot(rewards, dungeon_id), _config)
	var max_level: int = _config.get("player_max_level", 60)
	for id: String in team_ids:
		if not state.heroes.has(id):
			continue
		var h: Dictionary = state.heroes[id]
		var r := Progression.add_xp(int(h.level), int(h.xp), split.hero_xp, _config.get("hero_xp", {}), hero_level_cap(id))
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
	# Coffre de fin de niveau (campagne) : bois, fer, or ou Serment selon les étoiles et la chance.
	if dungeon_id.begins_with("monde"):
		result["chest"] = _open_campaign_chest(dungeon_id, stars)
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


## Tire et donne le coffre d'une victoire de campagne. Renvoie {kind, name, rewards}.
func _open_campaign_chest(dungeon_id: String, stars: int) -> Dictionary:
	if not state.has("chests"):
		state["chests"] = {"opened": 0, "since_best": 0}
	var c: Dictionary = state.chests
	var gd: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	var region: Dictionary = gd.regions.get(dungeon_id.get_slice("_", 0), {}) if "regions" in gd else {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chest := Progression.roll_chest(stars, _config, rng, int(c.opened), int(c.since_best),
		String(region.get("element", "")), 2 if dungeon_id.contains("_h") else 1)
	c.opened = int(c.opened) + 1
	c.since_best = 0 if chest.kind == "serment" else int(c.since_best) + 1
	for key: String in chest.rewards:
		var n := int(chest.rewards[key])
		match key:
			"gold":
				state.gold = gold() + n
				_add_stat("gold_earned", n)
			"gems":
				state.gems = gems() + n
			_:
				state.items[key] = item_count(key) + n
	chest["name"] = _config.get("chests", {}).get("names", {}).get(chest.kind, chest.kind)
	return chest


# --- Ma Loge (donjon du joueur, règles dans `Lodge`) ---------------------------------

func _lodge_cfg() -> Dictionary:
	var gd: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	if gd.lodge.is_empty():
		gd.reload()  # autoload pas encore prêt (tests)
	return gd.lodge


## Donjon de la Loge (créé vide au premier appel ; "lodge" est le nom de la loge) : {rooms, traps, stake, rivals_day, rivals_done}.
func lodge() -> Dictionary:
	var cfg := _lodge_cfg()
	var d: Variant = state.get("lodge_dungeon")
	if not d is Dictionary or d.get("rooms", []).size() != cfg.get("rooms", []).size():
		state["lodge_dungeon"] = Lodge.empty_state(cfg)
	elif not d.has("defenses"):
		d["defenses"] = Lodge.empty_state(cfg).defenses
	return state.lodge_dungeon


## Pièges possédés (consommables gagnés à la Lanterne) : objets "piege_<id>".
func trap_count(trap_id: String) -> int:
	return item_count(String(_lodge_cfg().get("trap_item_prefix", "piege_")) + trap_id)


func _add_trap_item(trap_id: String, n: int) -> void:
	var key := String(_lodge_cfg().get("trap_item_prefix", "piege_")) + trap_id
	state.items[key] = item_count(key) + n


## Pièces nécessaires pour construire une défense (lodge.json "pieces").
func defense_recipe(defense_id: String) -> Dictionary:
	return _lodge_cfg().get("defenses", {}).get(defense_id, {}).get("pieces", {})


func can_build_defense(defense_id: String) -> bool:
	var recipe := defense_recipe(defense_id)
	for item: String in recipe:
		if item_count(item) < int(recipe[item]):
			return false
	return true


## Construit une défense avec des pièces du Mécanicien ; la retirer rend ses pièces.
func lodge_add_defense(room: int, defense_id: String) -> bool:
	if not can_build_defense(defense_id) or not Lodge.add_defense(lodge(), _lodge_cfg(), room, defense_id):
		return false
	var recipe := defense_recipe(defense_id)
	for item: String in recipe:
		state.items[item] = item_count(item) - int(recipe[item])
	_lodge_saved()
	return true


func lodge_remove_defense(room: int, index: int) -> void:
	var removed := Lodge.remove_defense(lodge(), room, index)
	if removed != "":
		var recipe := defense_recipe(removed)
		for item: String in recipe:
			state.items[item] = item_count(item) + int(recipe[item])
		_lodge_saved()


## Atelier du Mécanicien : `count` tirages payés en or (le paquet ×10 en offre un, comme les
## héros). Chaque tirage donne `pieces_per_pull` pièces au hasard selon leur poids.
## Renvoie {item: quantité}, vide si le joueur n'a pas assez d'or.
func mechanic_cost(config: Dictionary, count: int) -> int:
	var m: Dictionary = config.get("mechanic", {})
	var pay := count
	for p: Dictionary in config.get("packs", []):
		if int(p.get("count", 0)) == count:
			pay = int(p.get("pay", count))
	return int(m.get("cost", 0)) * pay


## Sanctuaire du Druide : `count` appels payés en Éclats de serment (le ×10 en offre un). Chaque
## appel donne `esprits_per_pull` Esprits d'un élément au hasard ; les Grands et Célestes ne sortent
## qu'une fois la Campagne 1 finie. Renvoie {esprit: quantité}, vide si pas assez d'éclats.
func druid_cost(config: Dictionary, count: int) -> int:
	var dr: Dictionary = config.get("druid", {})
	var pay := count
	for p: Dictionary in config.get("packs", []):
		if int(p.get("count", 0)) == count:
			pay = int(p.get("pay", count))
	return int(dr.get("cost", 0)) * pay


func druid_pull(config: Dictionary, count: int, rng: RandomNumberGenerator) -> Dictionary:
	var dr: Dictionary = config.get("druid", {})
	var currency := String(dr.get("currency", "fragments_relique"))
	var cost := druid_cost(config, count)
	if cost <= 0 or item_count(currency) < cost:
		return {}
	state.items[currency] = item_count(currency) - cost
	var weights: Dictionary = dr.get("stages_after_campaign1" if relics_unlocked() else "stages", {})
	var total := 0
	for st: String in Progression.ESPRIT_STAGES:
		total += int(weights.get(st, 0))
	var out := {}
	for i in count * int(dr.get("esprits_per_pull", 1)):
		var pick := rng.randi_range(1, maxi(1, total))
		var stage := "oeuf"
		for st: String in Progression.ESPRIT_STAGES:
			pick -= int(weights.get(st, 0))
			if pick <= 0:
				stage = st
				break
		var elem: String = Progression.ELEMENTS[rng.randi_range(0, Progression.ELEMENTS.size() - 1)]
		var id := Progression.esprit_id(stage, elem)
		out[id] = int(out.get(id, 0)) + 1
	for id: String in out:
		state.items[id] = item_count(id) + int(out[id])
	save_game()
	changed.emit()
	return out


func mechanic_pull(config: Dictionary, count: int, rng: RandomNumberGenerator) -> Dictionary:
	var m: Dictionary = config.get("mechanic", {})
	var cost := mechanic_cost(config, count)
	if cost <= 0 or gold() < cost:
		return {}
	state.gold = gold() - cost
	var pieces: Dictionary = m.get("pieces", {})
	var ids: Array = pieces.keys()
	ids.sort()
	var total := 0
	for id: String in ids:
		total += int(pieces[id].get("weight", 1))
	var out := {}
	for i in count * int(m.get("pieces_per_pull", 1)):
		var pick := rng.randi_range(1, maxi(1, total))
		for id: String in ids:
			pick -= int(pieces[id].get("weight", 1))
			if pick <= 0:
				out[id] = int(out.get(id, 0)) + 1
				break
	for id: String in out:
		state.items[id] = item_count(id) + int(out[id])
	save_game()
	changed.emit()
	return out


func lodge_add_defender(room: int, id: String) -> bool:
	if not state.heroes.has(id) or not Lodge.add_defender(lodge(), _lodge_cfg(), room, id):
		return false
	_lodge_saved()
	return true


func lodge_remove_defender(room: int, id: String) -> void:
	Lodge.remove_defender(lodge(), room, id)
	_lodge_saved()


## Poser un piège en consomme un de la réserve (il reste armé dans la salle) ; le retirer le rend.
func lodge_toggle_trap(room: int, trap_id: String) -> bool:
	var placing: bool = room >= 0 and room < lodge().traps.size() and trap_id not in lodge().traps[room]
	if placing and trap_count(trap_id) <= 0:
		return false
	if not Lodge.toggle_trap(lodge(), _lodge_cfg(), room, trap_id):
		return false
	_add_trap_item(trap_id, -1 if placing else 1)
	_lodge_saved()
	return true


## Change la récompense mise en jeu : l'or passe du coffre du joueur à la Loge (ou revient).
func lodge_set_stake(amount: int) -> bool:
	var cfg := _lodge_cfg()
	amount = clampi(amount, 0, int(cfg.get("stake_max", 20000)))
	var diff := amount - int(lodge().stake)
	if diff > gold():
		return false
	state.gold = gold() - diff
	lodge().stake = amount
	_lodge_saved()
	return true


func _lodge_saved() -> void:
	save_game()
	changed.emit()


## Force d'un héros possédé, et Force de l'équipe de chasse.
func hero_power(id: String) -> int:
	var gd: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	return Progression.power(hero_stats(id, gd.hero(id)))


## Force moyenne par héros de l'équipe de chasse (comparée à celle d'un donjon de Loge).
func team_power() -> int:
	return Lodge.average_power(team(), hero_power)


func lodge_power() -> int:
	return Lodge.power(lodge().rooms, hero_power)


## Donjons de chasseurs rivaux du jour (attaquables une fois chacun par jour).
func lodge_rivals() -> Array:
	var gd: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	var power_at := func(id: String, level: int) -> int:
		return Progression.power(Progression.hero_stats(gd.hero(id), level, 0, _config))
	return Lodge.rivals(today(), team_power(), gd.heroes.keys(), _lodge_cfg(), power_at)


func lodge_rival_done(rival_id: String) -> bool:
	var l := lodge()
	if l.get("rivals_day", "") != today():
		l.rivals_day = today()
		l.rivals_done = []
	return rival_id in l.rivals_done


## Prépare un combat de Loge. `rival` vide = tester son propre donjon (gratuit, sans gain).
## Pour un rival : il faut une équipe pas plus forte que son donjon et payer la mise d'entrée.
func start_lodge_battle(rival: Dictionary = {}) -> String:
	var cfg := _lodge_cfg()
	if team().is_empty():
		return "Ton équipe de chasse est vide."
	if rival.is_empty():
		if not Lodge.is_ready(lodge()):
			return "Place au moins un défenseur dans chaque salle."
		current_lodge_battle = {"kind": "own", "name": lodge_name(), "rooms": lodge().rooms.duplicate(true),
			"traps": lodge().traps.duplicate(true), "defenses": lodge().defenses.duplicate(true), "stake": 0, "fee": 0,
			"level": 0}
		return ""
	if lodge_rival_done(rival.id):
		return "Tu as déjà attaqué ce donjon aujourd'hui."
	if not Lodge.can_attack(team_power(), int(rival.power)):
		return "Ton équipe est trop forte pour ce donjon (Force %d > %d)." % [team_power(), int(rival.power)]
	var fee := Lodge.entry_fee(int(rival.stake), cfg)
	if gold() < fee:
		return "Il faut %d or de mise pour entrer." % fee
	state.gold = gold() - fee
	lodge().rivals_done.append(rival.id)
	save_game()
	changed.emit()
	current_lodge_battle = {"kind": "rival", "id": rival.id, "name": rival.name, "rooms": rival.rooms,
		"traps": rival.traps, "defenses": rival.get("defenses", []), "stake": int(rival.stake), "fee": fee,
		"level": int(rival.level)}
	return ""


## Fin d'un combat de Loge : l'attaquant victorieux d'un rival gagne une part de sa récompense.
## Égalité (combat arrêté) : rien n'est gagné, l'énergie de la chasse est rendue, la mise d'un
## combat de Loge aussi.
func refund_draw(dungeon_id: String, lodge_battle: Dictionary) -> void:
	if lodge_battle.is_empty():
		state["energy"] = energy() + hunt_cost(dungeon_id)
	else:
		state.gold = gold() + int(current_lodge_battle.get("fee", 0))
	save_game()
	changed.emit()


func finish_lodge_battle(won: bool) -> Dictionary:
	var b := current_lodge_battle
	var result := {"gold": 0}
	if won and b.get("kind", "") == "rival":
		result.gold = Lodge.win_reward(int(b.stake), _lodge_cfg()) + int(b.fee)
		state.gold = gold() + result.gold
		_add_stat("gold_earned", result.gold)
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
