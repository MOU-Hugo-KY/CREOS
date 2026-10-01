class_name Puppet2D
extends Node3D
## Personnage dessiné en 2D, animé comme une marionnette dans le monde 3D (à la Cult of the Lamb).
##
## Les pièces (tête, corps, bras…) sont des PNG à fond transparent dans un dossier, décrites par
## `puppet.json` : pour chaque pièce, son point de pivot dans son image, son parent et l'endroit
## (en pixels de l'image du parent) où elle s'accroche. Toutes les animations sont faites par code
## (respiration, course en sautillant, attaques avec élan et impact, coup reçu, mort, victoire).
## La marionnette fait toujours face à la caméra ; `facing` = 1 (vers la droite) ou -1.

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float alpha = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) { discard; }
	ALBEDO = mix(c.rgb * tint.rgb, flash_color.rgb, flash);
	ALPHA = alpha;
}
"""
const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform float strength = 0.38;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.55, 1.0, d)) * strength;
}
"""

# Mouvements d'attaque connus (le champ "anim" des attaques dans heroes.json).
const MOVES := ["punch", "kick", "slam", "spin", "cast", "cast_sky", "throw", "slash", "stab", "shoot", "pull"]

var folder := ""
var facing := 1.0
var pixel_size := 0.002
var height := 2.4  # hauteur approximative du personnage, en mètres
var state := "idle"
var hover := 0.0  # lévitation (en mètres) : les créatures qui flottent, comme la Liche

var _flip: Node3D
var _rig: Node3D
var _pivots: Dictionary = {}  # nom -> Node3D (rotation de la pièce)
var _rest: Dictionary = {}  # nom -> {pos, rot}
var _mats: Array[ShaderMaterial] = []
var _time := 0.0
var _state_time := 0.0
var _hit_time := 0.4
var _length := 1.0
var _flash_tween: Tween

static var _shader: Shader
static var _shadow_shader: Shader


## Charge la marionnette décrite par `<dossier>/puppet.json`.
func setup(p_folder: String) -> Puppet2D:
	folder = p_folder
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("puppet.json")))
	var cfg: Dictionary = parsed if parsed is Dictionary else {}
	pixel_size = float(cfg.get("pixel_size", 0.002))
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	_add_shadow(float(cfg.get("shadow", 0.9)))
	_flip = Node3D.new()
	add_child(_flip)
	_rig = Node3D.new()
	_flip.add_child(_rig)
	var parts: Dictionary = cfg.get("parts", {})
	# Les parents avant les enfants.
	var pending := parts.keys()
	var guard := 0
	while not pending.is_empty() and guard < 50:
		guard += 1
		for name: String in pending.duplicate():
			var p: Dictionary = parts[name]
			var parent_name: String = p.get("parent", "")
			if parent_name != "" and not _pivots.has(parent_name):
				continue
			_add_part(name, p, parts.get(parent_name, {}))
			pending.erase(name)
	height = float(cfg.get("height", 2.4))
	hover = float(cfg.get("float", 0.0))
	play("idle")
	return self


func _add_part(name: String, p: Dictionary, parent_cfg: Dictionary) -> void:
	var tex: Texture2D = load(folder.path_join(p.get("file", name + ".png")))
	if tex == null:
		return
	var w := tex.get_width()
	var h := tex.get_height()
	var pivot: Array = p.get("pivot", [w / 2.0, h])
	var pivot_node := Node3D.new()
	var parent_name: String = p.get("parent", "")
	if parent_name == "":
		_rig.add_child(pivot_node)
	else:
		var at: Array = p.get("at", [0, 0])
		var ppivot: Array = parent_cfg.get("pivot", [0, 0])
		pivot_node.position = Vector3((float(at[0]) - float(ppivot[0])) * pixel_size,
			-(float(at[1]) - float(ppivot[1])) * pixel_size, 0.0)
		(_pivots[parent_name] as Node3D).add_child(pivot_node)
	pivot_node.position.z = float(p.get("z", 0)) * 0.012
	pivot_node.rotation.z = deg_to_rad(-float(p.get("rest", 0)))
	_pivots[name] = pivot_node
	_rest[name] = {"pos": pivot_node.position, "rot": pivot_node.rotation.z}
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(w, h) * pixel_size
	quad.mesh = mesh
	quad.position = Vector3((w / 2.0 - float(pivot[0])) * pixel_size, (float(pivot[1]) - h / 2.0) * pixel_size, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tex", tex)
	quad.material_override = mat
	_mats.append(mat)
	pivot_node.add_child(quad)


func _add_shadow(size: float) -> void:
	var s := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.6, 0.8) * size
	s.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = _shadow_shader
	s.material_override = m
	s.position.y = 0.03
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)


