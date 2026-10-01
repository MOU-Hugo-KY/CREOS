class_name PortFranc
extends Node3D
## Décor du hub : Port-Franc, la ville des chasseurs, au soleil couchant.
## Les bâtiments et accessoires sont nos modèles GLB (`assets/hub/`, en mètres, origine au sol,
## façade vers +Z). Ce script les place, ajoute le sol, la mer, le ciel, les lumières, et rend
## cliquables les bâtiments importants. Purement visuel.

signal building_clicked(building_id: String)

const HUB := "res://assets/hub/"
const KIT := "res://assets/kaykit/dungeon/Assets/"  # dalles de la place
const RELIC := Color(0.72, 0.42, 1.0)
const GRASS := Color(0.36, 0.52, 0.25)
const STONE := Color(0.62, 0.6, 0.58)
const STONE_DARK := Color(0.42, 0.41, 0.42)
const SEA_LEVEL := -0.5
const DOCK_SURFACE := 0.97  # hauteur de marche du ponton dans son modèle

# Bâtiments cliquables : [id, modèle, position, rotation Y, taille de la zone cliquable, hauteur de l'étiquette]
const BUILDINGS := [
	["loge_des_heros", "Loge_Des_Heros", Vector3(-8.0, 0, -11.0), 16.0, Vector3(7.2, 8.4, 4.6), 9.4],
	["ma_loge", "Ma_Loge", Vector3(8.0, 0, -11.0), -16.0, Vector3(6.2, 5.6, 4.6), 6.6],
	["marche", "Marche", Vector3(-10.0, 0, -0.5), 62.0, Vector3(4.2, 3.6, 2.4), 4.6],
	["table_des_chasses", "Table_Des_Chasses", Vector3(8.5, 0, 0.5), -58.0, Vector3(4.2, 3.9, 3.0), 4.9],
	["autel", "Autel_Des_Reliques", Vector3(0, 0, -3.0), 0.0, Vector3(5.0, 3.2, 5.0), 4.4],
]

# Décor : [modèle, position, rotation Y]
const DECOR := [
	["Maison_Toit_Vert", Vector3(-1.0, 0, -15.5), 0.0],
	["Maison_Toit_Orange", Vector3(4.2, 0, -16.5), -6.0],
	["Maison_Toit_Rouge", Vector3(-15.0, 0, -6.5), 70.0],
	["Maison_Toit_Vert", Vector3(-16.0, 0, 1.5), 85.0],
	["Maison_Toit_Orange", Vector3(14.0, 0, -15.5), -30.0],
	["Maison_Toit_Rouge", Vector3(-13.5, 0, -14.0), 35.0],
	["Arbre", Vector3(-19, 0, -11), 10.0], ["Arbre", Vector3(-7.5, 0, -17.5), 60.0],
	["Arbre", Vector3(12.0, 0, -19), 0.0], ["Arbre", Vector3(-20, 0, 7), 130.0],
	["Arbre", Vector3(18.5, 0, -11), 200.0], ["Arbre", Vector3(-21, 0, -2), 80.0],
	["Tonneau", Vector3(-5.2, 0, -12.6), 0.0], ["Tonneau", Vector3(-4.3, 0, -12.2), 30.0],
	["Tonneau", Vector3(13.2, 0, 2.6), 0.0], ["Tonneau", Vector3(-12.4, 0, 1.6), 15.0],
	["Caisses", Vector3(12.7, 0, -3.2), -80.0], ["Caisses", Vector3(5.2, 0, -13.0), 10.0],
	["Caisses", Vector3(-12.8, 0, -2.6), 70.0],
]

const LAMPS := [Vector3(-4.5, 0, 2.5), Vector3(4.5, 0, 2.5), Vector3(-5.5, 0, -7.5), Vector3(5.5, 0, -7.5)]

# La Tour de Morvath mesure vraiment 40 m : elle se dresse loin derrière la ville.
const TOWER_POS := Vector3(-34, 0, -210)

