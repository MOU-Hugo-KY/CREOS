class_name HeroPreview
extends SubViewport
## Petite scène 3D séparée qui montre un héros sur un socle lumineux, en train de tourner
## doucement. `play(anim)` lui fait jouer une animation (ses attaques) puis revenir au repos.

var _pivot: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _idle := "Idle"
var _disc_mat: StandardMaterial3D
var _rim: OmniLight3D


func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_2X
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.75)
	e.ambient_light_energy = 0.7
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	add_child(env)
	var cam := Camera3D.new()
	cam.fov = 32
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.4, 7.6), Vector3(0, 1.35, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	_rim = OmniLight3D.new()
	_rim.position = Vector3(0, 2.0, -2.0)
	_rim.omni_range = 6.0
	_rim.light_energy = 2.0
	add_child(_rim)
	# Socle
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.25
	cyl.bottom_radius = 1.35
	cyl.height = 0.18
	cyl.radial_segments = 32
	disc.mesh = cyl
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.albedo_color = Color(0.12, 0.12, 0.15)
	_disc_mat.emission_enabled = true
	_disc_mat.emission_energy_multiplier = 0.12
	disc.material_override = _disc_mat
	disc.position.y = -0.09
	add_child(disc)
	_pivot = Node3D.new()
	add_child(_pivot)


func _process(delta: float) -> void:
	_pivot.rotation.y += delta * 0.35


func show_hero(hero: Dictionary) -> void:
	if _model:
		_model.queue_free()
	_model = null
	_anim = null
	_idle = hero.get("anims", {}).get("idle", "Idle")
	var color := Palette.element_color(hero.get("element", ""))
	_disc_mat.emission = color
	_rim.light_color = color
	_pivot.rotation.y = deg_to_rad(-20)
	var scene: PackedScene = load(hero.get("model", ""))
	if scene == null:
		return
	_model = scene.instantiate()
	_pivot.add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim and _anim.has_animation(_idle):
		_anim.get_animation(_idle).loop_mode = Animation.LOOP_LINEAR
		_anim.play(_idle)


func play(anim_name: String) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.play(anim_name, 0.15)
	_anim.queue(_idle)
