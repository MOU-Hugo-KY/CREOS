class_name Blocks
extends RefCounted
## Petite boîte à outils pour construire le décor en blocs (style des héros chibi) :
## matériaux à texture « pixel » (bruit très fin, filtrage nearest) et formes simples.

static var _materials: Dictionary = {}
static var _noise_tex: ImageTexture


## Matériau mat à grain pixel. `emission` > 0 le fait briller (fenêtres, cristaux…).
static func mat(color: Color, emission := 0.0, grain := 0.1) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), emission, grain]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if grain > 0.0:
		m.albedo_texture = _noise(grain)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.5
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## Prisme triangulaire (toit à deux pans). Le faîte est le long de l'axe X.
static func roof(parent: Node3D, width: float, depth: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(depth, height, width)
	mi.mesh = p
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees.y = 90.0
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, sides := 8, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	mi.mesh = c
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Texture de bruit 16 × 16 (variations de ±grain autour du blanc), partagée.
static func _noise(grain: float) -> ImageTexture:
	if _noise_tex:
		return _noise_tex
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in 16:
		for x in 16:
			var v := 1.0 - rng.randf() * grain * 2.0
			img.set_pixel(x, y, Color(v, v, v))
	_noise_tex = ImageTexture.create_from_image(img)
	return _noise_tex
