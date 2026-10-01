extends SceneTree
## Tests sans affichage du moteur de combat.
## Lancer : godot --headless --path . --script res://tests/run_tests.gd

const GameDataScript := preload("res://scripts/core/game_data.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_elements()
	test_battle_is_deterministic()
	test_starter_team_beats_first_dungeon()
	test_special_attacks()
	test_data_is_valid()
	print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  OK   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)


func _data() -> Node:
	var gd: Node = GameDataScript.new()
	gd.reload()
	return gd


func _team(gd: Node) -> Array:
	return ["torvald", "kaito", "vesprin", "orage"].map(func(id: String) -> Dictionary: return gd.hero(id))


func test_elements() -> void:
	print("Éléments")
	check(Elements.multiplier("feu", "nature") == Elements.ADVANTAGE, "feu bat nature")
	check(Elements.multiplier("nature", "feu") == Elements.DISADVANTAGE, "nature perd contre feu")
	check(Elements.multiplier("eau", "feu") == Elements.ADVANTAGE, "eau bat feu")
	check(Elements.multiplier("lumiere", "ombre") == Elements.ADVANTAGE, "lumière bat ombre")
	check(Elements.multiplier("ombre", "lumiere") == Elements.ADVANTAGE, "ombre bat lumière")
	check(Elements.multiplier("feu", "feu") == 1.0, "neutre")


func test_battle_is_deterministic() -> void:
	print("Déterminisme")
	var gd := _data()
	var a := BattleEngine.new()
	a.setup(_team(gd), gd.dungeon_waves("brumenoire_1"), 42)
	a.simulate()
	var b := BattleEngine.new()
	b.setup(_team(gd), gd.dungeon_waves("brumenoire_1"), 42)
	b.simulate()
	check(a.won == b.won and is_equal_approx(a.time, b.time), "même graine => même combat")
	gd.free()


func test_starter_team_beats_first_dungeon() -> void:
	print("Équilibrage")
	var gd := _data()
	var wins := 0
	var total_time := 0.0
	var stars_total := 0
	for s in 20:
		var e := BattleEngine.new()
		e.setup(_team(gd), gd.dungeon_waves("brumenoire_1"), s)
		if e.simulate():
			wins += 1
		stars_total += e.stars()
		total_time += e.time
	print("    victoires : %d/20, durée moyenne : %.1f s, étoiles moyennes : %.1f" % [wins, total_time / 20.0, stars_total / 20.0])
	var e3 := BattleEngine.new()
	e3.setup(_team(gd), gd.dungeon_waves("brumenoire_1"), 3)
	e3.won = true
	check(e3.stars() == 3, "victoire sans perte = 3 étoiles")
	e3.heroes[0].hp = 0.0
	check(e3.stars() == 2, "un héros tombé = 2 étoiles")
	e3.heroes[1].hp = 0.0
	check(e3.stars() == 1, "deux héros tombés = 1 étoile")
	e3.won = false
	check(e3.stars() == 0, "défaite = 0 étoile")
	check(gd.dungeon_rewards("brumenoire_1", 0).is_empty(), "défaite = pas de butin")
	check(gd.dungeon_rewards("brumenoire_1", 3).get("gold", 0) > 0, "victoire = de l'or")
	check(wins >= 14, "l'équipe de départ gagne le 1er donjon la plupart du temps")
	check(total_time / 20.0 > 20.0 and total_time / 20.0 < 150.0, "durée de combat raisonnable (20 à 150 s)")
	gd.free()


