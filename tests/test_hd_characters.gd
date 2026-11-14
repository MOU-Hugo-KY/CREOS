extends SceneTree
## La version active utilise les dessins HD et les articulations, sans textures pixel.
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL : ", label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.get_node("PlayerData").use_memory_only()
	check(not PixelSheet.enabled, "le rendu HD est actif par défaut")
	var data := root.get_node("GameData")
	for id: String in data.heroes:
		check(PixelSheet.for_actor(id) == null, id + " : aucun atlas pixel actif")
		var rig := Rig.for_actor(id)
		check(rig != null and not rig.draw_order.is_empty(), id + " : pièces HD articulées")
		var actor := ClipPlayer.new()
		actor.bundle = "res://assets/anim/heroes/"
		actor.sound_enabled = false
		root.add_child(actor)
		for state: String in ["idle", "walk", "hurt", "death", "0", "1", "2", "3", "4", "5"]:
			check(actor.play(id + "_" + state), id + " : clip " + state)
			check(actor._pixel == null and not actor._rig_anim.is_empty(), id + " : animation articulée " + state)
			check(actor.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, id + " : filtre HD")
		for part: Dictionary in rig.draw_order:
			check(part.texture != null, id + " : pièce disponible")
		check(RoundPortrait.portrait_texture(data.hero(id)) != null, id + " : portrait illustré")
		actor.free()
		print("OK : ", id, " — dessin HD, 10 mouvements et portrait")
	print("%d vérifications HD, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)
