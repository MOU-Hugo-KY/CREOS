extends SceneTree
## Test de fumée du hub : la place se charge, ses bâtiments sont là, les écrans s'ouvrent
## (Lanterne, Marchand, Reliques, carte des mondes) et la Table des chasses mène au combat.
## Lancer : godot --headless --path . --script res://tests/smoke_hub.gd

var hub: Node
var frames := 0
var ok := true


func _initialize() -> void:
	root.get_node("PlayerData").use_memory_only()  # ne touche pas à la vraie sauvegarde
	hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub


func _fail(text: String) -> void:
	printerr("ÉCHEC : ", text)
	ok = false


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		hub._do_action("altar", "autel")
		if not hub.hud.altar.visible:
			_fail("la Lanterne des Serments ne s'ouvre pas")
		hub.hud.close_altar()
		hub._do_action("shop", "echoppe_masques")
		if not hub.hud.shop.visible:
			_fail("le Marchand ne s'ouvre pas")
		hub.hud.shop.close_window()
		hub._do_action("relics", "reliques")
		if not hub.hud.relics.visible:
			_fail("l'écran des reliques ne s'ouvre pas")
		hub.hud.relics.close_window()
	if frames == 5:
		var ids: Array = hub.town.buildings.keys()
		var placed := ["hunt_table", "hero_lodge", "oath_lantern", "merchant", "relics", "private_lodge"]
		for id: String in placed:
			if id not in ids:
				_fail("bâtiment absent " + id)
		print("bâtiments : ", ids.size(), "  héros sur la place : ", hub.town._walkers.size())
		hub.town.tap(hub.town.buildings["merchant"].approach + Vector2(0, 2))
		hub._do_action("campaign", "table_des_chasses")
		if not hub.hud.campaign.visible:
			_fail("la carte des mondes ne s'ouvre pas")
		hub.hud.campaign.hunt_chosen.emit("monde01_1")
		if not hub.hud.hunt_prep.visible:
			_fail("l'écran « Préparer la chasse » ne s'ouvre pas")
		hub.start_hunt(hub.hud.hunt_prep.dungeon_id)
	if frames == 30:
		var scene_name: String = String(current_scene.name) if current_scene else "aucune"
		print("scène après « Chasses » : ", scene_name)
		if scene_name != "Battle":
			_fail("la Table des chasses ne lance pas le combat")
		quit(0 if ok else 1)
	return false
