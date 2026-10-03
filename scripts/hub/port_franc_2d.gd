class_name PortFranc2D
extends Node3D
## Port-Franc en 2D dessinée, monté comme un théâtre en plans étagés : chaque calque de
## `assets/hub2d/port/` est une grande image posée plus ou moins loin de la caméra. Quand on
## glisse, les plans lointains bougent moins vite (parallaxe naturelle). Bâtiments cliquables
## (avec leur version « survol »), animations en planches de sprites, héros marionnettes qui se
## promènent sur la place. Positions : `Layout.json`, en pixels de la scène 3840 × 1080.

signal building_clicked(building_id: String)

const DIR := "res://assets/hub2d/port/"
const PX := 0.01  # 1 pixel de la scène = 1 cm au plan de la place
const SCENE_SIZE := Vector2(3840, 1080)
const FOV := 30.0
const CAM_DIST := 20.153  # distance caméra / place pour voir 1080 px de haut avec FOV 30°

# Calques de fond : [fichier, profondeur derrière la place, en mètres]
const LAYERS := [["Port_Ciel.png", 60.0], ["Port_Horizon.png", 30.0], ["Port_Ville_Fond.png", 6.0],
	["Port_Place.png", 0.0], ["Port_Premier_Plan.png", -1.2]]
# Fichier du Layout -> id du bâtiment dans data/hub.json
const IDS := {"Loge_Des_Heros": "loge_des_heros", "Ma_Loge": "ma_loge", "Marche": "marche",
	"Table_Des_Chasses": "table_des_chasses", "Echoppe_Des_Masques": "echoppe_masques",
	"Lanterne_Des_Serments": "autel", "Tour_De_Morvath": "tour"}
# Animations posées dans la scène : [planche, x, y, taille en px, profondeur]
const ANIMS := [
	["Fumee_Cheminee_8f_10fps.png", 1432, 40, 150, 0.0], ["Fumee_Cheminee_8f_10fps.png", 2598, 70, 130, 0.0],
	["Flamme_Lanterne_8f_12fps.png", 1592, 430, 46, 0.0], ["Flamme_Lanterne_8f_12fps.png", 1752, 430, 46, 0.0],
	["Flamme_Lanterne_8f_12fps.png", 2340, 450, 42, 0.0], ["Flamme_Lanterne_8f_12fps.png", 2492, 450, 42, 0.0],
	["Fanion_8f_10fps.png", 352, 40, 110, 6.0], ["Fanion_8f_10fps.png", 760, 210, 90, 6.0], ["Fanion_8f_10fps.png", 3580, 560, 110, 0.0],
	["Eau_Port_8f_10fps.png", 3150, 640, 150, 0.0], ["Eau_Port_8f_10fps.png", 3420, 700, 170, 0.0],
	["Eau_Port_8f_10fps.png", 3700, 620, 140, 0.0], ["Eau_Port_8f_10fps.png", 3300, 760, 130, 0.0],
]
const GROUND := Rect2(720, 880, 2160, 130)  # zone où marchent les héros (px)

var buildings: Dictionary = {}  # id -> HubBuilding
var camera_pos := Vector3(19.2, 5.4, CAM_DIST)
var camera_look := Vector3(19.2, 5.4, 0)
var pan_limit := 9.6
var wanderers: Array = []
var own_wanderers := true  # la scène du hub ne crée pas ses promeneurs 3D

