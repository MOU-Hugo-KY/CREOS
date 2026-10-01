class_name UnitView
extends Node3D
## Affichage 3D d'une BattleUnit : modèle, animations, barre de vie, nombres flottants.

const ANIM_IDLE := "Idle"
const ANIM_HIT := "Hit_A"
const ANIM_DEATH := "Death_A"
const ANIM_DEFAULT_ATTACK := "1H_Melee_Attack_Chop"
const HP_BAR_WIDTH := 1.2

var unit: BattleUnit
var anims: Dictionary = {}
var home_position: Vector3

var _anim_player: AnimationPlayer
var _hp_bar: Node3D
var _hp_fill: MeshInstance3D
var _status: Label3D
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
		PixelStyle.apply(model)
		_anim_player = model.find_child("AnimationPlayer", true, false)
	_build_hp_bar(2.4 * data.get("scale", 1.0))
	_play(ANIM_IDLE, true)
	refresh()


func refresh() -> void:
	if unit == null:
		return
	var ratio := clampf(unit.hp / unit.max_hp, 0.0, 1.0)
	_hp_fill.scale.x = maxf(ratio, 0.001)
	_hp_fill.position.x = -HP_BAR_WIDTH * (1.0 - ratio) * 0.5
	var icons := ""
	if unit.taunt_time > 0.0:
		icons += "!"
	if unit.stun_time > 0.0:
		icons += "*"
	_status.text = icons
	_hp_bar.visible = unit.is_alive()


## Barre de vie pixel : deux rectangles plats, toujours face à la caméra.
func _build_hp_bar(height: float) -> void:
	_hp_bar = Node3D.new()
	_hp_bar.position = Vector3(0, height, 0)
	_hp_bar.rotation.y = -rotation.y  # annule la rotation du modèle : la barre reste alignée à l'écran
	add_child(_hp_bar)
	var bg := _quad(Vector2(HP_BAR_WIDTH + 0.08, 0.2), Color(0.08, 0.06, 0.1))
	_hp_bar.add_child(bg)
	var color := Color(0.35, 0.9, 0.35) if unit.team == 0 else Color(0.95, 0.3, 0.25)
	_hp_fill = _quad(Vector2(HP_BAR_WIDTH, 0.12), color)
	_hp_fill.sorting_offset = 1.0
	_hp_bar.add_child(_hp_fill)
	_status = Label3D.new()
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.no_depth_test = true
	_status.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_status.font_size = 64
	_status.outline_size = 16
	_status.position = Vector3(0, 0.4, 0)
	_hp_bar.add_child(_status)


func _quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 10 if color.g > 0.2 or color.r > 0.2 else 9
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


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
	l.pixel_size = 0.012
	l.outline_size = 18
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
