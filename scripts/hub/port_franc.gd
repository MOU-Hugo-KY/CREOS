class_name PortFranc
extends Node3D
## Décor du hub : Port-Franc, la ville des chasseurs, au soleil couchant.
## Une place fermée façon village : maisons sur les côtés, la ville qui monte en terrasses au
## fond, le port à droite, et à l'horizon tout le continent de CREOS (ContinentBackdrop).
##
## Direction artistique : les héros sont en pixels, le décor est « propre » (couleurs unies,
## facettes nettes). Les textures pixel de nos modèles de bâtiments sont donc lissées en aplats
## au chargement, et c'est la lumière (soleil doré, contre-jour bleu, lampes, fenêtres, halo)
## qui donne le relief et le charme.

signal building_clicked(building_id: String)

const HUB := "res://assets/hub/"
# Lot 1 du générateur Blender (bâtiments détaillés, textures cuites) : prioritaire s'il existe.
const HUB_LOT1 := "res://assets/hub/lot1/"
# Pack « Port-Franc hybride » (décor pour personnages 2D) : Lanterne des serments, Échoppe des masques.
const HUB_HYBRIDE := "res://assets/hub/hybride/GLB/"
# Lot 2 : sol de la place, terrasses, escaliers, remparts, quai et végétation (repère du monde).
const HUB_LOT2 := "res://assets/hub/lot2/"
const KIT := "res://assets/kaykit/dungeon/Assets/"  # dalles de la place
const RELIC := Color(0.72, 0.42, 1.0)
const GRASS := Color(0.42, 0.58, 0.3)
const STONE := Color(0.72, 0.68, 0.62)
const STONE_DARK := Color(0.5, 0.47, 0.46)
const SEA_LEVEL := -0.5
const DOCK_SURFACE := 0.97  # hauteur de marche du ponton dans son modèle
const TERRACE_1 := 2.4  # hauteur de la première terrasse derrière la place
const TERRACE_2 := 4.8

# Bâtiments cliquables : [id, modèle, position, rotation Y, taille de la zone cliquable, hauteur de l'étiquette]
const BUILDINGS := [
	["loge_des_heros", "Loge_Des_Heros", Vector3(-8.5, 0, -11.0), 14.0, Vector3(7.2, 8.4, 4.6), 9.4],
	["ma_loge", "Ma_Loge", Vector3(8.5, 0, -11.0), -14.0, Vector3(6.2, 5.6, 4.6), 6.6],
	["marche", "Marche", Vector3(-10.0, 0, -0.5), 62.0, Vector3(4.2, 3.6, 2.4), 4.6],
	["table_des_chasses", "Table_Des_Chasses", Vector3(8.8, 0, 0.8), -58.0, Vector3(4.2, 3.9, 3.0), 4.9],
	["autel", "Lanterne_Des_Serments", Vector3(0, 0, -3.0), 0.0, Vector3(5.0, 4.6, 5.0), 5.6],
	["echoppe_masques", "Echoppe_Des_Masques", Vector3(-4.4, 0, -1.4), 24.0, Vector3(4.4, 3.4, 2.6), 2.9],
]

