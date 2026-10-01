class_name PortFranc
extends Node3D
## Décor du hub : Port-Franc, la ville des chasseurs, au soleil couchant.
## Place pavée, maisons à colombages en blocs, marché, port avec bateau, fontaine au cristal
## (Autel des Reliques) et, au loin, la Tour de Morvath. Purement visuel + bâtiments cliquables.

signal building_clicked(building_id: String)

const KIT := "res://assets/kaykit/dungeon/Assets/"

# Couleurs du village
const STONE := Color(0.62, 0.6, 0.58)
const STONE_DARK := Color(0.42, 0.41, 0.42)
const PLASTER := Color(0.93, 0.86, 0.72)
const PLASTER_WARM := Color(0.95, 0.8, 0.62)
const TIMBER := Color(0.36, 0.22, 0.13)
const WOOD := Color(0.55, 0.36, 0.2)
const ROOF_RED := Color(0.72, 0.25, 0.18)
const ROOF_BLUE := Color(0.24, 0.38, 0.62)
const ROOF_TEAL := Color(0.2, 0.5, 0.5)
const ROOF_ORANGE := Color(0.82, 0.48, 0.2)
const WINDOW := Color(1.0, 0.78, 0.4)
const GRASS := Color(0.36, 0.52, 0.25)
const LEAVES := Color(0.3, 0.55, 0.25)
const LEAVES_DARK := Color(0.22, 0.42, 0.2)
const RELIC := Color(0.72, 0.42, 1.0)

# Maisons : [id ou "", position, rotation Y, largeur, hauteur, profondeur, couleur du toit, enseigne]
const HOUSES := [
	["loge_des_heros", Vector3(-8.0, 0, -11.0), 16.0, 7.0, 4.8, 4.5, ROOF_BLUE, true],
	["ma_loge", Vector3(8.0, 0, -11.0), -16.0, 6.0, 4.4, 4.5, ROOF_RED, true],
	["", Vector3(-1.0, 0, -15.5), 0.0, 4.5, 6.0, 4.0, ROOF_TEAL, false],
	["", Vector3(3.6, 0, -16.5), 0.0, 3.6, 4.6, 3.6, ROOF_ORANGE, false],
	["", Vector3(-15.0, 0, -6.5), 70.0, 4.8, 4.6, 4.0, ROOF_RED, false],
	["", Vector3(-16.0, 0, 2.0), 85.0, 4.0, 4.0, 3.6, ROOF_ORANGE, false],
	["", Vector3(14.0, 0, -15.5), -30.0, 4.5, 5.0, 4.0, ROOF_TEAL, false],
]

const TREES := [Vector3(-19, 0, -11), Vector3(-12.5, 0, -16), Vector3(12.5, 0, -18), Vector3(-20, 0, 7),
	Vector3(-7, 0, -18), Vector3(18, 0, -11), Vector3(-21, 0, -2)]
const LAMPS := [Vector3(-4.5, 0, 2.5), Vector3(4.5, 0, 2.5), Vector3(-5.5, 0, -7.5), Vector3(5.5, 0, -7.5)]

var buildings: Dictionary = {}  # id -> HubBuilding
var _crystal: Node3D
var _lights: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_harbor()
	_build_background()
	for h: Array in HOUSES:
		_build_house(h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7])
	_build_altar()
	_build_market()
	_build_hunt_table()
	_build_tower()
	for p: Vector3 in TREES:
		_build_tree(p)
	for p: Vector3 in LAMPS:
		_build_lamp(p)
	_scatter_props()


