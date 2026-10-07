class_name BattleStage
extends Node2D
## Décor de combat dessiné d'un monde (`assets/decors/mondeNN/`), dans le cadre de travail
## 1280 × 720 : fond complet, ambiance animée et premier plan. Décors pixel (decor.json "scenes") :
## un fond et un premier plan par scène, sol compris dans le fond. Anciens décors : fondN.jpg, sol
## transparent et premier plan coupé en deux moitiés écartées vers les bords. Pieds sur y ≈ 590.
## Ordre de dessin : fond (-30) < sol (-20) < ambiance (-10) < combattants (0) < premier plan (20).

const SIZE := Vector2(1280, 720)

var ambience: Ambience
var info: Dictionary = {}
## Arène vue en plongée (`areneN.png` + `areneN.json`) : les combattants se répartissent sur le sol.
var topdown := false
var combat_rect := Rect2(80, 300, 1120, 380)


## `dir` : dossier du monde ; `scene` : 1 entrée, 2 profondeur, 3 boss.
func setup(dir: String, scene: int) -> void:
	var path := dir + "decor.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			info = parsed
	# Décors pixel : fond et premier plan propres à chaque scène (decor.json "scenes"), sur le même
	# canevas que le fond, sol compris. Anciens décors : fondN.jpg + sol + premier plan coupé en deux.
	if ResourceLoader.exists(dir + "arene%d.png" % scene):
		_setup_arena(dir, scene)
		return
	var scenes: Array = info.get("scenes", [])
	var sc: Dictionary = scenes[scene - 1] if scene - 1 < scenes.size() else {}
	if sc.has("background"):
		_layer(dir + String(sc.background), -30, true)
		if sc.has("foreground"):
			_layer(dir + String(sc.foreground), 20, true)
	else:
		_layer(dir + "fond%d.jpg" % scene, -30)
		_layer(dir + "sol.png", -20)
		_split_foreground(dir + "premier_plan.png")
	ambience = Ambience.new()
	ambience.config_path = dir + "ambiance%d.json" % scene
	ambience.z_index = -10
	add_child(ambience)


func _setup_arena(dir: String, scene: int) -> void:
	topdown = true
	var path := dir + "arene%d.json" % scene
	if FileAccess.file_exists(path):
		var a: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if a is Dictionary and a.has("combat_rect"):
			var r: Array = a.combat_rect
			combat_rect = Rect2(r[0], r[1], r[2], r[3])
	_layer(dir + "arene%d.png" % scene, -30, true)
	_layer(dir + "arene%d_avant.png" % scene, 20, true)
	ambience = Ambience.new()  # pas de particules de l'ancien décor ; sert à l'assombrissement des ultimes
	ambience.z_index = -10
	add_child(ambience)


func _split_foreground(fg_path: String) -> void:
	if not ResourceLoader.exists(fg_path):
		return
	var tex: Texture2D = load(fg_path)
	var offset := float(info.get("foreground_offset", 96))
	var half := tex.get_width() / 2.0
	for side in 2:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(half * side, 0, half, tex.get_height())
		s.scale = SIZE / Vector2(tex.get_size())
		s.position = Vector2(-offset if side == 0 else SIZE.x / 2.0 + offset, 0)
		s.z_index = 20
		add_child(s)


## Ligne des pieds dans le cadre 1280 × 720 (les décors pixel la donnent sur leur canevas).
func foot_line() -> float:
	var canvas: Array = info.get("canvas_size", [SIZE.x, SIZE.y])
	return float(info.get("foot_baseline", 590)) * SIZE.y / float(canvas[1])


func _layer(path: String, z: int, pixel := false) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	if pixel:
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture = load(path)
	s.centered = false
	s.scale = SIZE / Vector2(s.texture.get_size())
	s.z_index = z
	add_child(s)