var buildings: Dictionary = {}  # id -> HubBuilding
var _crystal: Node3D
var _crystal_y := 0.0
var _boat: Node3D
var _lights: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_harbor()
	_build_background()
	for b: Array in BUILDINGS:
		_build_building(b[0], b[1], b[2], b[3], b[4], b[5])
	for d: Array in DECOR:
		_place(self, d[0], d[1], d[2])
	for p: Vector3 in LAMPS:
		_build_lamp(p)
	_build_tower()


func _process(delta: float) -> void:
	_time += delta
	if _crystal:
		_crystal.rotation.y += delta * 0.65
		_crystal.position.y = _crystal_y + sin(_time * 1.8) * 0.12
	if _boat:
		_boat.position.y = SEA_LEVEL - 0.45 + sin(_time * 1.1) * 0.06
		_boat.rotation_degrees.z = sin(_time * 0.8) * 2.0
	for i in _lights.size():
		_lights[i].light_energy = 1.6 + sin(_time * 7.0 + i * 2.1) * 0.15


# --- Ciel et lumière ------------------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.45, 0.75)
	sky_mat.sky_horizon_color = Color(1.0, 0.68, 0.45)
	sky_mat.ground_horizon_color = Color(0.85, 0.6, 0.45)
	sky_mat.ground_bottom_color = Color(0.25, 0.25, 0.3)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.75)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.08
	e.fog_enabled = true
	e.fog_light_color = Color(0.55, 0.55, 0.75)
	e.fog_density = 0.0022
	e.fog_sky_affect = 0.2
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	e.adjustment_contrast = 1.08
	var env := WorldEnvironment.new()
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 55, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


# --- Sol, port, arrière-plan ----------------------------------------------------

func _build_ground() -> void:
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 400)
	grass.mesh = plane
	grass.material_override = Blocks.mat(GRASS, 0.0, 0.18)
	grass.position = Vector3(-236, -0.06, -180)
	add_child(grass)
	# Pavés de la place (dalles KayKit réchauffées) en ellipse irrégulière.
	var tile_scene: PackedScene = load(KIT + "floor_tile_large.gltf.glb")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for x in range(-5, 4):
		for z in range(-4, 2):
			var cx := x * 4 + 2
			var cz := z * 4 + 2
			var d := Vector2(cx / 15.0, (cz + 4.0) / 11.0).length()
			if d > 1.15 or (d > 0.95 and rng.randf() < 0.5):
				continue
			var t := tile_scene.instantiate() as Node3D
			t.position = Vector3(cx, 0, cz)
			_tint(t, Color(0.82, 0.74, 0.64))
			add_child(t)


func _build_harbor() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 320)
	plane.subdivide_width = 60
	plane.subdivide_depth = 100
	water.mesh = plane
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MarshLevel.WATER_SHADER
	mat.shader = shader
	mat.set_shader_parameter("deep_color", Color(0.06, 0.2, 0.32))
	mat.set_shader_parameter("shallow_color", Color(0.15, 0.42, 0.5))
	mat.set_shader_parameter("glint_color", Color(1.0, 0.75, 0.45))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.noise = noise
	noise_tex.generate_mipmaps = true
	mat.set_shader_parameter("noise_tex", noise_tex)
	water.material_override = mat
	water.position = Vector3(94, SEA_LEVEL, -100)
	add_child(water)
	# Quai en pierre le long de l'eau
	Blocks.box(self, Vector3(1.5, 1.0, 40), Vector3(14.2, -0.45, -6), Blocks.mat(STONE))
	# Ponton : sa surface (0,97 m dans le modèle) au niveau du quai ; il part vers la mer (+X).
	_place(self, "Ponton_Bois", Vector3(19.0, -DOCK_SURFACE + 0.02, 1.2), 90.0)
	# Bateau qui se balance doucement
	_boat = _place(self, "Bateau_De_Peche", Vector3(21.8, SEA_LEVEL - 0.45, -5.2), 20.0)


