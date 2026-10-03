class_name ContinentBackdrop
extends Node3D
## Le continent de CREOS en toile de fond du hub, vu depuis Port-Franc : chaque région a sa
## silhouette sur l'horizon (forêt, marais, citadelle de Morvath, volcan, île des dragons,
## falaises). Tout repose sur une même chaîne de collines et baigne dans la même brume : c'est
## un seul paysage, pas des maquettes posées. Purement décoratif.

# Couleurs « propres » (pas de texture) : la lumière et la brume font le reste.
const HILL := Color(0.38, 0.5, 0.32)
const HILL_FAR := Color(0.32, 0.4, 0.38)
const FOREST := Color(0.2, 0.42, 0.22)
const FOREST_LIGHT := Color(0.32, 0.58, 0.28)
const TRUNK := Color(0.35, 0.24, 0.16)
const MARSH := Color(0.2, 0.3, 0.28)
const DEAD_TREE := Color(0.18, 0.17, 0.16)
const CITADEL_ROCK := Color(0.16, 0.13, 0.2)
const VOLCANO := Color(0.36, 0.22, 0.18)
const LAVA := Color(1.0, 0.45, 0.12)
const CLIFF := Color(0.86, 0.84, 0.78)
const ISLAND_ROCK := Color(0.45, 0.4, 0.38)
const RELIC := Color(0.72, 0.42, 1.0)
const ISLAND_Y := 34.0

var tower_root: Node3D  # où poser la Tour de Morvath (sur la citadelle)

var _dragon: Node3D
var _dragon_wings: Array[Node3D] = []
var _island: Node3D
var _storm_light: OmniLight3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	_build_ridge()
	_build_sylvecroc(Vector3(-190, 0, -235))
	_build_brumenoire(Vector3(-95, 0, -255))
	_build_citadel(Vector3(-10, 0, -290))
	_build_cendrefer(Vector3(85, 0, -270))
	_build_sel_brise(Vector3(200, 0, -190))
	_build_drakonis(Vector3(150, ISLAND_Y, -240))


func _process(delta: float) -> void:
	_time += delta
	if _island:
		_island.position.y = ISLAND_Y + sin(_time * 0.4) * 1.2
	if _dragon:
		var a := _time * 0.25
		_dragon.position = Vector3(150, ISLAND_Y + 12.0, -240) + Vector3(cos(a) * 34.0, sin(a * 2.0) * 3.0, sin(a) * 18.0)
		_dragon.rotation.y = -a + PI
		for w in _dragon_wings:
			w.rotation.z = sin(_time * 5.0) * 0.6 * (1.0 if w.position.x > 0 else -1.0)
	if _storm_light:
		# Éclairs violets de temps en temps au-dessus de la citadelle.
		var flash := pow(maxf(0.0, sin(_time * 1.7) * sin(_time * 0.53 + 1.0)), 30.0)
		_storm_light.light_energy = 3.0 + flash * 40.0


# --- Une seule chaîne de collines relie toutes les régions ------------------------

func _build_ridge() -> void:
	var near := _mat(HILL)
	var far := _mat(HILL_FAR)
	for i in 26:
		var x := -230.0 + i * 18.0 + _rng.randf_range(-6, 6)
		var z := -205.0 - absf(x) * 0.1 + _rng.randf_range(-10, 10)
		if x > 120.0:
			continue  # la mer à droite
		_hill(Vector3(x, 0, z), _rng.randf_range(18, 28), _rng.randf_range(6, 14), near)
		_hill(Vector3(x + 9, 0, z - 40), _rng.randf_range(22, 32), _rng.randf_range(10, 20), far)


# --- Forêt de Sylvecroc : arbres géants -----------------------------------------

func _build_sylvecroc(c: Vector3) -> void:
	_hill(c + Vector3(0, 0, 0), 40, 14, _mat(HILL))
	for i in 9:
		var p := c + Vector3(_rng.randf_range(-30, 30), 6, _rng.randf_range(-18, 12))
		var h := _rng.randf_range(16, 24)
		_cyl(p + Vector3(0, h / 2.0, 0), 1.6, h, _mat(TRUNK), 6)
		for k in 3:
			var r := _rng.randf_range(7, 10) * (1.0 - k * 0.22)
			var leaf := _sphere(p + Vector3(_rng.randf_range(-2, 2), h + k * 5.0 - 2.0, _rng.randf_range(-2, 2)),
				r, _mat(FOREST if k == 0 else FOREST_LIGHT))
			leaf.scale.y = 0.75


