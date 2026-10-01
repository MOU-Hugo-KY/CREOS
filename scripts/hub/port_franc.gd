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
	["autel", "Autel_Des_Reliques", Vector3(0, 0, -3.0), 0.0, Vector3(5.0, 3.2, 5.0), 4.4],
]

# Décor : [modèle, position, rotation Y, échelle]
const DECOR := [
	# Côté gauche de la place (encadre l'image)
	["Maison_Toit_Rouge", Vector3(-16.5, 0, -4.0), 80.0, 1.05],
	["Maison_Toit_Vert", Vector3(-17.0, 0, 3.5), 95.0, 1.0],
	["Maison_Toit_Orange", Vector3(-15.5, 0, -12.5), 45.0, 1.0],
	# Côté droit, avant le port
	["Maison_Toit_Vert", Vector3(16.0, 0, -12.0), -40.0, 1.0],
	# Première terrasse
	["Maison_Toit_Orange", Vector3(-19.0, TERRACE_1, -21.0), 10.0, 1.1],
	["Maison_Toit_Rouge", Vector3(-11.0, TERRACE_1, -21.5), 0.0, 1.0],
	["Maison_Toit_Vert", Vector3(-4.6, TERRACE_1, -22.5), -4.0, 0.95],
	["Maison_Toit_Rouge", Vector3(5.0, TERRACE_1, -22.0), 6.0, 1.05],
	["Maison_Toit_Orange", Vector3(11.5, TERRACE_1, -21.5), -6.0, 1.0],
	["Maison_Toit_Vert", Vector3(18.5, TERRACE_1, -20.0), -18.0, 1.1],
	# Deuxième terrasse (plus haut, plus loin)
	["Maison_Toit_Vert", Vector3(-15.0, TERRACE_2, -33.0), 8.0, 1.15],
	["Maison_Toit_Orange", Vector3(-7.0, TERRACE_2, -34.0), 0.0, 1.1],
	["Loge_Des_Heros", Vector3(1.0, TERRACE_2, -35.0), 0.0, 1.0],
	["Maison_Toit_Rouge", Vector3(9.0, TERRACE_2, -33.5), -5.0, 1.1],
	["Maison_Toit_Vert", Vector3(16.0, TERRACE_2, -32.0), -12.0, 1.0],
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

const LAMPS := [Vector3(-4.5, 0, 2.5), Vector3(4.5, 0, 2.5), Vector3(-5.5, 0, -7.5), Vector3(5.5, 0, -7.5),
	Vector3(-2.6, TERRACE_1, -17.0), Vector3(2.6, TERRACE_1, -17.0)]

var buildings: Dictionary = {}  # id -> HubBuilding
var backdrop: ContinentBackdrop
var _crystal: Node3D
var _crystal_y := 0.0
var _boat: Node3D
var _gulls: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _time := 0.0

static var _clean_cache: Dictionary = {}  # texture -> texture lissée


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_terraces()
	_build_harbor()
	backdrop = ContinentBackdrop.new()
	add_child(backdrop)
	for b: Array in BUILDINGS:
		_build_building(b[0], b[1], b[2], b[3], b[4], b[5])
	for d: Array in DECOR:
		var n := _place(self, d[0], d[1], d[2])
		if n:
			n.scale = Vector3.ONE * float(d[3])
	for p: Vector3 in LAMPS:
		_build_lamp(p)
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
	e.ambient_light_color = Color(0.42, 0.5, 0.72)
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	e.tonemap_white = 1.6
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_strength = 1.0
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.15
	e.fog_enabled = true
	e.fog_light_color = Color(0.55, 0.58, 0.75)
	e.fog_density = 0.0024
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
	sun.light_energy = 1.55
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

func _build_ground() -> void:
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 400)
	grass.mesh = plane
	grass.material_override = Blocks.mat(GRASS, 0.0, 0.0)
	grass.position = Vector3(-236, -0.06, -180)
	add_child(grass)
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



func _build_harbor() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 360)
	plane.subdivide_width = 60
	plane.subdivide_depth = 100
	water.mesh = plane
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MarshLevel.WATER_SHADER
	mat.shader = shader
	mat.set_shader_parameter("deep_color", Color(0.05, 0.2, 0.34))
	mat.set_shader_parameter("shallow_color", Color(0.14, 0.45, 0.55))
	mat.set_shader_parameter("glint_color", Color(1.0, 0.78, 0.5))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.noise = noise
	noise_tex.generate_mipmaps = true
	mat.set_shader_parameter("noise_tex", noise_tex)
	water.material_override = mat
	water.position = Vector3(134, SEA_LEVEL, -120)
	add_child(water)
	Blocks.box(self, Vector3(1.5, 1.0, 46), Vector3(14.2, -0.45, -9), Blocks.mat(STONE, 0.0, 0.0))
	_place(self, "Ponton_Bois", Vector3(19.0, -DOCK_SURFACE + 0.02, 1.2), 90.0)
	_boat = _place(self, "Bateau_De_Peche", Vector3(21.8, SEA_LEVEL - 0.45, -5.2), 20.0)


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


func _build_lamp(pos: Vector3) -> void:
	_place(self, "Lampadaire", pos, 0.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 7.0
	light.light_energy = 1.8
	light.position = pos + Vector3(0, 3.6, 0)
	add_child(light)
	_lights.append(light)


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
		buildings[id].set_label_visible(on)


func _register(b: HubBuilding, id: String, click_size: Vector3, label_height: float) -> void:
	var info: Dictionary = GameData.hub.get("buildings", {}).get(id, {})
	b.setup(id, info.get("name", id), click_size, label_height)
	b.clicked.connect(func(bid: String) -> void: building_clicked.emit(bid))
	buildings[id] = b


## Place un modèle de `assets/hub/` (nom sans extension), avec ses textures lissées.
func _place(parent: Node3D, model: String, pos: Vector3, yaw: float) -> Node3D:
	var path := HUB + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Modèle du hub introuvable : " + path)
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw
	parent.add_child(n)
	_clean(n)
	return n


## Remplace la texture pixel (grille 4 × 4 de cases bruitées) par des aplats de couleur.
func _clean(node: Node) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var m := mesh.get_active_material(i) as StandardMaterial3D
			if m == null or m.albedo_texture == null:
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