func _build_background() -> void:
	# Montagnes lointaines, derrière la tour
	var rock := Blocks.mat(Color(0.22, 0.27, 0.42), 0.0, 0.12)
	var snow := Blocks.mat(Color(0.92, 0.9, 0.98))
	var peaks := [
		[Vector3(-110, 0, -300), 60.0, 34.0], [Vector3(-40, 0, -320), 70.0, 42.0], [Vector3(40, 0, -300), 55.0, 30.0],
		[Vector3(110, 0, -280), 50.0, 26.0], [Vector3(-170, 0, -250), 50.0, 24.0],
	]
	for p: Array in peaks:
		var h: float = p[2]
		Blocks.cylinder(self, p[1], h, p[0] + Vector3(0, h / 2.0 - 1.0, 0), rock, 7, 0.0)
		Blocks.cylinder(self, float(p[1]) * 0.22, h * 0.22, p[0] + Vector3(0, h * 0.89 - 1.0, 0), snow, 7, 0.0)
	# Remparts de la ville derrière les maisons
	var wall := Blocks.mat(STONE_DARK)
	for i in range(-6, 6):
		Blocks.box(self, Vector3(4.2, 3.0, 1.2), Vector3(i * 4.0, 1.5, -21.5), wall)
		Blocks.box(self, Vector3(1.0, 0.8, 1.2), Vector3(i * 4.0 - 1.2, 3.4, -21.5), wall)
		Blocks.box(self, Vector3(1.0, 0.8, 1.2), Vector3(i * 4.0 + 1.2, 3.4, -21.5), wall)


# --- Bâtiments ------------------------------------------------------------------

func _build_building(id: String, model: String, pos: Vector3, yaw: float, click: Vector3, label_h: float) -> void:
	var root := HubBuilding.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var node := _place(root, model, Vector3.ZERO, 0.0)
	if id == "autel" and node:
		# Seul le nœud « Cristal » tourne et flotte ; la fontaine reste fixe.
		_crystal = node.find_child("Cristal", true, false) as Node3D
		if _crystal:
			_crystal_y = _crystal.position.y
		var light := OmniLight3D.new()
		light.light_color = RELIC
		light.light_energy = 2.2
		light.omni_range = 8.0
		light.position.y = 2.3
		root.add_child(light)
		_sparkles(root, Vector3(0, 2.2, 0), RELIC)
	_register(root, id, click, label_h)


## La Tour de Morvath (40 m) au loin, lumière violette au sommet. Cliquable.
func _build_tower() -> void:
	var root := HubBuilding.new()
	root.position = TOWER_POS
	root.rotation_degrees.y = 15.0
	add_child(root)
	_place(root, "Tour_De_Morvath", Vector3.ZERO, 0.0)
	var light := OmniLight3D.new()
	light.light_color = RELIC
	light.light_energy = 8.0
	light.omni_range = 40.0
	light.position.y = 38.0
	root.add_child(light)
	_register(root, "tour", Vector3(14, 40, 12), 24.0)


func _build_lamp(pos: Vector3) -> void:
	_place(self, "Lampadaire", pos, 0.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.omni_range = 6.0
	light.light_energy = 1.6
	light.position = pos + Vector3(0, 3.6, 0)
	add_child(light)
	_lights.append(light)


func _sparkles(parent: Node3D, pos: Vector3, color: Color) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.5
	p.preprocess = 2.5
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.3, 0)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = color.lightened(0.3)
	m.albedo_texture = MarshLevel.soft_dot_texture()
	quad.material = m
	p.draw_pass_1 = quad
	parent.add_child(p)


## Cache les noms des bâtiments (quand un écran plein est ouvert par-dessus).
func set_labels_visible(on: bool) -> void:
	for id: String in buildings:
		buildings[id].set_label_visible(on)


func _register(b: HubBuilding, id: String, click_size: Vector3, label_height: float) -> void:
	var info: Dictionary = GameData.hub.get("buildings", {}).get(id, {})
	b.setup(id, info.get("name", id), click_size, label_height)
	b.clicked.connect(func(bid: String) -> void: building_clicked.emit(bid))
	buildings[id] = b


## Place un modèle de `assets/hub/` (nom sans extension).
func _place(parent: Node3D, model: String, pos: Vector3, yaw: float) -> Node3D:
	var path := HUB + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Modèle du hub introuvable : " + path)
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw
	parent.add_child(n)
	return n


func _tint(node: Node, tint: Color) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i)
			if m is StandardMaterial3D:
				var copy := m.duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				mesh.set_surface_override_material(i, copy)
