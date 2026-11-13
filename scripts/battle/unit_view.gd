class_name UnitView
extends Node3D
## Affichage 3D ; les mouvements et délais ne modifient jamais la simulation.

const ANIM_IDLE := "Idle"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"
const ANIM_DEFAULT_ATTACK := "1H_Melee_Attack_Chop"

var unit: BattleUnit
var anims: Dictionary = {}
var presentation: Dictionary = {}
var home_position: Vector3
var displayed_hp := 0.0

var _anim_player: AnimationPlayer
var _hp_bar: Label3D
var _dead := false
var _acting := false
var _celebrating := false
var _attack_index := 0
var _home_rotation := Vector3.ZERO
var _action_tween: Tween
var _action_impact := 0.0
var _action_duration := 0.0


func setup(p_unit: BattleUnit, data: Dictionary) -> void:
	unit = p_unit
	displayed_hp = unit.hp
	home_position = position
	_home_rotation = rotation
	anims = data.get("anim", {})
	presentation = data.get("presentation", {})
	var scene: PackedScene = load(data.get("model", ""))
	if scene:
		var model := scene.instantiate()
		model.scale = Vector3.ONE * float(data.get("scale", 1.0))
		add_child(model)
		_apply_equipment(model, data)
		_anim_player = model.find_child("AnimationPlayer", true, false)
		if _anim_player:
			for library_name in _anim_player.get_animation_library_list():
				var library := _anim_player.get_animation_library(library_name).duplicate() as AnimationLibrary
				_anim_player.remove_animation_library(library_name)
				_anim_player.add_animation_library(library_name, library)
			_anim_player.animation_finished.connect(_on_animation_finished)
	_hp_bar = Label3D.new()
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.position = Vector3(0, 2.6 * data.get("scale", 1.0), 0)
	_hp_bar.font_size = 48
	_hp_bar.outline_size = 12
	_hp_bar.no_depth_test = true
	add_child(_hp_bar)
	_play(ANIM_IDLE, true)
	refresh()


func _apply_equipment(node: Node, data: Dictionary) -> void:
	# Une liste explicite évite de masquer le corps, le casque ou la cape.
	if node is MeshInstance3D and node.name in data.get("equipment_nodes", []):
		node.visible = node.name in data.get("show", [])
	for child in node.get_children():
		_apply_equipment(child, data)


func refresh() -> void:
	if unit == null:
		return
	var filled := clampi(int(round(displayed_hp / unit.max_hp * 10.0)), 0, 10)
	_hp_bar.text = "%s\n%s" % [unit.display_name, "█".repeat(filled) + "░".repeat(10 - filled)]
	_hp_bar.modulate = Color(0.4, 1, 0.4) if unit.team == 0 else Color(1, 0.45, 0.4)
	if unit.taunt_time > 0.0:
		_hp_bar.text += "  🛡"
	if unit.stun_time > 0.0:
		_hp_bar.text += "  💫"
	_hp_bar.visible = not _dead


