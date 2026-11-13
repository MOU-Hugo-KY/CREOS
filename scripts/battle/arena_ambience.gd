class_name ArenaAmbience
extends Node2D
## Vie des arènes en plongée : halos qui vacillent sur les sources de lumière indiquées par l'arène
## (`lumieres` de areneN.json : torches, cristaux, lanternes) et particules propres au monde
## (braises, neige, spores, poussière, bulles…). Dessin simple, sans texture, léger sur téléphone.

## Particules par monde : [genre, couleur, nombre]. genre : rise (monte), fall (tombe), drift (flotte).
const WORLD_PARTICLES := {
	"monde01": ["drift", Color(1.0, 0.95, 0.8, 0.5), 18],  # poussière dorée
	"monde02": ["rise", Color(0.75, 1.0, 0.6, 0.7), 26],  # spores
	"monde03": ["drift", Color(1.0, 0.75, 0.35, 0.6), 22],  # lueurs ambrées
	"monde04": ["rise", Color(1.0, 0.5, 0.2, 0.8), 30],  # braises
	"monde05": ["drift", Color(0.9, 0.85, 0.7, 0.45), 24],  # poussière de pierre
	"monde06": ["rise", Color(0.45, 1.0, 0.9, 0.6), 24],  # bulles spectrales
	"monde07": ["fall", Color(1.0, 1.0, 1.0, 0.85), 60],  # neige
	"monde08": ["drift", Color(1.0, 1.0, 1.0, 0.35), 20],  # vent et nuages
	"monde09": ["rise", Color(1.0, 0.55, 0.15, 0.85), 34],  # braises de lave
	"monde10": ["rise", Color(0.75, 0.45, 1.0, 0.75), 30],  # éclats violets
}
const SIZE := Vector2(1280, 720)

var _lights: Array = []  # [position, rayon, couleur, phase]
var _parts: Array = []  # {p, v, life, size}
var _kind := ""
var _color := Color.WHITE
var _clock := 0.0
var _dim := 1.0
var _rng := RandomNumberGenerator.new()
var soft := false  # arène peinte : poussières rondes et lumineuses au lieu de carrés de pixel art


func setup(world: String, arena: Dictionary) -> void:
	_rng.seed = hash(world)
	for l: Array in arena.get("lumieres", []):
		_lights.append([Vector2(l[0], l[1]), float(l[2]), Color(String(l[3])), _rng.randf() * TAU])
	var spec: Array = WORLD_PARTICLES.get(world, [])
	if not spec.is_empty():
		_kind = spec[0]
		_color = spec[1]
		for i in int(spec[2]):
			_parts.append(_new_particle(true))


## Les ultimes assombrissent la scène : l'ambiance s'efface un peu.
func set_dim(on: bool) -> void:
	create_tween().tween_property(self, "_dim", 0.35 if on else 1.0, 0.3)


func _new_particle(anywhere: bool) -> Dictionary:
	var p := Vector2(_rng.randf_range(0, SIZE.x), _rng.randf_range(0, SIZE.y))
	var v := Vector2(_rng.randf_range(-12, 12), 0)
	match _kind:
		"rise":
			v.y = -_rng.randf_range(18, 45)
			if not anywhere:
				p.y = SIZE.y + 10
		"fall":
			v = Vector2(_rng.randf_range(-20, -5), _rng.randf_range(35, 70))
			if not anywhere:
				p.y = -10
		_:
			v = Vector2(_rng.randf_range(10, 30), _rng.randf_range(-6, 6))
			if not anywhere:
				p.x = -10
	return {"p": p, "v": v, "size": _rng.randf_range(3.0, 6.0), "phase": _rng.randf() * TAU}


func _process(delta: float) -> void:
	_clock += delta
	for i in _parts.size():
		var q: Dictionary = _parts[i]
		q.p += q.v * delta + Vector2(sin(_clock * 1.3 + q.phase) * 8.0 * delta, 0)
		if q.p.y < -20 or q.p.y > SIZE.y + 20 or q.p.x < -20 or q.p.x > SIZE.x + 20:
			_parts[i] = _new_particle(false)
	queue_redraw()


func _draw() -> void:
	for l: Array in _lights:
		var flick := 0.85 + 0.1 * sin(_clock * 3.1 + l[3]) + 0.05 * sin(_clock * 7.7 + l[3])
		var c: Color = l[2]
		var r: float = l[1] * 1.6
		for k in 4:  # halo en couches, du plus large au plus serré
			var f := 1.0 - k / 4.0
			if soft:
				var rr := r * f * flick * 1.5
				draw_texture_rect(StageGrade.disc(), Rect2(l[0] - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(c, 0.16 * _dim))
			else:
				draw_circle(l[0], r * f * flick, Color(c, 0.12 * _dim))
	for q: Dictionary in _parts:
		var a := _color.a * _dim * (0.7 + 0.3 * sin(_clock * 2.0 + q.phase))
		if soft:
			var s: float = q.size * 3.2
			draw_texture_rect(StageGrade.disc(), Rect2(q.p - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(_color, a * 0.8))
			continue
		var r := Rect2(q.p.round(), Vector2(q.size, q.size).round())
		draw_rect(r.grow(1.0), Color(_color.darkened(0.6), a * 0.5))  # liseré sombre : lisible sur un sol clair
		draw_rect(r, Color(_color, a))
