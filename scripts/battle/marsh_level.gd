class_name MarshLevel
extends Node3D
## Décor du premier donjon : « Brumenoire — Le Gué des Noyés ».
## Une île de boue au milieu d'un marais brumeux, entourée de ruines englouties.
## Purement visuel (aucune règle de jeu). Tout est construit par code.

const KIT := "res://assets/kaykit/dungeon/Assets/"

# Dalles de boue de l'île (4 × 4 unités chacune), avec quelques variantes.
const DIRT_TILES := ["floor_dirt_large", "floor_dirt_large", "floor_dirt_large_rocky"]

# Éléments de décor : [modèle, position, rotation Y en degrés, échelle].
# Y négatif = à moitié englouti dans le marais.
const PROPS := [
	# Ruines du fond (côté héros à gauche, côté Liche à droite)
	["wall_broken", Vector3(-9.0, -0.6, -8.5), 8.0, 1.0],
	["wall_arched", Vector3(-3.0, -0.9, -10.5), -4.0, 1.0],
	["wall_cracked", Vector3(3.5, -0.7, -10.0), 6.0, 1.0],
	["wall_broken", Vector3(10.0, -0.5, -8.0), -12.0, 1.0],
	["pillar_decorated", Vector3(-12.5, -1.2, -5.0), 0.0, 1.2],
	["pillar", Vector3(13.0, -1.4, -4.5), 0.0, 1.3],
	["pillar", Vector3(-6.5, -1.6, -9.5), 0.0, 1.0],
	["column", Vector3(7.5, -1.0, -9.0), 0.0, 1.0],
	# Gravats et débris sur l'île
	["rubble_large", Vector3(-12.5, -0.3, -4.5), 30.0, 1.0],
	["rubble_half", Vector3(10.8, -0.1, 1.5), -40.0, 1.0],
	["rubble_half", Vector3(-1.0, -0.05, -6.2), 75.0, 0.8],
	["floor_tile_small_broken_A", Vector3(-1.5, 0.02, -4.8), 15.0, 1.0],
	["floor_tile_small_broken_B", Vector3(1.8, 0.02, -5.2), -20.0, 1.0],
	["floor_tile_small_weeds_A", Vector3(0.2, 0.02, 4.6), 0.0, 1.0],
	["sword_shield_broken", Vector3(-0.5, 0.0, -3.8), 40.0, 1.0],
	["barrel_small", Vector3(-8.8, 0.0, -4.0), 0.0, 1.0],
	["box_small", Vector3(-9.6, 0.0, -3.4), 25.0, 1.0],
	["candle_melted", Vector3(9.2, 0.0, -3.6), 0.0, 1.0],
	["candle_thin_lit", Vector3(9.6, 0.0, -3.2), 0.0, 1.0],
	# Bannières de Morvath du côté ennemi
	["banner_patternB_red", Vector3(8.5, 0.0, -6.2), -10.0, 1.0],
	["banner_thin_red", Vector3(12.0, -0.3, -2.0), -60.0, 1.0],
]

# Teintes appliquées aux modèles KayKit (trop propres pour un marais).
const MUD_TINT := Color(0.42, 0.37, 0.3)
const MOSS_TINT := Color(0.62, 0.72, 0.66)

# Torches allumées : position (une lumière orange qui vacille est ajoutée).
const TORCHES := [Vector3(-7.0, 0.0, -5.5), Vector3(6.5, 0.0, -5.8), Vector3(-11.0, 0.0, 3.0), Vector3(11.5, 0.0, 3.5)]

