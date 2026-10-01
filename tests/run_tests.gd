extends SceneTree
## Tests sans affichage du moteur de combat.
## Lancer : godot --headless --path . --script res://tests/run_tests.gd

const GameDataScript := preload("res://scripts/core/game_data.gd")
const PlayerDataScript := preload("res://scripts/core/player_data.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	test_elements()
	test_battle_is_deterministic()
	test_starter_team_beats_first_dungeon()
	test_special_attacks()
	test_data_is_valid()
	test_progression()
	test_save()
	test_summon()
	test_quests()
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
	return ["corbin", "aegis", "brume", "orage"].map(func(id: String) -> Dictionary: return gd.hero(id))


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
	var foe := e.enemies[e.enemies.size() - 1]
	check(e.set_focus(foe.uid), "le joueur peut cibler un ennemi")
	check(not e.set_focus(hero.uid), "on ne peut pas cibler un allié")
	e.drain_events()
	e.request_attack(hero.uid, BattleUnit.SLOT_BASIC)
	var hit_focus := e.drain_events().any(func(ev: Dictionary) -> bool:
		return ev.type == "attack" and ev.src == hero.uid and ev.targets == [foe.uid])
	check(hit_focus or hero.attacks[0].get("target", "single_enemy") != "single_enemy",
		"l'attaque à cible unique frappe l'ennemi ciblé")
	e.set_focus(foe.uid)
	check(e.focus_uid == -1, "toucher encore le même ennemi enlève la cible")

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
		var anim_player: AnimationPlayer = null
		if d.has("puppet"):
			if not FileAccess.file_exists(String(d.puppet).path_join("puppet.json")):
				problems.append("%s : marionnette introuvable" % id)
			for a: Dictionary in attacks:
				if Puppet2D.normalize(a.get("anim", "")) != a.get("anim", ""):
					problems.append("%s/%s : mouvement de marionnette inconnu %s" % [id, a.get("id"), a.get("anim")])
		else:
			anim_player = _anim_player(d.get("model", ""))
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


func test_progression() -> void:
	print("Progression")
	var gd := _data()
	var cfg: Dictionary = gd.progression
	var curve: Dictionary = cfg.hero_xp
	check(Progression.xp_to_next(curve, 2) > Progression.xp_to_next(curve, 1), "il faut plus d'XP à chaque niveau")
	var r := Progression.add_xp(1, 0, Progression.xp_to_next(curve, 1) + 5, curve, 30)
	check(r.level == 2 and r.xp == 5 and r.gained_levels == 1, "passage au niveau 2 avec le reste d'XP")
	var big := Progression.add_xp(29, 0, 999999, curve, 30)
	check(big.level == 30 and big.xp == 0, "niveau maximum respecté")
	var base: Dictionary = gd.hero("corbin").stats
	var s5 := Progression.stats_at_level(base, 5, cfg.stat_growth)
	check(s5.hp > base.hp and s5.atk > base.atk and s5.spd == base.spd, "les stats montent avec le niveau (sauf la vitesse)")
	var split := Progression.split_rewards({"gold": 250, "xp": 120, "essence_ombre": 3}, cfg)
	check(split.hero_xp == 120 and split.loot.gold == 250 and not split.loot.has("xp"), "partage du butin")
	var e := Progression.regen_energy(10, 60, 1000.0, 1000.0 + 300 * 3 + 10, 300.0)
	check(e.energy == 13 and is_equal_approx(e.last_time, 1900.0), "l'énergie remonte de 1 toutes les 5 min")
	gd.free()


func test_save() -> void:
	print("Sauvegarde")
	var gd := _data()
	var pd: Node = PlayerDataScript.new()
	pd.configure(gd.player_start, gd.progression, gd.dungeons)
	pd.use_memory_only()
	var gold0: int = pd.gold()
	var energy0: int = pd.energy()
	check(pd.team().size() == 4, "équipe de départ de 4 héros")
	check(not pd.toggle_team("recrue"), "pas de héros non possédé dans l'équipe")
	pd.state.heroes["recrue"] = {"level": 1, "xp": 0}
	check(not pd.toggle_team("recrue"), "pas de 5e héros dans l'équipe")
	check(pd.toggle_team("orage") and pd.toggle_team("recrue") and pd.in_team("recrue"), "remplacer un héros de l'équipe")
	check(pd.start_hunt("brumenoire_1") and pd.energy() == energy0 - pd.hunt_cost("brumenoire_1"), "une chasse coûte de l'énergie")
	var res: Dictionary = pd.finish_hunt("brumenoire_1", true, 3, {"gold": 250, "xp": 120, "essence_ombre": 3}, pd.team())
	check(pd.gold() == gold0 + 250 and pd.item_count("essence_ombre") == 3, "victoire : or et essences gagnés")
	check(pd.hero_level("corbin") == 2 and res.heroes.corbin.gained_levels == 1, "victoire : les héros gagnent de l'XP et des niveaux")
	check(pd.best_stars("brumenoire_1") == 3, "meilleures étoiles retenues")
	var lost: Dictionary = pd.finish_hunt("brumenoire_1", false, 0, {}, pd.team())
	check(lost.gold == 0 and pd.gold() == gold0 + 250, "défaite : rien de gagné")
	pd.state.energy = 0
	check(not pd.start_hunt("brumenoire_1"), "pas de chasse sans énergie")
	pd.free()
	gd.free()


func _anim_player(model_path: String) -> AnimationPlayer:
	var scene: PackedScene = load(model_path) if ResourceLoader.exists(model_path) else null
	if scene == null:
		return null
	var model := scene.instantiate()
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	model.queue_free()
	return player


func test_summon() -> void:
	print("Autel des Reliques (invocations)")
	var gd := _data()
	var cfg: Dictionary = gd.summon
	var pd: Node = PlayerDataScript.new()
	pd.configure(gd.player_start, gd.progression, gd.dungeons)
	pd.use_memory_only()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var frag0: int = pd.item_count("fragments_relique")
	# Un héros pas encore possédé, ajouté pour le test (le jeu n'en a pas d'autre pour l'instant).
	var test_pool: Dictionary = gd.heroes.duplicate(true)
	test_pool["recrue"] = {"name": "Recrue", "rarity": 4}
	cfg = cfg.duplicate(true)
	cfg.first_summon = "recrue"
	var first: Dictionary = pd.summon("fragments_relique", cfg, test_pool, rng)
	check(first.get("id") == "recrue" and first.new and pd.owned_heroes().has("recrue"),
		"la première invocation réveille un nouveau héros")
	check(pd.item_count("fragments_relique") == frag0 - pd.summon_cost("fragments_relique", cfg), "les fragments sont dépensés")
	var again: Dictionary = pd.summon("fragments_relique", cfg, gd.heroes, rng)
	check(not again.new and again.shards > 0 and pd.hero_shards(again.id) == again.shards,
		"un héros déjà possédé donne des fragments de ce héros")
	pd.state.items["fragments_relique"] = 0
	check(pd.summon("fragments_relique", cfg, gd.heroes, rng).is_empty(), "pas d'invocation sans fragments")
	# Garantie : au moins un héros Légendaire (rareté 4+) sur `pity_every` invocations.
	var pool: Dictionary = test_pool
	var every := int(cfg.pity_every)
	var ok := true
	var pity := 0
	for i in 300:
		var r := Summon.roll(pool, cfg, 1 + i, pity, rng)
		pity = 0 if r.rarity >= int(cfg.pity_min_rarity) else pity + 1
		ok = ok and pity < every
	check(ok, "garantie : un Légendaire au moins toutes les %d invocations" % every)
	var odds := Summon.odds(pool, cfg)
	var total := 0.0
	for k in odds:
		total += odds[k]
	check(is_equal_approx(total, 100.0), "les taux affichés font 100 %")
	gd.free()
	pd.free()


func test_quests() -> void:
	print("Primes du jour et profil")
	var gd := _data()
	var pd: Node = PlayerDataScript.new()
	pd.configure(gd.player_start, gd.progression, gd.dungeons)
	pd.quests_config = gd.quests
	pd.use_memory_only()
	pd.debug_day = "2026-10-01"
	check(Quests.can_claim(pd.daily(), pd.quest("connexion")), "la connexion du jour compte tout de suite")
	var gold0: int = pd.gold()
	var r: Dictionary = pd.claim_quest("connexion")
	check(r.get("gold", 0) == 100 and pd.gold() == gold0 + 100, "récupérer une prime donne sa récompense")
	check(pd.claim_quest("connexion").is_empty(), "une prime ne se récupère qu'une fois")
	check(pd.claim_quest("chasses").is_empty(), "une prime pas finie ne se récupère pas")
	for i in 3:
		pd.start_hunt("brumenoire_1")
		pd.finish_hunt("brumenoire_1", true, 3, gd.dungeon_rewards("brumenoire_1", 3), pd.team())
	check(not pd.claim_quest("chasses").is_empty() and not pd.claim_quest("trois_etoiles").is_empty(),
		"3 chasses gagnées (avec 3 étoiles) remplissent leurs primes")
	check(pd.daily().progress.get("energy_spent", 0) == 3 * pd.hunt_cost("brumenoire_1"), "l'énergie dépensée est comptée")
	check(not pd.open_chest(0).is_empty(), "le premier coffre s'ouvre avec assez de points")
	check(pd.open_chest(3).is_empty(), "le dernier coffre reste fermé sans assez de points")
	pd.record_event("guild_help")
	check(not Quests.can_claim(pd.daily(), pd.quest("guilde")), "une prime « bientôt disponible » ne se récupère pas")
	var available := 0
	for q: Dictionary in gd.quests.quests:
		if Quests.is_available(q):
			available += int(q.points)
	check(available >= int(gd.quests.chests[-1].points), "tous les coffres sont atteignables avec les primes disponibles")
	pd.debug_day = "2026-10-02"
	check(pd.daily().claimed.is_empty() and Quests.can_claim(pd.daily(), pd.quest("connexion")), "nouvelles primes le lendemain")
	check(pd.stat("hunts_won") == 3 and pd.stat("days_played") == 2, "statistiques du profil")
	check(not pd.rename("Hu", "Loge") and pd.rename("Hugo", "Loge des Braves") and pd.player_name() == "Hugo",
		"renommer le joueur (3 à 16 lettres)")
	pd.set_avatar("brume")
	check(pd.avatar() == "brume", "choisir le héros du profil")
	gd.free()
	pd.free()
