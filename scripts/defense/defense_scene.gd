extends Node2D
## Défense de base : affichage + commandes. Aucune règle de jeu ici (tout est dans DefenseEngine).
## Images du pack Tiny Swords dans assets/tiny/ (copiées par tools/import_tiny_swords.py, hors git) ;
## sans elles, on dessine des formes simples.

const CELL := 96.0  # une tuile du pack (64 px) agrandie ×1,5
const TILE := 64.0
const BOARD_ORIGIN := Vector2(192, 64)
const BAR_Y := 944.0  # barre des cartes en bas
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
var selected := ""  # ce qu'on va poser (vide = rien)
var moving_uid := 0  # troupe ou héros choisi pour changer de case
var _dragging := false
var paused := false
var hover_cell := Vector2i(-1, -1)
var anim_time := 0.0

var _tex := {}  # chemin -> Texture2D (ou null si absente)
var _vis := {}  # uid -> {face, attack_t}
var _fx: Array = []  # flèches, explosions, poussières, cercles de compétence
var _hud: Label
var _pause_btn: Button
var _skill_buttons := {}  # id du héros -> Button
var _cards := {}  # id posable -> Button
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
	for order in [["guerrier", 4, 2], ["guerrier", 4, 4], ["lancier", 5, 3], ["archer", 2, 1], ["archer", 2, 5],
			["tour", 3, 0], ["tour", 3, 6], ["barriere", 5, 1], ["barriere", 5, 5], ["catapulte", 1, 1],
			["chevalier", 3, 3], ["archere", 2, 3]]:
		engine.place(order[0], Vector2i(order[1], order[2]))


# --- Interface ----------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = _label(layer, Vector2(BOARD_ORIGIN.x, 8), 34, Color.WHITE)

	_pause_btn = _button(layer, "Pause", Vector2(1560, 4), Vector2(170, 56))
	_pause_btn.pressed.connect(func() -> void: set_paused(not paused))

	# cartes : une par troupe, défense ou héros, avec son image et son prix
	var x := BOARD_ORIGIN.x
	var kinds: Array = engine.cfg.placeables.keys() + engine.cfg.heroes.keys()
	for kind in kinds:
		var price := "%d" % engine.cost_of(kind) if engine.cfg.placeables.has(kind) else "héros"
		var b := _button(layer, price, Vector2(x, BAR_Y), Vector2(124, 124))
		b.icon = _card_icon(kind)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.tooltip_text = _name_of(kind)
		b.pressed.connect(func() -> void: _select_card(kind))
		_cards[kind] = b
		x += 132.0

	x += 24.0
	for hid in engine.cfg.heroes.keys():
		var b := _button(layer, "", Vector2(x, BAR_Y + 22), Vector2(210, 80), true)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(func() -> void: engine.use_skill(engine.hero_uid(hid)))
		_skill_buttons[hid] = b
		x += 218.0

	_end_label = _label(layer, Vector2(560, 400), 64, Color.WHITE)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.size = Vector2(800, 200)
	_end_label.visible = false


## Première image de l'unité (ou le bâtiment) pour sa carte.
func _card_icon(kind: String) -> Texture2D:
	var t: Texture2D
	var region := Rect2()
	if LOOKS.has(kind):
		t = tex("units/%s/%s_idle.png" % [LOOKS[kind][0], LOOKS[kind][1]])
		if t:
			var fh := float(t.get_height())
			region = Rect2(fh * 0.25, fh * 0.2, fh * 0.5, fh * 0.5)  # le personnage, sans le vide autour
	else:
		t = tex({"tour": "buildings/tower.png", "catapulte": "buildings/archery.png", "barriere": "terrain/rock1.png"}.get(kind, ""))
	if t == null or region == Rect2():
		return t
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = region
	return at


func _select_card(kind: String) -> void:
	selected = "" if selected == kind else kind
	moving_uid = 0


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
	_hud.text = "Or %d  ·  Château %d / %d  ·  Vague %d%s" % [
		engine.gold, engine.castle_hp, engine.castle_max_hp, engine.wave, next]
	for kind in _cards:
		var card: Button = _cards[kind]
		card.disabled = (engine.cfg.placeables.has(kind) and engine.gold < engine.cost_of(kind)) \
				or (engine.cfg.heroes.has(kind) and engine.hero_uid(kind) != 0)
		card.modulate = Color(1.15, 1.15, 1.15) if kind == selected else Color.WHITE
		card.position.y = BAR_Y - (12.0 if kind == selected else 0.0)
	if moving_uid != 0 and engine.unit(moving_uid).is_empty():
		moving_uid = 0
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


## Clic sur une de ses troupes (ou un héros) : on la choisit, puis on clique sa nouvelle case
## (ou on la fait glisser). Sinon, un clic pose la carte choisie. Clic droit : annule.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = _cell_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at(event.position)
		if event.pressed:
			var uid := _unit_at(event.position)
			if uid != 0:
				moving_uid = uid
				selected = ""
				_dragging = true
			elif moving_uid != 0:
				engine.move_unit(moving_uid, cell)
				moving_uid = 0
			elif selected != "":
				engine.place(selected, cell)
		elif _dragging:
			_dragging = false
			var u := engine.unit(moving_uid)
			if not u.is_empty() and cell != u.post and engine.move_unit(moving_uid, cell):
				moving_uid = 0
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		moving_uid = 0
		selected = ""
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		set_paused(not paused)


