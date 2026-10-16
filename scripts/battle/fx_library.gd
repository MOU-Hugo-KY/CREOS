class_name FxLibrary
extends Node2D
## Effets de lancer et d'impact pilotés par les données (data/fx.json) — affichage seulement.
## Élément du lanceur × type d'attaque (base / technique / ultime) × nature (corps-à-corps, distance,
## magie, soin, bouclier, état). Particules CPU légères (quelques dizaines au plus), petites images
## en pixel art générées au démarrage (filtre NEAREST), mélange additif pour la lumière.
## Chaque nœud se libère tout seul à la fin.

const DATA_PATH := "res://data/fx.json"
const SHIELD_SHADER := preload("res://scripts/battle/shield_bubble.gdshader")
const MAX_PARTICLES := 48  # plafond par émetteur (mobile)

static var _data: Dictionary = {}
static var _textures: Dictionary = {}

var camera: Camera2D
var _flash_rect: ColorRect
var _add_mat: CanvasItemMaterial


func setup(p_camera: Camera2D) -> void:
	camera = p_camera
	z_index = 40
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Flash d'écran (ultimes, critiques) : rectangle additif au-dessus du décor, sous l'interface.
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.material = _add_mat
	layer.add_child(_flash_rect)


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


## Contexte visuel d'une attaque : élément, type (base/technique/ultime/secret), nature, fx propre.
static func attack_context(unit: BattleUnit, attack: Dictionary, slot: int) -> Dictionary:
	var slot_key := "base"
	match slot:
		BattleUnit.SLOT_COOLDOWN: slot_key = "technique"
		BattleUnit.SLOT_ULTIMATE: slot_key = "ultime"
		BattleUnit.SLOT_SECRET: slot_key = "secret"
	var effects: Array = attack.get("effects", [{"type": "damage"}])
	var types := effects.map(func(e: Dictionary) -> String: return String(e.get("type", "")))
	var nature := "melee"
	if not types.has("damage") and not types.has("dot"):
		if types.has("heal") or types.has("regen"):
			nature = "heal"
		elif types.has("shield"):
			nature = "shield"
		else:
			nature = "status"
	elif unit.attack_kind == "magic":
		nature = "magic"
	elif unit.range_type == "ranged":
		nature = "ranged"
	var element := unit.element if data().get("elements", {}).has(unit.element) else "neutre"
	return {"element": element, "slot": slot_key, "nature": nature, "preset": String(attack.get("fx", ""))}


# --- Effets publics -----------------------------------------------------------------------------

## Au lancer : lueur montante de l'élément autour du lanceur (magie, soin, bouclier, ultime).
func cast(pos: Vector2, ctx: Dictionary) -> void:
	var d := data()
	var nat: Dictionary = d.get("natures", {}).get(ctx.nature, {})
	var sl: Dictionary = d.get("slots", {}).get(ctx.slot, {})
	if not nat.get("cast", false) and ctx.slot == "base":
		return
	var spec: Dictionary = d.get("cast", {}).duplicate()
	spec["colors"] = _elem(ctx.element).get("colors", ["#ffffff"])
	emit(pos, spec, float(sl.get("scale", 1.0)), float(sl.get("amount", 1.0)))


## À l'impact d'un coup : éclat de la nature + particules de l'élément, mis à l'échelle du type.
func impact(pos: Vector2, ctx: Dictionary, crit := false) -> void:
	var d := data()
	var sl: Dictionary = d.get("slots", {}).get(ctx.slot, {})
	var sc := float(sl.get("scale", 1.0))
	var am := float(sl.get("amount", 1.0))
	var elem := _elem(ctx.element)
	var preset: Dictionary = d.get("presets", {}).get(ctx.get("preset", ""), {})
	if not preset.is_empty():
		emit(pos, preset, sc, am, elem)
	else:
		var nat: Dictionary = d.get("natures", {}).get(ctx.nature, {})
		if nat.has("impact"):
			emit(pos, nat.impact, sc, 1.0, elem)
		emit(pos, elem, sc, am, elem)
		if elem.has("extra"):
			emit(pos, elem.extra, sc, am, elem)
	if sl.get("ring", false):
		_ring(pos, _col(elem.get("colors", ["#ffffff"])[1]), 7.0 * sc, 0.5)
	if crit:
		var c: Dictionary = d.get("crit", {})
		emit(pos, c, sc, 1.0, elem)
		_ring(pos, Color(c.get("ring_color", "#ffe066")), 9.0, 0.4)
		flash(Color(c.get("ring_color", "#ffe066")), float(c.get("flash", 0.1)))


## Flash d'écran additif (s'efface en ~0,25 s).
func flash(color: Color, strength: float) -> void:
	if _flash_rect == null or strength <= 0.0:
		return
	_flash_rect.color = Color(color, minf(0.6, strength))
	var tw := _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.28).set_ease(Tween.EASE_OUT)