func _process(delta: float) -> void:
	_time += delta
	if _crystal:
		_crystal.rotation.y += delta * 0.8
		_crystal.position.y = 3.6 + sin(_time * 1.6) * 0.18
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
	e.tonemap_exposure = 1.0
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.08
	e.fog_enabled = true
	e.fog_light_color = Color(0.55, 0.55, 0.75)
	e.fog_density = 0.0035
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
	plane.size = Vector2(90, 120)
	grass.mesh = plane
	grass.material_override = Blocks.mat(GRASS, 0.0, 0.18)
	grass.position = Vector3(-31, -0.06, -30)
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
	# Mer
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 160)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
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
	water.position = Vector3(74, -0.5, -30)
	add_child(water)
	# Quai en pierre le long de l'eau
	Blocks.box(self, Vector3(1.5, 1.0, 40), Vector3(14.2, -0.45, -6), Blocks.mat(STONE))
	# Ponton en bois
	var plank := Blocks.mat(WOOD)
	var dark := Blocks.mat(TIMBER)
	for i in 8:
		Blocks.box(self, Vector3(1.0, 0.18, 3.2), Vector3(15.5 + i * 1.05, 0.0, 1.0), plank, Vector3(0, randf_range(-2, 2), 0))
	for x in [15.2, 19.2, 23.2]:
		for z in [-0.5, 2.5]:
			Blocks.cylinder(self, 0.18, 1.8, Vector3(x, -0.4, z), dark, 6)
	# Bateau de pêche
	var boat := Node3D.new()
	boat.position = Vector3(21.5, -0.35, -5.0)
	boat.rotation_degrees.y = 18
	add_child(boat)
	var hull := Blocks.mat(Color(0.45, 0.28, 0.16))
	Blocks.box(boat, Vector3(2.4, 0.9, 6.0), Vector3(0, 0.3, 0), hull)
	Blocks.box(boat, Vector3(2.6, 0.2, 6.2), Vector3(0, 0.8, 0), Blocks.mat(Color(0.75, 0.6, 0.35)))
	Blocks.box(boat, Vector3(1.7, 0.7, 1.4), Vector3(0, 0.3, 3.5), hull, Vector3(0, 45, 0))
	Blocks.cylinder(boat, 0.1, 5.0, Vector3(0, 3.2, -0.5), dark, 6)
	Blocks.box(boat, Vector3(0.06, 3.2, 2.6), Vector3(0.1, 3.4, 0.6), Blocks.mat(Color(0.96, 0.92, 0.82)))