# --- Marais de Brumenoire : brume, arbres morts, ruines --------------------------

func _build_brumenoire(c: Vector3) -> void:
	var ground := _sphere(c + Vector3(0, -6, 0), 38, _mat(MARSH))
	ground.scale = Vector3(1.0, 0.3, 0.6)
	for i in 8:
		var p := c + Vector3(_rng.randf_range(-28, 28), 4, _rng.randf_range(-12, 10))
		var h := _rng.randf_range(10, 16)
		_cyl(p + Vector3(0, h / 2.0, 0), 0.7, h, _mat(DEAD_TREE), 5)
		var branch := _box(p + Vector3(1.5, h * 0.7, 0), Vector3(5, 0.6, 0.6), _mat(DEAD_TREE))
		branch.rotation_degrees.z = _rng.randf_range(20, 40)
	for i in 3:
		_box(c + Vector3(-10 + i * 9, 6, 6), Vector3(2.5, _rng.randf_range(6, 11), 2.5), _mat(Color(0.35, 0.38, 0.36)))
	# Nappe de brume verdâtre qui reste posée sur le marais
	for i in 5:
		var fog := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(46, 12)
		fog.mesh = q
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.albedo_color = Color(0.6, 0.78, 0.68, 0.22)
		m.albedo_texture = MarshLevel.soft_dot_texture()
		fog.material_override = m
		fog.position = c + Vector3(-20 + i * 10, 7 + i % 2 * 2, 4)
		add_child(fog)


# --- Citadelle de Morvath : montagne noire, nuage d'orage violet ------------------

func _build_citadel(c: Vector3) -> void:
	var rock := _mat(CITADEL_ROCK)
	_cyl(c + Vector3(0, 10, 0), 34, 20, rock, 7, 7.0)
	_cyl(c + Vector3(-24, 7, 8), 18, 14, rock, 6, 2.0)
	_cyl(c + Vector3(26, 8, 4), 20, 16, rock, 6, 2.5)
	# Plateforme où se dresse la Tour de Morvath (posée par Port-Franc)
	tower_root = Node3D.new()
	tower_root.position = c + Vector3(0, 19.5, 0)
	add_child(tower_root)
	# Nuage d'orage qui tourne autour du sommet
	var cloud_mat := _mat(Color(0.22, 0.17, 0.3))
	for i in 9:
		var a := i * TAU / 9.0
		var puff := _sphere(c + Vector3(cos(a) * 26, 66 + sin(i * 1.7) * 3, sin(a) * 14), _rng.randf_range(7, 11), cloud_mat)
		puff.scale.y = 0.45
	_storm_light = OmniLight3D.new()
	_storm_light.light_color = RELIC
	_storm_light.omni_range = 80.0
	_storm_light.position = c + Vector3(0, 60, 10)
	add_child(_storm_light)


# --- Pics de Cendrefer : volcan avec lave et fumée -------------------------------

func _build_cendrefer(c: Vector3) -> void:
	_cyl(c + Vector3(0, 22, 0), 38, 44, _mat(VOLCANO), 8, 8.0)
	_cyl(c + Vector3(30, 12, 10), 18, 24, _mat(VOLCANO.lightened(0.08)), 7, 3.0)
	var lava := _mat(LAVA, 3.0)
	_cyl(c + Vector3(0, 44.2, 0), 7.5, 0.6, lava, 8)
	# Coulées de lave
	for i in 3:
		var flow := _box(c + Vector3(-6 + i * 6, 34, 14), Vector3(1.4, 22, 0.8), lava)
		flow.rotation_degrees = Vector3(-38, 0, -10 + i * 10)
	var glow := OmniLight3D.new()
	glow.light_color = LAVA
	glow.light_energy = 6.0
	glow.omni_range = 40.0
	glow.position = c + Vector3(0, 50, 0)
	add_child(glow)
	_smoke_column(c + Vector3(0, 46, 0))


# --- Côtes de Sel-Brisé : falaises blanches et phare -----------------------------

