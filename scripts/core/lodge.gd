class_name Lodge
extends RefCounted
## Règles pures de « Ma Loge » (données dans data/lodge.json) : le donjon du joueur.
## Trois salles, chacune avec des héros en défense, des défenses construites (tour, mur, baliste, autel)
## et des pièges ; une récompense mise en jeu.
## Seules les équipes dont la Force est inférieure ou égale à celle du donjon peuvent l'attaquer.
## Aucun nœud ici : PlayerData garde l'état, le combat lit les vagues et les pièges.


## État vide d'une Loge : {rooms: [[ids]…], traps: [[ids]…], defenses: [[ids]…], stake, rivals_day, rivals_done}.
static func empty_state(cfg: Dictionary) -> Dictionary:
	var rooms: Array = []
	var traps: Array = []
	var defenses: Array = []
	for _r in cfg.get("rooms", []):
		rooms.append([])
		traps.append([])
		defenses.append([])
	return {"rooms": rooms, "traps": traps, "defenses": defenses, "stake": 0, "rivals_day": "", "rivals_done": []}


## Construit une défense dans une salle (au plus `defenses` par salle). Renvoie false si impossible.
static func add_defense(state: Dictionary, cfg: Dictionary, room: int, defense_id: String) -> bool:
	if room < 0 or room >= state.defenses.size() or not cfg.get("defenses", {}).has(defense_id):
		return false
	if state.defenses[room].size() >= int(cfg.rooms[room].get("defenses", 1)):
		return false
	state.defenses[room].append(defense_id)
	return true


static func remove_defense(state: Dictionary, room: int, index: int) -> String:
	if room < 0 or room >= state.defenses.size() or index < 0 or index >= state.defenses[room].size():
		return ""
	return state.defenses[room].pop_at(index)


## Ajoute un défenseur dans une salle (un héros ne défend qu'une seule salle). Renvoie false si impossible.
static func add_defender(state: Dictionary, cfg: Dictionary, room: int, id: String) -> bool:
	if room < 0 or room >= state.rooms.size():
		return false
	for r: Array in state.rooms:
		if id in r:
			return false
	var cap := int(cfg.rooms[room].get("defenders", 3))
	if state.rooms[room].size() >= cap:
		return false
	state.rooms[room].append(id)
	return true


static func remove_defender(state: Dictionary, room: int, id: String) -> void:
	if room >= 0 and room < state.rooms.size():
		state.rooms[room].erase(id)


## Pose ou retire un piège dans une salle (au plus `traps` par salle, chacun une fois par salle).
static func toggle_trap(state: Dictionary, cfg: Dictionary, room: int, trap_id: String) -> bool:
	if room < 0 or room >= state.traps.size() or not cfg.get("traps", {}).has(trap_id):
		return false
	var list: Array = state.traps[room]
	if trap_id in list:
		list.erase(trap_id)
		return true
	if list.size() >= int(cfg.rooms[room].get("traps", 2)):
		return false
	list.append(trap_id)
	return true


## Le donjon est jouable s'il a au moins un défenseur dans chaque salle.
static func is_ready(state: Dictionary) -> bool:
	return not state.rooms.is_empty() and state.rooms.all(func(r: Array) -> bool: return not r.is_empty())


## Vagues du combat : une par salle, les héros défenseurs (données de combat via `hero_data`), puis les
## défenses construites, dont les stats suivent la moyenne des défenseurs de la salle.
static func waves(rooms: Array, hero_data: Callable, defenses: Array = [], cfg: Dictionary = {}) -> Array:
	var out: Array = []
	for i in rooms.size():
		var wave: Array = []
		for id: String in rooms[i]:
			var d: Dictionary = hero_data.call(id)
			d["id"] = id
			wave.append(d)
		var built: Array = defenses[i] if i < defenses.size() else []
		var heroes_only := wave.duplicate()
		for def_id: String in built:
			var u := defense_unit(def_id, heroes_only, cfg)
			if u.wall:
				wave.push_front(u)  # le mur se place devant
			else:
				wave.append(u)
		out.append(wave)
	return out