const WATER_SHADER := """
shader_type spatial;

uniform vec3 deep_color : source_color = vec3(0.02, 0.05, 0.05);
uniform vec3 shallow_color : source_color = vec3(0.08, 0.14, 0.11);
uniform vec3 glint_color : source_color = vec3(0.5, 0.85, 0.7);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void vertex() {
	VERTEX.y += (sin(VERTEX.x * 0.7 + TIME * 0.7) + sin(VERTEX.z * 1.1 - TIME * 0.5)) * 0.02;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world.xz * 0.05;
	float n1 = texture(noise_tex, uv + vec2(TIME * 0.012, TIME * 0.007)).r;
	float n2 = texture(noise_tex, uv * 2.3 - vec2(TIME * 0.01, -TIME * 0.015)).r;
	float n = n1 * 0.6 + n2 * 0.4;
	// Plus clair près de l'île (au centre), plus sombre au loin.
	float near_island = 1.0 - smoothstep(10.0, 24.0, length(world.xz * vec2(0.75, 1.4)));
	ALBEDO = mix(deep_color, shallow_color, near_island * 0.9) * (0.8 + n * 0.4);
	// Quelques reflets qui scintillent, rares et irréguliers.
	float glint = smoothstep(0.7, 0.78, n2) * smoothstep(0.55, 0.7, n1);
	EMISSION = glint_color * glint * 0.25 * (0.3 + near_island * 0.7);
	NORMAL_MAP = vec3(n1, n2, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.08 + n * 0.1;
	METALLIC = 0.1;
	SPECULAR = 0.6;
}
"""

var _torch_lights: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_island()
	_build_water()
	_build_props()
	_build_fog_and_wisps()


func _process(delta: float) -> void:
	_time += delta
	# Les torches vacillent.
	for i in _torch_lights.size():
		var l := _torch_lights[i]
		l.light_energy = 2.2 + sin(_time * 9.0 + i * 1.7) * 0.25 + sin(_time * 23.0 + i) * 0.15


# --- Ciel, lumières, brouillard -------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.03, 0.04, 0.07)
	sky_mat.sky_horizon_color = Color(0.12, 0.17, 0.16)
	sky_mat.ground_horizon_color = Color(0.1, 0.14, 0.13)
	sky_mat.ground_bottom_color = Color(0.03, 0.05, 0.05)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.5, 0.58)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_bloom = 0.05
	e.fog_enabled = true
	e.fog_light_color = Color(0.13, 0.19, 0.18)
	e.fog_density = 0.028
	e.fog_sky_affect = 0.6
	e.fog_height = -0.5
	e.fog_height_density = 0.12
	var env := WorldEnvironment.new()
	env.environment = e
	add_child(env)

	# Lune froide (lumière principale) + contre-jour verdâtre du marais.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, -35, 0)
	moon.light_color = Color(0.78, 0.86, 1.0)
	moon.light_energy = 1.0
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_color = Color(0.45, 0.8, 0.6)
	rim.light_energy = 0.35
	add_child(rim)


# --- Île de boue ---------------------------------------------------------------

func _build_island() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # même île à chaque fois
	for x in range(-4, 4):
		for z in range(-2, 2):
			var cx := x * 4 + 2
			var cz := z * 4 + 2
			# Bords irréguliers : on retire quelques dalles aux coins.
			var edge := absi(x * 2 + 1) >= 7 and absi(z * 2 + 1) >= 3
			if edge and rng.randf() < 0.7:
				continue
			var tile := _instance(DIRT_TILES[rng.randi() % DIRT_TILES.size()])
			if tile:
				_tint(tile, MUD_TINT)
				tile.position = Vector3(cx, 0, cz)
				tile.rotation_degrees.y = 90.0 * rng.randi_range(0, 3)
				add_child(tile)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	plane.subdivide_width = 80
	plane.subdivide_depth = 80
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	mat.shader = shader
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise
	noise_tex.generate_mipmaps = true
	mat.set_shader_parameter("noise_tex", noise_tex)
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = plane
	water.material_override = mat
	water.position = Vector3(0, -0.12, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_props() -> void:
	for p: Array in PROPS:
		var node := _instance(p[0])
		if node == null:
			continue
		var model_name := String(p[0])
		if model_name.begins_with("wall") or model_name.begins_with("pillar") or model_name == "column":
			_tint(node, MOSS_TINT)
		elif model_name.begins_with("rubble") or model_name.begins_with("floor"):
			_tint(node, MUD_TINT.lightened(0.25))
		node.position = p[1]
		node.rotation_degrees.y = p[2]
		node.scale = Vector3.ONE * float(p[3])
		add_child(node)
	for pos: Vector3 in TORCHES:
		var torch := _instance("torch_lit")
		if torch:
			torch.position = pos
			add_child(torch)
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 2.2, 0)
		light.light_color = Color(1.0, 0.6, 0.25)
		light.omni_range = 7.0
		light.light_energy = 2.2
		add_child(light)
		_torch_lights.append(light)


