extends Node2D
## Défense de base : affichage + commandes. Aucune règle de jeu ici (tout est dans DefenseEngine).
## Images du pack Tiny Swords dans assets/tiny/ (copiées par tools/import_tiny_swords.py, hors git) ;
## sans elles, on dessine des formes simples.

const CELL := 96.0  # une tuile du pack (64 px) agrandie ×1,5
const TILE := 64.0
const BOARD_ORIGIN := Vector2(96, 72)
const PANEL_X := 1660.0
const FPS := 10.0
const TINY := "res://assets/tiny/"

const WATER := Color("#47aba9")
const GRASS := Color("#8fcf5a")
const BLUE := Color("#3f78c9")
const RED := Color("#c94a3f")
const INK := Color("#29262e")

# id du jeu -> [dossier de couleur, type d'unité du pack, échelle]
const LOOKS := {
	"guerrier": ["blue", "warrior", 0.9], "archer": ["blue", "archer", 0.9], "lancier": ["blue", "lancer", 0.9],
	"chevalier": ["yellow", "warrior", 1.1], "archere": ["yellow", "archer", 1.1],
	"gobelin": ["red", "warrior", 0.85], "lanceur": ["red", "archer", 0.85], "brute": ["red", "lancer", 1.05],
}

var engine := DefenseEngine.new()
var selected := "guerrier"
var paused := false
var hover_cell := Vector2i(-1, -1)
var anim_time := 0.0

var _tex := {}  # chemin -> Texture2D (ou null si absente)
var _vis := {}  # uid -> {face, attack_t}
var _fx: Array = []  # flèches, explosions, poussières, cercles de compétence
var _hud: Label
var _pause_btn: Button
var _skill_buttons := {}  # id du héros -> Button
var _end_label: Label


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := FileAccess.open("res://data/defense.json", FileAccess.READ)
	engine.setup(JSON.parse_string(f.get_as_text()), 7)
	_build_ui()


func tex(rel: String) -> Texture2D:
	if not _tex.has(rel):
		var path := TINY + rel
		var t: Texture2D = null
		if ResourceLoader.exists(path):
			t = load(path)
		elif FileAccess.file_exists(path):  # pas encore importée par Godot
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				t = ImageTexture.create_from_image(img)
		_tex[rel] = t
	return _tex[rel]


## Base d'exemple pour les captures (tools/screenshot.gd --demo).
func demo_setup() -> void:
	if not is_node_ready():
		await ready
	engine.gold = 2000
	for order in [["guerrier", 4, 3], ["guerrier", 4, 5], ["lancier", 5, 4], ["archer", 2, 2], ["archer", 2, 6],
			["tour", 3, 1], ["tour", 3, 7], ["barriere", 5, 2], ["barriere", 5, 6], ["catapulte", 1, 2],
			["chevalier", 3, 4], ["archere", 2, 4]]:
		engine.place(order[0], Vector2i(order[1], order[2]))


# --- Interface ----------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = _label(layer, Vector2(BOARD_ORIGIN.x, 12), 34, Color.WHITE)

	_pause_btn = _button(layer, "Pause", Vector2(PANEL_X, 12), Vector2(240, 72))
	_pause_btn.pressed.connect(func() -> void: set_paused(not paused))

	var y := 100.0
	var kinds: Array = engine.cfg.placeables.keys() + engine.cfg.heroes.keys()
	for kind in kinds:
		var def: Dictionary = engine.cfg.placeables.get(kind, engine.cfg.heroes.get(kind, {}))
		var text := "%s  %d or" % [def.name, engine.cost_of(kind)] if engine.cfg.placeables.has(kind) else "%s  (héros)" % def.name
		var b := _button(layer, text, Vector2(PANEL_X, y), Vector2(240, 72))
		b.pressed.connect(func() -> void: selected = kind)
		y += 80.0

	y += 20.0
	for hid in engine.cfg.heroes.keys():
		var b := _button(layer, "", Vector2(PANEL_X, y), Vector2(240, 80), true)
		b.pressed.connect(func() -> void: engine.use_skill(engine.hero_uid(hid)))
		_skill_buttons[hid] = b
		y += 88.0

	_end_label = _label(layer, Vector2(560, 440), 64, Color.WHITE)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.size = Vector2(800, 200)
	_end_label.visible = false


func _label(parent: Node, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 10)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, pos: Vector2, size: Vector2, red := false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)
	var normal := tex("ui/button_red.png" if red else "ui/button.png")
	if normal:
		b.add_theme_stylebox_override("normal", _box(normal))
		b.add_theme_stylebox_override("hover", _box(normal))
		b.add_theme_stylebox_override("disabled", _box(normal, Color(0.55, 0.55, 0.55)))
		b.add_theme_stylebox_override("pressed", _box(tex("ui/button_pressed.png")))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b


