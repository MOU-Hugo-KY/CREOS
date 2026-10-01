class_name BattleFx
extends Node3D
## Effets visuels du combat : projectiles, éclats d'impact, ondes de choc, tremblement de caméra.
## Purement visuel.

var camera: Camera3D
var _cam_home: Vector3
var _shake := 0.0
var _dot_tex: Texture2D
var _materials: Dictionary = {}  # "couleur|billboard" -> StandardMaterial3D


func setup(p_camera: Camera3D) -> void:
	camera = p_camera
	_cam_home = camera.position
	_dot_tex = MarshLevel.soft_dot_texture()


func _process(delta: float) -> void:
	if camera == null:
		return
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var s := _shake * _shake
		camera.position = _cam_home + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * s * 0.35
	else:
		camera.position = _cam_home


func shake(strength := 0.6) -> void:
	_shake = clampf(maxf(_shake, strength), 0.0, 1.0)


## Boule lumineuse qui vole de `from` à `to` en `duration` secondes.
func projectile(from: Vector3, to: Vector3, color: Color, duration: float, size := 0.35) -> void:
	var orb := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size) * 2.0
	orb.mesh = quad
	orb.material_override = _glow_material(color)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	orb.global_position = from
	var trail := _burst_particles(color, 18, 0.35, 0.3, 0.12)
	trail.one_shot = false
	trail.emitting = true
	orb.add_child(trail)
	var arc := Vector3(0, 0.6, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		orb.global_position = from.lerp(to, t) + arc * sin(t * PI), 0.0, 1.0, maxf(duration, 0.08))
	tw.tween_callback(orb.queue_free)


## Éclat d'impact (étincelles) à une position.
func burst(at: Vector3, color: Color, big := false) -> void:
	var p := _burst_particles(color, 28 if big else 14, 0.5, 4.5 if big else 3.0, 0.16 if big else 0.11)
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)
	var flash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (2.4 if big else 1.4)
	flash.mesh = quad
	flash.material_override = _glow_material(color).duplicate()
	add_child(flash)
	flash.global_position = at
	var tw := create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3.ONE * 1.6, 0.18)
	tw.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(flash.queue_free)


## Onde de choc au sol (attaques ultimes, soins de groupe).
func ring(at: Vector3, color: Color, radius := 4.0) -> void:
	var ring_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 48
	ring_mesh.mesh = torus
	var mat := _glow_material(color, false).duplicate() as StandardMaterial3D
	ring_mesh.material_override = mat
	add_child(ring_mesh)
	ring_mesh.global_position = at + Vector3(0, 0.15, 0)
	ring_mesh.scale = Vector3(0.3, 0.05, 0.3)
	var tw := create_tween().set_parallel()
	tw.tween_property(ring_mesh, "scale", Vector3(radius, 0.05, radius), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_delay(0.1)
	tw.chain().tween_callback(ring_mesh.queue_free)


## Colonne de lumière qui monte (soin, bouclier, lancement d'ultime).
func aura(at: Vector3, color: Color) -> void:
	var p := _burst_particles(color, 20, 0.9, 1.2, 0.14)
	p.process_material.direction = Vector3.UP
	p.process_material.spread = 15.0
	p.process_material.gravity = Vector3(0, 2.0, 0)
	p.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	p.process_material.emission_ring_radius = 0.6
	p.process_material.emission_ring_inner_radius = 0.4
	p.process_material.emission_ring_height = 0.1
	p.process_material.emission_ring_axis = Vector3.UP
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.6, false).timeout.connect(p.queue_free)


## Éclair en zigzag entre deux points (disparaît en un quart de seconde).
func lightning(from: Vector3, to: Vector3, color: Color, segments := 8, thickness := 0.07) -> void:
	var bolt := Node3D.new()
	add_child(bolt)
	var mat := _bolt_material(color)
	var prev := from
	var side := (to - from).cross(Vector3.FORWARD).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p := from.lerp(to, t)
		if i < segments:
			p += side * randf_range(-0.35, 0.35) + Vector3(0, randf_range(-0.2, 0.2), 0)
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		var length := prev.distance_to(p)
		box.size = Vector3(thickness, thickness, length)
		seg.mesh = box
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.add_child(seg)
		seg.global_position = (prev + p) / 2.0
		if length > 0.001:
			seg.look_at(p, Vector3.UP if absf((p - prev).normalized().y) < 0.99 else Vector3.RIGHT)
		prev = p
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 5.0
	bolt.add_child(light)
	light.global_position = to + Vector3(0, 0.5, 0)
	var tw := create_tween()
	tw.tween_interval(0.08)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.parallel().tween_property(light, "light_energy", 0.0, 0.18)
	tw.tween_callback(bolt.queue_free)


## La foudre tombe du ciel sur une position.
func sky_lightning(at: Vector3, color: Color) -> void:
	lightning(at + Vector3(randf_range(-1, 1), 9.0, randf_range(-1, 1)), at, color, 12, 0.12)
	burst(at + Vector3(0, 0.3, 0), color, true)
	ring(at, color, 2.0)


## Flaque (poison…) posée au sol pendant `duration` secondes, avec des bulles.
func pool(at: Vector3, color: Color, duration: float, radius := 1.1) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 24
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, 0.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	disc.global_position = at + Vector3(0, 0.04, 0)
	disc.scale = Vector3(0.2, 1, 0.2)
	var bubbles := _burst_particles(color.lightened(0.3), 10, 1.0, 0.8, 0.09)
	bubbles.one_shot = false
	bubbles.explosiveness = 0.0
	bubbles.process_material.gravity = Vector3(0, 0.6, 0)
	bubbles.process_material.spread = 25.0
	bubbles.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	bubbles.process_material.emission_sphere_radius = radius * 0.7
	disc.add_child(bubbles)
	bubbles.emitting = true
	var tw := create_tween()
	tw.tween_property(disc, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.55, 0.25)
	tw.tween_interval(maxf(0.1, duration - 0.75))
	tw.tween_callback(func() -> void: bubbles.emitting = false)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(disc.queue_free)


## Nuage qui gonfle (explosion de poison, poussière…).
func cloud(at: Vector3, color: Color, size := 3.0) -> void:
	var p := _burst_particles(color, 26, 1.4, 2.5, 0.6)
	p.process_material.gravity = Vector3(0, 0.4, 0)
	p.process_material.damping_min = 3.0
	p.process_material.damping_max = 5.0
	p.process_material.scale_min = size * 0.4
	p.process_material.scale_max = size * 0.7
	add_child(p)
	p.global_position = at + Vector3(0, 0.8, 0)
	p.emitting = true
	get_tree().create_timer(2.0, false).timeout.connect(p.queue_free)


# --- Interne -----------------------------------------------------------------

func _bolt_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.lightened(0.5), 1.0)
	m.disable_receive_shadows = true
	return m


func _burst_particles(color: Color, amount: int, lifetime: float, speed: float, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -6, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * 2.0
	quad.material = _glow_material(color)
	p.draw_pass_1 = quad
	return p


func _glow_material(color: Color, billboard := true) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), billboard]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.disable_receive_shadows = true
	m.no_depth_test = false
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = _dot_tex
	_materials[key] = m
	return m
