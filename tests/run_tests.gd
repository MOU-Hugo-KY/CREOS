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
	test_hero_upgrades()
	test_quartet()
	test_team_combos()
	test_lodge()
	test_formation_lines()
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
	a.setup(_team(gd), gd.dungeon_waves("monde01_1"), 42)
	a.simulate()
	var b := BattleEngine.new()
	b.setup(_team(gd), gd.dungeon_waves("monde01_1"), 42)
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
		e.setup(_team(gd), gd.dungeon_waves("monde01_1"), s)
		if e.simulate():
			wins += 1
		stars_total += e.stars()
		total_time += e.time
	print("    victoires : %d/20, durée moyenne : %.1f s, étoiles moyennes : %.1f" % [wins, total_time / 20.0, stars_total / 20.0])
	var e3 := BattleEngine.new()
	e3.setup(_team(gd), gd.dungeon_waves("monde01_1"), 3)
	e3.won = true
	check(e3.stars() == 3, "victoire sans perte = 3 étoiles")
	e3.heroes[0].hp = 0.0
	check(e3.stars() == 2, "un héros tombé = 2 étoiles")
	e3.heroes[1].hp = 0.0
	check(e3.stars() == 1, "deux héros tombés = 1 étoile")
	e3.won = false
	check(e3.stars() == 0, "défaite = 0 étoile")
	check(gd.dungeon_rewards("monde01_1", 0).is_empty(), "défaite = pas de butin")
	check(gd.dungeon_rewards("monde01_1", 3).get("gold", 0) > 0, "victoire = de l'or")
	check(wins >= 14, "l'équipe de départ gagne le 1er donjon la plupart du temps")
	check(total_time / 20.0 > 20.0 and total_time / 20.0 < 150.0, "durée de combat raisonnable (20 à 150 s)")
	gd.free()


