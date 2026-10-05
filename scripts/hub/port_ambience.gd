class_name PortAmbience
extends Node
## Le temps qui passe sur Port-Franc : aube, journée, crépuscule et nuit, avec des transitions
## douces. Suit l'heure réelle (ou une heure imposée par le bouton du hub). Change la couleur du
## ciel (shader qui garde les nuages dessinés), teinte la ville, allume les lanternes et les
## fenêtres la nuit (halos lumineux), et ajoute des effets : étoiles et lune, brume du matin,
## rayons de soleil, poussières dorées, lucioles, feuilles qui volent, éclat de la Lanterne.

const SKY_SHADER := """
shader_type canvas_item;
uniform vec4 top_color : source_color = vec4(0.3, 0.55, 0.95, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float recolor = 0.0;
uniform float span = 0.75;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	vec3 g = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, span, UV.y));
	vec3 c = g * (0.45 + 0.95 * lum);
	COLOR = vec4(mix(t.rgb, c, recolor), t.a);
}
"""

# Ambiances clés : ciel (haut, bas, part recolorée), teinte de la ville, lumières, étoiles,
# brume, rayons (et leur couleur), poussières, lucioles, feuilles.
const MOODS := {
	"nuit": {"top": Color(0.03, 0.04, 0.13), "bottom": Color(0.12, 0.12, 0.3), "recolor": 1.0,
		"world": Color(0.36, 0.4, 0.66), "light": 1.0, "stars": 1.0, "mist": 0.2, "rays": 0.0,
		"ray_color": Color(0.6, 0.7, 1.0), "dust": 0.0, "fireflies": 1.0, "leaves": 0.2},
	"aube": {"top": Color(0.36, 0.46, 0.8), "bottom": Color(1.0, 0.72, 0.58), "recolor": 0.85,
		"world": Color(1.0, 0.84, 0.8), "light": 0.4, "stars": 0.12, "mist": 1.0, "rays": 0.9,
		"ray_color": Color(1.0, 0.78, 0.62), "dust": 0.35, "fireflies": 0.0, "leaves": 0.4},
	"jour": {"top": Color(0.28, 0.56, 0.95), "bottom": Color(0.8, 0.91, 1.0), "recolor": 0.9,
		"world": Color(1.06, 1.04, 1.0), "light": 0.0, "stars": 0.0, "mist": 0.0, "rays": 0.4,
		"ray_color": Color(1.0, 0.96, 0.82), "dust": 0.7, "fireflies": 0.0, "leaves": 1.0},
	"crepuscule": {"top": Color(0.4, 0.38, 0.75), "bottom": Color(1.0, 0.6, 0.55), "recolor": 0.0,
		"world": Color(1.0, 0.97, 0.97), "light": 0.55, "stars": 0.0, "mist": 0.15, "rays": 0.5,
		"ray_color": Color(1.0, 0.62, 0.48), "dust": 0.55, "fireflies": 0.1, "leaves": 0.7},
	"soir": {"top": Color(0.1, 0.09, 0.28), "bottom": Color(0.6, 0.32, 0.46), "recolor": 0.55,
		"world": Color(0.68, 0.6, 0.8), "light": 0.85, "stars": 0.45, "mist": 0.2, "rays": 0.0,
		"ray_color": Color(1.0, 0.6, 0.6), "dust": 0.1, "fireflies": 0.6, "leaves": 0.3},
}
# Heure -> ambiance (on passe doucement de l'une à l'autre).
const KEYS := [[0.0, "nuit"], [5.0, "nuit"], [6.5, "aube"], [8.5, "jour"], [17.0, "jour"], [19.0, "crepuscule"],
	[20.5, "soir"], [22.0, "nuit"], [24.0, "nuit"]]

var hour_override := -1.0  # -1 = heure réelle
var current: Dictionary = {}  # ambiance affichée (glisse vers la cible)

var _town: PortFranc2D
var _sky_mats: Array[Dictionary] = []  # {mat, factor}
var _tinted: Array[CanvasItem] = []
var _halos: Array[Dictionary] = []  # {sprite, base, flicker, color}
var _sky_fx: Node2D
var _air_fx: Node2D
var _front_fx: Node2D
var _rays: Node2D
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _stars: Array[Vector3] = []
var _motes: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []


