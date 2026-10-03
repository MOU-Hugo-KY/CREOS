class_name Summon
extends RefCounted
## Règles pures de l'Autel des Reliques (invocations), sans affichage ni sauvegarde.
## Chiffres dans `data/summon.json`. Les taux sont affichés au joueur, et une garantie
## (« pitié ») donne au moins un Légendaire toutes les `pity_every` invocations.


## Tire un héros dans `pool` (id -> données de heroes.json, avec "rarity").
## `count` = invocations déjà faites, `pity` = invocations depuis le dernier héros rare.
## Renvoie {id, rarity} (id vide si la réserve est vide).
static func roll(pool: Dictionary, config: Dictionary, count: int, pity: int, rng: RandomNumberGenerator) -> Dictionary:
	var first: String = config.get("first_summon", "")
	if count == 0 and pool.has(first):
		return {"id": first, "rarity": int(pool[first].get("rarity", 1))}
	var by_rarity: Dictionary = {}
	for id: String in pool:
		var r := int(pool[id].get("rarity", 1))
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append(id)
	if by_rarity.is_empty():
		return {"id": "", "rarity": 0}
	var min_rarity := 0
	if pity + 1 >= int(config.get("pity_every", 10)):
		min_rarity = int(config.get("pity_min_rarity", 4))
	var weights: Dictionary = config.get("rarity_weights", {})
	var choices: Array = []
	var total := 0.0
	for r: int in by_rarity:
		var w := float(weights.get(str(r), 0))
		if r >= min_rarity and w > 0.0:
			choices.append([r, w])
			total += w
	if choices.is_empty():
		# Garantie impossible (pas de héros assez rare) : on prend la meilleure rareté disponible.
		var best: int = by_rarity.keys().max()
		choices.append([best, 1.0])
		total = 1.0
	choices.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var pick := rng.randf() * total
	var rarity: int = choices[-1][0]
	for c: Array in choices:
		pick -= float(c[1])
		if pick < 0.0:
			rarity = c[0]
			break
	var ids: Array = by_rarity[rarity]
	ids.sort()
	return {"id": ids[rng.randi_range(0, ids.size() - 1)], "rarity": rarity}


## Chance (en %) de chaque rareté, pour l'affichage des taux.
static func odds(pool: Dictionary, config: Dictionary) -> Dictionary:
	var weights: Dictionary = config.get("rarity_weights", {})
	var present: Dictionary = {}
	for id: String in pool:
		present[int(pool[id].get("rarity", 1))] = true
	var total := 0.0
	for r: int in present:
		total += float(weights.get(str(r), 0))
	var out: Dictionary = {}
	for r: int in present:
		out[r] = 0.0 if total <= 0.0 else 100.0 * float(weights.get(str(r), 0)) / total
	return out