# Décor : [modèle, position, rotation Y, échelle]
const DECOR := [
	# Côté gauche de la place (encadre l'image) : les maisons à thème du lot 1
	["Maison_Taverne", Vector3(-16.5, 0, -4.0), 80.0, 1.0],
	["Maison_Boulangerie", Vector3(-17.0, 0, 3.5), 95.0, 1.0],
	["Maison_Forge", Vector3(-15.5, 0, -12.5), 45.0, 1.0],
	# Côté droit, avant le port
	["Maison_Pecheur", Vector3(16.0, 0, -12.0), -40.0, 1.0],
	# Première terrasse
	["Maison_Herboriste", Vector3(-19.0, TERRACE_1, -21.0), 10.0, 1.0],
	["Maison_Toit_Rouge", Vector3(-11.0, TERRACE_1, -21.5), 0.0, 1.0],
	["Maison_Cartographe", Vector3(-4.6, TERRACE_1, -22.5), -4.0, 1.0],
	["Maison_Toit_Rouge", Vector3(5.0, TERRACE_1, -22.0), 6.0, 1.05],
	["Maison_Taverne", Vector3(11.5, TERRACE_1, -21.5), -6.0, 1.0],
	["Maison_Toit_Vert", Vector3(18.5, TERRACE_1, -20.0), -18.0, 1.1],
	# Deuxième terrasse (plus haut, plus loin)
	["Maison_Toit_Vert", Vector3(-15.0, TERRACE_2, -33.0), 8.0, 1.15],
	["Maison_Boulangerie", Vector3(-7.0, TERRACE_2, -34.0), 0.0, 1.05],
	["Loge_Des_Heros", Vector3(1.0, TERRACE_2, -35.0), 0.0, 1.0],
	["Maison_Herboriste", Vector3(9.0, TERRACE_2, -33.5), -5.0, 1.05],
	["Maison_Toit_Orange", Vector3(16.0, TERRACE_2, -32.0), -12.0, 1.0],
	# Arbres, tonneaux, caisses
	["Arbre", Vector3(-21.0, 0, -8.0), 10.0, 1.2], ["Arbre", Vector3(-13.0, 0, 6.5), 60.0, 1.0],
	["Arbre", Vector3(-1.0, TERRACE_1, -18.5), 0.0, 0.9], ["Arbre", Vector3(-23.0, TERRACE_1, -17.5), 130.0, 1.2],
	["Arbre", Vector3(21.5, TERRACE_2, -28.0), 200.0, 1.1], ["Arbre", Vector3(-20.5, TERRACE_2, -29.0), 80.0, 1.2],
	["Arbre", Vector3(14.5, 0, -7.0), 30.0, 1.0],
	["Tonneau", Vector3(-5.2, 0, -12.6), 0.0, 1.0], ["Tonneau", Vector3(-4.3, 0, -12.2), 30.0, 1.0],
	["Tonneau", Vector3(13.2, 0, 2.6), 0.0, 1.0], ["Tonneau", Vector3(-12.6, 0, 1.8), 15.0, 1.0],
	["Caisses", Vector3(12.7, 0, -3.2), -80.0, 1.0], ["Caisses", Vector3(5.2, 0, -13.2), 10.0, 1.0],
	["Caisses", Vector3(-12.8, 0, -2.6), 70.0, 1.0],
]

# Avec le lot 2, les maisons suivent son plan (terrain et verdure sont faits pour lui),
# plus quelques maisons en plus pour fermer les côtés de la place.
const DECOR_LOT2 := [
	["Maison_Boulangerie", Vector3(-17.0, 0, -7.0), 20.0, 1.0],
	["Maison_Forge", Vector3(-17.0, TERRACE_1, -21.0), 18.0, 1.0],
	["Maison_Taverne", Vector3(-8.0, TERRACE_1, -23.0), 8.0, 1.0],
	["Maison_Pecheur", Vector3(16.0, TERRACE_1, -23.0), -18.0, 1.0],
	["Maison_Herboriste", Vector3(8.0, TERRACE_2, -34.0), -8.0, 1.0],
	["Maison_Cartographe", Vector3(-8.0, TERRACE_2, -34.0), 8.0, 1.0],
	["Maison_Taverne", Vector3(-17.5, 0, 2.0), 80.0, 1.0],
	["Maison_Cartographe", Vector3(8.0, TERRACE_1, -23.0), -8.0, 1.0],
	["Tonneau", Vector3(-5.2, 0, -12.6), 0.0, 1.0], ["Tonneau", Vector3(-4.3, 0, -12.2), 30.0, 1.0],
	["Tonneau", Vector3(-12.6, 0, 1.8), 15.0, 1.0],
	["Caisses", Vector3(5.2, 0, -13.2), 10.0, 1.0], ["Caisses", Vector3(-12.8, 0, -2.6), 70.0, 1.0],
]

const LAMPS := [Vector3(-4.5, 0, 2.5), Vector3(4.5, 0, 2.5), Vector3(-5.5, 0, -7.5), Vector3(5.5, 0, -7.5),
	Vector3(-2.6, TERRACE_1, -17.0), Vector3(2.6, TERRACE_1, -17.0)]

# Guirlandes de fanions au-dessus de la place : [départ, arrivée] (en haut des lampadaires)
const BUNTING := [
	[Vector3(-5.5, 3.5, -7.5), Vector3(5.5, 3.5, -7.5)],
	[Vector3(-4.5, 3.5, 2.5), Vector3(-5.5, 3.5, -7.5)],
	[Vector3(4.5, 3.5, 2.5), Vector3(5.5, 3.5, -7.5)],
]
const BUNTING_COLORS := [Color(0.85, 0.25, 0.22), Color(0.95, 0.75, 0.25), Color(0.25, 0.45, 0.8), Color(0.95, 0.92, 0.85)]