## Renvoie le délai d'impact et la durée totale pour synchroniser les événements.
func play_action(target: UnitView = null, skill := false) -> Dictionary:
	if _dead or _celebrating:
		return {"impact": 0.0, "duration": 0.0}
	# Une attaque produite au même pas qu'une compétence garde le geste en cours.
	if _acting and _action_tween and _action_tween.is_running():
		var elapsed := _action_tween.get_total_elapsed_time()
		return {"impact": maxf(0.0, _action_impact - elapsed),
			"duration": maxf(0.0, _action_duration - elapsed)}
	var clip: String = anims.get("attack", ANIM_DEFAULT_ATTACK)
	var variants: Array = anims.get("attacks", [])
	if not skill and not variants.is_empty():
		clip = variants[_attack_index % variants.size()]
		_attack_index += 1
	if skill:
		clip = anims.get("skill", clip)
	clip = _available_clip(clip, anims.get("attack", ANIM_DEFAULT_ATTACK))
	if clip.is_empty():
		return {"impact": 0.0, "duration": 0.0}
	_acting = true
	var duration: float = presentation.get("action_duration", 0.65)
	var advance: bool = presentation.get("advance", false) and not skill and is_instance_valid(target)
	var approach: float = presentation.get("approach_duration", 0.2) if advance else 0.0
	var retreat: float = presentation.get("return_duration", 0.24) if advance else 0.0
	var ratio: float = presentation.get("skill_impact_ratio" if skill else "impact_ratio", 0.45)
	_action_impact = approach + duration * clampf(ratio, 0.0, 1.0)
	_action_duration = approach + duration + retreat
	_action_tween = create_tween()
	if advance:
		var direction := target.global_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			rotation.y = atan2(direction.x, direction.z)
		var distance := maxf(0.0, direction.length() - float(presentation.get("reach", 1.5)))
		var destination := global_position + direction.normalized() * distance
		_play(anims.get("run", ANIM_IDLE), true)
		_action_tween.tween_property(self, "global_position", destination, approach).set_trans(Tween.TRANS_SINE)
	_action_tween.tween_callback(_play_timed.bind(clip, duration))
	_action_tween.tween_interval(duration)
	if advance:
		_action_tween.tween_callback(_play.bind(anims.get("return", ANIM_IDLE), true))
		_action_tween.tween_property(self, "position", home_position, retreat).set_trans(Tween.TRANS_SINE)
	_action_tween.tween_callback(_finish_action)
	return {"impact": _action_impact, "duration": _action_duration}


func play_attack() -> void:
	play_action()


func play_skill() -> void:
	play_action(null, true)


func play_hit() -> void:
	# Le recul ne coupe ni l'attaque ni le retour à la position de départ.
	if not _dead and not _acting and not _celebrating:
		_play(anims.get("hit", ANIM_HIT))


func play_death() -> void:
	_dead = true
	_acting = false
	if _action_tween:
		_action_tween.kill()
	_play(ANIM_DEATH)
	refresh()


func play_victory() -> void:
	if _dead:
		return
	_celebrating = true
	if _action_tween:
		_action_tween.kill()
	_acting = false
	_play(anims.get("victory", ANIM_IDLE), true)


func show_shield() -> void:
	if _dead or not presentation.has("shield_color"):
		return
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.position.y = 0.12
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(presentation.shield_color)
	ring.material_override = material
	add_child(ring)
	var tw := create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(1.8, 1.0, 1.8), 0.65).set_trans(Tween.TRANS_SINE)
	tw.tween_property(material, "albedo_color:a", 0.0, 0.65)
	tw.chain().tween_callback(ring.queue_free)


func popup(text: String, color: Color, big := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font_size = 96 if big else 64
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(randf_range(-0.3, 0.3), 2.0, 0)
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", 3.2, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _available_clip(requested: String, fallback: String) -> String:
	if _anim_player == null:
		return ""
	if _anim_player.has_animation(requested):
		return requested
	if _anim_player.has_animation(fallback):
		return fallback
	return ANIM_IDLE if _anim_player.has_animation(ANIM_IDLE) else ""


func _play_timed(clip: String, duration: float) -> void:
	_play(clip)
	_anim_player.speed_scale = _anim_player.get_animation(clip).length / duration


func _finish_action() -> void:
	_acting = false
	position = home_position
	rotation = _home_rotation
	_play(ANIM_IDLE, true)


func _on_animation_finished(_clip: StringName) -> void:
	if not _dead and not _acting and not _celebrating:
		_play(ANIM_IDLE, true)


func _play(anim_name: String, loop := false) -> void:
	var clip := _available_clip(anim_name, ANIM_IDLE)
	if clip.is_empty():
		return
	_anim_player.clear_queue()
	_anim_player.speed_scale = 1.0
	# Dupliquer seulement le clip dont on change la boucle, dans une bibliothèque locale.
	var desired_loop := Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if _anim_player.get_animation(clip).loop_mode != desired_loop:
		var animation := _anim_player.get_animation(clip).duplicate() as Animation
		animation.loop_mode = desired_loop
		var library := _anim_player.get_animation_library(_anim_player.find_animation_library(_anim_player.get_animation(clip)))
		var animation_name := _anim_player.find_animation(_anim_player.get_animation(clip))
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)
	_anim_player.play(clip, float(presentation.get("blend", 0.12)))
