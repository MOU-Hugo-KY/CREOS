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
##   status     {dst, status, duration}   taunt / stun / dot / marque, mouille… (fiche de combat)
##   miss       {src, dst, reason}        esquive, aveuglement, leurre
##   quartet    {id, src, members, targets, hit_times, name, clip}  attaque combinée du quatuor
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
var quartet: Dictionary = {}  # quatuor de l'équipe (data/relics.json "quartets"), vide si aucun
var quartet_used := false  # une seule attaque combinée par combat


## heroes_data : Array de Dictionary (données de heroes.json + clé "id").
## waves_data  : Array d'Array de Dictionary (données de monsters.json + clé "id").
func setup(heroes_data: Array, waves_data: Array, rng_seed: int = 0, quartets: Dictionary = {}) -> void:
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
	quartet = {}
	quartet_used = false
	var ids: Array = heroes_data.map(func(d: Dictionary) -> String: return d.get("id", ""))
	for qid: String in quartets:
		var q: Dictionary = quartets[qid]
		if q.members.all(func(m: String) -> bool: return m in ids):
			quartet = q.duplicate(true)
			quartet["id"] = qid
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


## Le quatuor peut frapper : ses 4 membres sont dans l'équipe, vivants, libres d'agir, et chacun a
## déjà lancé son ultime une fois dans ce combat. Une seule fois par combat.
func quartet_ready() -> bool:
	if quartet.is_empty() or quartet_used or finished:
		return false
	for m: String in quartet.members:
		var u := _hero_by_id(m)
		if u == null or not u.is_alive() or not u.used_ultimate or u.stun_time > 0.0:
			return false
	return true


## Le héros dont c'est le tour déclenche l'attaque combinée (elle consomme son action).
func request_quartet(uid: int) -> bool:
	if uid != awaiting_uid or not quartet_ready():
		return false
	awaiting_uid = -1
	_use_quartet(get_unit(uid))
	_check_end()
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
		_ai_act(waiting)
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
			_ai_act(u)
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
	u.tick_statuses(delta)
	for hot in u.hots.duplicate():
		var step_time := minf(delta, hot.time)
		hot.time -= delta
		hot.acc = hot.get("acc", 0.0) + step_time
		var ended: bool = hot.time <= 0.0
		if ended:
			u.hots.erase(hot)
		if hot.acc >= DOT_TICK or ended:
			_heal(get_unit(hot.src), u, hot.hps * hot.acc)
			hot.acc = 0.0
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


func _ai_act(u: BattleUnit) -> void:
	if u.team == 0 and quartet_ready():
		_use_quartet(u)
	else:
		_use_attack(u, _ai_choice(u))


func _hero_by_id(id: String) -> BattleUnit:
	for h in heroes:
		if h.def_id == id:
			return h
	return null


## IA simple : l'ultime dès qu'elle est prête, sinon l'attaque à recharge, sinon l'attaque de base.
func _ai_choice(u: BattleUnit) -> int:
	for slot in [BattleUnit.SLOT_ULTIMATE, BattleUnit.SLOT_SECRET, BattleUnit.SLOT_COOLDOWN]:
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
		"random_enemy":
			var r: Array[BattleUnit] = []
			if not foes.is_empty():
				r.append(foes[_rng.randi_range(0, foes.size() - 1)])
			return r
		"two_enemies":
			var two: Array[BattleUnit] = []
			if not foes.is_empty():
				var first := _pick_basic_target(caster, foes)
				two.append(first)
				for f in foes:
					if f != first:
						two.append(f)
						break
			return two
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
	if slot == BattleUnit.SLOT_ULTIMATE:
		caster.used_ultimate = true
	var target_type: String = atk_data.get("target", "single_enemy")
	var targets := _attack_targets(caster, target_type)
	var effects: Array = atk_data.get("effects", [{"type": "damage", "power": 1.0}])
	# Chaque effet touche les cibles de l'attaque, sauf s'il a sa propre `"target"` ou `"self_only"`.
	# Avec la cible « random_enemy », chaque coup choisit un nouvel ennemi au hasard.
	var per_effect: Array = []
	var shown: Array[BattleUnit] = targets.duplicate()
	for effect: Dictionary in effects:
		var effect_targets: Array[BattleUnit] = targets
		if effect.get("self_only", false):
			effect_targets = [caster]
		elif effect.has("target"):
			effect_targets = _attack_targets(caster, effect.target)
		elif target_type == "random_enemy" and effect.get("type") == "damage":
			effect_targets = _attack_targets(caster, "random_enemy")
		for t in effect_targets:
			if t not in shown:
				shown.append(t)
		per_effect.append(effect_targets)
	var hit_time := float(atk_data.get("hit_time", DEFAULT_HIT_TIME))
	_emit({
		"type": "attack", "src": caster.uid, "slot": slot, "attack_id": atk_data.get("id", ""),
		"name": atk_data.get("name", ""), "anim": atk_data.get("anim", ""), "clip": atk_data.get("clip", ""),
		"hit_time": float(atk_data.get("hit_times", [hit_time])[0]),
		"hit_times": atk_data.get("hit_times", [hit_time]),
		"targets": shown.map(func(t: BattleUnit) -> int: return t.uid),
	})
	var single := target_type in ["single_enemy", "lowest_hp_enemy", "random_enemy"]
	var dealt := 0.0
	for i in effects.size():
		dealt += _apply_effect(caster, effects[i], per_effect[i], single)
	# Le vol de vie se calcule après tous les coups de l'attaque.
	for e: Dictionary in effects:
		if e.get("type") == "lifesteal" and dealt > 0.0:
			_heal(caster, caster, dealt * float(e.get("ratio", 0.2)))
	if slot != BattleUnit.SLOT_ULTIMATE:
		caster.add_energy(ENERGY_ON_ATTACK)