var buildings: Dictionary = {}  # id -> HubBuilding
var backdrop: ContinentBackdrop
var _crystal: Node3D
var _crystal_y := 0.0
var _boat: Node3D
var _gulls: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _flags: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _time := 0.0

static var _clean_cache: Dictionary = {}  # texture -> texture lissée
static var _lot1_materials: Dictionary = {}  # nom du matériau glTF -> matériau partagé
static var _lot2_materials: Dictionary = {}


func _ready() -> void:
	_build_environment()
	var lot2 := ResourceLoader.exists(HUB_LOT2 + "Decor_Place.glb")
	_build_ground(not lot2)
	if lot2:
		_build_lot2()
	else:
		_build_terraces()
	_build_harbor(not lot2)
	backdrop = ContinentBackdrop.new()
	add_child(backdrop)
	for b: Array in BUILDINGS:
		_build_building(b[0], b[1], b[2], b[3], b[4], b[5])
	for d: Array in (DECOR_LOT2 if lot2 else DECOR):
		var n := _place(self, d[0], d[1], d[2])
		if n:
			n.scale = Vector3.ONE * float(d[3])
	for p: Vector3 in LAMPS:
		_build_lamp(p)
	for line: Array in BUNTING:
		_build_bunting(line[0], line[1])
	_build_tower()
	_build_life()


func _process(delta: float) -> void:
	_time += delta
	if _crystal:
		_crystal.rotation.y += delta * 0.65
		_crystal.position.y = _crystal_y + sin(_time * 1.8) * 0.12
	if _boat:
		_boat.position.y = SEA_LEVEL - 0.45 + sin(_time * 1.1) * 0.06
		_boat.rotation_degrees.z = sin(_time * 0.8) * 2.0
	for i in _lights.size():
		_lights[i].light_energy = 1.8 + sin(_time * 7.0 + i * 2.1) * 0.15
	for i in _gulls.size():
		var a := _time * (0.35 + i * 0.07) + i * 2.0
		var g := _gulls[i]
		g.position = Vector3(24 + cos(a) * (9 + i * 3), 14 + i * 2 + sin(a * 3.0) * 0.6, -10 + sin(a) * (7 + i * 2))
		g.rotation.y = -a
		g.get_child(0).rotation.z = sin(_time * 8.0 + i) * 0.5
		g.get_child(1).rotation.z = -sin(_time * 8.0 + i) * 0.5
	for i in _flags.size():
		_flags[i].rotation.y = sin(_time * 2.3 + i) * 0.18
		_flags[i].rotation.x = sin(_time * 3.1 + i * 0.7) * 0.06
	for i in _pennants.size():
		_pennants[i].rotation.x = sin(_time * 2.6 + i * 0.9) * 0.35
	for c in _clouds:
		c.position.x += delta * 1.5
		if c.position.x > 260.0:
			c.position.x = -260.0


# --- Ciel et lumière ------------------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.38, 0.72)
	sky_mat.sky_horizon_color = Color(1.0, 0.7, 0.48)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.8, 0.62, 0.5)
	sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.3)
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.06
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.46, 0.5, 0.68)  # ombres bleutées, contraste avec le soleil doré
	e.ambient_light_energy = 0.48
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	e.tonemap_white = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.15
	e.fog_enabled = true
	e.fog_light_color = Color(0.78, 0.7, 0.66)
	e.fog_density = 0.0016
	e.fog_sky_affect = 0.1
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.2
	e.adjustment_contrast = 1.14
	e.adjustment_brightness = 0.97
	var env := WorldEnvironment.new()
	env.environment = e
	add_child(env)

	# Soleil couchant (lumière principale, longues ombres)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, 48, 0)
	sun.light_color = Color(1.0, 0.76, 0.52)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	# Contre-jour bleu du ciel (pas d'ombre)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-40, -140, 0)
	fill.light_color = Color(0.5, 0.62, 1.0)
	fill.light_energy = 0.4
	add_child(fill)


# --- Sol, terrasses, port ---------------------------------------------------------