func test_special_attacks() -> void:
	print("Tour par tour et attaques")
	var gd := _data()
	var e := BattleEngine.new()
	e.setup(_team(gd), gd.dungeon_waves("monde01_1"), 7)
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
	var reach := e.reachable(hero, e.enemies)
	var foe := reach[reach.size() - 1]
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
	var targets := ["single_enemy", "all_enemies", "lowest_hp_enemy", "all_allies", "lowest_hp_ally", "self",
		"random_enemy", "two_enemies"]
	var effects := ["damage", "heal", "shield", "taunt", "stun", "dot", "cleanse", "status", "buff", "regen",
		"gauge", "lifesteal"]
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
		if d.has("anim"):
			# Animations 2D en pièces détachées (clips importés par tools/import_creos_packs.py).
			var states := ["idle", "hurt", "death"]
			for st: String in states:
				if not FileAccess.file_exists(String(d.anim) + "clips/%s_%s.json" % [id, st]):
					problems.append("%s : clip %s absent" % [id, st])
			for a: Dictionary in attacks:
				if not FileAccess.file_exists(String(d.anim) + "clips/%s.json" % a.get("clip", "?")):
					problems.append("%s/%s : clip d'attaque absent %s" % [id, a.get("id"), a.get("clip")])
		else:
			problems.append("%s : pas d'animations (\"anim\")" % id)
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
	# Rareté : en moyenne, au même niveau, légendaire > épique > rare.
	var avg := {}
	for id: String in gd.heroes:
		var h: Dictionary = gd.heroes[id]
		var rar := int(h.get("rarity", 3))
		var pw := Progression.power(Progression.hero_stats(h, 30, 0, cfg))
		avg[rar] = avg.get(rar, []) + [pw]
	var mean := func(a: Array) -> float: return float(a.reduce(func(x, y): return x + y, 0)) / a.size()
	check(mean.call(avg[4]) > mean.call(avg[3]) and mean.call(avg[3]) > mean.call(avg[2]),
		"les légendaires sont plus forts que les épiques, eux-mêmes plus forts que les rares")
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
	check(pd.toggle_team("recrue") and pd.team().size() == 5, "un 5e héros rejoint l'équipe (jusqu'à 8)")
	check(pd.toggle_team("recrue") and not pd.in_team("recrue"), "retirer un héros de l'équipe")
	check(pd.start_hunt("monde01_1") and pd.energy() == energy0 - pd.hunt_cost("monde01_1"), "une chasse coûte de l'énergie")
	var res: Dictionary = pd.finish_hunt("monde01_1", true, 3, {"gold": 250, "xp": 120, "essence_ombre": 3}, pd.team())
	var chest_gold := int(res.get("chest", {}).get("rewards", {}).get("gold", 0))
	check(pd.gold() == gold0 + 250 + chest_gold and pd.item_count("essence_ombre") == 3, "victoire : or et essences gagnés")
	check(res.get("chest", {}).get("kind", "") == "fer", "premier coffre de campagne garanti en fer")
	check(pd.hero_level("corbin") == 2 and res.heroes.corbin.gained_levels == 1, "victoire : les héros gagnent de l'XP et des niveaux")
	check(pd.best_stars("monde01_1") == 3, "meilleures étoiles retenues")
	var lost: Dictionary = pd.finish_hunt("monde01_1", false, 0, {}, pd.team())
	check(lost.gold == 0 and pd.gold() == gold0 + 250 + chest_gold and not lost.has("chest"), "défaite : rien de gagné")
	# Éveil : au niveau 10, le héros doit nourrir des Esprits pour continuer.
	pd.state.heroes["recrue"] = {"level": 10, "xp": 0, "awakened": 0}
	for item: String in pd.state.items.keys():
		if item.begins_with("esprit_"):
			pd.state.items.erase(item)  # le coffre gagné plus haut a pu en donner
	var hero := {"element": "feu"}
	check(pd.hero_needs_awakening("recrue") and pd.hero_level_cap("recrue") == 10, "niveau 10 : éveil nécessaire")
	pd.state.gold = 100000
	check(not pd.level_up_hero("recrue"), "pas de niveau 11 sans éveil")
	check(not pd.can_awaken("recrue", hero), "pas d'éveil sans Esprits")
	pd.state.items["esprit_oeuf_feu"] = 3
	check(pd.awaken_hero("recrue", hero) and pd.item_count("esprit_oeuf_feu") == 0, "éveil avec 3 Œufs de feu")
	check(pd.level_up_hero("recrue") and pd.hero_level("recrue") == 11, "après l'éveil, le niveau 11")
	var cfg: Dictionary = pd._config
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kinds := {}
	for i in 400:
		kinds[Progression.roll_chest(3, cfg, rng, 5, 0, "feu").kind] = true
	check(kinds.has("bois") and kinds.has("or"), "les coffres varient selon la chance")
	check(Progression.roll_chest(1, cfg, rng, 5, 29, "feu").kind == "serment", "coffre du Serment garanti après 30 coffres")
	check(Progression.awaken_cost(20, "feu", cfg).get("esprit_oeuf_lumiere", 0) == 2, "l'éveil demande aussi un deuxième élément")
	pd.state.items["esprit_oeuf_eau"] = 6
	check(pd.fuse_esprit("esprit_oeuf_eau") and pd.item_count("esprit_petit_eau") >= 1 and pd.item_count("esprit_oeuf_eau") == 1,
		"fusion : 5 Œufs donnent 1 Petit")
	check(not pd.fuse_esprit("esprit_oeuf_eau"), "pas de fusion sans 5 Esprits")
	pd.state.energy = 0
	check(not pd.start_hunt("monde01_1"), "pas de chasse sans énergie")
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
	var owned_pool: Dictionary = {}
	for id: String in pd.owned_heroes():
		owned_pool[id] = test_pool[id]
	var again: Dictionary = pd.summon("fragments_relique", cfg, owned_pool, rng)
	check(not again.new and again.echoes == 1 and pd.hero_echoes(again.id) == 1,
		"un héros déjà possédé revient en Écho")
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
		pd.start_hunt("monde01_1")
		pd.finish_hunt("monde01_1", true, 3, gd.dungeon_rewards("monde01_1", 3), pd.team())
	check(not pd.claim_quest("chasses").is_empty() and not pd.claim_quest("trois_etoiles").is_empty(),
		"3 chasses gagnées (avec 3 étoiles) remplissent leurs primes")
	check(pd.daily().progress.get("energy_spent", 0) == 3 * pd.hunt_cost("monde01_1"), "l'énergie dépensée est comptée")
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