## Soin : halo vert qui monte autour du personnage soigné.
func heal(feet: Vector2, chest: Vector2) -> void:
	var spec: Dictionary = data().get("heal", {})
	emit(feet + Vector2(0, -10), spec)
	if spec.has("extra"):
		emit(chest, spec.extra)
	_ring(feet, _col(spec.get("colors", ["#5fd35f", "#5fd35f"])[2]), 6.0, 0.6, true)


## Bouclier : bulle (shader) qui apparaît, scintille et s'efface.
func shield(chest: Vector2, height: float) -> void:
	var spec: Dictionary = data().get("shield", {})
	var r := maxf(float(spec.get("radius", 70.0)), height * 0.6)
	var s := Sprite2D.new()
	s.texture = _tex("bubble")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = SHIELD_SHADER
	mat.set_shader_parameter("tint", Color(spec.get("color", "#7fd3ff")))
	s.material = mat
	s.position = chest
	var base := r / 32.0
	s.scale = Vector2(base * 0.4, base * 0.4)
	add_child(s)
	var life := float(spec.get("life", 1.1))
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(base, base), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.5)
	tw.tween_property(s, "modulate:a", 0.0, life * 0.4)
	tw.tween_callback(s.queue_free)


## État posé : nuage, braises, gouttes, étoiles qui tournent (étourdi)…
func status(name: String, head: Vector2, chest: Vector2, feet: Vector2, duration: float) -> void:
	var table: Dictionary = data().get("statuses", {})
	var spec: Dictionary = table.get(name, {})
	if spec.is_empty():
		if name.begins_with("buff_"):
			spec = table.get("_buff", {})
		elif name.begins_with("debuff_") or name == "armure_reduite":
			spec = table.get("_debuff", {})
	if spec.is_empty():
		return
	var at: Vector2 = {"head": head, "feet": feet}.get(spec.get("at", "chest"), chest)
	if spec.has("orbit"):
		_orbit(at, spec, clampf(duration, 1.0, 3.0))
	else:
		emit(at, spec)


## Petite traînée de particules qui suit un projectile.
func attach_trail(node: Node2D, element: String) -> void:
	var e := _elem(element)
	var p := CPUParticles2D.new()
	p.texture = _tex(String(e.get("shape", "dot")))
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.local_coords = false
	p.amount = 14
	p.lifetime = 0.3
	p.gravity = Vector2(0, float(e.get("gravity", 0)) * 0.3)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 30.0
	p.spread = 180.0
	p.scale_amount_min = float(e.get("size", 1.0)) * 0.8
	p.scale_amount_max = float(e.get("size", 1.0)) * 1.3
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _ramp(e.get("colors", ["#ffffff"]))
	if e.get("additive", false):
		p.material = _add_mat
	p.show_behind_parent = true
	node.add_child(p)


# --- Émetteur générique -------------------------------------------------------------------------

## Une gerbe de particules décrite par `spec` (voir data/fx.json). "@element" dans les couleurs =
## couleur de l'élément du lanceur.
func emit(pos: Vector2, spec: Dictionary, scale_mul := 1.0, amount_mul := 1.0, elem: Dictionary = {}) -> void:
	if spec.is_empty():
		return
	var colors: Array = []
	for c: Variant in spec.get("colors", ["#ffffff"]):
		colors.append(elem.get("colors", ["#ffffff", "#ffffff"])[1] if String(c) == "@element" else c)
	var shape := String(spec.get("shape", "dot"))
	if shape == "ring":
		_ring(pos, _col(colors[-1]), float(spec.get("size", 6.0)) * scale_mul, float(spec.get("life", 0.4)))
		return
	var p := CPUParticles2D.new()
	p.texture = _tex(shape)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = clampi(int(float(spec.get("amount", 10)) * amount_mul), 1, MAX_PARTICLES)
	p.lifetime = float(spec.get("life", 0.5))
	p.randomness = 0.4
	p.lifetime_randomness = 0.35
	var dir: Array = spec.get("direction", [0, -1])
	p.direction = Vector2(float(dir[0]), float(dir[1]))
	p.spread = float(spec.get("spread", 180.0))
	var spd: Array = spec.get("speed", [100, 300])
	p.initial_velocity_min = float(spd[0]) * sqrt(scale_mul)
	p.initial_velocity_max = float(spd[1]) * sqrt(scale_mul)
	p.gravity = Vector2(0, float(spec.get("gravity", 0)))
	p.damping_min = 40.0
	p.damping_max = 120.0
	var radius := float(spec.get("radius", 8.0))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * scale_mul
	var size := float(spec.get("size", 1.0)) * (0.7 + 0.3 * scale_mul)
	p.scale_amount_min = size * 1.2
	p.scale_amount_max = size * 2.2
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _ramp(colors)
	p.particle_flag_align_y = spec.get("align", false)
	if spec.has("spin"):
		p.angular_velocity_min = -float(spec.spin)
		p.angular_velocity_max = float(spec.spin)
		p.angle_min = 0.0
		p.angle_max = 360.0
	if spec.get("additive", false):
		p.material = _add_mat
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	# Filet de sécurité : libération même si « finished » ne vient pas (nœud caché, etc.).
	var ref: WeakRef = weakref(p)
	get_tree().create_timer(p.lifetime * 2.0 + 0.5, false).timeout.connect(func() -> void:
		var n: Object = ref.get_ref()
		if n:
			n.queue_free())


