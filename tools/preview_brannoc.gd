extends SceneTree
## Démonstration reproductible, sans modifier le combat ni ses statistiques.
## godot --path . --script res://tools/preview_brannoc.gd
## Vidéo : ajouter --write-movie /chemin/brannoc.avi --fixed-fps 30 --quit-after 450

var hero: UnitView
var target: UnitView
var caption: Label
var elapsed := 0.0
var stage := -1
var stages := [1.0, 3.0, 5.0, 7.0, 9.0, 11.0, 13.0]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101e2b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bed8ed")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	world.add_child(light)
	var floor := MeshInstance3D.new()
	var plane := CylinderMesh.new()
	plane.top_radius = 5.5
	plane.bottom_radius = 5.5
	plane.height = 0.2
	floor.mesh = plane
	floor.position.y = -0.12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("2a3e4c")
	floor.material_override = material
	world.add_child(floor)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(5, 4.2, 7.5)
	camera.look_at(Vector3(0, 1.1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	var gd := root.get_node("GameData")
	var data: Dictionary = gd.hero("brannoc")
	hero = UnitView.new()
	world.add_child(hero)
	hero.position = Vector3(-1.8, 0, 0)
	hero.rotation_degrees.y = 90
	hero.setup(BattleUnit.from_data(1, "brannoc", data, 0, 0), data)
	hero._hp_bar.visible = false
	data = gd.monster("squelette_serviteur")
	target = UnitView.new()
	world.add_child(target)
	target.position = Vector3(2.0, 0, 0)
	target.rotation_degrees.y = -90
	target.setup(BattleUnit.from_data(2, "squelette_serviteur", data, 1, 0), data)
	target._hp_bar.visible = false
	var hud := CanvasLayer.new()
	world.add_child(hud)
	var title := Label.new()
	title.text = "CREOS  /  BRANNOC LE ROC"
	title.position = Vector2(60, 44)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("b8f1dc"))
	hud.add_child(title)
	caption = Label.new()
	caption.position = Vector2(60, 110)
	caption.add_theme_font_size_override("font_size", 28)
	hud.add_child(caption)
	caption.text = "Gardien de Nature · épée et bouclier"
	var footer := Label.new()
	footer.text = "Animations KayKit · intégration Godot · démonstration du prototype"
	footer.position = Vector2(60, 990)
	footer.add_theme_font_size_override("font_size", 23)
	hud.add_child(footer)


func _process(delta: float) -> bool:
	if hero == null:
		return false
	elapsed += delta
	if stage + 1 < stages.size() and elapsed >= stages[stage + 1]:
		stage += 1
		match stage:
			0, 1, 2:
				caption.text = ["01 / Taille verticale", "02 / Taille diagonale", "03 / Estoc"][stage]
				var timing := hero.play_action(target)
				create_timer(timing.impact).timeout.connect(func() -> void:
					target.play_hit()
					target.popup("Impact", Color("b8f1dc")))
			3:
				caption.text = "04 / Rempart · protection de l'équipe"
				var timing := hero.play_action(null, true)
				create_timer(timing.impact).timeout.connect(hero.show_shield)
			4:
				caption.text = "05 / Réaction au bouclier"
				hero.play_hit()
			5:
				caption.text = "06 / Victoire"
				hero.play_victory()
			6:
				caption.text = "07 / Mort · aucune reprise de l'attente"
				hero.play_death()
	return false
