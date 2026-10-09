extends SceneTree
## Captures d'écran du combat. Nécessite un affichage (pas --headless).
##   godot --path . --resolution 1280x720 --script res://tools/screenshot.gd
## Options (après `--`) :
##   --shots=200,600     images où prendre une capture (défaut : 200)
##   --out=res://docs/capture-prototype.png   (plusieurs captures : -1, -2… ajoutés au nom)
##   --auto              active le mode Auto
##   --speed=2           accélère le combat
##   --end               attend l'écran de fin et le capture en dernier
##   --scene=res://scenes/hub/hub.tscn   capture une autre scène (défaut : le combat)
##   --action=campaign   (hub) ouvre un écran avant la capture : campaign, heroes, altar, shop, relics…
##   --hour=23      (hub) heure du port (aube 7, jour 13, crépuscule 19.3, nuit 23)
##   --hero=corbin       (hub, avec --action=heroes) ouvre la fiche de ce héros

var shots: Array[int] = [200]
var out := "res://docs/capture-prototype.png"
var wait_end := false
var frames := 0
var taken := 0
var end_frame := -1
var scene: Node
var scene_path := "res://scenes/battle/battle.tscn"
var action := ""
var hero := ""
var tab := ""
var hour := -2.0
var end_wait := 150  # --endwait=N : images après l'apparition de l'écran de fin
var force_draw := false  # --draw : montre « Arrêter » puis déclare l'égalité
var combo := ""  # --combo=ombres : lance ce combo dès le premier tour (membres dans --team)


var team: Array = []


func _initialize() -> void:
	var auto := false
	var speed := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots.clear()
			for s in arg.trim_prefix("--shots=").split(","):
				shots.append(int(s))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--auto":
			auto = true
		elif arg.begins_with("--speed="):
			speed = float(arg.trim_prefix("--speed="))
		elif arg == "--end":
			wait_end = true
		elif arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--action="):
			action = arg.trim_prefix("--action=")
		elif arg.begins_with("--hero="):
			hero = arg.trim_prefix("--hero=")
		elif arg.begins_with("--hour="):
			hour = float(arg.trim_prefix("--hour="))
		elif arg.begins_with("--tab="):
			tab = arg.trim_prefix("--tab=")
		elif arg.begins_with("--dungeon="):  # ex. --dungeon=monde01_8 (niveau avec boss)
			root.get_node("PlayerData").current_dungeon = arg.trim_prefix("--dungeon=")
		elif arg.begins_with("--endwait="):
			end_wait = int(arg.trim_prefix("--endwait="))
		elif arg == "--draw":
			force_draw = true
		elif arg.begins_with("--combo="):
			combo = arg.trim_prefix("--combo=")
		elif arg.begins_with("--team="):  # ex. --team=corbin,nyx,rivet,aegis,bastion,nacre,valen,orage
			team = Array(arg.trim_prefix("--team=").split(","))
	var pd := root.get_node("PlayerData")
	pd.use_memory_only()  # ne touche pas à la vraie sauvegarde
	if not team.is_empty():
		for id: String in team:
			pd.state.heroes[id] = {"level": 20, "xp": 0}
		pd.state.team = team
	scene = load(scene_path).instantiate()
	root.add_child(scene)
	if scene.has_method("set_auto"):
		scene.set_auto(auto)
	Engine.time_scale = speed


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2 and hour > -2.0 and "town" in scene:
		scene.town.set_hour(hour)
	if frames == 5 and action == "prep":  # préparation de chasse du premier niveau
		scene.hud.open_hunt_prep("monde01_1")
	elif frames == 5 and action.begins_with("shop_"):  # Marchand sur un onglet : shop_fusion, shop_rachat
		var pd: Node = root.get_node("PlayerData")
		pd.state.items["esprit_oeuf_feu"] = 7
		pd.state.items["esprit_petit_eau"] = 2
		scene.hud.open_shop()
		scene.hud.shop._set_mode(action.trim_prefix("shop_"))
	elif frames == 5 and action == "fusion":  # Lanterne : fusion des Esprits chez le Druide
		var pd2: Node = root.get_node("PlayerData")
		pd2.state.items["esprit_oeuf_feu"] = 7
		pd2.state.items["esprit_petit_eau"] = 2
		pd2.state.items["esprit_oeuf_nature"] = 3
		scene.hud.open_altar()
		scene.hud.altar._set_mode("fusion")
	elif frames == 5 and action == "druide":  # Lanterne : le sanctuaire du Druide, un appel ×10
		scene.hud.open_altar()
		var pd: Node = root.get_node("PlayerData")
		pd.state.items["fragments_relique"] = 200
		scene.hud.altar._set_mode("esprits")
		scene.hud.altar._call_esprits(10)
	elif frames == 5 and action == "atelier":  # Lanterne : l'atelier du Mécanicien, un tirage ×10
		scene.hud.open_altar()
		root.get_node("PlayerData").state.gold = 20000
		scene.hud.altar._set_mode("pieces")
		scene.hud.altar._pull(10)
	elif frames == 5 and action == "summon":  # Lanterne : une invocation avec des gemmes
		scene.hud.open_altar()
		root.get_node("PlayerData").state.gems = 1200
		scene.hud.altar._summon(10)
	elif frames == 5 and action != "":
		if scene.hud.has_method("open_" + action):  # ex. --action=profile, shop, relics, quests, altar
			scene.hud.call("open_" + action)
		else:
			scene._do_action(action, "")
		if action == "relics" and tab != "":
			scene.hud.relics._tab = tab
			scene.hud.relics.refresh()
		if hero != "" and tab == "Relique":  # relics_open : ouvre les reliques pour la capture
			root.get_node("PlayerData").state.dungeons["monde10_8"] = {"stars": 3}
			root.get_node("PlayerData").state.relics = {hero: 2}
		if hero != "":
			scene.hud.lodge.show_hero(hero, tab if tab != "" else "Techniques")
	if frames == 30 and hero != "" and tab == "Voies":  # montre le détail de la première voie
		for c in scene.hud.lodge._tab_box.get_children():
			if c is Panel:
				c.mouse_entered.emit()
				break
	if combo != "" and frames > 10 and scene.engine.awaiting_uid >= 0:
		for u in scene.engine.heroes:
			u.used_ultimate = true
		scene._on_combo_requested(combo)
		print("combo lancé à l'image ", frames)
		combo = ""
	if force_draw and frames == 100:
		scene.hud.draw_button.visible = true
	if force_draw and frames == 160:
		scene.engine.declare_draw()
		scene._handle_events()
	if frames in shots:
		_save()
	if wait_end and end_frame < 0 and "end_screen" in scene.hud and scene.hud.end_screen.visible:
		end_frame = frames + end_wait  # laisse le temps aux étoiles (et au coffre) d'apparaître
	if end_frame > 0 and frames == end_frame:
		_save()
	var done_shots: bool = frames >= int(shots.max())
	if done_shots and (not wait_end or (end_frame > 0 and frames >= end_frame)) or frames > 30000:
		Engine.time_scale = 1.0
		quit()
	return false


func _save() -> void:
	taken += 1
	var path := out
	var multi := shots.size() + (1 if wait_end else 0) > 1
	if multi:
		path = out.get_basename() + "-%d.png" % taken
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	root.get_texture().get_image().save_png(abs_path)
	print("Capture : ", abs_path)
