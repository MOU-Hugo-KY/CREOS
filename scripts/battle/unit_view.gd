class_name UnitView
extends Node3D
## Affichage 3D d'une BattleUnit : modèle, animations, déplacements, éclats, nombres flottants.
## Ne contient aucune règle de jeu : la scène lui dit quoi jouer à partir des événements du moteur.

# Noms d'animations par défaut (modèles KayKit). Un modèle peut les changer avec
# `"anims": {"idle": …, "hit": …, "death": …, "run": …}` dans son JSON.
const DEFAULT_ANIMS := {"idle": "Idle", "hit": "Hit_A", "death": "Death_A", "run": "Running_A", "cheer": "Cheer"}
const ANIM_SPAWN := "Spawn_Ground_Skeletons"
const DASH_TIME := 0.22
const MELEE_REACH := 1.5

const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float amount = 0.0;
void fragment() {
	ALBEDO = flash_color.rgb * amount;
	ALPHA = amount;
}
"""

var unit: BattleUnit
var data: Dictionary
var home_position: Vector3
var model_scale := 1.0
var shown_hp := 0.0  # PV affichés (mis à jour à l'instant de l'impact, pas avant)
var hp_seq := -1  # numéro du dernier événement qui a mis à jour shown_hp

var _anim_player: AnimationPlayer
var _anims: Dictionary = DEFAULT_ANIMS.duplicate()
var _flash_mat: ShaderMaterial
var _dead := false
var _move_tween: Tween
var _flash_tween: Tween
var _highlight: MeshInstance3D
var _target_mark: Node3D

static var _flash_shader: Shader


func setup(p_unit: BattleUnit, p_data: Dictionary) -> void:
	unit = p_unit
	data = p_data
	shown_hp = unit.hp
	home_position = position
	_anims.merge(data.get("anims", {}), true)
	model_scale = data.get("scale", 1.0)
	var scene: PackedScene = load(data.get("model", ""))
	if scene:
		var model := scene.instantiate()
		model.scale = Vector3.ONE * model_scale
		add_child(model)
		_anim_player = model.find_child("AnimationPlayer", true, false)
		_setup_flash(model)
	if unit.team == 1 and _has(ANIM_SPAWN):
		_play(ANIM_SPAWN)
	else:
		_play(_anims.idle, true)


## Point au-dessus de la tête (pour la barre de vie de l'interface).
func head_position() -> Vector3:
	return global_position + Vector3(0, 2.75 * model_scale, 0)


func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.1 * model_scale, 0)


func is_dead() -> bool:
	return _dead


## Joue une attaque. Si `dash_to` est donné (corps-à-corps), avance vers la cible puis revient.
## Renvoie le délai avant l'impact (temps de course + `hit_time`).
func play_attack(anim_name: String, hit_time: float, dash_to: Variant = null) -> float:
	if _dead:
		return hit_time
	var delay := hit_time
	var length := _anim_length(anim_name)
	if dash_to is Vector3:
		var target: Vector3 = dash_to
		var dir := (target - home_position)
		dir.y = 0.0
		var stop := target - dir.normalized() * MELEE_REACH * maxf(1.0, model_scale)
		_kill_move()
		_move_tween = create_tween()
		_move_tween.tween_property(self, "position", stop, DASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_move_tween.tween_callback(func() -> void: _play(anim_name))
		_move_tween.tween_interval(maxf(length, hit_time + 0.2))
		_move_tween.tween_property(self, "position", home_position, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		if _has(_anims.run):
			_play(_anims.run)
		delay += DASH_TIME
	else:
		_play(anim_name)
	return delay


## Anneau doré au sol sous le héros dont c'est le tour.
func set_highlight(on: bool) -> void:
	if on and _highlight == null:
		_highlight = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.75
		torus.outer_radius = 0.95
		torus.rings = 40
		_highlight.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Palette.GOLD
		mat.emission_enabled = true
		mat.emission = Palette.GOLD
		mat.emission_energy_multiplier = 1.5
		_highlight.material_override = mat
		_highlight.scale = Vector3(1, 0.06, 1) * maxf(1.0, model_scale)
		_highlight.position.y = 0.05
		_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_highlight)
	if _highlight:
		_highlight.visible = on


## Cible choisie par le joueur : anneau rouge au sol et flèche qui flotte au-dessus de la tête.
func set_target_mark(on: bool) -> void:
	if on and _target_mark == null:
		_target_mark = Node3D.new()
		add_child(_target_mark)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Palette.TARGET
		mat.no_depth_test = true
		mat.render_priority = 2
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.8
		torus.outer_radius = 0.95
		torus.rings = 40
		ring.mesh = torus
		ring.material_override = mat
		ring.scale = Vector3(1, 0.06, 1) * maxf(1.0, model_scale)
		ring.position.y = 0.06
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_target_mark.add_child(ring)
		var arrow := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.22
		cone.bottom_radius = 0.0
		cone.height = 0.4
		cone.radial_segments = 4
		arrow.mesh = cone
		arrow.material_override = mat
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var top := 3.55 * model_scale
		arrow.position.y = top
		_target_mark.add_child(arrow)
		var tw := arrow.create_tween().set_loops()
		tw.tween_property(arrow, "position:y", top + 0.25, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(arrow, "position:y", top, 0.45).set_trans(Tween.TRANS_SINE)
	if _target_mark:
		_target_mark.visible = on and not _dead


func play_hit(color := Color.WHITE) -> void:
	flash(color, 0.6)
	if _dead:
		return
	# Petit recul (sauf si l'unité est en train de courir vers sa cible).
	if _move_tween == null or not _move_tween.is_running():
		var away := Vector3(-0.25 if unit.team == 0 else 0.25, 0, 0)
		var tw := create_tween()
		tw.tween_property(self, "position", home_position + away, 0.06)
		tw.tween_property(self, "position", home_position, 0.18)
	if _anim_player and not _anim_player.current_animation.begins_with("Spell") and not _is_attacking():
		_play(_anims.hit if randf() < 0.5 or not _has("Hit_B") else "Hit_B")


func play_death() -> void:
	if _target_mark:
		_target_mark.visible = false
	_dead = true
	_kill_move()
	position = home_position
	_play(_anims.death)
	if unit.team == 1:
		# Les ennemis s'enfoncent dans le marais.
		var tw := create_tween()
		tw.tween_interval(1.6)
		tw.tween_property(self, "position:y", -2.5 * model_scale, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: visible = false)


func play_cheer() -> void:
	if not _dead:
		_play(_anims.cheer if _has(_anims.cheer) else _anims.idle, true)


## Éclat lumineux sur tout le modèle (coup reçu, soin, bouclier…).
func flash(color: Color, strength := 0.8) -> void:
	if _flash_mat == null:
		return
	_flash_mat.set_shader_parameter("flash_color", color)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float) -> void: _flash_mat.set_shader_parameter("amount", v), strength, 0.0, 0.3)


## Texte flottant au-dessus de l'unité (dégâts, soins, nom d'attaque…).
func popup(text: String, color: Color, big := false, height := 2.2) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font_size = 110 if big else 72
	l.outline_size = 22
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.position = Vector3(randf_range(-0.35, 0.35), height * model_scale, 0)
	l.scale = Vector3.ONE * 0.4
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector3.ONE * (1.25 if big else 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y + 1.1, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


# --- Interne -----------------------------------------------------------------

func _setup_flash(model: Node) -> void:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FLASH_SHADER
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = _flash_shader
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _flash_mat


func _kill_move() -> void:
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()


func _is_attacking() -> bool:
	var cur := _anim_player.current_animation
	return cur.contains("Attack") or cur.contains("Shoot") or cur == "Throw" or cur.begins_with("Block") or cur.begins_with("Spell")


func _has(anim_name: String) -> bool:
	return _anim_player != null and _anim_player.has_animation(anim_name)


func _anim_length(anim_name: String) -> float:
	if not _has(anim_name):
		return 0.8
	return _anim_player.get_animation(anim_name).length


func _play(anim_name: String, loop := false) -> void:
	if not _has(anim_name):
		return
	_anim_player.play(anim_name, 0.12)
	if loop:
		_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	elif not _dead:
		_anim_player.queue(_anims.idle)
		_anim_player.get_animation(_anims.idle).loop_mode = Animation.LOOP_LINEAR