func _box(t: Texture2D, tint := Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = t
	s.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_texture_margin(side, 24)
		s.set_content_margin(side, 14)
	return s


func set_paused(value: bool) -> void:
	paused = value
	_pause_btn.text = "Reprendre" if paused else "Pause"


# --- Boucle -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not paused:
		engine.step(delta)
		anim_time += delta
	for ev in engine.drain_events():
		_on_event(ev)
	if not paused:
		for v in _vis.values():
			v.attack_t = max(0.0, v.attack_t - delta)
		for fx in _fx:
			fx.t += delta
		_fx = _fx.filter(func(fx: Dictionary) -> bool: return fx.t < fx.dur)
	_update_facing()

	var next := "" if engine.finished else "  ·  prochaine dans %d s" % ceili(engine.time_to_next_wave())
	_hud.text = "Or %d  ·  Château %d / %d  ·  Vague %d%s  ·  Pose : %s" % [
		engine.gold, engine.castle_hp, engine.castle_max_hp, engine.wave, next, _name_of(selected)]
	for hid in _skill_buttons:
		var uid := engine.hero_uid(hid)
		var b: Button = _skill_buttons[hid]
		var sk: Dictionary = engine.cfg.heroes[hid].skill
		b.visible = uid != 0
		b.disabled = not engine.skill_ready(uid)
		b.text = sk.name if not b.disabled or uid == 0 else "%s  %d s" % [sk.name, ceili(engine.unit(uid).skill_cd)]
	queue_redraw()


func _name_of(kind: String) -> String:
	return engine.cfg.placeables.get(kind, engine.cfg.heroes.get(kind, {})).get("name", kind)


func _on_event(ev: Dictionary) -> void:
	match ev.type:
		"placed", "spawn":
			_vis[ev.uid] = {"face": 1.0 if ev.type == "placed" else -1.0, "attack_t": 0.0, "last_x": 0.0}
		"attack":
			if _vis.has(ev.uid):
				_vis[ev.uid].attack_t = 0.6
				_vis[ev.uid].face = 1.0 if ev.to.x >= ev.from.x else -1.0
			var u := engine.unit(ev.uid)
			if not u.is_empty() and u.kind == "catapulte":
				_fx.append({"kind": "boulder", "from": ev.from, "to": ev.to, "t": 0.0, "dur": 0.6})
			elif ev.ranged:
				_fx.append({"kind": "arrow", "from": ev.from, "to": ev.to, "t": 0.0, "dur": 0.3})
		"death":
			_fx.append({"kind": "dust", "at": ev.pos, "t": 0.0, "dur": 0.8})
			_vis.erase(ev.uid)
		"skill":
			var u := engine.unit(ev.uid)
			if not u.is_empty():
				_fx.append({"kind": "circle", "at": u.pos, "t": 0.0, "dur": 0.6})
		"defeat":
			_end_label.text = "La base est tombée !\nVague atteinte : %d" % ev.wave
			_end_label.visible = true


func _update_facing() -> void:
	for u in engine.units:
		var v: Dictionary = _vis.get(u.uid, {})
		if v.is_empty():
			continue
		if u.moving and absf(u.pos.x - v.last_x) > 0.001:
			v.face = 1.0 if u.pos.x > v.last_x else -1.0
		v.last_x = u.pos.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = _cell_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		engine.place(selected, _cell_at(event.position))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		set_paused(not paused)


func _cell_at(screen: Vector2) -> Vector2i:
	var p := (screen - BOARD_ORIGIN) / CELL
	return Vector2i(floori(p.x), floori(p.y))


func _to_screen(cell_pos: Vector2) -> Vector2:
	return BOARD_ORIGIN + cell_pos * CELL


# --- Dessin -------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), WATER)
	_draw_island()
	_draw_water_decor()
	if hover_cell.x >= 0 and hover_cell.y >= 0 and hover_cell.x < engine.cols() and hover_cell.y < engine.rows():
		var ok := engine.can_place(selected, hover_cell)
		draw_rect(Rect2(_to_screen(Vector2(hover_cell)), Vector2(CELL, CELL)), Color(1, 1, 1, 0.35) if ok else Color(1, 0.2, 0.2, 0.3))

	# château et unités, triés par leur point au sol
	var drawables: Array = engine.units.duplicate()
	drawables.append({"castle": true, "pos": Vector2(engine.castle_cell()) + Vector2(0.5, 0.5)})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for d in drawables:
		if d.has("castle"):
			_draw_castle()
		else:
			_draw_unit(d)
	for fx in _fx:
		_draw_fx(fx)
	_draw_clouds()


func _draw_island() -> void:
	var cols := engine.cols()
	var rows := engine.rows()
	var tm := tex("terrain/tilemap.png")
	var foam := tex("terrain/foam.png")
	if tm == null:
		draw_rect(Rect2(BOARD_ORIGIN, Vector2(cols, rows) * CELL), GRASS)
		return
	# écume animée sous les bords de l'île
	if foam:
		var n := int(foam.get_width() / foam.get_height())
		var fr := int(anim_time * FPS) % n
		for c in cols:
			for r in rows + 1:
				if c == 0 or r == 0 or c == cols - 1 or r == rows:
					var center := _to_screen(Vector2(c + 0.5, r + 0.5))
					draw_texture_rect_region(foam, Rect2(center - Vector2(144, 144), Vector2(288, 288)), Rect2(fr * 192, 0, 192, 192))
	for c in cols:
		var tx := 0 if c == 0 else (2 if c == cols - 1 else 1)
		for r in rows:
			var ty := 0 if r == 0 else (2 if r == rows - 1 else 1)
			draw_texture_rect_region(tm, Rect2(_to_screen(Vector2(c, r)), Vector2(CELL, CELL)), Rect2(tx * TILE, ty * TILE, TILE, TILE))
		# falaise sous la dernière rangée
		var cx := 6 if c == 0 else (8 if c == cols - 1 else 7)
		draw_texture_rect_region(tm, Rect2(_to_screen(Vector2(c, rows)), Vector2(CELL, CELL)), Rect2(cx * TILE, 5 * TILE, TILE, TILE))
	# zone de construction : cases légèrement éclairées
	for c in int(engine.cfg.grid.build_cols):
		for r in rows:
			var rect := Rect2(_to_screen(Vector2(c, r)) + Vector2(3, 3), Vector2(CELL - 6, CELL - 6))
			draw_rect(rect, Color(1, 1, 1, 0.07))
			draw_rect(rect, Color(1, 1, 1, 0.18), false, 2.0)


func _draw_water_decor() -> void:
	var rocks := tex("terrain/water_rocks.png")
	if rocks:
		var fr := int(anim_time * 6.0) % 16
		for p in [Vector2(1620, 300), Vector2(40, 900), Vector2(900, 1020)]:
			draw_texture_rect_region(rocks, Rect2(p - Vector2(48, 48), Vector2(96, 96)), Rect2(fr * 64, 0, 64, 64))
	var duck := tex("terrain/duck.png")
	if duck:
		var fr := int(anim_time * 4.0) % 3
		draw_texture_rect_region(duck, Rect2(Vector2(1500, 1030), Vector2(64, 64)), Rect2(fr * 32, 0, 32, 32))


func _draw_clouds() -> void:
	var cloud := tex("terrain/cloud.png")
	if cloud == null:
		return
	for i in 2:
		var x := fmod(anim_time * 12.0 + i * 1100.0, 2400.0) - 400.0
		draw_texture_rect(cloud, Rect2(Vector2(x, 140 + i * 520), Vector2(576, 256)), false, Color(1, 1, 1, 0.35))


func _draw_castle() -> void:
	var foot := _to_screen(Vector2(engine.castle_cell()) + Vector2(0.5, 1.0))
	var t := tex("buildings/castle.png")
	if t:
		var size := Vector2(320, 256) * 0.7
		draw_texture_rect(t, Rect2(foot - Vector2(size.x / 2, size.y - 10), size), false)
	else:
		draw_rect(Rect2(foot - Vector2(40, 110), Vector2(80, 110)), Color("#d9c7a3"))
	_bar(foot + Vector2(-80, -200), 160, float(engine.castle_hp) / engine.castle_max_hp)


func _draw_unit(u: Dictionary) -> void:
	var p := _to_screen(u.pos)
	var shadow := tex("terrain/shadow.png")
	if shadow:
		draw_texture_rect(shadow, Rect2(p + Vector2(-36, -6), Vector2(72, 28)), false, Color(1, 1, 1, 0.6))
	var drawn := false
	if u.role == "defense":
		drawn = _draw_defense(u, p)
	elif LOOKS.has(u.kind):
		drawn = _draw_sprite_unit(u, p)
	if not drawn:
		draw_circle(p, 22, BLUE if u.team == 0 else RED)
	if u.role == "hero":
		draw_arc(p + Vector2(0, 8), 34, 0, TAU, 32, Color("#f2d24b"), 4.0)
	if u.hp < u.max_hp:
		_bar(p + Vector2(-30, -80), 60, float(u.hp) / u.max_hp)


func _draw_sprite_unit(u: Dictionary, p: Vector2) -> bool:
	var look: Array = LOOKS[u.kind]
	var v: Dictionary = _vis.get(u.uid, {"face": 1.0, "attack_t": 0.0})
	var anim := "idle"
	var frame_t := anim_time
	if v.attack_t > 0.0:
		anim = "attack"
		frame_t = 0.6 - v.attack_t
	elif u.moving:
		anim = "run"
	var t := tex("units/%s/%s_%s.png" % [look[0], look[1], anim])
	if t == null:
		return false
	var fh := float(t.get_height())
	var n := int(t.get_width() / fh)
	var fr := int(frame_t * FPS * (n / 6.0 if anim == "attack" else 1.0)) % n
	var size := fh * float(look[2])
	# le personnage est au centre de son image ; ses pieds sont un peu sous le centre
	var center := p - Vector2(0, size * 0.18)
	draw_set_transform(center, 0.0, Vector2(v.face, 1.0))
	draw_texture_rect_region(t, Rect2(-size / 2, -size / 2, size, size), Rect2(fr * fh, 0, fh, fh))
	draw_set_transform(Vector2.ZERO)
	return true


func _draw_defense(u: Dictionary, p: Vector2) -> bool:
	match u.kind:
		"tour":
			var t := tex("buildings/tower.png")
			if t:
				var s := Vector2(128, 256) * 0.62
				draw_texture_rect(t, Rect2(p - Vector2(s.x / 2, s.y - 24), s), false)
				return true
		"catapulte":
			var t := tex("buildings/archery.png")
			if t:
				var s := Vector2(192, 256) * 0.45
				draw_texture_rect(t, Rect2(p - Vector2(s.x / 2, s.y - 24), s), false)
				return true
		"barriere":
			var a := tex("terrain/rock1.png")
			var b := tex("terrain/rock2.png")
			if a and b:
				draw_texture_rect(a, Rect2(p + Vector2(-48, -48), Vector2(64, 64)), false)
				draw_texture_rect(b, Rect2(p + Vector2(-8, -40), Vector2(56, 56)), false)
				draw_texture_rect(a, Rect2(p + Vector2(-30, -20), Vector2(60, 60)), false)
				return true
	return false


func _draw_fx(fx: Dictionary) -> void:
	var k: float = fx.t / fx.dur
	match fx.kind:
		"arrow":
			var t := tex("fx/arrow.png")
			var from := _to_screen(fx.from) - Vector2(0, 30)
			var to := _to_screen(fx.to) - Vector2(0, 30)
			var pos := from.lerp(to, k) - Vector2(0, sin(k * PI) * 40.0)
			if t:
				draw_set_transform(pos, (to - from).angle(), Vector2.ONE)
				draw_texture_rect(t, Rect2(-32, -32, 64, 64), false)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_circle(pos, 4, Color.WHITE)
		"boulder":
			var from := _to_screen(fx.from) - Vector2(0, 40)
			var to := _to_screen(fx.to)
			if k < 0.5:
				var pos := from.lerp(to, k * 2.0) - Vector2(0, sin(k * 2.0 * PI) * 160.0)
				draw_circle(pos, 10, Color("#6b6058"))
			else:
				_draw_strip("fx/explosion.png", to - Vector2(0, 40), 1.0, (k - 0.5) * 2.0)
		"dust":
			_draw_strip("fx/dust.png", _to_screen(fx.at), 1.6, k)
		"circle":
			draw_arc(_to_screen(fx.at), 2.5 * CELL * (0.6 + 0.4 * k), 0, TAU, 48, Color(1, 0.9, 0.3, 1.0 - k), 6.0)


## Joue une planche d'images horizontale (cadres carrés) à l'avancement k (0..1).
func _draw_strip(rel: String, center: Vector2, scale: float, k: float) -> void:
	var t := tex(rel)
	if t == null:
		return
	var fh := float(t.get_height())
	var n := int(t.get_width() / fh)
	var fr := clampi(int(k * n), 0, n - 1)
	var s := fh * scale
	draw_texture_rect_region(t, Rect2(center - Vector2(s, s) / 2, Vector2(s, s)), Rect2(fr * fh, 0, fh, fh))


func _bar(pos: Vector2, width: float, ratio: float) -> void:
	draw_rect(Rect2(pos, Vector2(width, 10)), INK)
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2((width - 4) * ratio, 6)), Color("#7fd34e") if ratio > 0.4 else Color("#e9a23b"))
