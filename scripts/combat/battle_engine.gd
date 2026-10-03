class_name BattleEngine
extends RefCounted
## Moteur de combat de CREOS : 4 héros contre des vagues de monstres.
##
## Logique pure et déterministe (graine aléatoire). Aucun nœud, aucun affichage :
## l'affichage appelle `step(delta)` puis lit les événements avec `drain_events()`.
##
## Tour par tour à jauges : la jauge de chaque unité se remplit selon sa vitesse. Quand celle
## d'un héros est pleine (hors mode Auto), le combat se fige (`awaiting_uid`) jusqu'à ce que le
## joueur choisisse une de ses 3 attaques avec `request_attack()`. Les ennemis et le mode Auto
## choisissent seuls.
##
## Événements produits (Dictionary avec une clé "type") :
##   wave_start {index, count}
##   turn       {src}                        au tour de ce héros de choisir son attaque
##   focus      {target}  (ennemi ciblé par le joueur, -1 = aucun)
##   attack     {src, slot, attack_id, name, anim, hit_time, targets}
##              slot 0 = attaque de base, 1 = attaque à recharge, 2 = ultime
##   damage     {src, dst, amount, crit, elem_mult, hp, dot}   dot = brûlure/poison
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
const DOT_TICK := 1.0
const DEFAULT_HIT_TIME := 0.35  # instant d'impact dans l'animation (pour l'affichage)

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
var awaiting_uid := -1  # héros qui attend le choix du joueur (-1 = personne)
var focus_uid := -1  # ennemi ciblé par le joueur (-1 = choix automatique)
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
	awaiting_uid = -1
	focus_uid = -1
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


## Le joueur choisit l'attaque `slot` (0, 1 ou 2) du héros dont c'est le tour.
func request_attack(uid: int, slot: int) -> bool:
	var u := get_unit(uid)
	if u == null or uid != awaiting_uid or not u.can_use(slot):
		return false
	awaiting_uid = -1
	_use_attack(u, slot)
	_check_end()
	return true


## Le joueur désigne l'ennemi que ses héros frappent (attaques sur une seule cible).
## Toucher à nouveau le même ennemi enlève la cible. Une provocation reste prioritaire.
func set_focus(uid: int) -> bool:
	var u := get_unit(uid)
	if u == null or u.team != 1 or not u.is_alive():
		return false
	focus_uid = -1 if focus_uid == uid else uid
	_emit({"type": "focus", "target": focus_uid})
	return true


func drain_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


## Avance le combat de `delta` secondes.
func step(delta: float) -> void:
	if finished:
		return
	if awaiting_uid != -1:
		# Combat figé : on attend le choix du joueur (sauf si le mode Auto vient d'être activé).
		if not auto_mode:
			return
		var waiting := get_unit(awaiting_uid)
		awaiting_uid = -1
		_use_attack(waiting, _ai_choice(waiting))
		if _check_end():
			return
	time += delta

	if _wave_timer > 0.0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_start_next_wave()
		return

	for u in all_units():
		if u.is_alive():
			u.tick_cooldowns(delta)
			_tick_statuses(u, delta)
	if _check_end():
		return

	# Jauges d'action : une unité dont la jauge est pleine joue son tour.
	for u in all_units():
		if not u.is_alive() or u.stun_time > 0.0:
			continue
		u.gauge += u.spd * GAUGE_RATE * delta
		if u.gauge >= BattleUnit.GAUGE_MAX:
			u.gauge -= BattleUnit.GAUGE_MAX
			if u.team == 0 and not auto_mode:
				awaiting_uid = u.uid
				_emit({"type": "turn", "src": u.uid})
				return
			_use_attack(u, _ai_choice(u))
			if _check_end():
				return


## Étoiles gagnées (0 à 3) : 3 si aucun héros n'est tombé, 2 si un seul est tombé, sinon 1.
func stars() -> int:
	if not won:
		return 0
	var fallen := heroes.size() - _alive(heroes).size()
	if fallen == 0:
		return 3
	return 2 if fallen == 1 else 1


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
	focus_uid = -1
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
	# Les dégâts sur la durée tombent une fois par seconde (et le reste à la fin).
	for dot in u.dots.duplicate():
		var step_time := minf(delta, dot.time)
		dot.time -= delta
		dot.acc = dot.get("acc", 0.0) + step_time
		var ended: bool = dot.time <= 0.0
		if ended:
			u.dots.erase(dot)
		if dot.acc >= DOT_TICK or ended:
			_apply_damage(get_unit(dot.src), u, dot.dps * dot.acc, false, 1.0, true)
			dot.acc = 0.0


