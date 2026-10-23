class_name DefenseEngine
extends RefCounted
## Défense de base : logique pure (aucun nœud, aucun affichage), déterministe avec une graine.
## Le joueur pose troupes, défenses et héros sur les cases de sa zone ; tout bouge ensuite seul.
## Les héros ont une compétence que le joueur déclenche. Les vagues arrivent sans fin par la droite.
## Positions en cases (Vector2, le centre d'une case = col + 0,5).
## Événements : placed, spawn, attack, damage, death, skill, wave_start, castle_hit, defeat.

var cfg: Dictionary = {}
var units: Array = []  # dictionnaires, voir _make_unit()
var gold := 0
var castle_hp := 0
var castle_max_hp := 0
var wave := 0  # numéro de la dernière vague lancée
var time := 0.0
var finished := false

var _rng := RandomNumberGenerator.new()
var _events: Array = []
var _next_uid := 1
var _wave_timer := 0.0
var _spawn_queue: Array = []  # ids d'ennemis encore à faire entrer
var _spawn_timer := 0.0


func setup(config: Dictionary, seed_value: int = 1) -> void:
	cfg = config
	_rng.seed = seed_value
	units.clear()
	_events.clear()
	gold = int(cfg.start_gold)
	castle_max_hp = int(cfg.castle.hp)
	castle_hp = castle_max_hp
	wave = 0
	time = 0.0
	finished = false
	_wave_timer = float(cfg.first_wave_delay)
	_spawn_queue.clear()


func cols() -> int:
	return int(cfg.grid.cols)


func rows() -> int:
	return int(cfg.grid.rows)


func castle_cell() -> Vector2i:
	return Vector2i(int(cfg.castle.cell[0]), int(cfg.castle.cell[1]))


func time_to_next_wave() -> float:
	return _wave_timer


func drain_events() -> Array:
	var out := _events
	_events = []
	return out


# --- Placement --------------------------------------------------------------

func cost_of(kind: String) -> int:
	if cfg.placeables.has(kind):
		return int(cfg.placeables[kind].cost)
	return 0  # les héros sont gratuits mais uniques


func can_place(kind: String, cell: Vector2i) -> bool:
	if finished:
		return false
	if cell.x < 0 or cell.y < 0 or cell.x >= int(cfg.grid.build_cols) or cell.y >= rows():
		return false
	if cell == castle_cell():
		return false
	if not cfg.placeables.has(kind) and not cfg.heroes.has(kind):
		return false
	if cfg.heroes.has(kind) and hero_uid(kind) != 0:
		return false
	if gold < cost_of(kind):
		return false
	for u in units:
		if u.alive and u.team == 0 and u.post == cell:
			return false
	return true


func place(kind: String, cell: Vector2i) -> int:
	if not can_place(kind, cell):
		return 0
	gold -= cost_of(kind)
	var def: Dictionary = cfg.placeables.get(kind, cfg.heroes.get(kind, {}))
	var role := "hero" if cfg.heroes.has(kind) else String(def.type)
	var u := _make_unit(kind, 0, role, def, Vector2(cell) + Vector2(0.5, 0.5), 1.0)
	u.post = cell
	if role == "hero":
		u.skill_cd = 0.0
	units.append(u)
	_events.append({"type": "placed", "uid": u.uid, "kind": kind})
	return u.uid


func hero_uid(kind: String) -> int:
	for u in units:
		if u.alive and u.role == "hero" and u.kind == kind:
			return u.uid
	return 0


func unit(uid: int) -> Dictionary:
	for u in units:
		if u.uid == uid:
			return u
	return {}


# --- Compétences des héros -------------------------------------------------

func skill_ready(uid: int) -> bool:
	var u := unit(uid)
	return not u.is_empty() and u.alive and u.role == "hero" and u.skill_cd <= 0.0 and not finished


func use_skill(uid: int) -> bool:
	if not skill_ready(uid):
		return false
	var u := unit(uid)
	var sk: Dictionary = cfg.heroes[u.kind].skill
	u.skill_cd = float(sk.cooldown)
	var radius := float(sk.radius)
	match String(sk.kind):
		"heal_allies":
			for a in units:
				if a.alive and a.team == 0 and a.pos.distance_to(u.pos) <= radius:
					_heal(a, int(a.max_hp * float(sk.amount)))
		"damage_area":
			# vise le groupe d'ennemis le plus proche du héros
			var target := _nearest(u, 1, 99.0)
			var center: Vector2 = target.pos if not target.is_empty() else u.pos
			for e in units:
				if e.alive and e.team == 1 and e.pos.distance_to(center) <= radius:
					_damage(u, e, int(sk.amount))
	_events.append({"type": "skill", "uid": uid, "name": sk.name})
	return true


# --- Boucle -----------------------------------------------------------------

func step(delta: float) -> void:
	if finished:
		return
	time += delta
	_update_waves(delta)
	for u in units:
		if not u.alive:
			continue
		u.atk_timer = max(0.0, u.atk_timer - delta)
		if u.role == "hero":
			u.skill_cd = max(0.0, u.skill_cd - delta)
		if u.team == 1:
			_enemy_think(u, delta)
		else:
			_ally_think(u, delta)
	units = units.filter(func(x: Dictionary) -> bool: return x.alive)
	if castle_hp <= 0 and not finished:
		finished = true
		_events.append({"type": "defeat", "wave": wave})


func _update_waves(delta: float) -> void:
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_start_wave()
		_wave_timer = float(cfg.wave_interval)
	if _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = float(cfg.waves.spawn_gap)
		_spawn_enemy(_spawn_queue.pop_front())