func _build_ground(with_tiles: bool) -> void:
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 400)
	grass.mesh = plane
	grass.material_override = Blocks.mat(GRASS, 0.0, 0.0)
	grass.position = Vector3(-236, -0.06, -180)
	add_child(grass)
	if not with_tiles:
		return
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
			_tint(t, Color(0.85, 0.76, 0.66))
			add_child(t)


## La ville monte derrière la place : deux terrasses à murs de pierre, un escalier, des remparts.
func _build_terraces() -> void:
	var wall := Blocks.mat(STONE, 0.0, 0.0)
	var cap := Blocks.mat(STONE_DARK, 0.0, 0.0)
	var top := Blocks.mat(GRASS.darkened(0.05), 0.0, 0.0)
	# Terrasse 1
	Blocks.box(self, Vector3(60, TERRACE_1, 16), Vector3(0, TERRACE_1 / 2.0, -24), wall)
	Blocks.box(self, Vector3(60, 0.1, 16), Vector3(0, TERRACE_1 + 0.03, -24), top)
	Blocks.box(self, Vector3(60, 0.35, 0.8), Vector3(0, TERRACE_1 + 0.17, -16.2), cap)
	# Terrasse 2
	Blocks.box(self, Vector3(60, TERRACE_2, 14), Vector3(0, TERRACE_2 / 2.0, -37), wall)
	Blocks.box(self, Vector3(60, 0.1, 14), Vector3(0, TERRACE_2 + 0.03, -37), top)
	Blocks.box(self, Vector3(60, 0.35, 0.8), Vector3(0, TERRACE_2 + 0.17, -30.2), cap)
	# Escaliers au centre
	for i in 6:
		var h := TERRACE_1 * (i + 1) / 6.0
		Blocks.box(self, Vector3(4.2, h, 0.6), Vector3(0, h / 2.0, -13.4 - i * 0.55), cap)
	for i in 6:
		var h := TERRACE_1 + (TERRACE_2 - TERRACE_1) * (i + 1) / 6.0
		Blocks.box(self, Vector3(4.2, h, 0.6), Vector3(0, h / 2.0, -26.6 - i * 0.55), cap)
	# Remparts et tours de guet tout en haut
	for i in range(-7, 8):
		Blocks.box(self, Vector3(4.2, 3.0, 1.4), Vector3(i * 4.0, TERRACE_2 + 1.5, -44.0), wall)
		Blocks.box(self, Vector3(1.0, 0.8, 1.4), Vector3(i * 4.0 - 1.2, TERRACE_2 + 3.4, -44.0), cap)
		Blocks.box(self, Vector3(1.0, 0.8, 1.4), Vector3(i * 4.0 + 1.2, TERRACE_2 + 3.4, -44.0), cap)



var _water_mat: ShaderMaterial


## Eau animée partagée par la mer et le canal (reflets dorés du couchant).
func _water_material() -> ShaderMaterial:
	if _water_mat:
		return _water_mat
	_water_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MarshLevel.WATER_SHADER
	_water_mat.shader = shader
	_water_mat.set_shader_parameter("deep_color", Color(0.05, 0.2, 0.34))
	_water_mat.set_shader_parameter("shallow_color", Color(0.14, 0.45, 0.55))
	_water_mat.set_shader_parameter("glint_color", Color(1.0, 0.78, 0.5))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.noise = noise
	noise_tex.generate_mipmaps = true
	_water_mat.set_shader_parameter("noise_tex", noise_tex)
	return _water_mat


func _build_harbor(with_quay: bool) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 360)
	plane.subdivide_width = 60
	plane.subdivide_depth = 100
	water.mesh = plane
	water.material_override = _water_material()
	water.position = Vector3(134, SEA_LEVEL, -120)
	add_child(water)
	if with_quay:
		Blocks.box(self, Vector3(1.5, 1.0, 46), Vector3(14.2, -0.45, -9), Blocks.mat(STONE, 0.0, 0.0))
	_place(self, "Ponton_Bois", Vector3(19.0, -DOCK_SURFACE + 0.02, 1.2), 90.0)
	_boat = _place(self, "Bateau_De_Peche", Vector3(21.8, SEA_LEVEL - 0.45, -5.2), 20.0)


