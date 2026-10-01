class_name UnitView
extends Node3D
## Affichage 3D d'une BattleUnit : modèle, animations, barre de vie, nombres flottants.

const ANIM_IDLE := "Idle"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"
const ANIM_DEFAULT_ATTACK := "1H_Melee_Attack_Chop"

var unit: BattleUnit
var anims: Dictionary = {}
var home_position: Vector3

var _anim_player: AnimationPlayer
var _hp_bar: Label3D
var _dead := false


func setup(p_unit: BattleUnit, data: Dictionary) -> void:
	unit = p_unit
	anims = data.get("anim", {})
	var scene: PackedScene = load(data.get("model", ""))
	if scene:
		var model := scene.instantiate()
		var s: float = data.get("scale", 1.0)
		model.scale = Vector3.ONE * s
		add_child(model)
		_anim_player = model.find_child("AnimationPlayer", true, false)
	_hp_bar = Label3D.new()
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.position = Vector3(0, 2.6 * data.get("scale", 1.0), 0)
	_hp_bar.font_size = 48
	_hp_bar.outline_size = 12
	_hp_bar.no_depth_test = true
	add_child(_hp_bar)
	_play(ANIM_IDLE, true)
	refresh()


func refresh() -> void:
	if unit == null:
		return
	var ratio := unit.hp / unit.max_hp
	var filled := int(round(ratio * 10.0))
	_hp_bar.text = "%s\n%s" % [unit.display_name, "█".repeat(filled) + "░".repeat(10 - filled)]
	_hp_bar.modulate = Color(0.4, 1, 0.4) if unit.team == 0 else Color(1, 0.45, 0.4)
	if unit.taunt_time > 0.0:
		_hp_bar.text += "  🛡"
	if unit.stun_time > 0.0:
		_hp_bar.text += "  💫"
	_hp_bar.visible = unit.is_alive()


func play_attack() -> void:
	_play(anims.get("attack", ANIM_DEFAULT_ATTACK))


func play_skill() -> void:
	_play(anims.get("skill", anims.get("attack", ANIM_DEFAULT_ATTACK)))


func play_hit() -> void:
	if not _dead:
		_play(ANIM_HIT)


func play_death() -> void:
	_dead = true
	_play(ANIM_DEATH)


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


func _play(anim_name: String, loop := false) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	_anim_player.play(anim_name, 0.15)
	if loop:
		_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	elif not _dead:
		_anim_player.queue(ANIM_IDLE)