func _start_wave() -> void:
	wave += 1
	if wave > 1:
		gold += int(cfg.wave_gold)
	var count := int(cfg.waves.base_count) + int(cfg.waves.count_per_wave) * (wave - 1)
	for i in count:
		var kind := "gobelin"
		var r := _rng.randf()
		if wave >= 3 and r < 0.2:
			kind = "brute"
		elif wave >= 2 and r < 0.45:
			kind = "lanceur"
		_spawn_queue.append(kind)
	_spawn_timer = 0.0
	_events.append({"type": "wave_start", "wave": wave, "count": count})


func _spawn_enemy(kind: String) -> void:
	var def: Dictionary = cfg.enemies[kind]
	var y := _rng.randf_range(0.6, rows() - 0.6)
	var scale := 1.0 + float(cfg.waves.hp_growth) * (wave - 1)
	var u := _make_unit(kind, 1, "enemy", def, Vector2(cols() + 0.4, y), scale)
	units.append(u)
	_events.append({"type": "spawn", "uid": u.uid, "kind": kind})


func _make_unit(kind: String, team: int, role: String, def: Dictionary, pos: Vector2, hp_scale: float) -> Dictionary:
	var hp := int(float(def.get("hp", 100)) * hp_scale)
	var u := {
		"uid": _next_uid, "kind": kind, "team": team, "role": role, "pos": pos,
		"hp": hp, "max_hp": hp, "atk": int(def.get("atk", 0)),
		"range": float(def.get("range", 0.0)), "speed": float(def.get("speed", 0.0)),
		"cooldown": float(def.get("cooldown", 1.0)), "aggro": float(def.get("aggro", 0.0)),
		"splash": float(def.get("splash", 0.0)), "blocks": bool(def.get("blocks", false)),
		"gold": int(def.get("gold", 0)), "atk_timer": 0.0, "alive": true,
		"post": Vector2i(-1, -1), "skill_cd": 0.0, "moving": false,
	}
	_next_uid += 1
	return u


# Troupes et héros : vont chercher l'ennemi proche de leur poste, puis y reviennent.
# Défenses : tirent sur place.
func _ally_think(u: Dictionary, delta: float) -> void:
	u.moving = false
	if u.atk <= 0:
		return
	if u.role == "defense":
		var t := _nearest(u, 1, u.range)
		if not t.is_empty():
			_try_attack(u, t)
		return
	var home := Vector2(u.post) + Vector2(0.5, 0.5)
	var target := _nearest_from(home, 1, u.aggro)
	if target.is_empty():
		_move_towards(u, home, delta, 0.05)
		return
	if u.pos.distance_to(target.pos) <= u.range:
		_try_attack(u, target)
	else:
		_move_towards(u, target.pos, delta, u.range * 0.9)


# Ennemis : avancent vers le château ; attaquent ce qui est à portée en chemin.
func _enemy_think(u: Dictionary, delta: float) -> void:
	u.moving = false
	var castle := Vector2(castle_cell()) + Vector2(0.5, 0.5)
	if u.pos.distance_to(castle) <= u.range + 0.6:
		if u.atk_timer <= 0.0:
			u.atk_timer = u.cooldown
			castle_hp = max(0, castle_hp - u.atk)
			_events.append({"type": "castle_hit", "uid": u.uid, "amount": u.atk})
		return
	var t := _nearest(u, 0, u.range)
	if t.is_empty():
		# une barrière juste devant bloque le passage
		t = _blocking_barrier(u)
	if not t.is_empty():
		_try_attack(u, t)
		return
	_move_towards(u, castle, delta, 0.0)


func _blocking_barrier(u: Dictionary) -> Dictionary:
	for b in units:
		if b.alive and b.blocks and b.pos.x < u.pos.x and u.pos.x - b.pos.x <= 1.0 and absf(b.pos.y - u.pos.y) < 0.6:
			return b
	return {}


func _move_towards(u: Dictionary, dest: Vector2, delta: float, stop_at: float) -> void:
	var d: float = u.pos.distance_to(dest)
	if d <= stop_at:
		return
	u.pos = u.pos.move_toward(dest, min(u.speed * delta, d - stop_at))
	u.moving = true


func _try_attack(u: Dictionary, t: Dictionary) -> void:
	if u.atk_timer > 0.0:
		return
	u.atk_timer = u.cooldown
	_events.append({"type": "attack", "uid": u.uid, "target": t.uid, "from": u.pos, "to": t.pos, "ranged": u.range > 1.5})
	if u.splash > 0.0:
		for e in units:
			if e.alive and e.team == t.team and e.pos.distance_to(t.pos) <= u.splash:
				_damage(u, e, u.atk)
	else:
		_damage(u, t, u.atk)


func _damage(src: Dictionary, t: Dictionary, amount: int) -> void:
	if not t.alive:
		return
	t.hp = max(0, t.hp - amount)
	_events.append({"type": "damage", "uid": t.uid, "amount": amount})
	if t.hp == 0:
		t.alive = false
		if t.team == 1:
			gold += t.gold
		_events.append({"type": "death", "uid": t.uid, "kind": t.kind, "by": src.uid, "pos": t.pos})


func _heal(t: Dictionary, amount: int) -> void:
	t.hp = min(t.max_hp, t.hp + amount)
	_events.append({"type": "heal", "uid": t.uid, "amount": amount})


func _nearest(u: Dictionary, team: int, max_dist: float) -> Dictionary:
	return _nearest_from(u.pos, team, max_dist)


func _nearest_from(p: Vector2, team: int, max_dist: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_dist
	for o in units:
		if o.alive and o.team == team:
			var d: float = p.distance_to(o.pos)
			if d <= best_d:
				best_d = d
				best = o
	return best