# --- Brume et feux follets ------------------------------------------------------

func _build_fog_and_wisps() -> void:
	# Nappes de brume basses qui dérivent lentement.
	var mist := GPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = 28
	mist.lifetime = 14.0
	mist.preprocess = 14.0
	mist.position = Vector3(0, 0.4, -2)
	var mist_proc := ParticleProcessMaterial.new()
	mist_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mist_proc.emission_box_extents = Vector3(22, 0.3, 10)
	mist_proc.direction = Vector3(1, 0, 0)
	mist_proc.spread = 20.0
	mist_proc.initial_velocity_min = 0.2
	mist_proc.initial_velocity_max = 0.5
	mist_proc.gravity = Vector3.ZERO
	mist_proc.scale_min = 0.7
	mist_proc.scale_max = 1.3
	var mist_curve := Curve.new()
	mist_curve.add_point(Vector2(0, 0))
	mist_curve.add_point(Vector2(0.3, 1))
	mist_curve.add_point(Vector2(0.7, 1))
	mist_curve.add_point(Vector2(1, 0))
	var mist_alpha := CurveTexture.new()
	mist_alpha.curve = mist_curve
	mist_proc.alpha_curve = mist_alpha
	mist.process_material = mist_proc
	var mist_quad := QuadMesh.new()
	mist_quad.size = Vector2(9, 3.5)
	mist_quad.material = _soft_billboard_material(Color(0.55, 0.68, 0.64, 0.16))
	mist.draw_pass_1 = mist_quad
	add_child(mist)

	# Feux follets verts (les âmes des noyés…).
	var wisps := GPUParticles3D.new()
	wisps.name = "Wisps"
	wisps.amount = 22
	wisps.lifetime = 6.0
	wisps.preprocess = 6.0
	wisps.position = Vector3(0, 1.2, -3)
	var wisp_proc := ParticleProcessMaterial.new()
	wisp_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	wisp_proc.emission_box_extents = Vector3(16, 1.0, 8)
	wisp_proc.direction = Vector3(0, 1, 0)
	wisp_proc.spread = 60.0
	wisp_proc.initial_velocity_min = 0.1
	wisp_proc.initial_velocity_max = 0.35
	wisp_proc.gravity = Vector3(0, 0.05, 0)
	wisp_proc.turbulence_enabled = true
	wisp_proc.turbulence_noise_strength = 0.6
	wisp_proc.turbulence_noise_scale = 3.0
	wisp_proc.alpha_curve = mist_alpha
	wisps.process_material = wisp_proc
	var wisp_quad := QuadMesh.new()
	wisp_quad.size = Vector2(0.22, 0.22)
	wisp_quad.material = _soft_billboard_material(Color(0.5, 1.0, 0.65, 0.9), 3.0)
	wisps.draw_pass_1 = wisp_quad
	add_child(wisps)


## Matériau de particule : disque flou, toujours face à la caméra.
func _soft_billboard_material(color: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = soft_dot_texture()
	m.disable_receive_shadows = true
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	return m


## Texture ronde et floue (dégradé radial), partagée par les particules du combat.
static func soft_dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## Assombrit/teinte tous les matériaux d'un modèle (copie : le fichier d'origine n'est pas modifié).
func _tint(node: Node, tint: Color) -> void:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_active_material(i)
			if mat is StandardMaterial3D:
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				mesh.set_surface_override_material(i, copy)


func _instance(model: String) -> Node3D:
	for ext in [".gltf.glb", ".glb"]:
		var path: String = KIT + model + ext
		if ResourceLoader.exists(path):
			return (load(path) as PackedScene).instantiate() as Node3D
	push_warning("Décor introuvable : " + model)
	return null
