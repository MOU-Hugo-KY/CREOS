class_name BattleUnit
extends RefCounted
## Une unité en combat (héros ou monstre). Logique pure, aucun affichage.
##
## Chaque unité a jusqu'à 3 attaques (`attacks` dans le JSON) :
##   [0] attaque de base : part toute seule quand la jauge d'action est pleine ;
##   [1] attaque à recharge : `"cooldown"` en secondes ;
##   [2] attaque ultime : coûte `"energy"` (100 par défaut si pas de recharge).

const GAUGE_MAX := 1000.0
const ENERGY_MAX := 100.0
const SLOT_BASIC := 0
const SLOT_COOLDOWN := 1
const SLOT_ULTIMATE := 2

var uid: int
var def_id: String
var display_name: String
var team: int  # 0 = héros du joueur, 1 = ennemis
var slot: int  # position dans l'équipe (0 = devant)
var element: String
var unit_class: String
var range_type: String
var attack_kind: String
var is_boss := false
var attacks: Array[Dictionary] = []
var cooldowns: Array[float] = []  # temps restant avant de pouvoir relancer chaque attaque

var max_hp: float
var hp: float
var atk: float
var def: float
var res: float
var spd: float
var crit: float

var gauge := 0.0
var energy := 0.0
var shield := 0.0
var taunt_time := 0.0
var stun_time := 0.0
var dots: Array = []  # [{dps, time, src, acc}]


static func from_data(p_uid: int, p_def_id: String, data: Dictionary, p_team: int, p_slot: int) -> BattleUnit:
	var u := BattleUnit.new()
	u.uid = p_uid
	u.def_id = p_def_id
	u.display_name = data.get("name", p_def_id)
	u.team = p_team
	u.slot = p_slot
	u.element = data.get("element", "")
	u.unit_class = data.get("class", "")
	u.range_type = data.get("range", "melee")
	u.attack_kind = data.get("attack_kind", "physical")
	u.is_boss = data.get("boss", false)
	for a: Dictionary in data.get("attacks", []):
		u.attacks.append(a)
		# Une attaque à recharge n'est pas disponible dès le début du combat.
		u.cooldowns.append(float(a.get("cooldown", 0.0)))
	var s: Dictionary = data.get("stats", {})
	u.max_hp = s.get("hp", 100)
	u.hp = u.max_hp
	u.atk = s.get("atk", 10)
	u.def = s.get("def", 0)
	u.res = s.get("res", 0)
	u.spd = s.get("spd", 100)
	u.crit = s.get("crit", 0.0)
	return u


func is_alive() -> bool:
	return hp > 0.0


func has_attack(index: int) -> bool:
	return index >= 0 and index < attacks.size()


## Énergie nécessaire pour l'attaque `index` (0 pour l'attaque de base et les attaques à recharge).
func energy_cost(index: int) -> float:
	if not has_attack(index) or index == SLOT_BASIC:
		return 0.0
	var a := attacks[index]
	if a.has("energy"):
		return float(a.energy)
	return 0.0 if a.has("cooldown") else ENERGY_MAX


## Vrai si l'attaque spéciale `index` (1 ou 2) peut partir maintenant.
func attack_ready(index: int) -> bool:
	if index == SLOT_BASIC or not has_attack(index) or not is_alive() or stun_time > 0.0:
		return false
	return cooldowns[index] <= 0.0 and energy >= energy_cost(index)


func uses_energy() -> bool:
	for i in attacks.size():
		if energy_cost(i) > 0.0:
			return true
	return false


func add_energy(amount: float) -> void:
	if uses_energy():
		energy = minf(ENERGY_MAX, energy + amount)


func tick_cooldowns(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