## IA simple : l'ultime dès qu'elle est prête, sinon l'attaque à recharge, sinon l'attaque de base.
func _ai_choice(u: BattleUnit) -> int:
	for slot in [BattleUnit.SLOT_ULTIMATE, BattleUnit.SLOT_COOLDOWN]:
		if u.attack_ready(slot):
			return slot
	return BattleUnit.SLOT_BASIC


func _pick_basic_target(src: BattleUnit, foes: Array[BattleUnit]) -> BattleUnit:
	for f in foes:
		if f.taunt_time > 0.0:
			return f
	if src.team == 0 and focus_uid != -1:
		for f in foes:
			if f.uid == focus_uid:
				return f
	if src.range_type == "melee":
		# Corps-à-corps : frappe l'ennemi le plus en avant.
		var front := foes[0]
		for f in foes:
			if f.slot < front.slot:
				front = f
		return front
	return foes[_rng.randi_range(0, foes.size() - 1)]


func _attack_targets(caster: BattleUnit, target_type: String) -> Array[BattleUnit]:
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


func _use_attack(caster: BattleUnit, slot: int) -> void:
	if not caster.has_attack(slot) or _foes_of(caster).is_empty():
		return
	var atk_data: Dictionary = caster.attacks[slot]
	caster.energy -= caster.energy_cost(slot)
	caster.cooldowns[slot] = float(atk_data.get("cooldown", 0.0))
	var targets := _attack_targets(caster, atk_data.get("target", "single_enemy"))
	var effects: Array = atk_data.get("effects", [{"type": "damage", "power": 1.0}])
	# Chaque effet touche les cibles de l'attaque, sauf s'il a sa propre `"target"` ou `"self_only"`.
	var per_effect: Array = []
	var shown: Array[BattleUnit] = targets.duplicate()
	for effect: Dictionary in effects:
		var effect_targets: Array[BattleUnit] = targets
		if effect.get("self_only", false):
			effect_targets = [caster]
		elif effect.has("target"):
			effect_targets = _attack_targets(caster, effect.target)
			for t in effect_targets:
				if t not in shown:
					shown.append(t)
		per_effect.append(effect_targets)
	var hit_time := float(atk_data.get("hit_time", DEFAULT_HIT_TIME))
	_emit({
		"type": "attack", "src": caster.uid, "slot": slot, "attack_id": atk_data.get("id", ""),
		"name": atk_data.get("name", ""), "anim": atk_data.get("anim", ""),
		"hit_time": float(atk_data.get("hit_times", [hit_time])[0]),
		"hit_times": atk_data.get("hit_times", [hit_time]),
		"targets": shown.map(func(t: BattleUnit) -> int: return t.uid),
	})
	for i in effects.size():
		var effect: Dictionary = effects[i]
		var power: float = effect.get("power", 1.0)
		for t: BattleUnit in per_effect[i]:
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
	if slot != BattleUnit.SLOT_ULTIMATE:
		caster.add_energy(ENERGY_ON_ATTACK)


func _hit(src: BattleUnit, dst: BattleUnit, power: float, kind: String) -> void:
	var mitigation := dst.res if kind == "magic" else dst.def
	var elem := Elements.multiplier(src.element, dst.element)
	var is_crit := _rng.randf() < src.crit
	var dmg := src.atk * power * (100.0 / (100.0 + mitigation)) * elem * _variance()
	if is_crit:
		dmg *= CRIT_MULT
	_apply_damage(src, dst, dmg, is_crit, elem)


func _apply_damage(src: BattleUnit, dst: BattleUnit, dmg: float, is_crit: bool, elem: float, is_dot := false) -> void:
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
		"amount": dmg, "crit": is_crit, "elem_mult": elem, "hp": dst.hp, "dot": is_dot,
	})
	if not dst.is_alive():
		dst.dots.clear()
		_emit({"type": "death", "dst": dst.uid})


func _variance() -> float:
	return _rng.randf_range(1.0 - VARIANCE, 1.0 + VARIANCE)
