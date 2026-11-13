extends SceneTree
## Les 19 héros gardent leurs mouvements, leurs repères et leurs portraits.
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL : ", label)

func _initialize() -> void:
	var heroes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes.json"))
	check(heroes.size() == 19, "19 héros")
	for id: String in heroes:
		var sheet := PixelSheet.for_actor(id)
		check(sheet != null, id + " : planche")
		check(sheet._original_cache.is_empty(), id + " : archives non chargées")
		check(sheet.anims.attack_1.frames.size() == 16, id + " : 16 poses de base")
		for state: String in ["idle", "walk", "attack_1", "attack_2", "ultimate", "skill", "dodge", "hurt", "death"]:
			check(sheet.has_original(state), id + " : original " + state)
			var anim: Dictionary = sheet.anims[state]
			check(anim.frames.size() >= 7, id + " : mouvement complet " + state)
			for f: Array in anim.frames:
				var texture := f[0] as AtlasTexture
				check(texture != null and texture.atlas != null, id + " : texture importée " + state)
				check(f[1] > 0, id + " : durée positive")
				check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), id + " : région valide")
				check(sheet.frame_rect(texture).size.y > 0 and sheet.frame_scale(texture) > 0, id + " : silhouette et échelle")
		check(sheet.body_rect().size.y > 100 and sheet.body_rect().size.y < 600, id + " : taille cohérente")
		check(RoundPortrait.pixel_head(id) != null, id + " : portrait")
		var clip := ClipPlayer.load_clip("res://assets/anim/heroes/", id + "_0")
		var hit := float(clip.cue[0][0])
		check(sheet.frame_at("attack_1", hit + 0.0001, float(clip.dur), hit) == sheet.anims.attack_1.frames[8][0], id + " : impact synchronisé")
		print("OK : ", id, " — 9 mouvements, attaque 16 poses, portrait et impact")
	print("%d vérifications refonte, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)