func _build_background() -> void:
	# Montagnes lointaines (cônes à facettes)
	var rock := Blocks.mat(Color(0.22, 0.27, 0.42), 0.0, 0.12)
	var snow := Blocks.mat(Color(0.92, 0.9, 0.98))
	var peaks := [
		[Vector3(-60, 0, -140), 30.0, 16.0], [Vector3(-25, 0, -150), 34.0, 19.0], [Vector3(20, 0, -145), 28.0, 15.0],
		[Vector3(55, 0, -135), 24.0, 12.0], [Vector3(-90, 0, -120), 26.0, 13.0],
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

func _build_house(id: String, pos: Vector3, yaw: float, w: float, h: float, d: float, roof_color: Color, sign: bool) -> void:
	var root: Node3D = HubBuilding.new() if id != "" else Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var plaster := Blocks.mat(PLASTER if randi() % 2 == 0 else PLASTER_WARM)
	var timber := Blocks.mat(TIMBER)
	var stone := Blocks.mat(STONE)
	var win := Blocks.mat(WINDOW, 2.2, 0.0)
	var low := h * 0.48
	var up := h * 0.52
	# Socle, rez-de-chaussée en pierre, étage à colombages qui déborde
	Blocks.box(root, Vector3(w + 0.4, 0.5, d + 0.4), Vector3(0, 0.25, 0), Blocks.mat(STONE_DARK))
	Blocks.box(root, Vector3(w, low, d), Vector3(0, 0.5 + low / 2.0, 0), stone)
	Blocks.box(root, Vector3(w + 0.5, up, d + 0.5), Vector3(0, 0.5 + low + up / 2.0, 0), plaster)
	var front := d / 2.0 + 0.27
	for i in range(int(w / 1.6) + 1):
		var x := -w / 2.0 - 0.1 + i * (w + 0.2) / int(w / 1.6)
		Blocks.box(root, Vector3(0.22, up, 0.1), Vector3(x, 0.5 + low + up / 2.0, front), timber)
	Blocks.box(root, Vector3(w + 0.6, 0.25, 0.12), Vector3(0, 0.5 + low + 0.1, front), timber)
	Blocks.box(root, Vector3(w + 0.6, 0.25, 0.12), Vector3(0, 0.5 + low + up - 0.1, front), timber)
	# Fenêtres éclairées et porte
	var wy := 0.5 + low + up * 0.5
	for x in [-w * 0.3, w * 0.3]:
		Blocks.box(root, Vector3(0.9, 1.0, 0.12), Vector3(x, wy, front + 0.02), win)
		Blocks.box(root, Vector3(1.1, 0.14, 0.18), Vector3(x, wy - 0.58, front + 0.05), timber)
	Blocks.box(root, Vector3(0.8, 0.8, 0.12), Vector3(w * 0.3, 0.5 + low * 0.55, d / 2.0 + 0.02), win)
	Blocks.box(root, Vector3(1.3, 2.0, 0.15), Vector3(-w * 0.1, 1.5, d / 2.0 + 0.05), Blocks.mat(WOOD))
	Blocks.box(root, Vector3(1.6, 0.2, 0.25), Vector3(-w * 0.1, 2.6, d / 2.0 + 0.1), timber)
	# Toit et cheminée qui fume
	var roof_h := h * 0.55
	Blocks.roof(root, w + 1.2, d + 1.3, roof_h, Vector3(0, 0.5 + h + roof_h / 2.0, 0), Blocks.mat(roof_color))
	var chimney := Vector3(w * 0.28, 0.5 + h + roof_h * 0.65, -d * 0.15)
	Blocks.box(root, Vector3(0.7, roof_h, 0.7), chimney, stone)
	_smoke(root, chimney + Vector3(0, roof_h / 2.0 + 0.2, 0))
	# Enseigne pendue (bâtiments importants)
	if sign:
		Blocks.box(root, Vector3(0.12, 0.12, 1.2), Vector3(w / 2.0 - 0.4, 0.5 + low + 0.4, front + 0.6), timber)
		Blocks.box(root, Vector3(0.1, 0.9, 1.1), Vector3(w / 2.0 - 0.4, 0.5 + low - 0.2, front + 0.75), Blocks.mat(roof_color.lightened(0.15)))
	if root is HubBuilding:
		_register(root as HubBuilding, id, Vector3(w + 0.5, h + roof_h + 0.5, d + 0.5), h + roof_h + 1.4)


## Fontaine avec le cristal-relique qui flotte : l'Autel des Reliques.
func _build_altar() -> void:
	var root := HubBuilding.new()
	root.position = Vector3(0, 0, -3.0)
	add_child(root)
	var stone := Blocks.mat(STONE)
	var dark := Blocks.mat(STONE_DARK)
	Blocks.cylinder(root, 2.6, 0.7, Vector3(0, 0.35, 0), dark, 10)
	Blocks.cylinder(root, 2.3, 0.72, Vector3(0, 0.38, 0), Blocks.mat(Color(0.25, 0.5, 0.65), 0.4, 0.0), 10)
	Blocks.cylinder(root, 0.7, 2.0, Vector3(0, 1.4, 0), stone, 8)
	Blocks.cylinder(root, 1.1, 0.35, Vector3(0, 2.5, 0), stone, 8)
	# Quatre colonnes runiques autour
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		var p := Vector3(cos(a) * 2.9, 0, sin(a) * 2.9)
		Blocks.box(root, Vector3(0.5, 1.8, 0.5), p + Vector3(0, 0.9, 0), stone)
		Blocks.box(root, Vector3(0.3, 0.3, 0.52), p + Vector3(0, 1.3, 0), Blocks.mat(RELIC, 2.5, 0.0))
	# Cristal (deux pyramides) qui tourne et flotte
	_crystal = Node3D.new()
	root.add_child(_crystal)
	var glow := Blocks.mat(RELIC, 3.0, 0.0)
	Blocks.cylinder(_crystal, 0.75, 1.4, Vector3(0, 0.7, 0), glow, 4, 0.0)
	var bottom := Blocks.cylinder(_crystal, 0.75, 1.0, Vector3(0, -0.5, 0), glow, 4, 0.0)
	bottom.rotation_degrees.x = 180
	var light := OmniLight3D.new()
	light.light_color = RELIC
	light.light_energy = 2.5
	light.omni_range = 8.0
	light.position.y = 3.6
	root.add_child(light)
	_sparkles(root, Vector3(0, 3.4, 0), RELIC)
	_register(root, "autel", Vector3(5.5, 5.0, 5.5), 6.0)


func _build_market() -> void:
	var root := HubBuilding.new()
	root.position = Vector3(-10.5, 0, -0.5)
	root.rotation_degrees.y = 62
	add_child(root)
	var post := Blocks.mat(TIMBER)
	for x in [-1.8, 1.8]:
		for z in [-1.0, 1.0]:
			Blocks.box(root, Vector3(0.2, 2.6, 0.2), Vector3(x, 1.3, z), post)
	Blocks.box(root, Vector3(3.8, 0.9, 1.8), Vector3(0, 0.45, 0.3), Blocks.mat(WOOD))
	# Auvent rayé
	for i in 8:
		var col := Color(0.85, 0.2, 0.2) if i % 2 == 0 else Color(0.97, 0.92, 0.8)
		Blocks.box(root, Vector3(0.5, 0.1, 2.8), Vector3(-1.75 + i * 0.5, 2.75, 0.2), Blocks.mat(col), Vector3(-14, 0, 0))
	# Marchandises
	var goods := [Color(0.9, 0.55, 0.15), Color(0.5, 0.75, 0.25), Color(0.85, 0.25, 0.25), Color(0.95, 0.85, 0.3)]
	for i in 4:
		Blocks.box(root, Vector3(0.45, 0.35, 0.45), Vector3(-1.3 + i * 0.85, 1.08, 0.5), Blocks.mat(goods[i]))
	_place_kit(root, "barrel_small", Vector3(2.4, 0, 1.0))
	_place_kit(root, "box_stacked", Vector3(-2.6, 0, 0.6))
	_register(root, "marche", Vector3(4.5, 3.2, 3.0), 4.4)


func _build_hunt_table() -> void:
	var root := HubBuilding.new()
	root.position = Vector3(8.5, 0, 0.5)
	root.rotation_degrees.y = -58
	add_child(root)
	_place_kit(root, "table_long", Vector3.ZERO)
	# Carte de CREOS posée sur la table (icône pixel en grand)
	var map := Sprite3D.new()
	map.texture = load("res://assets/ui/hub/chasses.png")
	map.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	map.pixel_size = 0.018
	map.rotation_degrees.x = -90
	map.position = Vector3(0, 1.02, 0)
	root.add_child(map)
	# Tableau des primes et fanion
	var post := Blocks.mat(TIMBER)
	Blocks.box(root, Vector3(0.2, 3.2, 0.2), Vector3(-1.4, 1.6, -1.4), post)
	Blocks.box(root, Vector3(0.2, 3.2, 0.2), Vector3(1.4, 1.6, -1.4), post)
	Blocks.box(root, Vector3(3.0, 1.6, 0.12), Vector3(0, 2.3, -1.4), Blocks.mat(WOOD))
	for i in 3:
		Blocks.box(root, Vector3(0.6, 0.75, 0.05), Vector3(-0.9 + i * 0.9, 2.3, -1.32), Blocks.mat(Color(0.95, 0.88, 0.7)))
	_place_kit(root, "banner_patternA_green", Vector3(2.0, 0, -1.2))
	_register(root, "table_des_chasses", Vector3(4.0, 3.5, 3.5), 4.6)


## La Tour de Morvath, au loin sur la montagne, qui luit en violet.
func _build_tower() -> void:
	var root := HubBuilding.new()
	root.position = Vector3(-16, 0, -75)
	root.scale = Vector3.ONE * 0.42
	add_child(root)
	# Matériaux sombres légèrement lumineux : la tour reste noire et violette même dans la brume.
	var dark := Blocks.mat(Color(0.12, 0.08, 0.18), 0.35, 0.15)
	Blocks.cylinder(root, 9.0, 14.0, Vector3(0, 7, 0), Blocks.mat(Color(0.14, 0.12, 0.2), 0.2), 7, 3.5)
	Blocks.cylinder(root, 2.6, 22.0, Vector3(0, 25, 0), dark, 6, 2.0)
	Blocks.cylinder(root, 3.4, 2.0, Vector3(0, 37, 0), dark, 6)
	for i in 6:
		var a := i * TAU / 6.0
		Blocks.box(root, Vector3(0.9, 2.4, 0.9), Vector3(cos(a) * 3.0, 39, sin(a) * 3.0), dark)
	var glow := Blocks.mat(RELIC, 4.0, 0.0)
	for y in [18.0, 24.0, 30.0]:
		Blocks.box(root, Vector3(0.8, 1.4, 0.3), Vector3(0, y, 2.4), glow)
	var orb := Blocks.cylinder(root, 1.2, 2.0, Vector3(0, 41.5, 0), glow, 4, 0.0)
	orb.name = "Orb"
	var light := OmniLight3D.new()
	light.light_color = RELIC
	light.light_energy = 6.0
	light.omni_range = 30.0
	light.position.y = 40
	root.add_child(light)
	_register(root, "tour", Vector3(10, 44, 10), 46.0)


# --- Petits éléments ------------------------------------------------------------

func _build_tree(pos: Vector3) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation_degrees.y = randf() * 90.0
	add_child(t)
	Blocks.box(t, Vector3(0.6, 2.2, 0.6), Vector3(0, 1.1, 0), Blocks.mat(TIMBER))
	var s := randf_range(0.9, 1.2)
	Blocks.box(t, Vector3(2.8, 1.6, 2.8) * s, Vector3(0, 2.8 * s, 0), Blocks.mat(LEAVES_DARK))
	Blocks.box(t, Vector3(2.1, 1.3, 2.1) * s, Vector3(0, 3.9 * s, 0), Blocks.mat(LEAVES), Vector3(0, 30, 0))
	Blocks.box(t, Vector3(1.2, 0.9, 1.2) * s, Vector3(0, 4.8 * s, 0), Blocks.mat(LEAVES.lightened(0.1)), Vector3(0, 10, 0))


func _build_lamp(pos: Vector3) -> void:
	Blocks.cylinder(self, 0.12, 3.0, pos + Vector3(0, 1.5, 0), Blocks.mat(Color(0.15, 0.15, 0.17)), 6)
	Blocks.box(self, Vector3(0.45, 0.55, 0.45), pos + Vector3(0, 3.2, 0), Blocks.mat(WINDOW, 3.0, 0.0))
	Blocks.box(self, Vector3(0.6, 0.12, 0.6), pos + Vector3(0, 3.53, 0), Blocks.mat(Color(0.15, 0.15, 0.17)))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.omni_range = 6.0
	light.light_energy = 1.6
	light.position = pos + Vector3(0, 3.0, 0)
	add_child(light)
	_lights.append(light)


func _scatter_props() -> void:
	var props := [
		["barrel_large", Vector3(-5.5, 0, -12.5)], ["barrel_small", Vector3(-4.6, 0, -12.0)],
		["crates_stacked", Vector3(12.8, 0, -3.5)], ["barrel_large", Vector3(13.2, 0, 2.6)],
		["box_large", Vector3(12.4, 0, -1.0)], ["keg", Vector3(5.0, 0, -12.8)],
		["torch_lit", Vector3(-4.2, 0, -8.6)], ["torch_lit", Vector3(4.6, 0, -8.6)],
		["banner_patternB_blue", Vector3(-12.0, 0, -8.2)], ["banner_patternC_red", Vector3(11.8, 0, -8.6)],
	]
	for p: Array in props:
		_place_kit(self, p[0], p[1])


func _smoke(parent: Node3D, pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.15, 0.1, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1))
	var sc := CurveTexture.new()
	sc.curve = curve
	pm.scale_curve = sc
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
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
	m.albedo_color = Color(0.85, 0.83, 0.8)
	m.albedo_texture = MarshLevel.soft_dot_texture()
	quad.material = m
	p.draw_pass_1 = quad
	parent.add_child(p)


func _sparkles(parent: Node3D, pos: Vector3, color: Color) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.5
	p.preprocess = 2.5
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.4
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


func _place_kit(parent: Node3D, model: String, pos: Vector3) -> void:
	for ext in [".gltf.glb", ".glb"]:
		var path: String = KIT + model + ext
		if ResourceLoader.exists(path):
			var n := (load(path) as PackedScene).instantiate() as Node3D
			n.position = pos
			parent.add_child(n)
			return


func _tint(node: Node, tint: Color) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i)
			if m is StandardMaterial3D:
				var copy := m.duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				mesh.set_surface_override_material(i, copy)