func test_hero_upgrades() -> void:
	print("Amélioration et évolution des héros")
	var gd := _data()
	var pd: Node = PlayerDataScript.new()
	pd.configure(gd.player_start, gd.progression, gd.dungeons)
	pd.use_memory_only()
	var gold0: int = pd.gold()
	var cost: int = pd.hero_level_up_cost("aegis")
	check(pd.level_up_hero("aegis") and pd.hero_level("aegis") == 2 and pd.gold() == gold0 - cost, "améliorer un héros coûte de l'or et donne un niveau")
	pd.state.gold = 0
	check(not pd.level_up_hero("aegis"), "pas d'amélioration sans or")
	# Échos : paliers 1, 3, 6, 9, 12 ; ils renforcent surtout la statistique principale.
	var h: Dictionary = gd.hero("aegis")
	var s0 := Progression.hero_stats(h, 1, 0, gd.progression)
	var s1 := Progression.hero_stats(h, 1, 1, gd.progression)
	var s3 := Progression.hero_stats(h, 1, 3, gd.progression)
	check(Progression.echo_tier(0, gd.progression) == 0 and Progression.echo_tier(3, gd.progression) == 2
		and Progression.echo_tier(12, gd.progression) == 5, "paliers d'Échos 1/3/6/9/12")
	check(s1.atk > s0.atk and s3.atk > s1.atk and s1.spd == s0.spd, "les Échos renforcent le héros (pas sa vitesse)")
	check((s1.atk / s0.atk) > (s1.mag / s0.mag), "la statistique principale gagne le plus")
	# Technique secrète : 4e attaque à 6 Échos, celle de la voie active.
	check(Progression.hero_for_battle(h, 1, gd.progression, 5).attacks.size() == 3, "pas de technique secrète avant 6 Échos")
	var with_secret := Progression.hero_for_battle(h, 1, gd.progression, 6, 0, 1)
	check(with_secret.attacks.size() == 4 and with_secret.attacks[3].clip == "aegis_4", "à 6 Échos, la technique secrète de la voie active")
	# Reliques : 100 fragments pour la retrouver, puis fragments + matériaux pour chaque palier.
	check(not pd.upgrade_relic("aegis"), "pas de relique sans fragments")
	pd.state.items["relique_aegis"] = 110
	pd.state.items["materiaux_relique"] = 20
	check(not pd.relics_unlocked() and not pd.upgrade_relic("aegis"), "reliques scellées avant la fin de la Campagne 1")
	check(not pd.filter_locked_loot({"relique_aegis": 3, "gold": 5}, "monde10_8").has("relique_aegis"), "jamais de fragments de relique en Campagne 1")
	check(pd.filter_locked_loot({"relique_aegis": 3}, "monde01_h1").has("relique_aegis"), "fragments de relique en Campagne 2")
	pd.state.dungeons[pd.RELIC_UNLOCK_DUNGEON] = {"stars": 1}
	check(pd.upgrade_relic("aegis") and pd.relic_tier("aegis") == 1 and pd.relic_fragments("aegis") == 10, "relique retrouvée contre 100 fragments")
	check(pd.upgrade_relic("aegis") and pd.relic_tier("aegis") == 2 and pd.item_count("materiaux_relique") == 0, "relique restaurée contre fragments et matériaux")
	var r2 := Progression.hero_stats(h, 1, 0, gd.progression, 2)
	check(r2.atk > s0.atk, "la relique renforce le héros")
	# Campagne : un niveau s'ouvre quand le précédent est gagné.
	var order: Array = pd.campaign_order()
	check(order[0] == "monde01_1" and pd.dungeon_unlocked("monde01_1") and not pd.dungeon_unlocked(order[1]), "seul le premier niveau est ouvert au début")
	pd.state.dungeons[order[0]] = {"stars": 1}
	check(pd.dungeon_unlocked(order[1]) and pd.current_campaign_level() == order[1], "gagner un niveau ouvre le suivant")
	# Marchand
	pd.state.gems = 100
	var energy0: int = pd.energy()
	check(pd.buy(gd.hub.shop[0]) and pd.gems() == 70 and pd.energy() == energy0 + 30, "le Marchand vend de l'énergie contre des gemmes")
	pd.free()
	gd.free()


