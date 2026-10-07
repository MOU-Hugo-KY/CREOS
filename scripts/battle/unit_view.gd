class_name UnitView
extends Node2D
## Affichage 2D d'une BattleUnit dans le cadre de combat 1280 × 720 : animations en pièces
## détachées (ClipPlayer : repos, touché, mort, attaques), ombre, anneau de tour, marque de cible,
## nombres flottants. Ne contient aucune règle de jeu : la scène lui dit quoi jouer à partir des
## événements du moteur. Le nœud est posé au point au sol du personnage.

const HERO_SCALE := 0.5
const ENEMY_SCALE := 0.8

var unit: BattleUnit
var data: Dictionary
var home_position: Vector2
var model_scale := 1.0
var shown_hp := 0.0  # PV affichés (mis à jour à l'instant de l'impact, pas avant)
var hp_seq := -1  # numéro du dernier événement qui a mis à jour shown_hp
var height := 150.0  # hauteur du personnage au repos (px du cadre)

var player: ClipPlayer
var _id := ""
var _dead := false
var _highlight := false
var _target := false
var _time := 0.0
var _attacking := false


func setup(p_unit: BattleUnit, p_data: Dictionary) -> void:
	unit = p_unit
	data = p_data
	shown_hp = unit.hp
	home_position = position
	_id = String(data.get("id", unit.def_id))
	model_scale = float(data.get("scale", HERO_SCALE if unit.team == 0 else ENEMY_SCALE))
	player = ClipPlayer.new()
	player.bundle = String(data.get("anim", "res://assets/anim/heroes/"))
	player.scale = Vector2.ONE * model_scale
	player.facing = 1.0  # les héros regardent à droite, les ennemis sont dessinés vers la gauche
	player.idle_clip = _id + "_idle"
	player.sound_volume_db = -10.0
	player.effect_color = Palette.element_color(p_unit.element)
	add_child(player)
	player.play(_id + "_idle")
	for clip_name: String in [_id + "_hurt", _id + "_death"]:
		ClipPlayer.warm(player.bundle, clip_name)
	for a: Dictionary in data.get("attacks", []):
		ClipPlayer.warm(player.bundle, String(a.get("clip", "")))
	var r := player.actor_rect(_id + "_idle")
	height = maxf(60.0, -r.position.y * model_scale)


## Point au-dessus de la tête, dans le repère de la scène de combat.
func head_position() -> Vector2:
	return position + Vector2(0, -height * _size_scale() - 14.0)


func chest_position() -> Vector2:
	return position + Vector2(0, -height * 0.5 * _size_scale())


## Échelle de placement de la vue (foule, profondeur de l'arène), sans l'écrasement des coups.
func _size_scale() -> float:
	return _base_scale.y if _base_scale != Vector2.ZERO else scale.y


## Point au-dessus de la tête, en pixels de l'écran (pour l'interface).
func head_screen() -> Vector2:
	return get_parent().get_global_transform_with_canvas() * head_position()


func chest_screen() -> Vector2:
	return get_parent().get_global_transform_with_canvas() * chest_position()


func is_dead() -> bool:
	return _dead


## Joue le clip d'une attaque (le clip contient la course, les coups et les effets).
## Renvoie le délai avant le premier impact (0 : les instants viennent des repères du clip).
var _base_scale := Vector2.ZERO


func play_attack(clip: String, _hit_time := 0.0, target := Vector2.INF) -> float:
	if _dead:
		return 0.0
	player.target_local = Vector2.INF if target == Vector2.INF else player.to_local(get_parent().to_global(target))
	if player.play(clip):
		player.idle_clip = _id + "_idle"
		_attacking = true
		z_index = 8  # les effets de l'attaque passent devant les autres combattants
		var done := func(_c: String) -> void:
			player.target_local = Vector2.INF
			_attacking = false
			z_index = 0
		player.finished.connect(done, CONNECT_ONE_SHOT)
	return 0.0


func clip_duration(clip: String) -> float:
	return player.duration(clip)


func set_highlight(on: bool) -> void:
	_highlight = on
	queue_redraw()


func set_target_mark(on: bool) -> void:
	_target = on
	queue_redraw()


func play_hit(color := Color.WHITE) -> void:
	if _dead:
		return
	player.flash(Color.WHITE.lerp(color, 0.3), 0.8)
	if not _attacking and player.has_clip(_id + "_hurt"):
		player.play(_id + "_hurt")
		player.idle_clip = _id + "_idle"
	# Recul et écrasement (pieds au sol) : le coup se sent.
	var tw := create_tween()
	var back := Vector2(-24 if unit.team == 0 else 24, 0)
	tw.tween_property(player, "position", back, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(player, "position", Vector2.ZERO, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _base_scale == Vector2.ZERO:
		_base_scale = scale
	var sq := create_tween()
	sq.tween_property(self, "scale", _base_scale * Vector2(1.12, 0.88), 0.05)
	sq.tween_property(self, "scale", _base_scale * Vector2(0.96, 1.04), 0.09)
	sq.tween_property(self, "scale", _base_scale, 0.12)


## Arrêt sur image : le personnage se fige un instant au moment du coup.
func freeze(seconds: float) -> void:
	player.freeze(seconds)


func play_death() -> void:
	if _dead:
		return
	_dead = true
	_highlight = false
	_target = false
	queue_redraw()
	player.idle_clip = ""
	player.play(_id + "_death", false)
	var tw := create_tween()
	tw.tween_interval(maxf(0.8, player.duration(_id + "_death")) + (0.6 if unit.team == 1 else 99.0))
	tw.tween_property(self, "modulate:a", 0.0, 0.5)


func play_cheer() -> void:
	if _dead:
		return
	var tw := create_tween()
	for i in 2:
		tw.tween_property(player, "position:y", -24.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(player, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func flash(color: Color, strength := 0.8) -> void:
	player.flash(color, strength)


## Nombre ou mot qui monte au-dessus du personnage puis disparaît.
func popup(text: String, color: Color, big := false, rise := 1.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34 if big else 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(240, 40)
	l.z_index = 40
	l.z_as_relative = false
	l.position = head_position() + Vector2(-120 + randf_range(-14, 14), -10)
	get_parent().add_child(l)
	l.scale = Vector2.ONE * 0.6
	l.pivot_offset = l.size / 2.0
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE * (1.15 if big else 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 46.0 * rise, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	_time += delta
	if _highlight or _target:
		queue_redraw()


func _draw() -> void:
	# Ombre au sol.
	var w := clampf(height * 0.42, 34.0, 120.0)
	_ellipse(Vector2.ZERO, Vector2(w, w * 0.22), Color(0, 0, 0, 0.28 if not _dead else 0.12))
	if _highlight:
		var pulse := 0.75 + 0.25 * sin(_time * 6.0)
		_ring(Vector2.ZERO, Vector2(w + 10, (w + 10) * 0.26), Color(1.0, 0.84, 0.35, pulse), 4.0)
	if _target:
		_ring(Vector2.ZERO, Vector2(w + 8, (w + 8) * 0.26), Color(0.95, 0.25, 0.22, 0.9), 4.0)
		var y := -height - 40.0 + sin(_time * 5.0) * 5.0
		var pts := PackedVector2Array([Vector2(-13, y - 14), Vector2(13, y - 14), Vector2(0, y + 4)])
		draw_colored_polygon(pts, Color(0.95, 0.25, 0.22))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.15, 0.05, 0.07), 3.0, true)


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, color)


func _ring(c: Vector2, r: Vector2, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_polyline(pts, color, width, true)
