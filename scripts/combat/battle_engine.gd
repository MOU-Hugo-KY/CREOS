class_name BattleEngine
extends RefCounted
## Moteur de combat de CREOS : 4 héros contre des vagues de monstres.
##
## Logique pure et déterministe (graine aléatoire). Aucun nœud, aucun affichage :
## l'affichage appelle `step(delta)` puis lit les événements avec `drain_events()`.
##
## Événements produits (Dictionary avec une clé "type") :
##   wave_start {index, count}
##   attack     {src, targets}             attaque de base qui démarre
##   skill      {src, skill_id, name, targets}
##   damage     {src, dst, amount, crit, elem_mult, hp}
##   heal       {src, dst, amount, hp}
##   shield     {dst, amount}
##   status     {dst, status, duration}   taunt / stun / dot
##   death      {dst}
##   victory    {}
##   defeat     {}

signal event_emitted(event: Dictionary)

const GAUGE_RATE := 6.0  # vitesse 100 => ~1,7 s entre deux attaques
const ENERGY_ON_ATTACK := 22.0
const ENERGY_ON_HIT := 8.0
const CRIT_MULT := 1.5
const VARIANCE := 0.05
const WAVE_DELAY := 1.2

var heroes: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var waves: Array = []  # Array de listes de Dictionary (données de monstres avec "id")
var wave_index := -1
var auto_mode := false
var finished := false
var won := false
var time := 0.0

var _rng := RandomNumberGenerator.new()
var _next_uid := 1
var _events: Array[Dictionary] = []
var _skill_queue: Array[int] = []
var _wave_timer := 0.0


## heroes_data : Array de Dictionary (données de heroes.json + clé "id").
## waves_data  : Array d'Array de Dictionary (données de monsters.json + clé "id").
func setup(heroes_data: Array, waves_data: Array, rng_seed: int = 0) -> void:
	_rng.seed = rng_seed
	heroes.clear()
	for i in heroes_data.size():
		var d: Dictionary = heroes_data[i]
		heroes.append(BattleUnit.from_data(_take_uid(), d.get("id", ""), d, 0, i))
	waves = waves_data
	wave_index = -1
	finished = false
	won = false
	time = 0.0
	_start_next_wave()


func all_units() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	out.append_array(heroes)
	out.append_array(enemies)
	return out


func get_unit(uid: int) -> BattleUnit:
	for u in all_units():
		if u.uid == uid:
			return u
	return null


## Le joueur touche le portrait d'un héros : sa compétence part dès que possible.
func request_skill(uid: int) -> bool:
	var u := get_unit(uid)
	if u == null or u.team != 0 or not u.skill_ready():
		return false
	if uid not in _skill_queue:
		_skill_queue.append(uid)
	return true


func drain_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


## Avance le combat de `delta` secondes.
func step(delta: float) -> void:
	if finished:
		return
	time += delta

	if _wave_timer > 0.0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_start_next_wave()
		return

	for u in all_units():
		if u.is_alive():
			_tick_statuses(u, delta)
	if _check_end():
		return

	# Compétences demandées par le joueur (ou automatiques).
	for u in heroes:
		if auto_mode and u.skill_ready() and u.uid not in _skill_queue:
			_skill_queue.append(u.uid)
	for u in enemies:
		if u.skill_ready():
			_skill_queue.append(u.uid)
	while not _skill_queue.is_empty():
		var caster := get_unit(_skill_queue.pop_front())
		if caster and caster.skill_ready():
			_cast_skill(caster)
			if _check_end():
				return

	# Jauges d'action -> attaques de base.
	for u in all_units():
		if not u.is_alive() or u.stun_time > 0.0:
			continue
		u.gauge += u.spd * GAUGE_RATE * delta
		if u.gauge >= BattleUnit.GAUGE_MAX:
			u.gauge -= BattleUnit.GAUGE_MAX
			_basic_attack(u)
			if _check_end():
				return


## Simule un combat complet sans affichage (pour les tests et l'équilibrage).
func simulate(max_time: float = 300.0, dt: float = 0.05) -> bool:
	auto_mode = true
	while not finished and time < max_time:
		step(dt)
	return won


# --- Interne -----------------------------------------------------------------

func _take_uid() -> int:
	_next_uid += 1
	return _next_uid - 1


func _emit(ev: Dictionary) -> void:
	_events.append(ev)
	event_emitted.emit(ev)


func _start_next_wave() -> void:
	wave_index += 1
	enemies.clear()
	var wave: Array = waves[wave_index]
	for i in wave.size():
		var d: Dictionary = wave[i]
		enemies.append(BattleUnit.from_data(_take_uid(), d.get("id", ""), d, 1, i))
	for h in heroes:
		h.gauge = 0.0
	_emit({"type": "wave_start", "index": wave_index, "count": waves.size()})


func _check_end() -> bool:
	if _alive(heroes).is_empty():
		finished = true
		won = false
		_emit({"type": "defeat"})
		return true
	if _alive(enemies).is_empty() and _wave_timer <= 0.0:
		if wave_index + 1 >= waves.size():
			finished = true
			won = true
			_emit({"type": "victory"})
		else:
			_wave_timer = WAVE_DELAY
		return true
	return false


