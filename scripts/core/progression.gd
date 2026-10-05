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


## Données d'un héros prêtes pour le combat : stats à son niveau, avec ses Échos et sa relique.
static func hero_for_battle(hero: Dictionary, level: int, config: Dictionary, echoes := 0, relic_tier := 0) -> Dictionary:
	var d := hero.duplicate(true)
	d["level"] = level
	d["echoes"] = echoes
	d["stats"] = hero_stats(hero, level, echoes, config, relic_tier)
	return d


## Correspondance des statistiques de la fiche de combat avec celles du moteur.
const SHEET_STATS := {"PV": ["hp"], "ATQ": ["atk"], "MAG": ["mag"], "DEF": ["def", "res"]}


## Stats d'un héros : base × croissance de niveau × (1 + bonus d'Échos), puis × (1 + bonus de
## relique). Les Échos renforcent surtout la statistique principale du héros, puis la secondaire ;
## la relique aussi. La vitesse et le critique ne changent pas.
static func hero_stats(hero: Dictionary, level: int, echoes: int, config: Dictionary, relic_tier := 0) -> Dictionary:
	var s := stats_at_level(hero.get("stats", {}), level, config.get("stat_growth", {}))
	var tier := echo_tier(echoes, config)
	var e: Dictionary = config.get("echoes", {})
	var relics: Array = config.get("relic_tiers", [])
	for sheet: String in SHEET_STATS:
		var rank := "other"
		if hero.get("primary", "") == sheet:
			rank = "primary"
		elif hero.get("secondary", "") == sheet:
			rank = "secondary"
		var echo_bonus := float(e.get(rank, [])[tier - 1]) if tier > 0 else 0.0
		var relic_bonus := 0.0
		if relic_tier > 0 and relic_tier <= relics.size() and rank != "other":
			relic_bonus = float(relics[relic_tier - 1].get(rank, 0.0))
		for key: String in SHEET_STATS[sheet]:
			if s.has(key):
				s[key] = round(float(s[key]) * (1.0 + echo_bonus) * (1.0 + relic_bonus))
	return s


## Palier d'Échos atteint (0 à 5) pour un nombre d'Échos (doublons du même héros).
static func echo_tier(echoes: int, config: Dictionary) -> int:
	var tier := 0
	for t in config.get("echoes", {}).get("thresholds", [1, 3, 6, 9, 12]):
		if echoes >= int(t):
			tier += 1
	return tier


## Échos à réunir pour le palier suivant (-1 si le dernier est atteint).
static func next_echo_threshold(echoes: int, config: Dictionary) -> int:
	for t in config.get("echoes", {}).get("thresholds", [1, 3, 6, 9, 12]):
		if echoes < int(t):
			return int(t)
	return -1


## Coût du palier de relique suivant : {fragments, materials, name}, ou {} au maximum.
static func relic_cost(tier: int, config: Dictionary) -> Dictionary:
	var tiers: Array = config.get("relic_tiers", [])
	if tier >= tiers.size():
		return {}
	return tiers[tier]


## Force d'un héros (un seul nombre pour comparer) à partir de ses stats.
static func power(stats: Dictionary) -> int:
	return int(round(float(stats.get("hp", 0)) / 8.0 + float(stats.get("atk", 0)) * 2.0
		+ float(stats.get("mag", 0)) * 0.5 + float(stats.get("def", 0)) + float(stats.get("res", 0)) + float(stats.get("spd", 0))
		+ float(stats.get("crit", 0)) * 300.0))


## Or pour faire monter un héros du niveau `level` au suivant.
static func level_up_cost(level: int, config: Dictionary) -> int:
	var c: Dictionary = config.get("level_up_gold", {})
	return int(c.get("base", 150)) + int(c.get("per_level", 75)) * (level - 1)


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