## Applique un effet à ses cibles. Renvoie les dégâts infligés (pour le vol de vie).
func _apply_effect(caster: BattleUnit, effect: Dictionary, targets: Array, single: bool) -> float:
	var power: float = effect.get("power", 1.0)
	var stat_name: String = effect.get("stat", "mag" if caster.attack_kind == "magic" else "atk")
	var dealt := 0.0
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		# Effet conditionnel : seulement sur une cible qui porte cet état (et le consomme).
		var cond: String = effect.get("if_status", "")
		if cond != "" and not t.has_status(cond):
			continue
		match effect.get("type", ""):
			"damage":
				var p := power
				var bonus_on: String = effect.get("bonus_if", "")
				if bonus_on != "" and t.has_status(bonus_on):
					p *= 1.0 + float(effect.get("bonus", 0.0))
					if effect.get("consume", false):
						t.statuses.erase(bonus_on)
				dealt += _hit(caster, t, p, effect.get("kind", caster.attack_kind), stat_name, single)
			"heal":
				_heal(caster, t, caster.stat(stat_name) * power * _variance())
			"shield":
				var amount := caster.stat(stat_name) * power
				t.shield += amount
				_emit({"type": "shield", "dst": t.uid, "amount": amount})
			"taunt":
				var who: BattleUnit = caster if effect.get("self_only", false) or t.team == caster.team else t
				who.taunt_time = effect.get("duration", 5.0)
				_emit({"type": "status", "dst": who.uid, "status": "taunt", "duration": who.taunt_time})
			"stun":
				var duration: float = effect.get("duration", 1.0)
				if t.is_boss:
					# Les boss ne perdent pas leur action : leur jauge recule un peu à la place.
					t.gauge = maxf(0.0, t.gauge - 0.1 * BattleUnit.GAUGE_MAX)
					_emit({"type": "status", "dst": t.uid, "status": "retard", "duration": 0.0})
				else:
					t.stun_time = maxf(t.stun_time, duration)
					_emit({"type": "status", "dst": t.uid, "status": "stun", "duration": t.stun_time,
						"label": effect.get("label", "")})
			"dot":
				var duration: float = effect.get("duration", 3.0)
				var dot_name: String = effect.get("name", "dot")
				t.dots.append({"dps": caster.stat(stat_name) * power, "time": duration, "src": caster.uid, "name": dot_name})
				t.statuses[dot_name] = maxf(t.statuses.get(dot_name, 0.0), duration)
				_emit({"type": "status", "dst": t.uid, "status": dot_name, "duration": duration})
			"regen":
				var duration: float = effect.get("duration", 4.0)
				t.hots.append({"hps": caster.stat(stat_name) * power / maxf(1.0, duration / 2.0), "time": duration,
					"src": caster.uid})
				_emit({"type": "status", "dst": t.uid, "status": "regen", "duration": duration})
			"status":
				var duration: float = effect.get("duration", 4.0)
				t.statuses[effect.name] = maxf(t.statuses.get(effect.name, 0.0), duration)
				_emit({"type": "status", "dst": t.uid, "status": effect.name, "duration": duration})
			"buff":
				var duration: float = effect.get("duration", 4.0)
				t.mods.append({"stat": effect.stat, "amount": float(effect.amount), "time": duration})
				var tag: String = effect.get("status", "")
				if tag == "":
					tag = ("buff_" if float(effect.amount) > 0.0 else "debuff_") + String(effect.stat)
				t.statuses[tag] = maxf(t.statuses.get(tag, 0.0), duration)
				_emit({"type": "status", "dst": t.uid, "status": tag, "duration": duration})
			"gauge":
				t.gauge = clampf(t.gauge + float(effect.get("amount", -0.1)) * BattleUnit.GAUGE_MAX, 0.0,
					BattleUnit.GAUGE_MAX)
				_emit({"type": "status", "dst": t.uid, "status": "retard", "duration": 0.0})
			"cleanse":
				t.dots.clear()
				t.stun_time = 0.0
				for bad in ["aveugle", "enracine", "brulure", "poison", "armure_reduite", "desequilibre"]:
					t.statuses.erase(bad)
				t.mods = t.mods.filter(func(m: Dictionary) -> bool: return float(m.amount) > 0.0)
		if cond != "" and effect.get("consume", false):
			t.statuses.erase(cond)
	return dealt