## Lot 2 : déjà en coordonnées du monde, on le pose en (0,0,0) sans le déplacer.
func _build_lot2() -> void:
	for model in ["Decor_Place", "Vegetation"]:
		var n := (load(HUB_LOT2 + model + ".glb") as PackedScene).instantiate() as Node3D
		add_child(n)
		for mesh: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var m := mesh.mesh.surface_get_material(i)
				var shared := lot2_material(String(m.resource_name) if m else "")
				if shared:
					mesh.set_surface_override_material(i, shared)
	# Le lit du canal (x = 12,5) attend l'eau du lot 3 : en attendant, une bande d'eau calme.
	var canal := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.8, 60)
	plane.subdivide_depth = 30
	canal.mesh = plane
	canal.material_override = _water_material()
	canal.position = Vector3(12.5, -0.25, -14)
	add_child(canal)


static func lot2_material(key: String) -> Material:
	if _lot2_materials.has(key):
		return _lot2_materials[key]
	var m: Material = null
	if key.begins_with("Atlas_Sol_"):
		# Case de l'atlas du sol : pavés en haut à gauche, pierre en haut à droite, terre, herbe.
		var offsets := {"paving": Vector2(0, 0.5), "stone": Vector2(0.5, 0.5),
			"dirt": Vector2(0, 0), "grass": Vector2(0.5, 0)}
		m = _atlas_shader("sol_atlas", "Sol")
		(m as ShaderMaterial).set_shader_parameter("tile_offset", offsets.get(key.trim_prefix("Atlas_Sol_"), Vector2.ZERO))
	elif key.begins_with("Atlas_Vegetation_"):
		m = _atlas_shader("vegetation_atlas", "Vegetation")
	elif key == "Fer_Accessoires":
		m = Blocks.mat(Color(0.16, 0.18, 0.19), 0.0, 0.0)
	_lot2_materials[key] = m
	return m


static func _atlas_shader(shader: String, family: String) -> ShaderMaterial:
	var cache_key := "_shader_" + family
	if _lot2_materials.has(cache_key):
		return _lot2_materials[cache_key].duplicate() if family == "Sol" else _lot2_materials[cache_key]
	var m := ShaderMaterial.new()
	m.shader = load(HUB_LOT2 + shader + ".gdshader")
	var dir := HUB_LOT2 + "textures/Atlas_" + family + "_"
	m.set_shader_parameter("atlas_color", load(dir + "BaseColor.png"))
	m.set_shader_parameter("atlas_normal", load(dir + "Normal.png"))
	m.set_shader_parameter("atlas_orm", load(dir + "ORM.png"))
	_lot2_materials[cache_key] = m
	return m.duplicate() if family == "Sol" else m


# --- Bâtiments ------------------------------------------------------------------

func _build_building(id: String, model: String, pos: Vector3, yaw: float, click: Vector3, label_h: float) -> void:
	var root := HubBuilding.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var node := _place(root, model, Vector3.ZERO, 0.0)
	if id == "autel" and node:
		# Seul le nœud « Cristal » tourne et flotte ; la fontaine reste fixe.
		_crystal = node.find_child("Coeur", true, false) as Node3D
		if _crystal == null:
			_crystal = node.find_child("Cristal", true, false) as Node3D
		if _crystal:
			_crystal_y = _crystal.position.y
		var light := OmniLight3D.new()
		light.light_color = RELIC
		light.light_energy = 2.5
		light.omni_range = 9.0
		light.position.y = 2.3
		root.add_child(light)
		_sparkles(root, Vector3(0, 2.2, 0), RELIC, 24, 1.2)
	elif id in ["loge_des_heros", "ma_loge"]:
		# Lumière chaude qui sort de la porte et des fenêtres sur les pavés.
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.7, 0.4)
		light.light_energy = 1.6
		light.omni_range = 6.0
		light.position = Vector3(0, 2.2, 3.2)
		root.add_child(light)
	_register(root, id, click, label_h)


## La Tour de Morvath (40 m, à sa vraie taille) sur la citadelle, au loin. Cliquable.
func _build_tower() -> void:
	var root := HubBuilding.new()
	backdrop.tower_root.add_child(root)
	_place(root, "Tour_De_Morvath", Vector3.ZERO, 15.0)
	var light := OmniLight3D.new()
	light.light_color = RELIC
	light.light_energy = 8.0
	light.omni_range = 40.0
	light.position.y = 38.0
	root.add_child(light)
	_register(root, "tour", Vector3(14, 40, 12), 24.0)
	root.set_label_visible(false)  # trop près du titre : la Tour a déjà son bouton à droite


