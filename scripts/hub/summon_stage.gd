class_name SummonStage
extends HeroPreview
## Scène 3D de l'Autel des Reliques : un sanctuaire nocturne, 4 piliers à cristaux et une relique
## qui flotte au centre. `ceremony()` joue l'invocation : la relique s'emballe, une colonne de
## lumière de la couleur de la rareté jaillit, puis le héros apparaît sur le socle.

const PILLAR_RADIUS := 2.3

var _relic: MeshInstance3D
var _relic_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _sparks_mat: StandardMaterial3D
var _flash: OmniLight3D
var _runes_mat: StandardMaterial3D
var _crystals: Array[MeshInstance3D] = []
var _crystal_mat: StandardMaterial3D
var _spin := 0.6
var _time := 0.0
var busy := false


func _ready() -> void:
	super._ready()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.24, 0.23, 0.29)
	stone.roughness = 0.85
	# Dalle du sanctuaire et cercle de runes
	var floor := MeshInstance3D.new()
	var slab := CylinderMesh.new()
	slab.top_radius = 3.4
	slab.bottom_radius = 3.6
	slab.height = 0.2
	slab.radial_segments = 48
	floor.mesh = slab
	floor.material_override = stone
	floor.position.y = -0.3
	add_child(floor)
	_runes_mat = _glow_mat(Palette.RARITIES[3][1], 0.8)
	var runes := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.85
	ring.outer_radius = 1.95
	ring.rings = 64
	runes.mesh = ring
	runes.material_override = _runes_mat
	runes.scale = Vector3(1, 0.05, 1)
	runes.position.y = -0.18
	add_child(runes)
	for i in 12:
		var a := TAU * i / 12.0
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.02, 0.08 if i % 2 else 0.3)
		mark.mesh = box
		mark.material_override = _runes_mat
		mark.position = Vector3(cos(a) * 2.25, -0.19, sin(a) * 2.25)
		mark.rotation.y = -a
		add_child(mark)
	# Piliers et cristaux
	_crystal_mat = _glow_mat(Palette.RARITIES[3][1], 1.4)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var base := Vector3(cos(a) * PILLAR_RADIUS, 0, sin(a) * PILLAR_RADIUS - 0.4)
		var pillar := MeshInstance3D.new()
		var col := CylinderMesh.new()
		col.top_radius = 0.2
		col.bottom_radius = 0.26
		col.height = 1.5
		col.radial_segments = 8
		pillar.mesh = col
		pillar.material_override = stone
		pillar.position = base + Vector3(0, 0.55, 0)
		add_child(pillar)
		var crystal := MeshInstance3D.new()
		var gem := CylinderMesh.new()
		gem.top_radius = 0.0
		gem.bottom_radius = 0.14
		gem.height = 0.42
		gem.radial_segments = 4
		crystal.mesh = gem
		crystal.material_override = _crystal_mat
		crystal.position = base + Vector3(0, 1.65, 0)
		add_child(crystal)
		_crystals.append(crystal)
	# Relique flottante au centre (avant l'invocation)
	_relic = MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.42
	prism.height = 0.9
	prism.radial_segments = 6
	_relic.mesh = prism
	_relic_mat = _glow_mat(Color(0.75, 0.55, 1.0), 2.0)
	_relic.material_override = _relic_mat
	var lower := MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.42
	tip.bottom_radius = 0.0
	tip.height = 0.55
	tip.radial_segments = 6
	lower.mesh = tip
	lower.material_override = _relic_mat
	lower.position.y = -0.72
	_relic.add_child(lower)
	add_child(_relic)
	# Colonne de lumière et éclair
	_beam = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.9
	tube.bottom_radius = 0.9
	tube.height = 9.0
	tube.radial_segments = 24
	tube.cap_top = false
	tube.cap_bottom = false
	_beam.mesh = tube
	# Colonne douce : plus vive au centre, s'efface sur les bords et vers le haut.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