func set_facing(dir: float) -> void:
	facing = 1.0 if dir >= 0.0 else -1.0


## Joue une animation. Accepte aussi les noms des modèles 3D (Idle, Running_A, Hit_A…).
## `hit_time` : instant de l'impact pour une attaque.
func play(anim: String, hit_time := 0.4) -> void:
	var a := normalize(anim)
	state = a
	_state_time = 0.0
	_hit_time = maxf(0.15, hit_time)
	_length = length(a, hit_time)


static func normalize(anim: String) -> String:
	var low := anim.to_lower()
	for key in ["idle", "run", "walk", "hit", "death", "cheer", "victory", "spawn"]:
		if low.contains(key):
			return {"walk": "run", "victory": "cheer", "spawn": "idle"}.get(key, key)
	return low if low in MOVES else "slash"


func has(_anim: String) -> bool:
	return true


func length(anim: String, hit_time := 0.4) -> float:
	match normalize(anim):
		"hit":
			return 0.4
		"death":
			return 1.2
		"idle", "run", "cheer":
			return 1.0
	return maxf(0.15, hit_time) + 0.55


func is_attacking() -> bool:
	return state in MOVES and _state_time < _length


func flash(color: Color, strength := 0.8) -> void:
	for m in _mats:
		m.set_shader_parameter("flash_color", color)
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(v: float) -> void:
		for m in _mats:
			m.set_shader_parameter("flash", v), strength * 0.85, 0.0, 0.3)


func set_alpha(v: float) -> void:
	for m in _mats:
		m.set_shader_parameter("alpha", v)


func _process(delta: float) -> void:
	_time += delta
	_state_time += delta
	# Face à la caméra (seulement autour de l'axe vertical, légèrement penché vers elle).
	var cam := get_viewport().get_camera_3d()
	if cam:
		var to := cam.global_position - global_position
		var yaw := atan2(to.x, to.z)
		global_rotation = Vector3(0, yaw, 0)
		_flip.rotation.x = -0.18
	_flip.scale.x = lerpf(_flip.scale.x, facing, minf(1.0, delta * 14.0))
	_reset_pose()
	match state:
		"idle":
			_pose_idle()
		"run":
			_pose_run()
		"hit":
			_pose_hit()
		"death":
			_pose_death()
		"cheer":
			_pose_cheer()
		_:
			_pose_attack()
	if hover > 0.0 and state != "death":
		_rig.position.y += hover + sin(_time * 1.7) * hover * 0.3
	if state in MOVES or state == "hit":
		if _state_time >= _length:
			play("idle")


# --- Poses ----------------------------------------------------------------------

func _reset_pose() -> void:
	_rig.position = Vector3.ZERO
	_rig.rotation = Vector3.ZERO
	_rig.scale = Vector3.ONE
	for n: String in _pivots:
		var p: Node3D = _pivots[n]
		p.position = _rest[n].pos
		p.rotation = Vector3(0, 0, _rest[n].rot)


func _rot(part: String, deg: float) -> void:
	if _pivots.has(part):
		(_pivots[part] as Node3D).rotation.z = _rest[part].rot - deg_to_rad(deg)


func _offset(part: String, v: Vector2) -> void:
	if _pivots.has(part):
		(_pivots[part] as Node3D).position = _rest[part].pos + Vector3(v.x, v.y, 0)


func _squash(amount: float) -> void:
	_rig.scale = Vector3(1.0 + amount * 0.6, 1.0 - amount, 1.0)


func _pose_idle() -> void:
	var b := sin(_time * 2.4)
	_squash(b * 0.025)
	_offset("head", Vector2(0, b * 0.025))
	_rot("head", sin(_time * 1.3) * 3.0)
	_rot("arm_front", -8.0 + sin(_time * 2.4 + 0.6) * 6.0)
	_rot("arm_back", 6.0 + sin(_time * 2.4 + 1.2) * 5.0)
	_rot("cape", sin(_time * 2.0) * 4.0)


func _pose_run() -> void:
	var t := _time * 11.0
	_rig.position.y = absf(sin(t)) * 0.16
	_rig.rotation.z = deg_to_rad(-9.0)
	_squash(-absf(sin(t)) * 0.05 + 0.03)
	_rot("arm_front", sin(t) * 35.0)
	_rot("arm_back", -sin(t) * 35.0)
	_rot("head", 4.0 + sin(t * 2.0) * 3.0)
	_rot("cape", -18.0 + sin(t) * 8.0)