func test_quartet() -> void:
	print("Quatuor (attaque combinée)")
	var gd := _data()
	var team: Array = ["mei_lian", "jin_seok", "yun_tao", "tang_su"].map(func(id: String) -> Dictionary: return gd.hero(id))
	var e := BattleEngine.new()
	e.setup(team, gd.dungeon_waves("monde01_1"), 5, gd.quartets())
	check(e.quartet.get("id", "") == "murim", "les quatre membres forment le quatuor Murim")
	check(not e.quartet_ready(), "pas de quatuor avant que chacun ait lancé son ultime")
	var hero := _wait_turn(e)
	for h in e.heroes:
		h.used_ultimate = true
	check(hero != null and e.quartet_ready(), "quatuor prêt quand les quatre ont lancé leur ultime")
	var hp_before := 0.0
	for en in e.enemies:
		hp_before += en.hp
	check(e.request_quartet(hero.uid), "le héros dont c'est le tour lance le quatuor")
	var evs := e.drain_events()
	check(evs.any(func(ev: Dictionary) -> bool: return ev.type == "quartet"), "événement « quartet » émis")
	var hp_after := 0.0
	for en in e.enemies:
		hp_after += en.hp
	check(hp_after < hp_before and not e.quartet_ready(), "le quatuor frappe tous les ennemis, une seule fois par combat")
	var other := BattleEngine.new()
	other.setup(_team(gd), gd.dungeon_waves("monde01_1"), 5, gd.quartets())
	check(other.quartet.is_empty(), "pas de quatuor sans ses quatre membres")
	gd.free()


func test_team_combos() -> void:
	print("Équipe de 7, duos, trios et synergies")
	var gd := _data()
	var ids := ["corbin", "nyx", "rivet", "aegis", "bastion", "nacre", "valen"]
	var team: Array = ids.map(func(id: String) -> Dictionary:
		var d: Dictionary = gd.hero(id).duplicate(true)
		d["id"] = id
		return d)
	var waves: Array = gd.dungeon_waves_for("monde01_1", team.size())
	check(waves[0].size() > gd.dungeon_waves("monde01_1")[0].size(), "une équipe de 7 affronte des vagues plus fournies")
	var e := BattleEngine.new()
	e.setup(team, waves, 3, gd.team_combos(), gd.synergies())
	check(e.heroes.size() == 7, "7 héros au combat")
	var combo_ids: Array = e.combos.map(func(c: Dictionary) -> String: return c.id)
	check("crocs_jumeaux" in combo_ids and "nuit_sans_lune" in combo_ids and "aube" in combo_ids,
		"duos et trios formés par l'équipe")
	check(e.combos[0].members.size() >= e.combos[-1].members.size(), "les plus grands combos d'abord")
	var names: Array = e.synergies.map(func(s: Dictionary) -> String: return s.key)
	check("lumiere" in names and "ombre" in names and "gardien" in names, "synergies d'élément et de classe actives")
	var aegis: BattleUnit = e._hero_by_id("aegis")
	check(aegis.stat("def") > aegis.def, "une synergie augmente la statistique")
	var hero := _wait_turn(e)
	for h in e.heroes:
		h.used_ultimate = true
	check(hero != null and "crocs_jumeaux" in e.ready_combos(), "duo prêt quand ses membres ont lancé leur ultime")
	check(e.request_combo(hero.uid, "aube"), "le héros dont c'est le tour lance un trio")
	var evs := e.drain_events()
	check(evs.any(func(ev: Dictionary) -> bool: return ev.type == "shield"), "le trio de l'aube protège l'équipe")
	check(not e.combo_ready("aube") and e.combo_ready("crocs_jumeaux"), "chaque combo une fois par combat, les autres restent prêts")
	gd.free()