func _alive(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in units:
		if u.is_alive():
			out.append(u)
	return out


func _allies_of(u: BattleUnit) -> Array[BattleUnit]:
	return _alive(heroes if u.team == 0 else enemies)


func _foes_of(u: BattleUnit) -> Array[BattleUnit]:
	return _alive(enemies if u.team == 0 else heroes)


func _tick_statuses(u: BattleUnit, delta: float) -> void:
	u.taunt_time = maxf(0.0, u.taunt_time - delta)
	u.stun_time = maxf(0.0, u.stun_time - delta)
	for dot in u.dots.duplicate():
		var dmg: float = dot.dps * minf(delta, dot.time)
		dot.time -= delta
		if dot.time <= 0.0:
			u.dots.erase(dot)
		_apply_damage(get_unit(dot.src), u, dmg, false, 1.0)


func _basic_attack(src: BattleUnit) -> void:
	var foes := _foes_of(src)
	if foes.is_empty():
		return
	var target := _pick_basic_target(src, foes)
	_emit({"type": "attack", "src": src.uid, "targets": [target.uid]})
	_hit(src, target, 1.0, src.attack_kind)
	src.add_energy(ENERGY_ON_ATTACK)


func _pick_basic_target(src: BattleUnit, foes: Array[BattleUnit]) -> BattleUnit:
	for f in foes:
		if f.taunt_time > 0.0:
			return f
	if src.range_type == "melee":
		# Corps-à-corps : frappe l'ennemi le plus en avant.
		var front := foes[0]
		for f in foes:
			if f.slot < front.slot:
				front = f
		return front
	return foes[_rng.randi_range(0, foes.size() - 1)]


func _skill_targets(caster: BattleUnit, target_type: String) -> Array[BattleUnit]:
	var foes := _foes_of(caster)
	var allies := _allies_of(caster)
	match target_type:
		"all_enemies":
			return foes
		"all_allies":
			return allies
		"self":
			var only: Array[BattleUnit] = [caster]
			return only
		"lowest_hp_enemy":
			return _lowest(foes)
		"lowest_hp_ally":
			return _lowest(allies)
		_:  # single_enemy
			var one: Array[BattleUnit] = []
			if not foes.is_empty():
				one.append(_pick_basic_target(caster, foes))
			return one


func _lowest(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	if units.is_empty():
		return out
	var best := units[0]
	for u in units:
		if u.hp / u.max_hp < best.hp / best.max_hp:
			best = u
	out.append(best)
	return out


func _cast_skill(caster: BattleUnit) -> void:
	caster.energy = 0.0
	var sk := caster.skill
	var targets := _skill_targets(caster, sk.get("target", "single_enemy"))
	_emit({
		"type": "skill", "src": caster.uid, "skill_id": sk.get("id", ""),
		"name": sk.get("name", ""), "targets": targets.map(func(t: BattleUnit) -> int: return t.uid),
	})
	for effect: Dictionary in sk.get("effects", []):
		var power: float = effect.get("power", 1.0)
		var effect_targets: Array[BattleUnit] = targets
		if effect.get("self_only", false):
			effect_targets = [caster]
		for t in effect_targets:
			if not t.is_alive():
				continue
			match effect.get("type", ""):
				"damage":
					_hit(caster, t, power, effect.get("kind", caster.attack_kind))
				"heal":
					var amount := caster.atk * power * _variance()
					t.hp = minf(t.max_hp, t.hp + amount)
					_emit({"type": "heal", "src": caster.uid, "dst": t.uid, "amount": amount, "hp": t.hp})
				"shield":
					var amount := caster.atk * power * 4.0
					t.shield += amount
					_emit({"type": "shield", "dst": t.uid, "amount": amount})
				"taunt":
					t.taunt_time = effect.get("duration", 5.0)
					_emit({"type": "status", "dst": t.uid, "status": "taunt", "duration": t.taunt_time})
				"stun":
					t.stun_time = maxf(t.stun_time, effect.get("duration", 1.0))
					_emit({"type": "status", "dst": t.uid, "status": "stun", "duration": t.stun_time})
				"dot":
					var duration: float = effect.get("duration", 3.0)
					t.dots.append({"dps": caster.atk * power, "time": duration, "src": caster.uid})
					_emit({"type": "status", "dst": t.uid, "status": "dot", "duration": duration})
				"cleanse":
					t.dots.clear()
					t.stun_time = 0.0


func _hit(src: BattleUnit, dst: BattleUnit, power: float, kind: String) -> void:
	var mitigation := dst.res if kind == "magic" else dst.def
	var elem := Elements.multiplier(src.element, dst.element)
	var is_crit := _rng.randf() < src.crit
	var dmg := src.atk * power * (100.0 / (100.0 + mitigation)) * elem * _variance()
	if is_crit:
		dmg *= CRIT_MULT
	_apply_damage(src, dst, dmg, is_crit, elem)


func _apply_damage(src: BattleUnit, dst: BattleUnit, dmg: float, is_crit: bool, elem: float) -> void:
	if not dst.is_alive():
		return
	if dst.shield > 0.0:
		var absorbed := minf(dst.shield, dmg)
		dst.shield -= absorbed
		dmg -= absorbed
	dst.hp = maxf(0.0, dst.hp - dmg)
	dst.add_energy(ENERGY_ON_HIT)
	_emit({
		"type": "damage", "src": src.uid if src else -1, "dst": dst.uid,
		"amount": dmg, "crit": is_crit, "elem_mult": elem, "hp": dst.hp,
	})
	if not dst.is_alive():
		dst.dots.clear()
		_emit({"type": "death", "dst": dst.uid})


func _variance() -> float:
	return _rng.randf_range(1.0 - VARIANCE, 1.0 + VARIANCE)
