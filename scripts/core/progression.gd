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


## Données d'un héros prêtes pour le combat, avec ses stats à son niveau.
static func hero_for_battle(hero: Dictionary, level: int, config: Dictionary) -> Dictionary:
	var d := hero.duplicate(true)
	d["level"] = level
	d["stats"] = stats_at_level(hero.get("stats", {}), level, config.get("stat_growth", {}))
	return d


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
