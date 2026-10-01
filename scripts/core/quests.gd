class_name Quests
extends RefCounted
## Règles pures des primes du jour (sans affichage ni sauvegarde).
## `daily` = {day, progress: {événement: nombre}, claimed: [id], chests: [index]}.
## Chiffres et textes dans `data/quests.json`.


## Le suivi du jour : remis à zéro si `day` (ex. "2026-10-01") a changé.
static func refresh(daily: Dictionary, day: String) -> Dictionary:
	if daily.get("day", "") == day:
		return daily
	return {"day": day, "progress": {}, "claimed": [], "chests": []}


static func record(daily: Dictionary, event: String, amount := 1) -> void:
	var p: Dictionary = daily.get("progress", {})
	p[event] = int(p.get(event, 0)) + amount
	daily["progress"] = p


static func is_available(quest: Dictionary) -> bool:
	return bool(quest.get("available", true))


static func progress(daily: Dictionary, quest: Dictionary) -> int:
	return mini(int(daily.get("progress", {}).get(quest.get("event", ""), 0)), int(quest.get("target", 1)))


static func is_claimed(daily: Dictionary, quest: Dictionary) -> bool:
	return daily.get("claimed", []).has(quest.get("id", ""))


static func can_claim(daily: Dictionary, quest: Dictionary) -> bool:
	return is_available(quest) and not is_claimed(daily, quest) \
		and progress(daily, quest) >= int(quest.get("target", 1))


## Points d'activité du jour (somme des primes récupérées).
static func points(daily: Dictionary, config: Dictionary) -> int:
	var total := 0
	for q: Dictionary in config.get("quests", []):
		if is_claimed(daily, q):
			total += int(q.get("points", 0))
	return total


static func can_open_chest(daily: Dictionary, config: Dictionary, index: int) -> bool:
	var chests: Array = config.get("chests", [])
	if index < 0 or index >= chests.size() or daily.get("chests", []).has(index):
		return false
	return points(daily, config) >= int(chests[index].get("points", 0))


## Nombre de choses à récupérer (pour la pastille rouge du bouton Primes).
static func claimable_count(daily: Dictionary, config: Dictionary) -> int:
	var n := 0
	for q: Dictionary in config.get("quests", []):
		if can_claim(daily, q):
			n += 1
	for i in config.get("chests", []).size():
		if can_open_chest(daily, config, i):
			n += 1
	return n