void fragment() {
	float core = pow(abs(dot(NORMAL, VIEW)), 2.5);
	float fade = smoothstep(1.0, 0.25, UV.y) * smoothstep(0.0, 0.05, UV.y);
	ALBEDO = color.rgb * 1.6;
	ALPHA = color.a * core * (1.0 - UV.y * 0.8) * fade;
}
"""
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = sh
	_beam.material_override = _beam_mat
	_beam.position.y = 4.3
	_beam.visible = false
	add_child(_beam)
	_add_sparks()
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 1.4, 1.0)
	_flash.omni_range = 9.0
	_flash.light_energy = 0.0
	add_child(_flash)
	reset_stage()


func _process(delta: float) -> void:
	super._process(delta)
	_time += delta
	if _relic.visible:
		_relic.rotation.y += delta * _spin
		_relic.position.y = 1.45 + sin(_time * 1.6) * 0.08
	for i in _crystals.size():
		_crystals[i].position.y = 1.65 + sin(_time * 2.0 + i) * 0.06
		_crystals[i].rotation.y += delta * 1.2


## Retour à l'attente : la relique flotte, pas de héros.
func reset_stage() -> void:
	clear_hero()
	_relic.visible = true
	_relic.scale = Vector3.ONE
	_spin = 0.6
	_beam.visible = false
	_flash.light_energy = 0.0
	_set_glow(Color(0.72, 0.42, 1.0))


## L'invocation, en ~2,5 s. Attendre avec `await stage.ceremony(...)`.
func ceremony(hero: Dictionary, rarity: int) -> void:
	busy = true
	var color: Color = Palette.RARITIES.get(rarity, Palette.RARITIES[3])[1]
	reset_stage()
	var tw := create_tween()
	tw.tween_property(self, "_spin", 14.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_relic, "position:y", 2.0, 1.2)
	tw.parallel().tween_method(_set_glow, Color(0.72, 0.42, 1.0), color, 1.2)
	await tw.finished
	_beam.visible = true
	_beam.scale = Vector3(0.2, 1, 0.2)
	_beam_mat.set_shader_parameter("color", Color(color, 0.0))
	var burst := create_tween()
	burst.tween_property(_beam, "scale", Vector3(1.3, 1, 1.3), 0.25).set_trans(Tween.TRANS_BACK)
	burst.parallel().tween_method(_beam_color.bind(color), 0.0, 1.0, 0.2)
	burst.parallel().tween_property(_flash, "light_energy", 9.0, 0.2)
	await burst.finished
	_relic.visible = false
	_flash.light_color = color
	show_hero(hero)
	_disc_mat.emission = color
	_rim.light_color = color
	var fade := create_tween()
	fade.tween_property(_beam, "scale", Vector3(0.05, 1, 0.05), 0.9).set_trans(Tween.TRANS_QUAD)
	fade.parallel().tween_method(_beam_color.bind(color), 1.0, 0.0, 0.9)
	fade.parallel().tween_property(_flash, "light_energy", 1.5, 0.9)
	await fade.finished
	_beam.visible = false
	var attacks: Array = hero.get("attacks", [])
	if attacks.size() > 2:
		play(String(attacks[2].get("anim", "")))
	busy = false


func _beam_color(alpha: float, c: Color) -> void:
	_beam_mat.set_shader_parameter("color", Color(c, alpha))


## Poussière magique qui monte lentement autour du cercle.
func _add_sparks() -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 3.0
	p.position.y = 0.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 2.0
	pm.emission_ring_inner_radius = 0.6
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	_sparks_mat = StandardMaterial3D.new()
	_sparks_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sparks_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_sparks_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = _sparks_mat
	p.draw_pass_1 = quad
	add_child(p)


func _set_glow(c: Color) -> void:
	if _sparks_mat:
		_sparks_mat.albedo_color = c
	for m in [_runes_mat, _crystal_mat, _relic_mat]:
		m.albedo_color = c
		m.emission = c


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m
