class_name Progression
extends RefCounted
## Règles de progression (logique pure, testable) : XP, niveaux, stats par niveau, butin.
## Les chiffres viennent de `data/progression.json`.


## XP nécessaire pour passer du niveau `level` au suivant.
static func xp_to_next(curve: Dictionary, level: int) -> int:
	# Au-delà du niveau 60 (surpassement), la courbe ne s'envole plus : +5 % par niveau.
	var capped := mini(level, 60)
	var base := float(curve.get("base", 100)) * pow(float(curve.get("growth", 1.2)), capped - 1)
	return int(round(base * (1.0 + 0.05 * maxi(0, level - 60))))


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
## Au-delà du niveau 60, chaque niveau compte pour moitié (le surpassement reste un bonus, pas un mur).
static func stats_at_level(base: Dictionary, level: int, growth: Dictionary) -> Dictionary:
	var out := base.duplicate()
	if growth.has("heal") and not out.has("heal"):
		out["heal"] = 0.0
	var eff := float(level) if level <= 60 else 60.0 + (level - 60) * 0.5
	for key: String in out:
		var g: float = growth.get(key, 0.0)
		var v: float = float(out[key]) * (1.0 + g * (eff - 1.0))
		if key == "crit" or key == "heal":
			v = float(out[key]) + g * (eff - 1.0)  # critique et soins gagnent des points, pas un pourcentage
		out[key] = v if key in ["crit", "heal"] else round(v)
	return out


## Données d'un héros prêtes pour le combat : stats à son niveau, avec ses Échos et sa relique.
## Au palier 3 d'Échos (6 Échos), la technique secrète de la voie active devient une 4e attaque.
static func hero_for_battle(hero: Dictionary, level: int, config: Dictionary, echoes := 0, relic_tier := 0,
		path := 0) -> Dictionary:
	var d := hero.duplicate(true)
	d["level"] = level
	d["echoes"] = echoes
	d["stats"] = hero_stats(hero, level, echoes, config, relic_tier)
	apply_relic_mods(d.attacks, relic_mods(hero, config, relic_tier))
	apply_relic_mods(d.attacks, echo_mods(hero, config, echo_tier(echoes, config)))
	var secrets: Array = hero.get("secret_techniques", [])
	if echo_tier(echoes, config) >= 3 and path < secrets.size() and secrets[path].has("effects"):
		d.attacks.append(secrets[path].duplicate(true))
	return d


## Correspondance des statistiques de la fiche de combat avec celles du moteur.
const SHEET_STATS := {"PV": ["hp"], "ATQ": ["atk"], "MAG": ["mag"], "DEF": ["def", "res"]}


## Stats d'un héros : base × croissance de niveau × (1 + bonus d'Échos), puis × (1 + bonus de
## relique). Les Échos renforcent surtout la statistique principale du héros, puis la secondaire ;
## la relique aussi. La vitesse et le critique ne changent pas.
static func hero_stats(hero: Dictionary, level: int, echoes: int, config: Dictionary, relic_tier := 0) -> Dictionary:
	var own := personal(hero, config)
	var s := stats_at_level(hero.get("stats", {}), level, own.get("growth", config.get("stat_growth", {})))
	# Rareté : un mythique est plus fort qu'un légendaire, lui-même plus fort qu'un épique.
	var rarity := float(config.get("rarity_bonus", {}).get(str(int(hero.get("rarity", 3))), 0.0))
	for key: String in ["hp", "atk", "mag", "def", "res"]:
		if s.has(key):
			s[key] = round(float(s[key]) * (1.0 + rarity))
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
		if own.has("relic"):
			pass  # relique propre au héros : appliquée plus bas
		elif relic_tier > 0 and relic_tier <= relics.size() and rank != "other":
			relic_bonus = float(relics[relic_tier - 1].get(rank, 0.0))
		for key: String in SHEET_STATS[sheet]:
			if s.has(key):
				s[key] = round(float(s[key]) * (1.0 + echo_bonus) * (1.0 + relic_bonus))
	# Relique propre au héros : statistiques de son palier (critique en points, le reste en %).
	var own_tiers: Array = own.get("relic", [])
	if relic_tier > 0 and relic_tier <= own_tiers.size():
		var bonus: Dictionary = own_tiers[relic_tier - 1].get("stats", {})
		for key: String in bonus:
			var keys: Array = ["def", "res"] if key == "def" else [key]
			for k: String in keys:
				if not s.has(k):
					continue
				if not s.has(k) and k == "heal":
					s[k] = 0.0
				if k == "crit" or k == "heal":
					s[k] = float(s[k]) + float(bonus[key])
				else:
					s[k] = round(float(s[k]) * (1.0 + float(bonus[key])))
	return s


## Progression propre au héros (data/hero_progression.json, chargée dans config "heroes").
static func personal(hero: Dictionary, config: Dictionary) -> Dictionary:
	return config.get("heroes", {}).get(String(hero.get("id", "")), {})


## Effets de gameplay de la relique jusqu'au palier `relic_tier` : [{type, slot, text…}].
static func relic_mods(hero: Dictionary, config: Dictionary, relic_tier: int) -> Array:
	var out: Array = []
	var tiers: Array = personal(hero, config).get("relic", [])
	for i in mini(relic_tier, tiers.size()):
		out.append_array(tiers[i].get("mods", []))
	return out