func setup(town: PortFranc2D) -> void:
	_town = town
	_rng.seed = 11
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER
	for i in town.layer_sprites.size():
		var s: Sprite2D = town.layer_sprites[i]
		var file := String(town.scene.layers[i].file)
		if file.contains("Ciel") or file.contains("Horizon"):
			var mat := ShaderMaterial.new()
			mat.shader = sky_shader
			mat.set_shader_parameter("span", 0.75 if file.contains("Ciel") else 0.45)
			s.material = mat
			_sky_mats.append({"mat": mat, "factor": 1.0 if file.contains("Ciel") else 0.55})
	for p: Dictionary in town.planes():
		if float(p.parallax) > 0.2:
			_tinted.append(p.node)
	# Ciel : étoiles et lune, derrière l'horizon.
	_sky_fx = Node2D.new()
	_sky_fx.z_index = 1
	town.plane_for(0.15).add_child(_sky_fx)
	_sky_fx.draw.connect(_draw_sky)
	for i in 160:
		_stars.append(Vector3(_rng.randf_range(0, 3840), _rng.randf_range(0, 430) * _rng.randf_range(0.4, 1.0), _rng.randf()))
	# Rayons de soleil, entre la ville et la place.
	_rays = Node2D.new()
	_rays.z_index = 58
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rays.material = add
	town.plane_for(1.0).add_child(_rays)
	_rays.draw.connect(_draw_rays)
	# Air de la place : brume, poussières, lucioles, feuilles (devant les bâtiments).
	_air_fx = Node2D.new()
	_air_fx.z_index = 60
	town.plane_for(1.0).add_child(_air_fx)
	_air_fx.draw.connect(_draw_air)
	_front_fx = Node2D.new()
	_front_fx.z_index = 20
	town.plane_for(1.15).add_child(_front_fx)
	_front_fx.draw.connect(_draw_front)
	for i in 70:
		_motes.append({"p": Vector2(_rng.randf_range(0, 3840), _rng.randf_range(250, 1000)), "ph": _rng.randf() * TAU,
			"s": _rng.randf_range(0.6, 1.4)})
	for i in 14:
		_leaves.append({"p": Vector2(_rng.randf_range(-200, 3840), _rng.randf_range(100, 900)), "ph": _rng.randf() * TAU,
			"v": _rng.randf_range(50, 110), "s": _rng.randf_range(0.7, 1.3)})
	_add_halos()
	current = _mood_at(_hour())


## Heure affichée : l'heure imposée, ou l'heure réelle de l'appareil.
func _hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var t := Time.get_time_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0


func mood_name() -> String:
	var h := _hour()
	if h >= 5.5 and h < 8.0:
		return "Aube"
	if h >= 8.0 and h < 18.0:
		return "Jour"
	if h >= 18.0 and h < 21.0:
		return "Crépuscule"
	return "Nuit"


func _process(delta: float) -> void:
	_time += delta
	var target := _mood_at(_hour())
	var k := 1.0 - exp(-delta * 1.5)
	for key: String in target:
		var a: Variant = current.get(key, target[key])
		current[key] = lerp(a, target[key], k)
	for s: Dictionary in _sky_mats:
		var mat: ShaderMaterial = s.mat
		mat.set_shader_parameter("top_color", current.top)
		mat.set_shader_parameter("bottom_color", current.bottom)
		mat.set_shader_parameter("recolor", float(current.recolor) * float(s.factor))
	for n in _tinted:
		n.modulate = current.world
	var light := float(current.light)
	for h: Dictionary in _halos:
		var sprite: Sprite2D = h.sprite
		var flick := 1.0 + (sin(_time * 9.0 + h.ph) * 0.06 + sin(_time * 23.0 + h.ph * 2.0) * 0.04) * float(h.flicker)
		var level := maxf(light, float(h.get("min", 0.0)))
		sprite.modulate = Color(h.color, level * float(h.base) * flick)
		sprite.visible = level > 0.01
	for m: Dictionary in _motes:
		m.p += Vector2(sin(_time * 0.4 + m.ph) * 12.0, -6.0 - 4.0 * m.s) * delta
		if m.p.y < 200.0:
			m.p = Vector2(_rng.randf_range(0, 3840), 1000.0)
	for l: Dictionary in _leaves:
		l.p += Vector2(l.v, 22.0 + sin(_time * 1.3 + l.ph) * 35.0) * delta
		if l.p.x > 3900.0 or l.p.y > 1080.0:
			l.p = Vector2(_rng.randf_range(-300, -40), _rng.randf_range(80, 700))
	_sky_fx.queue_redraw()
	_rays.queue_redraw()
	_air_fx.queue_redraw()
	_front_fx.queue_redraw()