func test_lodge() -> void:
	print("Ma Loge : salles, pièges, rivaux")
	var gd := _data()
	var cfg: Dictionary = gd.lodge
	var st := Lodge.empty_state(cfg)
	check(st.rooms.size() == 3 and not Lodge.is_ready(st), "trois salles vides, donjon pas encore prêt")
	check(Lodge.add_defender(st, cfg, 0, "bastion") and not Lodge.add_defender(st, cfg, 1, "bastion"),
		"un héros ne défend qu'une salle")
	Lodge.add_defender(st, cfg, 0, "aegis")
	Lodge.add_defender(st, cfg, 0, "kharok")
	check(not Lodge.add_defender(st, cfg, 0, "nyx"), "salle pleine")
	Lodge.add_defender(st, cfg, 1, "nyx")
	Lodge.add_defender(st, cfg, 2, "valen")
	check(Lodge.is_ready(st), "un défenseur par salle : donjon prêt")
	check(Lodge.toggle_trap(st, cfg, 0, "pieux") and Lodge.toggle_trap(st, cfg, 0, "brasero")
		and not Lodge.toggle_trap(st, cfg, 0, "gaz"), "deux pièges au plus par salle")
	check(Lodge.can_attack(500, 600) and Lodge.can_attack(600, 600) and not Lodge.can_attack(700, 600),
		"seules les équipes moins fortes ou aussi fortes peuvent attaquer")
	# Combat : les pièges de la première salle frappent les héros dès l'entrée.
	var hero_data := func(id: String) -> Dictionary: return gd.hero(id).duplicate(true)
	var e := BattleEngine.new()
	e.setup(_team(gd), Lodge.waves(st.rooms, hero_data), 7, {}, {}, Lodge.wave_traps(st.traps, cfg))
	var evs := e.drain_events()
	var traps := evs.filter(func(ev: Dictionary) -> bool: return ev.type == "trap")
	check(traps.size() == 2, "les deux pièges se déclenchent à l'entrée de la salle")
	check(e.heroes[0].hp < e.heroes[0].max_hp and e.heroes[3].hp == e.heroes[3].max_hp,
		"les pieux ne touchent que les héros de devant")
	check(e.heroes.all(func(u: BattleUnit) -> bool: return u.has_status("brulure")), "le brasero brûle toute l'équipe")
	check(e.enemies.size() == 3 and e.enemies[0].def_id == "bastion", "les défenseurs sont les héros de la salle")
	e.simulate()
	check(e.finished, "le combat de Loge va jusqu'au bout")
	# Rivaux du jour : déterministes et attaquables par l'équipe.
	var power_at := func(id: String, level: int) -> int:
		return Progression.power(Progression.hero_stats(gd.hero(id), level, 0, gd.progression))
	var r1 := Lodge.rivals("2026-10-07", 700, gd.heroes.keys(), cfg, power_at)
	var r2 := Lodge.rivals("2026-10-07", 700, gd.heroes.keys(), cfg, power_at)
	check(r1.size() == 3 and r1[0].name == r2[0].name and r1[0].rooms == r2[0].rooms, "les rivaux du jour sont toujours les mêmes")
	check(r1.all(func(r: Dictionary) -> bool: return Lodge.can_attack(700, int(r.power)) and int(r.stake) > 0),
		"chaque rival peut être attaqué et met une récompense en jeu")
	check(Lodge.win_reward(1000, cfg) == 300 and Lodge.entry_fee(1000, cfg) == 100, "parts de la récompense")
	# Défenses : le mur passe devant et attire les coups, la tour tire, l'autel soigne.
	check(Lodge.add_defense(st, cfg, 0, "mur") and not Lodge.add_defense(st, cfg, 0, "tour_mage"),
		"une défense dans la première salle")
	Lodge.add_defense(st, cfg, 2, "tour_mage")
	Lodge.add_defense(st, cfg, 2, "autel")
	var dw := Lodge.waves(st.rooms, hero_data, st.defenses, cfg)
	check(dw[0][0].get("wall", false) and dw[0].size() == 4, "le mur se place devant les défenseurs")
	check(float(dw[2][-1].stats.mag) > 0.0 and dw[2].size() == 3, "les défenses suivent la force des défenseurs")
	var e2 := BattleEngine.new()
	e2.setup(_team(gd), dw, 5)
	e2.auto_mode = true
	var wall := e2.enemies[0]
	check(wall.structure == "mur" and wall.taunt_time > 1000.0, "le mur provoque tant qu'il tient")
	for i in 400:
		e2.step(0.05)
	check(wall.hp < wall.max_hp, "les héros doivent frapper le mur")
	e2.simulate()
	check(e2.finished, "un donjon avec défenses va jusqu'au bout")
	# Pièges consommables gagnés à la Lanterne.
	var pd: Node = PlayerDataScript.new()
	pd.configure(gd.player_start, gd.progression, gd.dungeons)
	pd.persist = false
	pd.reset()
	var cfg_s: Dictionary = gd.summon.duplicate(true)
	cfg_s["trap_bonus"] = {"count": 1}
	pd.state.gems = 10000
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var res: Dictionary = pd.summon("gems", cfg_s, gd.heroes, rng)
	check(res.traps.size() == 1 and pd.trap_count(res.traps[0]) == 1, "une invocation donne un piège")
	pd.free()
	gd.free()


