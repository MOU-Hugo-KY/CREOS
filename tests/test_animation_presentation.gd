extends SceneTree
## Régressions avec les vrais modèles : mouvement, interruptions et impacts différés.
## godot --headless --path . --script res://tests/test_animation_presentation.gd --fixed-fps 60

var failures := 0
var checks := 0
var scene: Node3D


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL : ", label)
	else:
		print("OK : ", label)


func _run() -> void:
	scene = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var hero: UnitView = scene.views[scene.engine.heroes[0].uid]
	var enemy: UnitView = scene.views[scene.engine.enemies[0].uid]
	for equipment: String in ["1H_Sword", "Round_Shield"]:
		check(hero.find_child(equipment, true, false).visible, equipment + " visible")
	for equipment: String in ["1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield", "Spike_Shield"]:
		check(not hero.find_child(equipment, true, false).visible, equipment + " masqué")
	for clip: String in hero.anims.attacks + ["Block_Attack", "Block_Hit", "Running_A", "Walking_Backwards", "Cheer"]:
		check(hero._anim_player.has_animation(clip), "clip présent : " + clip)
	var home := hero.position
	var yaw := hero.rotation
	for expected: String in hero.anims.attacks:
		var timing := hero.play_action(enemy)
		check(timing.impact > 0.2 and timing.impact < timing.duration, "impact entre approche et retour")
		await create_timer(0.26).timeout
		check(hero.position.distance_to(enemy.position) < home.distance_to(enemy.position), "approche de la cible")
		check(hero._anim_player.current_animation == expected, "variante : " + expected)
		hero.play_hit()
		check(hero._anim_player.current_animation == expected, "un coup reçu ne coupe pas l'attaque")
		await create_timer(timing.duration).timeout
		check(hero.position.is_equal_approx(home) and hero.rotation.is_equal_approx(yaw), "retour à la place et orientation initiales")
		check(hero._anim_player.current_animation == "Idle", "retour à l'attente")
	# La compétence ne projette pas le gardien vers un allié.
	hero.play_action(hero, true)
	await create_timer(0.1).timeout
	check(hero.position.is_equal_approx(home), "Rempart reste sur place")
	await create_timer(0.8).timeout
	# Effets létaux puis victoire : les PV et la mort attendent réellement le geste.
	var previous_hp := enemy.displayed_hp
	scene.engine._emit({"type": "attack", "src": hero.unit.uid, "targets": [enemy.unit.uid]})
	scene.engine._emit({"type": "damage", "src": hero.unit.uid, "dst": enemy.unit.uid,
		"hp": 0.0, "amount": previous_hp, "crit": false, "elem_mult": 1.0})
	scene.engine._emit({"type": "death", "dst": enemy.unit.uid})
	scene.engine._emit({"type": "victory"})
	scene._handle_events()
	check(enemy.displayed_hp == previous_hp and not enemy._dead, "pas de dégâts ni mort avant impact")
	check(not scene._restart_button.visible, "pas de victoire anticipée")
	scene._visual_time += 0.55
	scene._flush_visual_events()
	check(enemy.displayed_hp == 0.0 and enemy._dead, "dégâts puis mort à l'impact")
	check(not scene._restart_button.visible, "la victoire attend le retour du gardien")
	scene._visual_time += 1.0
	scene._flush_visual_events()
	check(scene._restart_button.visible, "victoire après le geste")
	# Relancer avant un impact ne doit pas tuer les nouvelles unités.
	scene.start_battle(42)
	hero = scene.views[scene.engine.heroes[0].uid]
	enemy = scene.views[scene.engine.enemies[0].uid]
	scene.engine._emit({"type": "attack", "src": hero.unit.uid, "targets": [enemy.unit.uid]})
	scene.engine._emit({"type": "death", "dst": enemy.unit.uid})
	scene._handle_events()
	check(not scene._visual_events.is_empty(), "impact en attente avant relance")
	scene.start_battle(42)
	check(scene._visual_events.is_empty(), "relance : anciens impacts supprimés")
	hero = scene.views[scene.engine.heroes[0].uid]
	enemy = scene.views[scene.engine.enemies[0].uid]
	hero.play_action(enemy)
	await create_timer(0.1).timeout
	hero.play_death()
	var death_position := hero.position
	await create_timer(1.3).timeout
	check(hero._dead and hero.position.is_equal_approx(death_position), "mort : déplacement annulé")
	check(hero._anim_player.current_animation != "Idle", "mort : aucune résurrection vers Idle")
	# Modifier une boucle sur une instance ne doit pas affecter le modèle partagé.
	var model: PackedScene = load("res://assets/kaykit/adventurers/Characters/Knight.glb")
	var original := model.instantiate()
	var player: AnimationPlayer = original.find_child("AnimationPlayer", true, false)
	var original_loop := player.get_animation("Cheer").loop_mode
	var data: Dictionary = root.get_node("GameData").hero("brannoc")
	var other := UnitView.new()
	scene.add_child(other)
	other.setup(BattleUnit.from_data(999, "brannoc", data, 0, 0), data)
	other.play_victory()
	check(other._anim_player.get_animation("Cheer").loop_mode == Animation.LOOP_LINEAR,
		"victoire : boucle locale activée")
	check(player.get_animation("Cheer").loop_mode == original_loop, "bibliothèques d'animations isolées")
	original.free()
	scene.queue_free()
	await process_frame
	print("%d vérifications d'animation, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)
