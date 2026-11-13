extends SceneTree
## Vérifie l'extension atlas et les frontières entre atlas et dessins classiques.
## godot --headless --path . --script res://tests/test_pixel_atlas.gd

var failures := 0
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL : ", label)
	else:
		print("OK : ", label)


func opaque_height(texture: Texture2D) -> int:
	var image := texture.get_image()
	var top := image.get_height()
	var bottom := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				top = mini(top, y)
				bottom = maxi(bottom, y + 1)
	return bottom - top


func _initialize() -> void:
	var sheet := PixelSheet.for_actor("corbin")
	check(sheet.anims.attack_1.frames.size() == 16, "16 nouvelles poses")
	check(sheet.anims.attack_1_original.frames.size() == 8, "8 dessins originaux conservés")
	check(sheet.anim_for("0") == "attack_1", "le combat utilise la nouvelle attaque")
	var original: Texture2D = sheet.anims.attack_1_original.frames[0][0]
	var reference_height := opaque_height(original) * sheet.scale
	for f: Array in sheet.anims.attack_1.frames:
		var texture := f[0] as AtlasTexture
		check(texture != null and texture.atlas != null, "région reliée à la planche importée")
		check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "découpe dans les limites de la planche")
		var anchor := sheet.frame_anchor(texture)
		check(anchor.x > 0 and anchor.y > 0 and anchor.x < texture.get_width() and anchor.y <= texture.get_height(), "pieds dans la case")
		check(sheet.frame_scale(texture) > 0.0, "échelle positive")
	var first: Texture2D = sheet.anims.attack_1.frames[0][0]
	check(absf(opaque_height(first) * sheet.frame_scale(first) - reference_height) < 3.0,
		"hauteur de la pose initiale conservée")
	var impact: Texture2D = sheet.frame_at("attack_1", 0.7021, 1.3, 0.702)
	check(impact == sheet.anims.attack_1.frames[8][0], "pose de frappe au repère d'impact du clip")
	var ready := sheet.frame_at("attack_1", 0.0, 1.3, 0.702)
	check(not ready is AtlasTexture, "avant le geste : repos classique")
	check(sheet.frame_scale(ready) == sheet.scale and sheet.frame_anchor(ready) == sheet.anchor,
		"le repos garde son calage et son échelle")
	var recovered := sheet.frame_at("attack_1", 1.5, 1.3, 0.702)
	check(not recovered is AtlasTexture, "après le geste : retour au repos classique")
	var death := sheet.frame_at("death", 20.0, 1.0, -1.0)
	check(death == sheet.anims.death.frames[-1][0], "la mort reste sur sa dernière pose")
	# Les anciens formats des autres héros restent utilisables.
	for hero: String in ["aegis", "brume", "orage"]:
		var other := PixelSheet.for_actor(hero)
		var texture := other.frame_at("attack_1", 0.4, 1.3, 0.7)
		check(texture != null and other.frame_scale(texture) == other.scale, hero + " : format historique intact")
	print("%d vérifications atlas, %d échec(s)" % [checks, failures])
	quit(1 if failures else 0)
