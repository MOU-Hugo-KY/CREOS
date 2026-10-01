class_name BattleUnit
extends RefCounted
## Une unité en combat (héros ou monstre). Logique pure, aucun affichage.

const GAUGE_MAX := 1000.0
const ENERGY_MAX := 100.0

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
var skill: Dictionary = {}

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
var dots: Array = []  # [{dps, time, src}]


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
	u.skill = data.get("skill", {})
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


func has_skill() -> bool:
	return not skill.is_empty()


func skill_ready() -> bool:
	return has_skill() and energy >= ENERGY_MAX and stun_time <= 0.0 and is_alive()


func add_energy(amount: float) -> void:
	if has_skill():
		energy = minf(ENERGY_MAX, energy + amount)