# --- Interne ------------------------------------------------------------------------------------

func _elem(element: String) -> Dictionary:
	var els: Dictionary = data().get("elements", {})
	return els.get(element, els.get("neutre", {}))


func _ring(pos: Vector2, color: Color, size: float, life: float, flat := false) -> void:
	var s := Sprite2D.new()
	s.texture = _tex("ring")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = _add_mat
	s.modulate = color
	s.position = pos
	var sy := 0.35 if flat else 1.0
	size *= 0.22  # image de 64 px : « size » 6 ≈ 85 px de diamètre final
	s.scale = Vector2(size * 0.3, size * 0.3 * sy)
	add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2(size, size * sy), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)


## Étoiles qui tournent au-dessus de la tête (étourdi).
func _orbit(pos: Vector2, spec: Dictionary, duration: float) -> void:
	var root := Node2D.new()
	root.position = pos
	add_child(root)
	var n := int(spec.get("count", 3))
	var col := Color(spec.get("color", "#ffe066"))
	var stars: Array[Sprite2D] = []
	for i in n:
		var s := Sprite2D.new()
		s.texture = _tex(String(spec.get("orbit", "star")))
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.modulate = col
		s.scale = Vector2(2.2, 2.2)
		root.add_child(s)
		stars.append(s)
	var tw := root.create_tween()
	tw.tween_method(func(t: float) -> void:
		for i in stars.size():
			var a := t * TAU * 1.5 + TAU * i / stars.size()
			stars[i].position = Vector2(cos(a) * 26.0, sin(a) * 8.0)
			stars[i].z_index = 1 if sin(a) > 0.0 else -1
		, 0.0, duration, duration)
	tw.tween_property(root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(root.queue_free)


static func _col(c: Variant) -> Color:
	return c if c is Color else Color(String(c))


static func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var cols := PackedColorArray()
	var offs := PackedFloat32Array()
	for i in colors.size():
		cols.append(_col(colors[i]))
		offs.append(float(i) / maxf(1.0, colors.size() - 1))
	var last := cols[cols.size() - 1]
	cols.append(Color(last, 0.0))
	offs.append(1.0)
	if offs.size() > 1:
		offs[offs.size() - 2] = minf(offs[offs.size() - 2], 0.85)
	g.offsets = offs
	g.colors = cols
	return g


static var _curve: Curve
static func _fade_curve() -> Curve:
	if _curve == null:
		_curve = Curve.new()
		_curve.add_point(Vector2(0.0, 0.6))
		_curve.add_point(Vector2(0.15, 1.0))
		_curve.add_point(Vector2(1.0, 0.2))
	return _curve


## Petites images en pixel art dessinées au premier usage (pas de fichier à importer).
static func _tex(shape: String) -> Texture2D:
	if _textures.has(shape):
		return _textures[shape]
	var size := 64 if shape in ["ring", "bubble"] else 8
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var dx := x - c
			var dy := y - c
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			match shape:
				"dot": a = 1.0 if d <= 2.6 else (0.5 if d <= 3.6 else 0.0)
				"ember": a = 1.0 if absf(dx) <= 1.5 and absf(dy) <= 1.5 else (0.35 if absf(dx) + absf(dy) <= 3.0 else 0.0)
				"spark": a = 1.0 if absf(dx) <= 0.6 and absf(dy) <= 3.6 else 0.0
				"shard": a = 1.0 if absf(dx) * 2.2 + absf(dy) * 0.8 <= 3.0 else 0.0
				"drop": a = 1.0 if (d <= 2.2 and dy >= -0.5) or (absf(dx) <= (dy + 3.6) * 0.6 and dy < 0.0 and dy > -3.6) else 0.0
				"leaf": a = 1.0 if absf(dx - dy) <= 1.2 and absf(dx + dy) <= 3.4 else (1.0 if absf(dx - dy) <= 2.2 and absf(dx + dy) <= 1.8 else 0.0)
				"smoke": a = clampf(1.0 - d / 3.8, 0.0, 1.0) * 0.8
				"star": a = 1.0 if (absf(dx) <= 0.6 and absf(dy) <= 3.6) or (absf(dy) <= 0.6 and absf(dx) <= 3.6) or d <= 1.3 else 0.0
				"ring": a = 1.0 if d >= c - 3.0 and d <= c - 0.5 else (0.35 if d >= c - 6.0 and d < c - 3.0 else 0.0)
				"bubble": a = 1.0 if d <= c - 0.5 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_textures[shape] = tex
	return tex