func _pose_hit() -> void:
	var k := 1.0 - clampf(_state_time / 0.4, 0.0, 1.0)
	_rig.rotation.z = deg_to_rad(14.0 * k)
	_rig.position.x = -0.15 * k
	_squash(-0.08 * k)
	_rot("head", 12.0 * k)
	_rot("arm_front", 30.0 * k)
	_rot("arm_back", -30.0 * k)


func _pose_death() -> void:
	var k := clampf(_state_time / 0.7, 0.0, 1.0)
	var e := k * k
	_rig.rotation.z = deg_to_rad(80.0 * e)
	_rig.position = Vector3(-0.5 * e, 0.0, 0.0)
	_rot("head", 20.0 * e)
	_rot("arm_front", 60.0 * e)
	_rot("arm_back", -40.0 * e)
	if _state_time > 1.1:
		set_alpha(1.0 - clampf((_state_time - 1.1) / 0.8, 0.0, 1.0))


func _pose_cheer() -> void:
	var t := _time * 8.0
	_rig.position.y = absf(sin(t)) * 0.22
	_rot("arm_front", -140.0 + sin(t) * 15.0)
	_rot("arm_back", 140.0 - sin(t) * 15.0)
	_rot("head", sin(t * 0.5) * 6.0)


## Attaque : élan jusqu'à juste avant l'impact, coup sec à l'impact, puis retour.
func _pose_attack() -> void:
	var t := _state_time
	var hit := _hit_time
	var wind := clampf(t / maxf(0.05, hit - 0.1), 0.0, 1.0)  # 0 -> 1 pendant l'élan
	var strike := clampf((t - (hit - 0.1)) / 0.1, 0.0, 1.0)  # 0 -> 1 juste avant l'impact
	var back := clampf((t - hit - 0.12) / 0.4, 0.0, 1.0)  # retour au repos
	var w := _ease(wind) * (1.0 - _ease(strike))
	var s := _ease(strike) * (1.0 - _ease(back))
	var impact := maxf(0.0, 1.0 - absf(t - hit) / 0.08)
	match state:
		"punch", "stab":
			_rot("arm_front", 50.0 * w - 85.0 * s)
			_offset("arm_front", Vector2(-0.12 * w + 0.28 * s, 0.0))
			_rig.rotation.z = deg_to_rad(8.0 * w - 12.0 * s)
			_rig.position.x = 0.25 * s
		"kick":
			_rig.position.y = 0.35 * s + 0.15 * w
			_rig.rotation.z = deg_to_rad(15.0 * w - 30.0 * s)
			_rot("arm_front", 60.0 * w - 40.0 * s)
			_rot("arm_back", -60.0 * w + 30.0 * s)
			_rig.position.x = 0.35 * s
		"slam":
			_rig.position.y = 0.45 * w
			_rot("arm_front", -130.0 * w + 30.0 * s)
			_rot("arm_back", 130.0 * w - 30.0 * s)
			_squash(-0.06 * w + 0.16 * impact)
		"spin":
			_flip.scale.x = facing * cos(clampf(t / maxf(0.2, hit), 0.0, 1.0) * TAU * 2.0)
			_rot("arm_front", -70.0 * (w + s))
			_rot("arm_back", 70.0 * (w + s))
			_rig.position.y = 0.12 * s
		"cast", "cast_sky":
			var up := -150.0 if state == "cast_sky" else -100.0
			_rot("arm_front", up * w + (up + 60.0) * s)
			_rot("arm_back", -up * 0.8 * w)
			_rig.position.y = 0.2 * w
			_rot("head", -10.0 * w)
		"throw":
			_rot("arm_front", 120.0 * w - 70.0 * s)
			_rig.rotation.z = deg_to_rad(10.0 * w - 10.0 * s)
		"pull":
			_rot("arm_front", -80.0 * s + 40.0 * back)
			_rig.rotation.z = deg_to_rad(-10.0 * s + 15.0 * back * (1.0 - back))
		_:  # slash
			_rot("arm_front", 110.0 * w - 70.0 * s)
			_rig.rotation.z = deg_to_rad(10.0 * w - 14.0 * s)
			_rig.position.x = 0.15 * s
	if impact > 0.0 and state not in ["spin", "slam"]:
		_squash(0.1 * impact)


static func _ease(v: float) -> float:
	return v * v * (3.0 - 2.0 * v)