## Bonus de compétences des Échos jusqu'au palier `tier` (1 à 5).
static func echo_mods(hero: Dictionary, config: Dictionary, tier: int) -> Array:
	var out: Array = []
	var tiers: Array = personal(hero, config).get("echoes", [])
	for i in mini(tier, tiers.size()):
		out.append_array(tiers[i])
	return out


## Applique les effets de relique aux attaques (copie) d'un héros prêt pour le combat.
static func apply_relic_mods(attacks: Array, mods: Array) -> void:
	for m: Dictionary in mods:
		var slot := int(m.get("slot", 0))
		if slot >= attacks.size():
			continue
		var a: Dictionary = attacks[slot]
		match String(m.get("type", "")):
			"power":
				for e: Dictionary in a.get("effects", []):
					if e.has("power"):
						e.power = float(e.power) * (1.0 + float(m.mult))
			"extra_hits":
				if not a.has("effects"):
					a["effects"] = [{"type": "damage", "power": 1.0}]
				var stat := "atk"
				for e: Dictionary in a.effects:
					if e.get("type") == "damage":
						stat = String(e.get("stat", stat))
				var times: Array = a.get("hit_times", [float(a.get("hit_time", 0.35))])
				var last := float(times[-1]) if not times.is_empty() else 0.35
				for i in int(m.count):
					a.effects.append({"type": "damage", "power": float(m.power), "stat": stat})
					last += 0.12
					times.append(last)
				a["hit_times"] = times
			"cooldown":
				a["cooldown"] = maxf(1.0, float(a.get("cooldown", 0.0)) - float(m.seconds))
			"add_effect":
				if not a.has("effects"):
					a["effects"] = [{"type": "damage", "power": 1.0}]
				a.effects.append((m.effect as Dictionary).duplicate(true))


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


# --- Paliers d'éveil (Esprits) et coffres de fin de niveau ---------------------------------
# Esprits : objets « esprit_<stade>_<élément> », stades oeuf < petit < grand < celeste.

const ESPRIT_STAGES := ["oeuf", "petit", "grand", "celeste"]
const ELEMENTS := ["feu", "eau", "nature", "lumiere", "ombre"]
## Deuxième élément demandé par l'éveil d'un héros (en plus du sien).
const SECOND_ELEMENT := {"feu": "lumiere", "eau": "nature", "nature": "eau", "lumiere": "ombre", "ombre": "feu"}


static func esprit_id(stage: String, element: String) -> String:
	return "esprit_%s_%s" % [stage, element]


## Niveau qu'un héros ne peut pas dépasser sans s'éveiller : le palier suivant (10, 20… 140), ou le maximum.
static func level_cap(awakened: int, config: Dictionary) -> int:
	var every := int(config.get("awakening", {}).get("every", 10))
	return mini(int(config.get("max_level", 150)), awakened + every)


## Esprits pour franchir le palier `gate` (10, 20…) : {objet: nombre}. Les clés du JSON « oeuf », « petit »…
## visent l'élément du héros ; « oeuf2 », « petit2 »… son deuxième élément.
static func awaken_cost(gate: int, element: String, config: Dictionary) -> Dictionary:
	var table: Dictionary = config.get("awakening", {}).get("costs", {}).get(str(gate), {})
	var out := {}
	for key: String in table:
		var second := key.ends_with("2")
		var stage := key.trim_suffix("2")
		var elem: String = SECOND_ELEMENT.get(element, "feu") if second else element
		out[esprit_id(stage, elem)] = int(out.get(esprit_id(stage, elem), 0)) + int(table[key])
	return out


## Tire le coffre d'une victoire de campagne. `opened` : coffres déjà ouverts ; `since_best` : coffres
## depuis le dernier coffre du Serment (garantie). Renvoie {kind, rewards}.
static func roll_chest(stars: int, config: Dictionary, rng: RandomNumberGenerator, opened: int, since_best: int,
		world_element: String, campaign := 1) -> Dictionary:
	var c: Dictionary = config.get("chests", {})
	var kinds: Array = c.get("kinds", ["bois", "fer", "or", "serment"])
	var kind: String = kinds[0]
	if opened == 0:
		kind = kinds[1]  # le premier coffre est garanti en fer
	elif since_best + 1 >= int(c.get("pity_every", 30)):
		kind = kinds[3]
	else:
		var odds: Array = c.get("odds", {}).get(str(clampi(stars, 1, 3)), [100, 0, 0, 0])
		var roll := rng.randf() * 100.0
		var acc := 0.0
		for i in kinds.size():
			acc += float(odds[i]) if i < odds.size() else 0.0
			if roll < acc:
				kind = kinds[i]
				break
	var table: Dictionary = c.get("campaign%d" % campaign, c.get("campaign1", {})).get(kind, {})
	var rewards := {}
	for key: String in table:
		var v = table[key]
		var n := rng.randi_range(int(v[0]), int(v[1])) if v is Array else int(v)
		if n <= 0:
			continue
		if key in ESPRIT_STAGES:
			# Surtout l'élément du monde, parfois un autre (la lumière n'a pas de monde à elle).
			var elem: String = world_element if world_element != "" and rng.randf() < 0.6 else ELEMENTS[rng.randi_range(0, 4)]
			var id := esprit_id(key, elem)
			rewards[id] = int(rewards.get(id, 0)) + n
		else:
			rewards[key] = n
	return {"kind": kind, "rewards": rewards}
