class_name BattleStage
extends Node2D
## Décor de combat dessiné d'un monde (`assets/decors/mondeNN/`), dans le cadre de travail
## 1280 × 720 : fond complet, sol transparent, ambiance animée, et premier plan coupé en deux
## moitiés écartées vers les bords pour dégager les combattants. Les pieds sont sur y ≈ 590.
## Ordre de dessin : fond (-30) < sol (-20) < ambiance (-10) < combattants (0) < premier plan (20).

const SIZE := Vector2(1280, 720)

var ambience: Ambience
var info: Dictionary = {}


## `dir` : dossier du monde ; `scene` : 1 entrée, 2 profondeur, 3 boss.
func setup(dir: String, scene: int) -> void:
	var path := dir + "decor.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			info = parsed
	_layer(dir + "fond%d.jpg" % scene, -30)
	_layer(dir + "sol.png", -20)
	ambience = Ambience.new()
	ambience.config_path = dir + "ambiance%d.json" % scene
	ambience.z_index = -10
	add_child(ambience)
	var fg_path := dir + "premier_plan.png"
	if ResourceLoader.exists(fg_path):
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


func foot_line() -> float:
	return float(info.get("foot_baseline", 590))


func _layer(path: String, z: int) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.scale = SIZE / Vector2(s.texture.get_size())
	s.z_index = z
	add_child(s)