func _heal(src: BattleUnit, t: BattleUnit, amount: float) -> void:
	if not t.is_alive() or amount <= 0.0:
		return
	t.hp = minf(t.max_hp, t.hp + amount)
	_emit({"type": "heal", "src": src.uid if src else -1, "dst": t.uid, "amount": amount, "hp": t.hp})


## Attaque combinée du quatuor : chaque membre ajoute sa contribution (puissance × sa statistique)
## sur tous les ennemis, chaque contribution étant réduite par la défense de la cible.
func _use_quartet(caster: BattleUnit) -> void:
	quartet_used = true
	var foes := _foes_of(caster)
	var members: Array[BattleUnit] = []
	for m: String in quartet.members:
		members.append(_hero_by_id(m))
	_emit({
		"type": "quartet", "id": quartet.id, "src": caster.uid, "name": quartet.get("attack", ""),
		"clip": quartet.get("clip", ""), "members": members.map(func(u: BattleUnit) -> int: return u.uid),
		"targets": foes.map(func(t: BattleUnit) -> int: return t.uid),
		"hit_times": quartet.get("hit_times", [1.45, 2.5, 3.56, 4.62]),
	})
	var contributions: Dictionary = quartet.get("contributions", {})
	for u in members:
		var c: Array = contributions.get(u.def_id, [1.5, "atk"])
		for t in _foes_of(caster):
			_hit(u, t, float(c[0]), "magic" if c[1] == "mag" else "physical", String(c[1]), false, false)


func _hit(src: BattleUnit, dst: BattleUnit, power: float, kind: String, stat_name := "", single := false,
		can_crit := true) -> float:
	if stat_name == "":
		stat_name = "mag" if kind == "magic" else "atk"
	# Esquive et aveuglement ne concernent que les attaques ciblées ; un leurre absorbe la première.
	if single:
		if dst.has_status("leurre"):
			dst.statuses.erase("leurre")
			_emit({"type": "miss", "src": src.uid, "dst": dst.uid, "reason": "leurre"})
			return 0.0
		var miss := dst.stat("evade") + (0.15 if src.has_status("aveugle") else 0.0)
		if miss > 0.0 and _rng.randf() < miss:
			_emit({"type": "miss", "src": src.uid, "dst": dst.uid, "reason": "esquive"})
			return 0.0
	var mitigation := dst.stat("res") if kind == "magic" else dst.stat("def")
	var elem := Elements.multiplier(src.element, dst.element)
	var is_crit := can_crit and _rng.randf() < src.stat("crit")
	var dmg := src.stat(stat_name) * power * (100.0 / (100.0 + mitigation)) * elem * _variance()
	if is_crit:
		dmg *= CRIT_MULT
	if dst.has_status("garde"):
		dst.statuses.erase("garde")
		dmg *= 0.6
	_apply_damage(src, dst, dmg, is_crit, elem)
	return dmg


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