func _build_lamp(pos: Vector3) -> void:
	_place(self, "Lampadaire", pos, 0.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 7.0
	light.light_energy = 1.8
	light.position = pos + Vector3(0, 3.6, 0)
	add_child(light)
	_lights.append(light)


## Une corde qui pend entre deux points, avec des fanions colorés qui flottent au vent.
func _build_bunting(a: Vector3, b: Vector3) -> void:
	var rope := Blocks.mat(Color(0.3, 0.24, 0.18), 0.0, 0.0)
	var length := a.distance_to(b)
	var count := int(length / 0.55)
	var sag := 0.08 * length
	var prev := a
	var flag_mats: Array[StandardMaterial3D] = []
	for c: Color in BUNTING_COLORS:
		var m := Blocks.mat(c, 0.0, 0.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag_mats.append(m)
	for i in range(1, count + 1):
		var t := float(i) / count
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.015
		cyl.bottom_radius = 0.015
		cyl.height = prev.distance_to(p)
		cyl.radial_segments = 4
		seg.mesh = cyl
		seg.material_override = rope
		add_child(seg)
		seg.look_at_from_position((prev + p) / 2.0, p, Vector3.UP if absf((p - prev).normalized().y) < 0.99 else Vector3.RIGHT)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		if i < count:
			var pivot := Node3D.new()
			add_child(pivot)
			pivot.look_at_from_position(p, p + (b - a).cross(Vector3.UP), Vector3.UP)
			var flag := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.34, 0.42, 0.01)
			flag.mesh = prism
			flag.material_override = flag_mats[i % flag_mats.size()]
			flag.rotation.z = PI  # pointe vers le bas
			flag.position.y = -0.21
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(flag)
			_pennants.append(pivot)
		prev = p


# --- Vie : poussières dorées, nuages, mouettes -----------------------------------

func _build_life() -> void:
	# Poussières qui flottent dans la lumière du soir
	_sparkles(self, Vector3(0, 3.0, -4.0), Color(1.0, 0.85, 0.55), 60, 12.0)
	# Nuages en blocs arrondis qui dérivent
	var cloud_mat := Blocks.mat(Color(1.0, 0.93, 0.88), 0.25, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-240, 240), rng.randf_range(70, 100), rng.randf_range(-260, -180))
		add_child(c)
		for k in 4:
			var puff := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = rng.randf_range(7, 12)
			s.height = s.radius * 1.2
			s.radial_segments = 10
			s.rings = 5
			puff.mesh = s
			puff.material_override = cloud_mat
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puff.position = Vector3(k * 10.0 - 15.0, rng.randf_range(-2, 3), rng.randf_range(-4, 4))
			c.add_child(puff)
		_clouds.append(c)
	# Mouettes au-dessus du port
	var white := Blocks.mat(Color(0.96, 0.96, 0.98), 0.0, 0.0)
	for i in 3:
		var g := Node3D.new()
		add_child(g)
		for side in [-1.0, 1.0]:
			var wing := Node3D.new()
			g.add_child(wing)
			Blocks.box(wing, Vector3(0.7, 0.05, 0.25), Vector3(0.35 * side, 0, 0), white)
		_gulls.append(g)