func _mood_at(hour: float) -> Dictionary:
	hour = fposmod(hour, 24.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= float(a[0]) and hour <= float(b[0]):
			var t := (hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t)
			var ma: Dictionary = MOODS[a[1]]
			var mb: Dictionary = MOODS[b[1]]
			var out := {}
			for key: String in ma:
				out[key] = lerp(ma[key], mb[key], t)
			return out
	return MOODS.nuit.duplicate()


# --- Lumières ---------------------------------------------------------------------

func _add_halos() -> void:
	var tex := _radial_texture()
	var plane := _town.plane_for(1.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for a: Dictionary in _town.scene.get("anims", []):
		var file := String(a.file)
		if file.begins_with("Flamme"):
			var p := plane if not a.get("front", false) else _town.plane_for(1.15)
			_halo(p, tex, add, Vector2(a.x, a.y), 260.0, Color(1.0, 0.72, 0.38), 0.9, 1.0)
		elif file.begins_with("Lanterne_Pulse"):
			_halo(plane, tex, add, Vector2(a.x, a.y), 420.0, Color(0.72, 0.42, 1.0), 0.8, 0.3, 0.35)
	for w: Array in _town.scene.get("windows", []):
		_halo(plane, tex, add, Vector2(w[0], w[1]), float(w[2]) * 6.0, Color(1.0, 0.78, 0.4), 0.75, 0.15)
		_halo(plane, tex, add, Vector2(w[0], w[1]), float(w[2]) * 1.6, Color(1.0, 0.9, 0.6), 0.9, 0.05)


func _halo(plane: Node2D, tex: Texture2D, mat: Material, at: Vector2, size: float, color: Color, base: float,
		flicker: float, min_level := 0.0) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.material = mat
	s.position = at
	s.scale = Vector2.ONE * size / tex.get_width()
	s.z_index = 55
	plane.add_child(s)
	_halos.append({"sprite": s, "base": base, "flicker": flicker, "color": color, "ph": _rng.randf() * TAU,
		"min": min_level})


func _radial_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


# --- Dessins ------------------------------------------------------------------------

func _draw_sky() -> void:
	var stars := float(current.get("stars", 0.0))
	if stars > 0.01:
		for s: Vector3 in _stars:
			var tw := 0.55 + 0.45 * sin(_time * (1.0 + s.z * 2.0) + s.z * 40.0)
			var r := 1.2 + s.z * 1.8
			_sky_fx.draw_circle(Vector2(s.x, s.y), r, Color(1, 0.97, 0.9, stars * tw))
			if s.z > 0.85:
				_sky_fx.draw_line(Vector2(s.x - r * 3, s.y), Vector2(s.x + r * 3, s.y), Color(1, 1, 1, stars * tw * 0.5), 1.0)
				_sky_fx.draw_line(Vector2(s.x, s.y - r * 3), Vector2(s.x, s.y + r * 3), Color(1, 1, 1, stars * tw * 0.5), 1.0)
		# Lune, avec son halo et ses taches.
		var m := Vector2(1150, 150)
		for i in 5:
			_sky_fx.draw_circle(m, 60.0 + i * 26.0, Color(0.85, 0.88, 1.0, stars * 0.05))
		_sky_fx.draw_circle(m, 52.0, Color(0.96, 0.95, 0.86, stars))
		_sky_fx.draw_circle(m + Vector2(-16, -10), 11.0, Color(0.84, 0.83, 0.76, stars))
		_sky_fx.draw_circle(m + Vector2(14, 14), 8.0, Color(0.84, 0.83, 0.76, stars))
		_sky_fx.draw_circle(m + Vector2(18, -18), 6.0, Color(0.86, 0.85, 0.78, stars))
		# Étoile filante de temps en temps.
		var cycle := fmod(_time, 9.0)
		if cycle < 0.9:
			var p0 := Vector2(2600 - cycle * 900.0, 60 + cycle * 260.0)
			_sky_fx.draw_line(p0, p0 + Vector2(160, -46), Color(1, 1, 1, stars * (1.0 - cycle / 0.9)), 2.5, true)


func _draw_rays() -> void:
	var rays := float(current.get("rays", 0.0))
	if rays < 0.01:
		return
	var c: Color = current.get("ray_color", Color.WHITE)
	var src := Vector2(3300, -260)
	for i in 7:
		var sway := sin(_time * 0.25 + i * 1.7) * 60.0
		var x := 400.0 + i * 430.0 + sway
		var w := 90.0 + float(i % 3) * 70.0
		var pts := PackedVector2Array([src + Vector2(-20, 0), src + Vector2(20, 0), Vector2(x + w, 1080), Vector2(x - w, 1080)])
		var a := rays * (0.08 + 0.04 * sin(_time * 0.6 + i))
		_rays.draw_colored_polygon(pts, Color(c, a))


func _draw_air() -> void:
	var mist := float(current.get("mist", 0.0))
	if mist > 0.01:
		# Bancs de brume qui glissent sur la place et sur le port.
		for i in 12:
			var x := fposmod(i * 420.0 + _time * (14.0 + i * 3.0), 4600.0) - 400.0
			var y := 600.0 + float(i % 4) * 110.0
			for j in 8:
				var k := j / 8.0
				_air_fx.draw_circle(Vector2(x + k * 520.0, y + sin(k * 6.0 + i) * 18.0), 110.0 + 50.0 * sin(k * 3.0 + i),
					Color(1.0, 0.93, 0.93, mist * 0.075))
	var dust := float(current.get("dust", 0.0))
	var flies := float(current.get("fireflies", 0.0))
	for i in _motes.size():
		var m: Dictionary = _motes[i]
		var tw := 0.5 + 0.5 * sin(_time * 2.0 + m.ph * 3.0)
		if dust > 0.01 and i % 2 == 0:
			_air_fx.draw_circle(m.p, 3.0 * m.s, Color(1.0, 0.92, 0.7, dust * 0.65 * tw))
		if flies > 0.01 and i % 2 == 1:
			var p: Vector2 = m.p + Vector2(sin(_time * 1.1 + m.ph) * 30.0, cos(_time * 0.9 + m.ph) * 20.0)
			var glow := flies * (0.3 + 0.7 * maxf(0.0, sin(_time * 1.7 + m.ph * 5.0)))
			_air_fx.draw_circle(p, 11.0 * m.s, Color(0.85, 1.0, 0.45, glow * 0.12))
			_air_fx.draw_circle(p, 3.0 * m.s, Color(0.95, 1.0, 0.6, glow))
	# Petites étincelles violettes qui montent de la Lanterne des Serments.
	for i in 12:
		var u := fposmod(_time * 0.22 + i * 0.083, 1.0)
		var p := Vector2(1120 + sin(i * 2.1 + _time) * 60.0, 700 - u * 420.0)
		_air_fx.draw_circle(p, 3.0, Color(0.8, 0.55, 1.0, sin(u * PI) * 0.8))


func _draw_front() -> void:
	var leaves := float(current.get("leaves", 0.0))
	if leaves < 0.01:
		return
	for l: Dictionary in _leaves:
		var ang := _time * 2.0 + float(l.ph)
		var s := 9.0 * float(l.s)
		var pts := PackedVector2Array()
		for v: Vector2 in [Vector2(-s * 1.6, 0), Vector2(0, -s * 0.7), Vector2(s * 1.6, 0), Vector2(0, s * 0.7)]:
			pts.append(l.p + v.rotated(ang) * Vector2(1.0, absf(cos(ang * 0.7)) + 0.2))
		_front_fx.draw_colored_polygon(pts, Color(0.36, 0.55, 0.22, leaves * 0.9))
		_front_fx.draw_line(pts[0], pts[2], Color(0.2, 0.3, 0.12, leaves * 0.8), 1.5)