var _shader: Shader
var _anim_shader: Shader
var _gulls: Array[Node3D] = []
var _walkers: Array[Dictionary] = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_build_shaders()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.5, 0.7)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)
	for l: Array in LAYERS:
		var layer := _sprite(load(DIR + l[0]), Vector2(1920, 540), Vector2(0.5, 0.5), SCENE_SIZE, float(l[1]))
		layer.material_override.render_priority = priority_for_depth(float(l[1]))
	var layout := _layout()
	for o: Dictionary in layout.get("objects", []):
		if not o.has("display_size"):
			continue
		var file: String = o.file
		var key := file.trim_suffix(".png")
		var size := Vector2(o.display_size[0], o.display_size[1])
		var anchor := Vector2(o.get("anchor_normalized", [0.5, 1.0])[0], o.get("anchor_normalized", [0.5, 1.0])[1])
		var at := Vector2(o.x, o.y)
		var depth := 29.9 if int(o.get("layer", 35)) < 20 else _depth_for(at.y)
		if key == "Lanterne_Coeur":
			var heart := _anim(load(DIR + "Lanterne_Pulse_8f_10fps.png"), at, size, depth - 0.01, 8, 10.0, anchor)
			heart.material_override.render_priority = priority_for(900.0) + 1  # sur la Lanterne
		elif key == "Bateau_De_Peche":
			var boat := _anim(load(DIR + "Bateau_Tangue_10f_8fps.png"), at, size, depth, 10, 8.0, anchor)
			boat.material_override.render_priority = priority_for(at.y)
		elif IDS.has(key):
			_building(IDS[key], key, at, size, anchor, depth, -90 if depth > 20.0 else priority_for(at.y))
	for a: Array in ANIMS:
		var tex: Texture2D = load(DIR + a[0])
		var frames := int(String(a[0]).get_slice("_", String(a[0]).get_slice_count("_") - 2).trim_suffix("f"))
		var fps := float(String(a[0]).get_slice("_", String(a[0]).get_slice_count("_") - 1).trim_suffix("fps.png"))
		var sz := float(a[3])
		var fx := _anim(tex, Vector2(a[1], a[2]), Vector2(sz, sz), float(a[4]) - 0.05, frames, fps, Vector2(0.5, 0.5))
		fx.material_override.render_priority = -19 if float(a[4]) > 1.0 else (priority_for(620.0) + 1 if a[2] < 600 else 5)
	for i in 3:
		var g := _anim(load(DIR + "Mouette_8f_10fps.png"), Vector2(0, 0), Vector2(90, 90), 8.0, 8, 10.0, Vector2(0.5, 0.5))
		g.material_override.render_priority = -30
		_gulls.append(g)
	_add_merchant()
	_add_heroes()


func _process(delta: float) -> void:
	_time += delta
	for i in _gulls.size():
		var a := _time * (0.12 + i * 0.03) + i * 2.1
		var p := Vector2(2600 + cos(a) * (900 + i * 250), 220 + sin(a * 2.0) * 60 + i * 50)
		_gulls[i].position = _world(p, 8.0)
		_gulls[i].scale.x = -1.0 if sin(a) > 0 else 1.0
	for w: Dictionary in _walkers:
		_walk(w, delta)


## Hauteur des étiquettes : appelée par la scène du hub quand un écran plein s'ouvre.
func set_labels_visible(on: bool) -> void:
	for id: String in buildings:
		buildings[id].set_label_visible(on and id != "tour")


# --- Construction -------------------------------------------------------------------

func _layout() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "Layout.json"))
	return parsed if parsed is Dictionary else {}


## Ordre de dessin (on ne se fie pas à la profondeur) : fond < place < objets triés par leur
## point au sol (plus bas = devant) < premier plan.
static func priority_for(ground_y: float) -> int:
	return clampi(10 + int((ground_y - 560.0) / 5.0), 10, 110)


static func priority_for_depth(depth: float) -> int:
	if depth >= 29.0:
		return -100 + int(60.0 - depth)  # ciel, horizon
	if depth >= 5.0:
		return -20  # ville du fond
	if depth > -0.5 and depth <= 0.0 and is_zero_approx(depth):
		return 0  # place
	return 120  # premier plan


## Profondeur d'un objet posé sur la place : plus il est bas à l'écran, plus il est devant.
func _depth_for(ground_y: float) -> float:
	return -(ground_y - 600.0) * 0.002


## Point de la scène (px) -> position 3D sur un plan à `depth` mètres derrière la place.
func _world(px: Vector2, depth: float) -> Vector3:
	var s := (CAM_DIST + depth) / CAM_DIST
	return Vector3(19.2 + (px.x - 1920.0) * PX * s, 5.4 + (540.0 - px.y) * PX * s, -depth)


func _quad(tex: Texture2D, size_px: Vector2, depth: float, anchor: Vector2, mat: ShaderMaterial) -> MeshInstance3D:
	var s := (CAM_DIST + depth) / CAM_DIST
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size_px * PX * s
	q.center_offset = Vector3((0.5 - anchor.x) * q.size.x, (anchor.y - 0.5) * q.size.y, 0)
	m.mesh = q
	mat.set_shader_parameter("tex", tex)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


