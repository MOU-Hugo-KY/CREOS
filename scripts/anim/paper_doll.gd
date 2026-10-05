class_name PaperDoll
extends Node2D
## Personnage en pièces (format `puppet.json` : pivot de chaque pièce, parent, point d'accroche)
## monté en 2D et animé par code : respiration au repos et petit geste du bras de temps en temps.
## Sert aux personnages non joueurs (le marchand de masques). Le nœud est posé au point au sol ;
## `scale` règle la taille (1 = taille des images).

var _pivots: Dictionary = {}  # nom -> Node2D (rotation de la pièce)
var _rest: Dictionary = {}  # nom -> rotation au repos
var _time := 0.0
var _gesture := 0.0  # 0..1 pendant un geste du bras
var _next_gesture := 3.0


func setup(folder: String) -> PaperDoll:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("puppet.json")))
	var cfg: Dictionary = parsed if parsed is Dictionary else {}
	var parts: Dictionary = cfg.get("parts", {})
	var pending := parts.keys()
	var guard := 0
	while not pending.is_empty() and guard < 50:
		guard += 1
		for name: String in pending.duplicate():
			var p: Dictionary = parts[name]
			var parent_name: String = p.get("parent", "")
			if parent_name != "" and not _pivots.has(parent_name):
				continue
			_add_part(folder, name, p, parts.get(parent_name, {}))
			pending.erase(name)
	return self


func _add_part(folder: String, name: String, p: Dictionary, parent_cfg: Dictionary) -> void:
	var tex: Texture2D = load(folder.path_join(p.get("file", name + ".png")))
	if tex == null:
		return
	var pivot: Array = p.get("pivot", [tex.get_width() / 2.0, tex.get_height()])
	var node := Node2D.new()
	var parent_name: String = p.get("parent", "")
	if parent_name == "":
		add_child(node)
	else:
		var at: Array = p.get("at", [0, 0])
		var ppivot: Array = parent_cfg.get("pivot", [0, 0])
		node.position = Vector2(float(at[0]) - float(ppivot[0]), float(at[1]) - float(ppivot[1]))
		(_pivots[parent_name] as Node2D).add_child(node)
	node.z_index = int(p.get("z", 0))
	node.rotation = deg_to_rad(float(p.get("rest", 0)))
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = -Vector2(float(pivot[0]), float(pivot[1]))
	node.add_child(sprite)
	_pivots[name] = node
	_rest[name] = node.rotation


func _process(delta: float) -> void:
	_time += delta
	_next_gesture -= delta
	if _next_gesture <= 0.0:
		_next_gesture = randf_range(4.0, 8.0)
		var tw := create_tween()
		tw.tween_property(self, "_gesture", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.5)
		tw.tween_property(self, "_gesture", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	var breath := sin(_time * 2.0)
	if _pivots.has("body"):
		var b: Node2D = _pivots.body
		b.scale = Vector2(1.0 - breath * 0.008, 1.0 + breath * 0.012)
	if _pivots.has("head"):
		var h: Node2D = _pivots.head
		h.rotation = _rest.head + sin(_time * 1.3) * 0.035 - _gesture * 0.06
	if _pivots.has("arm_front"):
		var a: Node2D = _pivots.arm_front
		a.rotation = _rest.arm_front + sin(_time * 1.7) * 0.05 - _gesture * 0.55
