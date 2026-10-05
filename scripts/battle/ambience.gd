class_name Ambience
extends Node2D
## Ambiance animée d'un décor de combat (pack « Ambiances animées » de ChatGPT) : flammes, fumée,
## brume, reflets, lueurs et particules dessinés par un shader, dans le cadre 1280 × 720.
## Config : assets/decors/mondeNN/ambianceS.json. `set_ultimate_active(true)` atténue l'ambiance.
@export_file("*.json") var config_path: String = ""
@export_enum("Off", "Mobile", "Standard", "High") var quality: int = 1:
	set(value):
		quality = clampi(value, 0, 3)
		if is_inside_tree():
			_rebuild()
@export_range(0.0, 1.0) var intensity: float = 1.0
@export var paused: bool = false
var _clock: float = 0.0
var _ultimate_weight: float = 1.0
var _ultimate_target: float = 1.0
var _data: Dictionary = {}
var _materials: Array[ShaderMaterial] = []
var _particles: Array[Dictionary] = []
var _accumulator: float = 0.0
const FX_SHADER = preload("res://scripts/battle/ambience.gdshader")
const TYPES = {"flame": 0, "smoke": 1, "water": 2, "mist": 3, "glow": 4, "magic": 5, "ritual": 6}

func _ready() -> void:
	z_index = -10
	_rebuild()

func _rebuild() -> void:
	queue_redraw()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_materials.clear()
	_particles.clear()
	if config_path.is_empty() or not FileAccess.file_exists(config_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary:
		push_error("CREOS: invalid ambience JSON: " + config_path)
		return
	_data = parsed
	if quality == 0:
		return
	for entry in _data.get("effects", []):
		var item: Dictionary = entry
		if quality == 1 and item.get("optional_mobile", false):
			continue
		var kind: String = item["kind"]
		if kind == "particles":
			var count: int = int(item.get("count", 12) * [0.0, 0.4, 0.7, 1.0][quality])
			var rng := RandomNumberGenerator.new()
			rng.seed = int(item.get("seed", 1))
			for i in count:
				_particles.append({"item": item, "phase": rng.randf(), "x": rng.randf(), "size": rng.randf_range(0.7, 1.3)})
			continue
		if not TYPES.has(kind):
			continue
		var rect: Array = item["rect"]
		var node := Polygon2D.new()
		var w := float(rect[2])
		var h := float(rect[3])
		node.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])
		node.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		# A one-pixel texture makes Polygon2D normalized UVs reliable.
		var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		pixel.fill(Color.WHITE)
		node.texture = ImageTexture.create_from_image(pixel)
		node.position = Vector2(float(rect[0]), float(rect[1]))
		var material := ShaderMaterial.new()
		material.shader = FX_SHADER
		material.set_shader_parameter("effect_kind", TYPES[kind])
		material.set_shader_parameter("tint", Color(item.get("color", "ffffff")))
		material.set_shader_parameter("phase", float(item.get("phase", 0.0)))
		material.set_shader_parameter("strength", intensity)
		node.material = material
		add_child(node)
		_materials.append(material)
	queue_redraw()

func _process(delta: float) -> void:
	if paused or quality == 0:
		return
	_accumulator += delta
	# Cap mobile updates at 30 fps; other modes follow the game.
	if quality == 1 and _accumulator < 1.0 / 30.0:
		return
	var elapsed := _accumulator
	_accumulator = 0.0
	_clock += elapsed
	_ultimate_weight = move_toward(_ultimate_weight, _ultimate_target, elapsed * 3.0)
	for material in _materials:
		material.set_shader_parameter("clock", _clock)
		material.set_shader_parameter("strength", intensity * _ultimate_weight)
	queue_redraw()

func set_ultimate_active(active: bool) -> void:
	_ultimate_target = 0.15 if active else 1.0

func set_quality(level: int) -> void:
	quality = level

func _draw() -> void:
	if quality == 0:
		return
	for particle in _particles:
		var item: Dictionary = particle["item"]
		var rect: Array = item["rect"]
		var duration := float(item.get("duration", 8.0))
		var u := fposmod(_clock / duration + float(particle["phase"]), 1.0)
		var style: String = item.get("style", "dust")
		var x := float(rect[0]) + fposmod(float(particle["x"]) + u * float(item.get("drift", 0.18)), 1.0) * float(rect[2])
		var y := float(rect[1]) + (u if style in ["leaf", "drop", "ash"] else 1.0 - u) * float(rect[3])
		var point := Vector2(x + sin(u * TAU * 2.0 + float(particle["phase"]) * TAU) * 6.0, y)
		var color := Color(item.get("color", "e7cc91"))
		color.a *= sin(u * PI) * intensity * _ultimate_weight * float(item.get("opacity", 0.5))
		var size := float(item.get("size", 2.0)) * float(particle["size"])
		if style == "leaf":
			var angle := _clock * 1.5 + float(particle["phase"]) * TAU
			var points := PackedVector2Array()
			for local in [Vector2(-size * 2, 0), Vector2(0, -size), Vector2(size * 2, 0), Vector2(0, size)]:
				points.append(point + local.rotated(angle))
			draw_colored_polygon(points, color)
		elif style == "drop":
			draw_line(point, point + Vector2(-1, size * 4), color, 1.0, true)
		else:
			draw_circle(point, size, color)
			color.a *= 0.15
			draw_circle(point, size * 2.5, color)