func _sprite(tex: Texture2D, at: Vector2, anchor: Vector2, size_px: Vector2, depth: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var m := _quad(tex, size_px, depth, anchor, mat)
	m.position = _world(at, depth)
	add_child(m)
	return m


func _anim(tex: Texture2D, at: Vector2, size_px: Vector2, depth: float, frames: int, fps: float, anchor: Vector2) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = _anim_shader
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("fps", fps)
	mat.set_shader_parameter("phase", _rng.randf() * 10.0)
	var m := _quad(tex, size_px, depth, anchor, mat)
	m.position = _world(at, depth)
	add_child(m)
	return m


func _building(id: String, key: String, at: Vector2, size: Vector2, anchor: Vector2, depth: float, prio: int) -> void:
	var b := HubBuilding.new()
	b.position = _world(at, depth)
	add_child(b)
	var tex: Texture2D = load(DIR + key + ".png")
	var hover_path := DIR + key + "_Survol.png"
	var hover: Texture2D = load(hover_path) if ResourceLoader.exists(hover_path) else null
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var quad := _quad(tex, size, depth, anchor, mat)
	mat.render_priority = prio
	b.add_child(quad)
	var s := (CAM_DIST + depth) / CAM_DIST
	var info: Dictionary = GameData.hub.get("buildings", {}).get(id, {})
	# Zone cliquable : la partie dessinée au-dessus du point au sol (un peu réduite).
	var visible_h := size.y * anchor.y * PX * s
	# Étiquette juste au-dessus de l'entrée (pas au sommet du toit, pour ne pas chevaucher).
	b.setup(id, info.get("name", id), Vector3(size.x * PX * s * 0.75, visible_h * 0.9, 0.3), minf(visible_h * 0.9, 3.0))
	b.set_label_size(26)
	b.clicked.connect(func(bid: String) -> void: building_clicked.emit(bid))
	if hover:
		b.hovered.connect(func(on: bool) -> void: mat.set_shader_parameter("tex", hover if on else tex))
	buildings[id] = b
	if id == "tour":
		b.set_label_visible(false)


func _add_merchant() -> void:
	var m := Puppet2D.new()
	add_child(m)
	m.setup("res://assets/npcs2d/marchand_masques/")
	var at := Vector2(1590, 905)
	m.position = _world(at, _depth_for(at.y) - 0.02)
	m.scale = Vector3.ONE * _depth_scale(at.y) * 0.85
	m.set_facing(-1.0)
	m.set_render_priority(priority_for(at.y) + 1)


## Les héros possédés se promènent sur la place, s'arrêtent, et montrent parfois une attaque.
func _add_heroes() -> void:
	var i := 0
	for id: String in PlayerData.owned_heroes():
		var hero := GameData.hero(id)
		if not hero.has("puppet"):
			continue
		var p := Puppet2D.new()
		add_child(p)
		p.setup(hero.puppet)
		var at := Vector2(_rng.randf_range(GROUND.position.x, GROUND.end.x), _rng.randf_range(GROUND.position.y, GROUND.end.y))
		var attacks: Array = hero.get("attacks", []).map(func(a: Dictionary) -> String: return String(a.get("anim", "")))
		var w := {"p": p, "at": at, "target": at, "wait": _rng.randf_range(0.5, 3.0) + i, "attacks": attacks}
		_place_walker(w)
		_walkers.append(w)
		wanderers.append(p)
		i += 1


func _walk(w: Dictionary, delta: float) -> void:
	var p: Puppet2D = w.p
	if w.wait > 0.0:
		w.wait -= delta
		if w.wait <= 0.0:
			w.target = Vector2(_rng.randf_range(GROUND.position.x, GROUND.end.x), _rng.randf_range(GROUND.position.y, GROUND.end.y))
			p.play("run")
		return
	var to: Vector2 = w.target - w.at
	if to.length() < 6.0:
		w.wait = _rng.randf_range(2.0, 5.0)
		if not w.attacks.is_empty() and _rng.randf() < 0.3:
			p.play(w.attacks[_rng.randi() % w.attacks.size()], 0.45)
		else:
			p.play("idle")
		return
	var step := to.normalized() * minf(140.0 * delta, to.length())
	w.at += step
	if absf(step.x) > 0.1:
		p.set_facing(signf(step.x))
	_place_walker(w)


func _place_walker(w: Dictionary) -> void:
	var p: Puppet2D = w.p
	var at: Vector2 = w.at
	p.position = _world(at, _depth_for(at.y) - 0.02)
	p.scale = Vector3.ONE * _depth_scale(at.y)
	p.set_render_priority(priority_for(at.y) + 1)


## Les héros plus haut sur la place (plus loin) sont un peu plus petits.
func _depth_scale(ground_y: float) -> float:
	return lerpf(0.78, 1.0, clampf((ground_y - 860.0) / 160.0, 0.0, 1.0))


func _build_shaders() -> void:
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""
	_anim_shader = Shader.new()
	_anim_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform int frames = 8;
uniform float fps = 10.0;
uniform float phase = 0.0;
void fragment() {
	float f = floor(mod((TIME + phase) * fps, float(frames)));
	vec4 c = texture(tex, vec2((UV.x + f) / float(frames), UV.y));
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""