## Troupe ou héros du joueur sous le pointeur (0 si aucun).
func _unit_at(screen: Vector2) -> int:
	var best := 0
	var best_d := 0.6
	for u in engine.units:
		if u.team == 0 and u.role != "defense":
			var d: float = (_to_screen(u.pos) - Vector2(0, CELL * 0.3)).distance_to(screen) / CELL
			if d < best_d:
				best_d = d
				best = u.uid
	return best


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
	if moving_uid != 0:
		var post: Vector2i = engine.unit(moving_uid).post
		draw_rect(Rect2(_to_screen(Vector2(post)) + Vector2(4, 4), Vector2(CELL - 8, CELL - 8)), Color(1, 1, 1, 0.8), false, 3.0)
	var showing := moving_uid != 0 or selected != ""
	if showing and hover_cell.x >= 0 and hover_cell.y >= 0 and hover_cell.x < engine.cols() and hover_cell.y < engine.rows():
		var ok := engine.can_move(moving_uid, hover_cell) if moving_uid != 0 else engine.can_place(selected, hover_cell)
		draw_rect(Rect2(_to_screen(Vector2(hover_cell)), Vector2(CELL, CELL)), Color(1, 1, 1, 0.35) if ok else Color(1, 0.2, 0.2, 0.3))

	# château et unités, triés par leur point au sol
	var drawables: Array = engine.units.duplicate()
	drawables.append({"castle": true, "pos": engine.castle_center()})
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
	# sol bas de l'île (tuiles plates, colonnes 0-2 du pack) et falaise avec écume dessous
	for c in cols:
		for r in rows:
			_tile(tm, Vector2i(c, r), Vector2i(_edge(c, cols), _edge(r, rows)))
		_tile(tm, Vector2i(c, rows), Vector2i(5 + _edge(c, cols), 5))
	# plateau de la base : herbe surélevée (colonnes 5-7), ombre portée à droite, falaise dessous
	var pw := int(engine.cfg.grid.build_cols)
	var ph := engine.build_rows()
	var shadow := tex("terrain/shadow.png")
	if shadow:
		draw_texture_rect(shadow, Rect2(_to_screen(Vector2(pw - 0.6, 0.2)), Vector2(CELL * 1.1, CELL * ph)), false, Color(1, 1, 1, 0.55))
		draw_texture_rect(shadow, Rect2(_to_screen(Vector2(0, ph + 0.6)), Vector2(CELL * pw, CELL * 0.8)), false, Color(1, 1, 1, 0.55))
	for c in pw:
		for r in ph:
			_tile(tm, Vector2i(c, r), Vector2i(5 + _edge(c, pw), _edge(r, ph)))
		_tile(tm, Vector2i(c, ph), Vector2i(5 + _edge(c, pw), 4))
	# zone de construction : cases légèrement marquées
	for c in pw:
		for r in ph:
			var rect := Rect2(_to_screen(Vector2(c, r)) + Vector2(4, 4), Vector2(CELL - 8, CELL - 8))
			draw_rect(rect, Color(1, 1, 1, 0.14), false, 2.0)
	_draw_scenery()


## Colonne (ou rangée) de tuile d'un bloc 3×3 : 0 = bord gauche, 1 = milieu, 2 = bord droit.
func _edge(i: int, count: int) -> int:
	return 0 if i == 0 else (2 if i == count - 1 else 1)


func _tile(tm: Texture2D, cell: Vector2i, src: Vector2i) -> void:
	draw_texture_rect_region(tm, Rect2(_to_screen(Vector2(cell)), Vector2(CELL, CELL)), Rect2(Vector2(src) * TILE, Vector2(TILE, TILE)))


## Arbres et buissons sur les bords de l'île, là où personne ne passe.
func _draw_scenery() -> void:
	var tree := tex("terrain/tree.png")
	var bush := tex("terrain/bush.png")
	var rows := engine.rows()
	if bush:
		var fr := int(anim_time * 8.0) % 8
		for p in [Vector2(7.2, 0.15), Vector2(10.6, 0.1), Vector2(13.8, rows - 0.2), Vector2(8.5, rows - 0.15)]:
			draw_texture_rect_region(bush, Rect2(_to_screen(p) - Vector2(48, 72), Vector2(96, 96)), Rect2(fr * 128, 0, 128, 128))
	if tree:
		var fr := int(anim_time * 8.0) % 8
		for p in [Vector2(9.6, 0.9), Vector2(14.4, 0.95), Vector2(11.2, rows + 0.05), Vector2(15.3, rows - 0.4)]:
			draw_texture_rect_region(tree, Rect2(_to_screen(p) - Vector2(72, 180), Vector2(144, 192)), Rect2(fr * 192, 0, 192, 256))


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
	var foot := _to_screen(engine.castle_center() + Vector2(0, engine.castle_size().y / 2.0 - 0.1))
	var t := tex("buildings/castle.png")
	if t:
		var size := Vector2(320, 256) * 0.62
		var sh := tex("terrain/shadow.png")
		if sh:
			draw_texture_rect(sh, Rect2(foot - Vector2(130, 40), Vector2(260, 80)), false, Color(1, 1, 1, 0.7))
		draw_texture_rect(t, Rect2(foot - Vector2(size.x / 2, size.y - 10), size), false)
	else:
		draw_rect(Rect2(foot - Vector2(40, 110), Vector2(80, 110)), Color("#d9c7a3"))
	_bar(foot + Vector2(-70, -180), 140, float(engine.castle_hp) / engine.castle_max_hp)


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
	var glow := Color(1.5, 1.5, 1.5) if u.uid == moving_uid and int(anim_time * 4.0) % 2 == 0 else Color.WHITE
	draw_texture_rect_region(t, Rect2(-size / 2, -size / 2, size, size), Rect2(fr * fh, 0, fh, fh), glow)
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
