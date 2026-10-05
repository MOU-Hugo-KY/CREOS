class_name SummonStage
extends HeroPreview
## Scène 2D de la Lanterne des Serments : la nuit, un cercle de runes qui tourne et le cristal
## violet de la Lanterne qui flotte en pulsant. `ceremony()` joue l'invocation : le cristal
## s'emballe, une colonne de lumière de la couleur de la rareté jaillit, puis le héros apparaît
## et lance son ultime.

const GEM := "res://assets/hub2d/port/Lanterne_Pulse_8f_10fps.png"
const GEM_FRAMES := 8

var busy := false
var _back: Node2D
var _front: Node2D
var _gem_tex: Texture2D
var _glow := Color(0.72, 0.42, 1.0)
var _gem_visible := true
var _gem_lift := 0.0
var _spin := 0.6
var _beam := 0.0  # 0..1 intensité de la colonne de lumière
var _beam_color := Color.WHITE
var _t := 0.0
var _angle := 0.0


func _ready() -> void:
	super._ready()
	_gem_tex = load(GEM) if ResourceLoader.exists(GEM) else null
	_back = Node2D.new()
	add_child(_back)
	move_child(_back, 0)
	_back.draw.connect(_draw_back)
	_front = Node2D.new()
	add_child(_front)
	_front.draw.connect(_draw_front)
	reset_stage()


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_angle += delta * _spin * 0.25
	_back.queue_redraw()
	_front.queue_redraw()


## Retour à l'attente : le cristal flotte, pas de héros.
func reset_stage() -> void:
	clear_hero()
	_gem_visible = true
	_gem_lift = 0.0
	_spin = 0.6
	_beam = 0.0
	_glow = Color(0.72, 0.42, 1.0)


## L'invocation, en ~2,5 s. Attendre avec `await stage.ceremony(...)`.
func ceremony(hero: Dictionary, rarity: int) -> void:
	busy = true
	var color: Color = Palette.RARITIES.get(rarity, Palette.RARITIES[3])[1]
	reset_stage()
	var tw := create_tween()
	tw.tween_property(self, "_spin", 12.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_gem_lift", 1.0, 1.2)
	tw.parallel().tween_property(self, "_glow", color, 1.2)
	await tw.finished
	_beam_color = color
	var burst := create_tween()
	burst.tween_property(self, "_beam", 1.0, 0.22).set_trans(Tween.TRANS_BACK)
	await burst.finished
	_gem_visible = false
	show_hero(hero)
	var fade := create_tween()
	fade.tween_property(self, "_beam", 0.0, 0.9).set_trans(Tween.TRANS_QUAD)
	fade.parallel().tween_property(self, "_spin", 0.8, 0.9)
	await fade.finished
	play(String(hero.get("id", "")) + "_2")
	busy = false


func _draw_back() -> void:
	var s := size
	# Nuit : dégradé du violet sombre vers le bleu nuit.
	for i in 12:
		var k := i / 12.0
		_back.draw_rect(Rect2(0, s.y * k, s.x, s.y / 12.0 + 1.0), Color(0.09, 0.07, 0.16).lerp(Color(0.16, 0.12, 0.26), k))
	var c := Vector2(s.x * 0.5, s.y * 0.86)
	# Cercle de runes qui tourne au sol.
	var r := Vector2(s.y * 0.42, s.y * 0.1)
	for ring in [1.0, 0.8]:
		var pts := PackedVector2Array()
		for i in 61:
			var a := TAU * i / 60.0
			pts.append(c + Vector2(cos(a) * r.x * ring, sin(a) * r.y * ring))
		_back.draw_polyline(pts, Color(_glow, 0.55), 3.0, true)
	for i in 12:
		var a := _angle + TAU * i / 12.0
		var p := c + Vector2(cos(a) * r.x * 0.9, sin(a) * r.y * 0.9)
		_back.draw_circle(p, 5.0, Color(_glow.lightened(0.3), 0.5 + 0.4 * sin(_t * 3.0 + i)))
	# Poussière magique qui monte.
	for i in 24:
		var u := fposmod(_t * 0.15 + i * 0.137, 1.0)
		var x := c.x + sin(i * 2.3) * r.x * 0.9
		var y := c.y - u * s.y * 0.8
		_back.draw_circle(Vector2(x + sin(_t + i) * 8.0, y), 2.5, Color(_glow, sin(u * PI) * 0.7))


func _draw_front() -> void:
	var s := size
	var c := Vector2(s.x * 0.5, s.y * 0.86)
	if _gem_visible and _gem_tex:
		var frame := int(_t * 10.0 * (1.0 + _spin * 0.15)) % GEM_FRAMES
		var fw := _gem_tex.get_width() / GEM_FRAMES
		var h := s.y * 0.38
		var pos := c + Vector2(0, -s.y * (0.42 + 0.1 * _gem_lift) + sin(_t * 1.6) * 8.0)
		_front.draw_circle(pos, h * 0.42, Color(_glow, 0.18))
		_front.draw_texture_rect_region(_gem_tex, Rect2(pos - Vector2(h, h) * 0.5, Vector2(h, h)),
			Rect2(fw * frame, 0, fw, _gem_tex.get_height()), Color(1, 1, 1).lerp(_glow.lightened(0.4), 0.3 * _gem_lift))
	if _beam > 0.0:
		var w := s.y * 0.32 * _beam
		for i in 6:
			var k := 1.0 - i / 6.0
			_front.draw_rect(Rect2(c.x - w * k * 0.5, 0, w * k, c.y), Color(_beam_color.lightened(0.3 * (1.0 - k)), 0.18 * _beam))
		_front.draw_rect(Rect2(0, 0, s.x, s.y), Color(1, 1, 1, 0.25 * _beam * _beam))
