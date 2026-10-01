extends SceneTree
## Test de fumée du hub : Port-Franc se charge, ses bâtiments sont là, et la Table des chasses
## mène au combat ; l'Autel des Reliques s'ouvre. Lancer : godot --headless --path . --script res://tests/smoke_hub.gd

var hub: Node
var frames := 0
var ok := true


func _initialize() -> void:
	root.get_node("PlayerData").use_memory_only()  # ne touche pas à la vraie sauvegarde
	hub = load("res://scenes/hub/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		hub._do_action("altar", "autel")
		if not hub.hud.altar.visible:
			printerr("ÉCHEC : l'Autel des Reliques ne s'ouvre pas")
			ok = false
		hub.hud.close_altar()
	if frames == 5:
		var ids: Array = hub.town.buildings.keys()
		for id: String in root.get_node("GameData").hub.get("buildings", {}):
			if id not in ids:
				printerr("ÉCHEC : bâtiment absent ", id)
				ok = false
		print("bâtiments : ", ids.size(), "  héros sur la place : ", hub.wanderers.size())
		hub._do_action("campaign", "table_des_chasses")
	if frames == 30:
		var scene_name: String = String(current_scene.name) if current_scene else "aucune"
		print("scène après « Chasses » : ", scene_name)
		if scene_name != "Battle":
			printerr("ÉCHEC : la Table des chasses ne lance pas le combat")
			ok = false
		quit(0 if ok else 1)
	return false