## Données de combat d'une défense : ses stats = coefficients × moyenne des défenseurs de la salle.
static func defense_unit(def_id: String, defenders: Array, cfg: Dictionary) -> Dictionary:
	var spec: Dictionary = cfg.defenses[def_id]
	var avg := {}
	var heroes := defenders.filter(func(d: Dictionary) -> bool: return not d.has("structure"))
	for key in ["hp", "atk", "mag", "def", "res", "spd"]:
		var total := 0.0
		for d: Dictionary in heroes:
			total += float(d.get("stats", {}).get(key, 0))
		avg[key] = total / maxf(1.0, heroes.size()) if not heroes.is_empty() else 500.0
	var stats := {}
	for key: String in spec.stats:
		stats[key] = float(spec.stats[key]) if key == "crit" else round(float(avg.get(key, 0.0)) * float(spec.stats[key]))
	return {
		"id": def_id, "name": spec.name, "structure": def_id, "wall": spec.get("wall", false),
		"element": spec.get("element", ""), "class": spec.get("class", ""), "range": spec.get("range", "ranged"),
		"attack_kind": spec.get("attack_kind", "physical"), "stats": stats, "attacks": spec.get("attacks", []).duplicate(true),
		"prop": spec.get("prop", ""), "prop_scale": spec.get("prop_scale", 2.0),
	}


## Pièges de chaque vague (données complètes, avec "id").
static func wave_traps(traps: Array, cfg: Dictionary) -> Array:
	var out: Array = []
	for list: Array in traps:
		var w: Array = []
		for t: String in list:
			if cfg.traps.has(t):
				var d: Dictionary = cfg.traps[t].duplicate(true)
				d["id"] = t
				w.append(d)
		out.append(w)
	return out


## Force d'un donjon : Force moyenne de ses défenseurs (comparée à la Force moyenne de l'équipe qui
## attaque, puisque les salles n'ont pas autant de héros qu'une équipe). `power_of` : Callable(id) -> Force.
static func power(rooms: Array, power_of: Callable) -> int:
	var ids: Array = []
	for r: Array in rooms:
		ids.append_array(r)
	return average_power(ids, power_of)


static func average_power(ids: Array, power_of: Callable) -> int:
	if ids.is_empty():
		return 0
	var total := 0
	for id: String in ids:
		total += int(power_of.call(id))
	return int(round(float(total) / ids.size()))


## Une équipe ne peut attaquer qu'un donjon au moins aussi fort qu'elle.
static func can_attack(team_power: int, lodge_power: int) -> bool:
	return team_power <= lodge_power


## Part de la récompense gagnée par l'attaquant victorieux, et mise d'entrée payée par l'attaquant.
static func win_reward(stake: int, cfg: Dictionary) -> int:
	return int(stake * float(cfg.get("win_share", 0.3)))


static func entry_fee(stake: int, cfg: Dictionary) -> int:
	return int(stake * float(cfg.get("entry_share", 0.1)))


## Donjons de chasseurs rivaux du jour (tant que le jeu en ligne n'existe pas) : tirés au sort avec la date,
## toujours au moins aussi forts que l'équipe du joueur pour pouvoir être attaqués.
## `power_at` : Callable(id, niveau) -> Force du héros à ce niveau.
static func rivals(day: String, team_power: int, hero_ids: Array, cfg: Dictionary, power_at: Callable) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day)
	var names: Array = cfg.get("rival_names", ["Chasseur rival"]).duplicate()
	var trap_ids: Array = cfg.get("traps", {}).keys()
	trap_ids.sort()
	var out: Array = []
	for n in int(cfg.get("rivals_per_day", 3)):
		var pool := hero_ids.duplicate()
		pool.sort()
		var rooms: Array = []
		var traps: Array = []
		var defenses: Array = []
		var defense_ids: Array = cfg.get("defenses", {}).keys()
		defense_ids.sort()
		for room: Dictionary in cfg.rooms:
			var built: Array = []
			for _k in int(room.get("defenses", 1)):
				if not defense_ids.is_empty() and rng.randf() < 0.6:
					built.append(defense_ids[rng.randi_range(0, defense_ids.size() - 1)])
			defenses.append(built)
			var r: Array = []
			for _i in int(room.get("defenders", 3)):
				if pool.is_empty():
					break
				r.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
			rooms.append(r)
			var t: Array = []
			for _j in int(room.get("traps", 2)):
				var pick: String = trap_ids[rng.randi_range(0, trap_ids.size() - 1)]
				if pick not in t:
					t.append(pick)
			traps.append(t)
		# Niveau le plus bas qui rend le donjon au moins aussi fort que l'équipe (+0 à 25 %).
		var target := int(team_power * rng.randf_range(1.0, 1.25))
		var level := 1
		while level < 60 and power(rooms, func(id: String) -> int: return power_at.call(id, level)) < target:
			level += 1
		var lp := power(rooms, func(id: String) -> int: return power_at.call(id, level))
		out.append({
			"id": "rival_%s_%d" % [day, n], "name": names.pop_at(rng.randi_range(0, names.size() - 1)),
			"rooms": rooms, "traps": traps, "defenses": defenses, "level": level, "power": lp,
			"stake": int(round(lp * rng.randf_range(6.0, 12.0) / 50.0)) * 50,
		})
	return out
