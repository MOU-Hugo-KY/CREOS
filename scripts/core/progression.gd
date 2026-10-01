class_name Progression
extends RefCounted
## Règles de progression (logique pure, testable) : XP, niveaux, stats par niveau, butin.
## Les chiffres viennent de `data/progression.json`.


## XP nécessaire pour passer du niveau `level` au suivant.
static func xp_to_next(curve: Dictionary, level: int) -> int:
	return int(round(float(curve.get("base", 100)) * pow(float(curve.get("growth", 1.2)), level - 1)))


## Ajoute de l'XP. Renvoie {level, xp, gained_levels}.
static func add_xp(level: int, xp: int, gained: int, curve: Dictionary, max_level: int) -> Dictionary:
	var start := level
	xp += gained
	while level < max_level and xp >= xp_to_next(curve, level):
		xp -= xp_to_next(curve, level)
		level += 1
	if level >= max_level:
		xp = 0
	return {"level": level, "xp": xp, "gained_levels": level - start}


## Stats d'un héros à un niveau donné : base × (1 + croissance × (niveau − 1)).
static func stats_at_level(base: Dictionary, level: int, growth: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for key: String in base:
		var g: float = growth.get(key, 0.0)
		var v: float = float(base[key]) * (1.0 + g * (level - 1))
		out[key] = v if key == "crit" else round(v)
	return out


## Données d'un héros prêtes pour le combat, avec ses stats à son niveau et ses étoiles.
static func hero_for_battle(hero: Dictionary, level: int, config: Dictionary, stars := 1) -> Dictionary:
	var d := hero.duplicate(true)
	d["level"] = level
	d["stars"] = stars
	d["stats"] = hero_stats(hero, level, stars, config)
	return d


## Stats d'un héros : niveau, puis bonus des étoiles (+10 % par étoile au-delà de la première,
## sauf vitesse et critique).
static func hero_stats(hero: Dictionary, level: int, stars: int, config: Dictionary) -> Dictionary:
	var s := stats_at_level(hero.get("stats", {}), level, config.get("stat_growth", {}))
	var bonus := float(config.get("stars", {}).get("bonus_per_star", 0.1)) * maxi(0, stars - 1)
	for key in ["hp", "atk", "def", "res"]:
		if s.has(key):
			s[key] = round(float(s[key]) * (1.0 + bonus))
	return s


## Force d'un héros (un seul nombre pour comparer) à partir de ses stats.
static func power(stats: Dictionary) -> int:
	return int(round(float(stats.get("hp", 0)) / 8.0 + float(stats.get("atk", 0)) * 2.0
		+ float(stats.get("def", 0)) + float(stats.get("res", 0)) + float(stats.get("spd", 0))
		+ float(stats.get("crit", 0)) * 300.0))


## Or pour faire monter un héros du niveau `level` au suivant.
static func level_up_cost(level: int, config: Dictionary) -> int:
	var c: Dictionary = config.get("level_up_gold", {})
	return int(c.get("base", 150)) + int(c.get("per_level", 75)) * (level - 1)


## Fragments du héros pour passer de `stars` à `stars + 1` (-1 si déjà au maximum).
static func star_cost(stars: int, config: Dictionary) -> int:
	var s: Dictionary = config.get("stars", {})
	var costs: Array = s.get("shards", [])
	var i := stars - int(s.get("start", 1))
	if stars >= int(s.get("max", 6)) or i < 0 or i >= costs.size():
		return -1
	return int(costs[i])


## Partage du butin d'un combat gagné : l'XP du donjon va à chaque héros de l'équipe,
## une partie (`player_xp_share`) au joueur, et le reste du butin (or, essences…) au joueur.
static func split_rewards(rewards: Dictionary, config: Dictionary) -> Dictionary:
	var xp: int = int(rewards.get("xp", 0))
	var loot := rewards.duplicate()
	loot.erase("xp")
	return {
		"hero_xp": xp,
		"player_xp": int(round(xp * float(config.get("player_xp_share", 0.5)))),
		"loot": loot,
	}


## Énergie regagnée depuis `last_time` (secondes Unix). Renvoie {energy, last_time}.
static func regen_energy(energy: int, energy_max: int, last_time: float, now: float, regen_seconds: float) -> Dictionary:
	if energy >= energy_max or regen_seconds <= 0.0:
		return {"energy": energy, "last_time": now}
	var gained := int(floor((now - last_time) / regen_seconds))
	if gained <= 0:
		return {"energy": energy, "last_time": last_time}
	var new_energy := mini(energy_max, energy + gained)
	var new_last := now if new_energy >= energy_max else last_time + gained * regen_seconds
	return {"energy": new_energy, "last_time": new_last}