func _build_sel_brise(c: Vector3) -> void:
	var cliff := _mat(CLIFF)
	for i in 5:
		_box(c + Vector3(-20 + i * 11, _rng.randf_range(7, 11), _rng.randf_range(-8, 8)),
			Vector3(12, _rng.randf_range(14, 24), 14), cliff).rotation_degrees.y = _rng.randf_range(-15, 15)
	_box(c + Vector3(0, 21, 0), Vector3(30, 2, 18), _mat(HILL))
	# Phare
	_cyl(c + Vector3(8, 30, 0), 1.8, 16, _mat(Color(0.95, 0.95, 0.92)), 8, 1.4)
	_cyl(c + Vector3(8, 32, 0), 1.9, 2.0, _mat(Color(0.8, 0.2, 0.2)), 8)
	_cyl(c + Vector3(8, 39, 0), 1.4, 2.0, _mat(Color(1.0, 0.9, 0.6), 4.0), 8)
	var beam := OmniLight3D.new()
	beam.light_color = Color(1.0, 0.9, 0.6)
	beam.light_energy = 4.0
	beam.omni_range = 25.0
	beam.position = c + Vector3(8, 39, 0)
	add_child(beam)


# --- Île des Dragons : île flottante, cascade, dragon qui tourne ------------------

func _build_drakonis(c: Vector3) -> void:
	_island = Node3D.new()
	_island.position = c
	add_child(_island)
	var rock := _cyl_in(_island, Vector3(0, -9, 0), 16, 18, _mat(ISLAND_ROCK), 7, 0.0)
	rock.rotation_degrees.x = 180
	_cyl_in(_island, Vector3(0, 0.6, 0), 16.5, 1.4, _mat(HILL), 7)
	for i in 4:
		var p := Vector3(_rng.randf_range(-9, 9), 1, _rng.randf_range(-7, 7))
		_cyl_in(_island, p + Vector3(0, 3, 0), 0.6, 6, _mat(TRUNK), 5)
		_sphere_in(_island, p + Vector3(0, 7, 0), 3.2, _mat(FOREST_LIGHT))
	# Cascade qui tombe dans le vide
	var fall := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 26)
	fall.mesh = q
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.9, 1.0, 0.7)
	fall.material_override = m
	fall.position = Vector3(6, -12, 14)
	_island.add_child(fall)
	# Dragon (silhouette en blocs) qui fait des cercles
	_dragon = Node3D.new()
	add_child(_dragon)
	var body := _mat(Color(0.55, 0.2, 0.18))
	_box_in(_dragon, Vector3.ZERO, Vector3(1.6, 1.4, 6), body)
	_box_in(_dragon, Vector3(0, 0.6, 3.6), Vector3(1.2, 1.1, 1.8), body)
	_box_in(_dragon, Vector3(0, 0.2, -4.2), Vector3(0.6, 0.6, 3.5), body)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.8 * side, 0.5, 0.5)
		_dragon.add_child(wing)
		_box_in(wing, Vector3(3.2 * side, 0, 0), Vector3(6, 0.15, 3), _mat(Color(0.7, 0.3, 0.22)))
		_dragon_wings.append(wing)


# --- Briques de construction ----------------------------------------------------

func _mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	return Blocks.mat(color, emission, 0.0)


func _hill(pos: Vector3, radius: float, height: float, m: Material) -> MeshInstance3D:
	var s := _sphere(pos, radius, m)
	s.scale = Vector3(1.0, height / radius, 0.7)
	return s


func _sphere(pos: Vector3, radius: float, m: Material) -> MeshInstance3D:
	return _sphere_in(self, pos, radius, m)


func _sphere_in(parent: Node3D, pos: Vector3, radius: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(pos: Vector3, radius: float, height: float, m: Material, sides := 8, top := -1.0) -> MeshInstance3D:
	return _cyl_in(self, pos, radius, height, m, sides, top)


func _cyl_in(parent: Node3D, pos: Vector3, radius: float, height: float, m: Material, sides := 8, top := -1.0) -> MeshInstance3D:
	var mi := Blocks.cylinder(parent, radius, height, pos, m, sides, top)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _box(pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	return _box_in(self, pos, size, m)


func _box_in(parent: Node3D, pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := Blocks.box(parent, size, pos, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _smoke_column(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = pos
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0.6, 0.2, 0)
	pm.scale_min = 6.0
	pm.scale_max = 9.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	var sc := CurveTexture.new()
	sc.curve = curve
	pm.scale_curve = sc
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.35, 0.3, 0.3)
	m.albedo_texture = MarshLevel.soft_dot_texture()
	quad.material = m
	p.draw_pass_1 = quad
	add_child(p)