func _sparkles(parent: Node3D, pos: Vector3, color: Color, amount: int, radius: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 3.5
	p.preprocess = 3.5
	p.position = pos
	p.visibility_aabb = AABB(Vector3.ONE * -radius * 1.5, Vector3.ONE * radius * 3.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radius, radius * 0.25 + 1.0, radius * 0.6)
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0.1, 0.15, 0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color.lightened(0.3)
	m.albedo_texture = MarshLevel.soft_dot_texture()
	quad.material = m
	p.draw_pass_1 = quad
	parent.add_child(p)


# --- Outils -------------------------------------------------------------------

## Cache les noms des bâtiments (quand un écran plein est ouvert par-dessus).
func set_labels_visible(on: bool) -> void:
	for id: String in buildings:
		buildings[id].set_label_visible(on and id != "tour")


func _register(b: HubBuilding, id: String, click_size: Vector3, label_height: float) -> void:
	var info: Dictionary = GameData.hub.get("buildings", {}).get(id, {})
	b.setup(id, info.get("name", id), click_size, label_height)
	b.clicked.connect(func(bid: String) -> void: building_clicked.emit(bid))
	buildings[id] = b


## Place un modèle (nom sans extension) : version du lot 1 si elle existe, sinon `assets/hub/`.
## Les anciens modèles en pixels ont leurs textures lissées en aplats.
func _place(parent: Node3D, model: String, pos: Vector3, yaw: float) -> Node3D:
	var path := HUB_LOT1 + model + ".glb"
	var lot1 := ResourceLoader.exists(path)
	var hybride := false
	if not lot1:
		path = HUB_HYBRIDE + model + ".glb"
		hybride = ResourceLoader.exists(path)
	if not lot1 and not hybride:
		path = HUB + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Modèle du hub introuvable : " + path)
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw
	parent.add_child(n)
	if lot1:
		_apply_lot1_materials(n)
	elif not hybride:
		_clean(n)
	_attach_life(n)
	return n


## Les GLB du lot 1 n'embarquent pas leurs textures (les 11 partagent le même atlas) :
## on leur donne les 3 matériaux partagés, créés une seule fois à partir de lot1/textures/.
func _apply_lot1_materials(n: Node) -> void:
	for mesh: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.mesh.surface_get_material(i)
			var key := String(m.resource_name) if m else "Atlas_Batiments"
			mesh.set_surface_override_material(i, lot1_material(key))


static func lot1_material(key: String) -> StandardMaterial3D:
	if _lot1_materials.has(key):
		return _lot1_materials[key]
	var dir := HUB_LOT1 + "textures/Atlas_Batiments_"
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_texture = load(dir + "BaseColor.png")
	m.normal_enabled = true
	m.normal_texture = load(dir + "Normal.png")
	var orm: Texture2D = load(dir + "ORM.png")
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.6
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if key == "Emissif_Fenetres":
		m.emission_enabled = true
		m.emission = Color(1.0, 0.62, 0.22)
		m.emission_energy_multiplier = 1.3
	elif key == "Emissif_Cristaux":
		m.emission_enabled = true
		m.emission = Color(0.6, 0.25, 1.0)
		m.emission_energy_multiplier = 3.0
	_lot1_materials[key] = m
	return m


## Points d'attache des modèles du lot 1 : fumée (Fumee_*), lumière (Lumiere_*), drapeaux (Drapeau_*).
func _attach_life(n: Node3D) -> void:
	for child in n.find_children("*", "Node3D", true, false):
		var node_name := String(child.name)
		if node_name.begins_with("Fumee_"):
			_smoke(child as Node3D)
		elif node_name.begins_with("Lumiere_") and node_name != "Lumiere_Reliques":
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.42)
			l.light_energy = 0.9
			l.omni_range = 3.5
			(child as Node3D).add_child(l)
		elif node_name.begins_with("Drapeau_"):
			_flags.append(child as Node3D)


func _smoke(parent: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.15, 0.1, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1))
	var sc := CurveTexture.new()
	sc.curve = curve
	pm.scale_curve = sc
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.45))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.88, 0.85, 0.82)
	m.albedo_texture = MarshLevel.soft_dot_texture()
	quad.material = m
	p.draw_pass_1 = quad
	parent.add_child(p)


## Remplace la texture pixel (grille 4 × 4 de cases bruitées) par des aplats de couleur.
func _clean(node: Node) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i) as StandardMaterial3D
			# Seules les petites textures pixel (128 px) sont lissées ; les textures cuites du lot 1 restent.
			if m == null or m.albedo_texture == null or m.albedo_texture.get_width() > 256:
				continue
			var copy := m.duplicate() as StandardMaterial3D
			copy.albedo_texture = clean_texture(m.albedo_texture)
			copy.roughness = 0.85
			mesh.set_surface_override_material(i, copy)


static func clean_texture(tex: Texture2D) -> Texture2D:
	if _clean_cache.has(tex):
		return _clean_cache[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var cells := 4
	var cw := img.get_width() / cells
	var ch := img.get_height() / cells
	for cy in cells:
		for cx in cells:
			var sum := Color(0, 0, 0, 0)
			for y in ch:
				for x in cw:
					sum += img.get_pixel(cx * cw + x, cy * ch + y)
			var avg := sum / float(cw * ch)
			img.fill_rect(Rect2i(cx * cw, cy * ch, cw, ch), avg)
	var out := ImageTexture.create_from_image(img)
	_clean_cache[tex] = out
	return out


func _tint(node: Node, tint: Color) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i)
			if m is StandardMaterial3D:
				var copy := m.duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				mesh.set_surface_override_material(i, copy)
