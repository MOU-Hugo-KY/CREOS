class_name HeroPreview
extends SubViewport
## Petite scène 2D séparée qui montre un héros animé (clips en pièces détachées) sur un socle
## lumineux. `play(clip)` lui fait jouer une attaque (on recule la vue pour voir toute l'action)
## puis il revient au repos ; « cheer » joue la présentation de sa relique.

var _root: Node2D
var _stage: Node2D
var _player: ClipPlayer
var _hero: Dictionary = {}
var _color := Color.WHITE
var _time := 0.0
var _tween: Tween
var pedestal := true  # socle lumineux sous le héros
var zoom := 1.0  # taille du héros (1 : la hauteur de la vue / 470)


func _init() -> void:
	size = Vector2i(16, 16)  # la taille vient du conteneur (sinon il réclame 512 px de haut)


func _ready() -> void:
	transparent_bg = true
	_root = Node2D.new()
	add_child(_root)
	_stage = Node2D.new()
	_root.add_child(_stage)
	_root.draw.connect(_draw_pedestal)
	size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	_root.queue_redraw()


func clear_hero() -> void:
	if _player:
		_player.queue_free()
	_player = null


func show_hero(hero: Dictionary) -> void:
	clear_hero()
	_hero = hero
	_color = Palette.element_color(hero.get("element", ""))
	var id := String(hero.get("id", ""))
	_player = ClipPlayer.new()
	_player.bundle = String(hero.get("anim", "res://assets/anim/heroes/"))
	_player.idle_clip = id + "_idle"
	_player.sound_volume_db = -6.0
	_stage.add_child(_player)
	_player.play(id + "_idle")
	_layout()


## Joue un clip du héros (une attaque : `<id>_0`, `<id>_1`…) ; « cheer » = sa relique.
func play(clip: String) -> void:
	if _player == null:
		return
	var id := String(_hero.get("id", ""))
	if clip == "cheer":
		clip = id + "_relic"
	if not _player.has_clip(clip):
		return
	_player.play(clip)
	_player.idle_clip = id + "_idle"
	# Les attaques foncent vers la droite : on recule la vue le temps du clip.
	var attack := clip.right(1).is_valid_int()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var base := _base_scale()
	if attack:
		_tween.tween_property(_stage, "scale", Vector2.ONE * base * 0.45, 0.25)
		_tween.parallel().tween_property(_stage, "position:x", size.x * 0.16, 0.25)
		_tween.tween_interval(maxf(0.2, _player.duration(clip) - 0.5))
	_tween.tween_property(_stage, "scale", Vector2.ONE * base, 0.3)
	_tween.parallel().tween_property(_stage, "position:x", size.x * 0.5, 0.3)


func _base_scale() -> float:
	return size.y / 470.0 * zoom


func _layout() -> void:
	if _stage == null:
		return
	_stage.position = Vector2(size.x * 0.5, size.y * 0.86)
	_stage.scale = Vector2.ONE * _base_scale()


func _draw_pedestal() -> void:
	if not pedestal:
		return
	var c := Vector2(size.x * 0.5, size.y * 0.86)
	var r := Vector2(size.y * 0.3, size.y * 0.075)
	var pulse := 0.5 + 0.15 * sin(_time * 2.0)
	for i in 3:
		var k := 1.0 + i * 0.18
		var pts := PackedVector2Array()
		for s in 40:
			var a := TAU * s / 40.0
			pts.append(c + Vector2(cos(a) * r.x * k, sin(a) * r.y * k))
		_root.draw_colored_polygon(pts, Color(_color, (0.22 - i * 0.06) * pulse * 2.0))
	var ring := PackedVector2Array()
	for s in 41:
		var a := TAU * s / 40.0
		ring.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_root.draw_polyline(ring, Color(_color.lightened(0.3), 0.8), 3.0, true)