## Lignes de la formation : le corps-à-corps frappe d'abord la ligne de devant, la distance
## atteint le milieu mais pas l'arrière tant que la ligne de devant tient ; bonus de l'arrière.
func test_formation_lines() -> void:
	print("
[Lignes de la formation]")
	var e := BattleEngine.new()
	var foes: Array[BattleUnit] = []
	for i in 7:
		foes.append(BattleUnit.from_data(100 + i, "m", {"stats": {"hp": 100}}, 1, i))
	var melee := BattleUnit.from_data(1, "a", {"range": "melee"}, 0, 0)
	var ranged := BattleUnit.from_data(2, "b", {"range": "ranged"}, 0, 5)
	check(e.reachable(melee, foes).all(func(f: BattleUnit) -> bool: return f.line() == 0),
		"le corps-à-corps ne vise que la ligne de devant")
	check(not e.reachable(ranged, foes).any(func(f: BattleUnit) -> bool: return f.line() == 2),
		"la distance ne vise pas l'arrière tant que le devant tient")
	check(e.reachable(ranged, foes).any(func(f: BattleUnit) -> bool: return f.line() == 1),
		"la distance vise le milieu")
	foes[0].hp = 0.0
	foes[1].hp = 0.0
	check(e.reachable(melee, foes).all(func(f: BattleUnit) -> bool: return f.line() == 1),
		"devant tombé : le corps-à-corps passe au milieu")
	check(e.reachable(ranged, foes).any(func(f: BattleUnit) -> bool: return f.line() == 2),
		"devant tombé : la distance atteint l'arrière")
	foes[6].taunt_time = 3.0
	check(e.reachable(melee, foes).has(foes[6]), "une provocation reste atteignable")
	check(ranged.line() == 2 and e._support_mult(ranged) > 1.0, "soins et boucliers renforcés à l'arrière")