func test_special_attacks() -> void:
	print("Tour par tour et attaques")
	var gd := _data()
	var e := BattleEngine.new()
	e.setup(_team(gd), gd.dungeon_waves("brumenoire_1"), 7)
	check(e.heroes[1].attacks.size() == 3, "un héros a 3 attaques")
	var hero := _wait_turn(e)
	check(hero != null, "le combat attend le choix du joueur quand la jauge d'un héros est pleine")
	if hero == null:
		gd.free()
		return
	var frozen_time := e.time
	e.step(0.5)
	check(is_equal_approx(e.time, frozen_time), "le combat est figé pendant le choix")
	var other := e.heroes[0] if e.heroes[0] != hero else e.heroes[1]
	check(not e.request_attack(other.uid, BattleUnit.SLOT_BASIC), "un autre héros ne peut pas jouer")
	check(not e.request_attack(hero.uid, BattleUnit.SLOT_ULTIMATE), "ultime refusée sans énergie")
	check(not e.request_attack(hero.uid, BattleUnit.SLOT_COOLDOWN), "attaque à recharge pas prête au début")
	check(e.request_attack(hero.uid, BattleUnit.SLOT_BASIC), "attaque de base acceptée")
	var basic := e.drain_events().any(func(ev: Dictionary) -> bool:
		return ev.type == "attack" and ev.src == hero.uid and ev.slot == BattleUnit.SLOT_BASIC)
	check(basic and e.awaiting_uid == -1, "l'attaque part et le combat reprend")

	hero = _wait_turn(e)
	hero.energy = BattleUnit.ENERGY_MAX
	check(e.request_attack(hero.uid, BattleUnit.SLOT_ULTIMATE), "ultime acceptée avec énergie pleine")
	check(hero.energy < BattleUnit.ENERGY_MAX, "l'énergie est consommée")

	hero = _wait_turn(e)
	hero.cooldowns[BattleUnit.SLOT_COOLDOWN] = 0.0
	check(e.request_attack(hero.uid, BattleUnit.SLOT_COOLDOWN), "attaque à recharge prête après la recharge")
	check(hero.cooldowns[BattleUnit.SLOT_COOLDOWN] > 0.0, "la recharge repart après usage")
	check(hero.energy_cost(BattleUnit.SLOT_COOLDOWN) == 0.0, "l'attaque à recharge ne coûte pas d'énergie")

	hero = _wait_turn(e)
	e.auto_mode = true
	e.step(0.05)
	check(e.awaiting_uid != hero.uid, "activer Auto joue le tour en attente")
	gd.free()


## Fait avancer le combat jusqu'au tour d'un héros ; renvoie ce héros (ou null).
func _wait_turn(e: BattleEngine) -> BattleUnit:
	for i in 2000:
		if e.awaiting_uid != -1:
			return e.get_unit(e.awaiting_uid)
		if e.finished:
			return null
		e.step(0.05)
		e.drain_events()
	return null


## Vérifie les fichiers JSON : 3 attaques par héros, cibles et effets connus, animations présentes.
func test_data_is_valid() -> void:
	print("Données")
	var gd := _data()
	var targets := ["single_enemy", "all_enemies", "lowest_hp_enemy", "all_allies", "lowest_hp_ally", "self"]
	var effects := ["damage", "heal", "shield", "taunt", "stun", "dot", "cleanse"]
	var problems: Array[String] = []
	var all_units: Dictionary = {}
	all_units.merge(gd.heroes)
	all_units.merge(gd.monsters)
	for id: String in all_units:
		var d: Dictionary = all_units[id]
		var attacks: Array = d.get("attacks", [])
		if id in gd.heroes and attacks.size() != 3:
			problems.append("%s : %d attaque(s) au lieu de 3" % [id, attacks.size()])
		var anim_player := _anim_player(d.get("model", ""))
		if anim_player == null:
			problems.append("%s : modèle introuvable" % id)
		for a: Dictionary in attacks:
			for fx: Dictionary in a.get("effects", []):
				if fx.has("target") and fx.target not in targets:
					problems.append("%s/%s : cible d'effet inconnue %s" % [id, a.get("id"), fx.target])
			if a.get("target", "single_enemy") not in targets:
				problems.append("%s/%s : cible inconnue %s" % [id, a.get("id"), a.get("target")])
			for fx: Dictionary in a.get("effects", []):
				if fx.get("type") not in effects:
					problems.append("%s/%s : effet inconnu %s" % [id, a.get("id"), fx.get("type")])
			if anim_player and not anim_player.has_animation(a.get("anim", "")):
				problems.append("%s/%s : animation absente %s" % [id, a.get("id"), a.get("anim")])
	for p in problems:
		printerr("    ", p)
	check(problems.is_empty(), "héros et monstres valides (attaques, cibles, effets, animations)")
	gd.free()


func _anim_player(model_path: String) -> AnimationPlayer:
	var scene: PackedScene = load(model_path) if ResourceLoader.exists(model_path) else null
	if scene == null:
		return null
	var model := scene.instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	model.queue_free()
	return player
