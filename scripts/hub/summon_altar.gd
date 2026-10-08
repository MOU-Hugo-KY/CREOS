class_name SummonAltar
extends Control
## Écran « Lanterne des Serments » (pièces pixel du pack partie 2, disposition de
## assets/ui/ecrans/lanterne/lanterne.json) : invoquer des héros avec des Fragments de serment
## (gagnés en chasse) ou des gemmes. Taux et garantie à gauche, héros de l'autel à droite, la
## lanterne au centre. L'invocation : la lanterne s'allume, une colonne de la couleur de la rareté
## jaillit, un éclat, puis le panneau de révélation montre le héros. Règles dans `Summon` et
## `PlayerData.summon()`.

signal closed
signal ui_sound(sfx_name: String)

const S := "lanterne"
const CURRENCIES := [["fragments_relique", "fragment_serment_64", "fragments"], ["gems", "gemme_64", "gemmes"]]
const RARITY_KEYS := {2: "rare", 3: "epic", 4: "legendary"}
## Couleur de la flamme selon la rareté (le dessin du pack est doré : on ne garde l'or que pour
## les légendaires).
const FLAME := {2: Color("4aa8ff"), 3: Color("b76cff")}
## Recolore seulement les pixels clairs et chauds (la flamme), pas le laiton plus sombre.
const FLAME_SHADER := """
shader_type canvas_item;
uniform vec4 flame : source_color = vec4(1.0);
uniform float amount = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	float warm = c.r - c.b;
	float k = smoothstep(0.55, 0.75, l) * step(0.15, warm) * amount;
	vec3 tinted = flame.rgb * (0.45 + 0.75 * l);
	COLOR = vec4(mix(c.rgb, tinted, k), c.a);
}
"""

var busy := false
var _scene: Control  # la salle de la lanterne, 1150 × 860, découpée
var _lantern: TextureRect
var _lit: Anim
var _flame: ShaderMaterial
var _columns: Dictionary = {}  # "rare"… -> Anim
var _burst: Anim
var _sparks: Anim
var _glow: Control
var _embers: Control
var _lantern_y := 0.0
var _lit_y := 0.0
var _time := 0.0
var _balance: Dictionary = {}  # monnaie -> Label
var _buttons: Dictionary = {}  # monnaie -> Button
var _odds: Label
var _pity: Label
var _rows: Array[Control] = []
var _pool_box: Control
var _event: Label
var _page_title: Label
var _page := 4  # rareté affichée sur la bannière
var _hover: Control
var _reveal: Control
var _reveal_name: Label
var _reveal_rarity: Panel
var _reveal_rarity_label: Label
var _reveal_trap: Label
var _rng := RandomNumberGenerator.new()

const Anim := ScreenPack.Anim
## Lanterne : pied du dessin (coordonnées de la salle), où il est posé, et sa taille.
const LANTERN_FOOT := Vector2(575, 585)
const LANTERN_AT := Vector2(190, 500)
const LANTERN_SCALE := 0.6
## Pied du héros invoqué, au centre du cercle (écran), et sa hauteur.
const HERO_FEET := Vector2(960, 735)
const HERO_HEIGHT := 400.0

var _hero_player: ClipPlayer
var _mage_room: MageRoom
var _hero_height := HERO_HEIGHT
var _hero_shadow: Control


func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var L := ScreenPack.layout(S)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := ScreenPack.frame(self)

	# Salle du Mage runique (pack « Invocateurs ») si elle est là, sinon l'ancienne salle de la lanterne.
	if MageRoom.available():
		_mage_room = MageRoom.new()
		root.add_child(_mage_room)
		_hero_height = 260.0
	else:
		# La salle couvre tout l'écran (agrandie à la largeur, recadrée en haut et en bas autour de la lanterne).
		var sr := ScreenPack.rect(L.central_scene_rect)
		var k := 1920.0 / sr.size.x
		_scene = Control.new()
		_scene.size = sr.size
		_scene.scale = Vector2(k, k)
		_scene.position = Vector2(0, -140)
		_scene.clip_contents = true
		_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_scene)
		ScreenPack.image(_scene, ScreenPack.tex(S, "fond"), Rect2(Vector2.ZERO, sr.size))
		_glow = _Ambient.new()  # lueur qui respire et cercle de runes, derrière la lanterne
		_glow.size = sr.size
		_scene.add_child(_glow)
		_sparks = _anim("particules", L.particles_anchor_in_scene)
		# La lanterne, réduite, est posée sur le côté gauche ; le cercle du milieu reste libre pour le héros.
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.scale = Vector2.ONE * LANTERN_SCALE
		box.position = LANTERN_AT - LANTERN_FOOT * LANTERN_SCALE
		_scene.add_child(box)
		_lantern = ScreenPack.image(box, ScreenPack.tex(S, "lanterne"), ScreenPack.rect(L.lantern_sprite_rect_in_scene))
		_lit = Anim.new(S, "lanterne_allumage")
		_lit.position = Vector2(L.lantern_anchor_in_scene[0], L.lantern_anchor_in_scene[1])
		box.add_child(_lit)
		_flame = ShaderMaterial.new()
		_flame.shader = Shader.new()
		_flame.shader.code = FLAME_SHADER
		_lit.material = _flame
		_lantern.material = _flame
		for c: String in ["rare", "epic", "legendary"]:
			_columns[c] = _anim("colonne_" + c, L.column_anchor_in_scene)
		_burst = _anim("eclat_final", L.final_anchor_in_scene)
		_embers = _Ambient.new()  # braises et poussières dorées qui montent devant
		_embers.front = true
		_embers.size = sr.size
		_scene.add_child(_embers)
		_lantern_y = _lantern.position.y
		_lit_y = _lit.position.y
	var fade := _SideFade.new()  # bandes sombres en haut et en bas pour le texte
	fade.size = Vector2(1920, 1080)
	root.add_child(fade)

	# Haut : retour discret, nom gravé, bourses.
	var back := ScreenPack.button(root, S, "return", "← Port", Rect2(28, 24, 190, 72), 26)
	back.pressed.connect(func() -> void:
		if busy:
			return
		ui_sound.emit("ui_click")
		closed.emit())
	var title := ScreenPack.text(root, String(GameData.summon.get("name", "Lanterne des Serments")).to_upper(),
		Rect2(560, 18, 800, 60), 40, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	for i in CURRENCIES.size():
		var c: Array = CURRENCIES[i]
		var r := Rect2(1500 + i * 200, 24, 186, 72)
		ScreenPack.panel(root, S, "currency_cartouche", r)
		ScreenPack.image(root, ScreenPack.tex(S, c[1]), Rect2(r.position + Vector2(18, 16), Vector2(40, 40)))
		_balance[c[0]] = ScreenPack.text(root, "", Rect2(r.position + Vector2(58, 0), Vector2(110, 72)),
			30, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# Droite : la bannière de l'autel, une page par rareté (flèches pour changer) : taux de la rareté,
	# chance par héros, médaillons (survol = fiche), puis événement et garantie.
	var banner := _Banner.new()
	banner.position = Vector2(1586, 120)
	banner.size = Vector2(310, 760)
	root.add_child(banner)
	ScreenPack.text(banner, "HÉROS DE L'AUTEL", Rect2(0, 22, 310, 34), 22, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER)
	for dir: int in [-1, 1]:
		var arrow := _Arrow.new()
		arrow.dir = dir
		arrow.position = Vector2(22 if dir < 0 else 248, 76)
		arrow.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_turn_page(dir))
		banner.add_child(arrow)
	_page_title = ScreenPack.text(banner, "", Rect2(70, 76, 170, 40), 28, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_page_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_page_title.add_theme_constant_override("shadow_offset_y", 3)
	_odds = ScreenPack.text(banner, "", Rect2(20, 120, 270, 70), 20, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(31, 214)
	banner.add_child(grid)
	_event = ScreenPack.text(banner, "", Rect2(24, 480, 262, 56), 18, Color("ffb070"), HORIZONTAL_ALIGNMENT_CENTER, true)
	_pity = ScreenPack.text(banner, "", Rect2(24, 540, 262, 56), 19, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER, true)
	ScreenPack.text(banner, "Un doublon devient un Écho.", Rect2(24, 600, 262, 30), 17, UiKit.PARCHMENT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	_pool_box = grid
	_hover = _HoverCard.new()
	_hover.visible = false
	_hover.z_index = 10
	root.add_child(_hover)

	# Bas : les deux boutons d'invocation, sous la lanterne.
	for i in CURRENCIES.size():
		var c: Array = CURRENCIES[i]
		var key := "fragments" if c[0] == "fragments_relique" else "gems"
		var b := ScreenPack.button(root, S, "invoke_" + key, "", Rect2(540 + i * 440, 968, 400, 88), 28,
			UiKit.INK if key == "fragments" else UiKit.WHITE)
		var currency: String = c[0]
		b.pressed.connect(func() -> void: _summon(currency))
		_buttons[currency] = b

	_build_reveal(root, L.reveal)
	PlayerData.changed.connect(_refresh)


## Vie de la salle : la lanterne flotte doucement et les boutons d'invocation disponibles brillent.
func _process(delta: float) -> void:
	_time += delta
	var bob := sin(_time * 1.6) * 6.0 if not busy else 0.0
	if _lantern:
		_lantern.position.y = _lantern_y + bob
		_lit.position.y = _lit_y + bob
	for currency: String in _buttons:
		var b: Button = _buttons[currency]
		var g := 1.0 + (0.12 + 0.12 * sin(_time * 3.0)) * (0.0 if b.disabled else 1.0)
		b.modulate = Color(g, g, g)


## Ambiance (coordonnées de la salle) : derrière, une lueur qui respire et des runes qui
## s'allument tour à tour sur le cercle du sol ; devant (`front`), des braises qui montent.
class _Ambient extends Control:
	const FLOOR := Vector2(578, 509)
	var CENTER := _l(Vector2(575, 330))
	var GLASS := _l(Vector2(580, 350))
	var k := SummonAltar.LANTERN_SCALE

	static func _l(p: Vector2) -> Vector2:
		return SummonAltar.LANTERN_AT + (p - SummonAltar.LANTERN_FOOT) * SummonAltar.LANTERN_SCALE
	var front := false
	var t := 0.0
	var motes: Array = []  # [x, y, vitesse, phase, couleur]
	var rng := RandomNumberGenerator.new()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		rng.seed = 7
		if front:
			for i in 90:
				motes.append(_mote(rng.randf_range(0, size.y)))

	func _mote(y: float) -> Array:
		var near := rng.randf() < 0.6
		var x := FLOOR.x + rng.randf_range(-200, 200) if near else rng.randf_range(0, size.x)
		var col := Color("ffd27a") if rng.randf() < 0.7 else Color("c9a0ff")
		return [x, y, rng.randf_range(10, 28), rng.randf() * TAU, col]

	func _process(delta: float) -> void:
		t += delta
		for m: Array in motes:
			m[1] -= m[2] * delta
			m[0] += sin(t * 1.3 + m[3]) * 6.0 * delta
			if m[1] < -10:
				m.assign(_mote(size.y + 10))
		queue_redraw()

	func _draw() -> void:
		if front:
			# Une lumière attend dans le verre de la lanterne, elle palpite doucement.
			var pulse := 0.5 + 0.5 * sin(t * 2.0)
			for i in 6:
				var k := 1.0 - i / 6.0
				draw_set_transform(GLASS + Vector2(0, sin(t * 1.6) * 3.6 * k), 0.0, Vector2(0.6, 1.0) * k)
				draw_circle(Vector2.ZERO, 20.0 + i * 14.0, Color(1.0, 0.72, 0.35, (0.05 + 0.04 * pulse) * k))
			draw_set_transform(Vector2.ZERO)
			for m: Array in motes:
				var a := 0.55 + 0.45 * sin(t * 2.5 + m[3])
				var fade := clampf(m[1] / size.y * 1.6, 0.0, 1.0)
				var c: Color = m[4]
				var big := 4.0 if int(m[3] * 10) % 3 == 0 else 3.0
				draw_rect(Rect2(Vector2(m[0], m[1]).floor(), Vector2(big, big)), Color(c, a * fade))
			return
		# Lueur douce derrière la lanterne (cercles empilés, en pixels).
		var breathe := 0.5 + 0.5 * sin(t * 1.4)
		for i in 10:
			var r := (70.0 + i * 22.0 + breathe * 10.0) * k
			draw_circle(CENTER, r, Color(1.0, 0.7, 0.3, 0.1 * (1.0 - i / 10.0) * (0.7 + 0.3 * breathe)))
		# Runes du cercle au sol : une vague de lumière qui tourne.
		for i in 16:
			var ang := i * TAU / 16.0
			var p := FLOOR + Vector2(cos(ang) * 195.0, sin(ang) * 37.0)
			var wave := pow(0.5 + 0.5 * cos(ang - t * 1.2), 6.0)
			draw_rect(Rect2(p.floor() - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.85, 0.45, 0.1 + 0.9 * wave))
			if wave > 0.5:
				draw_circle(p, 14.0, Color(1.0, 0.75, 0.35, 0.3 * wave))


## Fondu des bords de la salle vers les côtés assombris, et des bandes haut / bas pour le texte.
class _SideFade extends Control:

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dark := Color(0.09, 0.08, 0.11)
		for i in 20:
			draw_rect(Rect2(0, i * 6, 1920, 6), Color(dark, 0.55 * (1.0 - i / 20.0)))
			draw_rect(Rect2(0, 1080 - (i + 1) * 7, 1920, 7), Color(dark, 0.6 * (1.0 - i / 20.0)))


## Flèche de laiton (triangle pixel) pour tourner les pages de la bannière.
class _Arrow extends Control:
	signal pressed
	var dir := 1
	var _hot := false

	func _ready() -> void:
		size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: _hot = true; queue_redraw())
		mouse_exited.connect(func() -> void: _hot = false; queue_redraw())
		gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				pressed.emit())

	func _draw() -> void:
		var tip := 34.0 if dir > 0 else 6.0
		var back := 10.0 if dir > 0 else 30.0
		var pts := PackedVector2Array([Vector2(back, 4), Vector2(tip, 20), Vector2(back, 36)])
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(3, 3))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.5))
		draw_colored_polygon(pts, Color("f3d9a0") if _hot else Color("c6a66c"))
		pts.append(pts[0])
		draw_polyline(pts, Color("29262e"), 2.0)


## Bannière de tissu bordeaux (comme celles de la salle), pointe en bas, liserés dorés.
class _Banner extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(-14, -8, s.x + 28, 14), Color("c6a66c"))
		draw_rect(Rect2(-14, -2, s.x + 28, 4), Color("8a6a3a"))
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y - 60),
			Vector2(s.x / 2.0, s.y), Vector2(0, s.y - 60)])
		var shadow := PackedVector2Array()
		for q in pts:
			shadow.append(q + Vector2(6, 8))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, Color("4a1f2b"))
		var inner := PackedVector2Array([Vector2(10, 6), Vector2(s.x - 10, 6), Vector2(s.x - 10, s.y - 66),
			Vector2(s.x / 2.0, s.y - 14), Vector2(10, s.y - 66)])
		draw_colored_polygon(inner, Color("6b2c3c"))
		inner.append(inner[0])
		draw_polyline(inner, Color("c6a66c"), 3.0)
		draw_rect(Rect2(30, 62, s.x - 60, 2), Color("c6a66c"))


## Fiche qui apparaît à côté d'un médaillon survolé.
class _HoverCard extends Control:
	var lines: Array = []  # [texte, taille, couleur]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(300, 10)

	func show_at(p: Vector2, l: Array) -> void:
		lines = l
		var h := 24.0
		for x: Array in l:
			h += x[1] * 1.35
		size.y = h
		position = (p - Vector2(size.x + 24, size.y / 2.0)).round()
		position.y = clampf(position.y, 10, 1070 - size.y)
		visible = true
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2(5, 6), size), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color("29262e"))
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("c6a66c"), false, 2.0)
		var y := 12.0
		for l: Array in lines:
			y += l[1]
			draw_string(UiKit.FONT, Vector2(18, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, l[1], l[2])
			y += l[1] * 0.35


func _anim(name: String, anchor: Array) -> Anim:
	var a := Anim.new(S, name)
	a.position = Vector2(anchor[0], anchor[1])
	_scene.add_child(a)
	return a


## Révélation sans panneau : le héros apparaît debout au centre du cercle, son nom et sa rareté
## au-dessus, ce qu'il apporte en dessous. Un clic le renvoie (il s'efface).
func _build_reveal(root: Control, _R: Dictionary) -> void:
	_reveal = Control.new()
	_reveal.size = Vector2(1920, 1080)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and not busy:
			_hide_reveal())
	root.add_child(_reveal)
	_hero_shadow = _HeroShadow.new()
	_hero_shadow.position = HERO_FEET
	if _mage_room:
		_reveal.position = _mage_room.hero_feet - HERO_FEET  # toute la révélation suit le cercle du mage
	_reveal.add_child(_hero_shadow)
	_reveal_name = ScreenPack.shadow(ScreenPack.text(_reveal, "", Rect2(460, 130, 1000, 100), 76, UiKit.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER), 5)
	_reveal_rarity = Panel.new()
	_reveal_rarity_label = ScreenPack.shadow(ScreenPack.text(_reveal, "", Rect2(660, 230, 600, 44), 30, UiKit.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER))
	_reveal_trap = ScreenPack.text(_reveal, "", Rect2(460, 800, 1000, 80), 28, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER, true)
	_reveal_trap.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_reveal_trap.add_theme_constant_override("shadow_offset_y", 3)
	ScreenPack.shadow(ScreenPack.text(_reveal, "Touche pour continuer", Rect2(660, 860, 600, 34), 22, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER), 2)
	_reveal.visible = false


## Ombre et halo de rareté sous les pieds du héros invoqué.
class _HeroShadow extends Control:
	var color := Color.WHITE
	var t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 2.5)
		for i in 5:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, 90.0 + i * 26.0 + pulse * 8.0, Color(color, 0.16 * (1.0 - i / 5.0)))
		draw_circle(Vector2.ZERO, 70.0, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO)


func open() -> void:
	visible = true
	_reset_scene()
	_reveal.visible = false
	_refresh()


func _reset_scene() -> void:
	if _mage_room:
		_mage_room.reset()
		return
	for a: Anim in [_lit, _burst] + _columns.values():
		a.stop()
	_lantern.texture = ScreenPack.tex(S, "lanterne")
	_lantern.visible = true
	_sparks.loop = true
	_sparks.play()


func _hide_reveal() -> void:
	var tw := create_tween()
	tw.tween_property(_reveal, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		_reveal.visible = false
		if _hero_player:
			_hero_player.queue_free()
			_hero_player = null)
	_reset_scene()
	_refresh()


func _summon(currency: String) -> void:
	if busy:
		return
	var cfg: Dictionary = GameData.summon
	if not PlayerData.can_summon(currency, cfg):
		ui_sound.emit("ui_toggle")
		return
	busy = true  # avant summon() : son signal « changed » ne doit pas montrer le résultat
	var r := PlayerData.summon(currency, cfg, GameData.heroes, _rng)
	if r.is_empty():
		busy = false
		return
	_reveal.visible = false
	_set_buttons_enabled(false)
	ui_sound.emit("magic_cast")
	var hero := GameData.hero(r.id)
	await _ceremony(int(r.rarity))
	ui_sound.emit("ultimate_impact")
	_show_result(hero, r)
	busy = false
	_refresh()


## Chronologie du JSON : allumage à 0, colonne à 0,8 s, éclat à 1,7 s, révélation à 2,35 s.
func _ceremony(rarity: int) -> void:
	if _mage_room:
		await _mage_room.ceremony(rarity)
		return
	_flame.set_shader_parameter("flame", FLAME.get(rarity, Color.WHITE))
	_flame.set_shader_parameter("amount", 1.0 if FLAME.has(rarity) else 0.0)
	_lantern.visible = false
	_lit.play()
	await get_tree().create_timer(0.8).timeout
	_lantern.texture = ScreenPack.tex(S, "lanterne_allumee")
	_lantern.visible = true
	var col: Anim = _columns[RARITY_KEYS.get(rarity, "rare")]
	col.play()
	await get_tree().create_timer(0.9).timeout
	_burst.play()
	await get_tree().create_timer(0.65).timeout


func _show_result(hero: Dictionary, r: Dictionary) -> void:
	var rarity := int(r.rarity)
	var key: String = RARITY_KEYS.get(rarity, "rare")
	_reveal_name.text = String(hero.name).to_upper()
	var rc: Color = (Palette.RARITIES.get(rarity, ["?", Color.WHITE])[1] as Color).lightened(0.25)
	_reveal_name.add_theme_color_override("font_color", rc)
	_reveal_rarity_label.add_theme_color_override("font_color", rc)
	_reveal_rarity_label.text = String(Palette.RARITIES.get(rarity, ["?"])[0]).to_upper()
	var lines: Array[String] = []
	if not r.new:
		lines.append("Déjà recruté : +1 Écho (%d)" % r.echoes)
	var traps: Array = r.get("traps", [])
	if not traps.is_empty():
		lines.append("+ Piège pour ton donjon : " + ", ".join(traps.map(func(t: String) -> String:
			return String(GameData.lodge.traps[t].name))))
	if lines.is_empty():
		lines.append("Nouveau héros ! Il t'attend dans la Loge.")
	_reveal_trap.text = "\n".join(lines)
	_reveal_trap.add_theme_font_size_override("font_size", 28 if lines.size() == 1 else 22)
	var rcol: Color = Palette.RARITIES.get(rarity, ["?", Color.WHITE])[1]
	(_hero_shadow as _HeroShadow).color = rcol.lightened(0.2)
	if _hero_player:
		_hero_player.queue_free()
	var id := String(hero.id)
	_hero_player = ClipPlayer.new()
	_hero_player.bundle = String(hero.get("anim", "res://assets/anim/heroes/"))
	_hero_player.idle_clip = id + "_idle"
	_hero_player.position = HERO_FEET
	_reveal.add_child(_hero_player)
	_reveal.move_child(_hero_player, 1)
	_hero_player.play(id + "_idle")
	var h := maxf(1.0, _hero_player.actor_rect(id + "_idle").size.y)
	var sc := _hero_height / h
	_hero_player.scale = Vector2(sc, sc) * 0.2
	_hero_player.flash(Color.WHITE, 1.0)
	create_tween().tween_property(_hero_player, "scale", Vector2(sc, sc), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal.visible = true
	ScreenPack.fit_all(_reveal)
	_reveal.modulate.a = 0.0
	create_tween().tween_property(_reveal, "modulate:a", 1.0, 0.2)
	if _hero_player.has_clip(id + "_relic"):
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(_hero_player) and _hero_player.has_clip(id + "_relic"):
				_hero_player.play(id + "_relic"))


func _refresh() -> void:
	if not is_inside_tree() or busy:
		return  # pendant la cérémonie, rien ne doit trahir le résultat
	var cfg: Dictionary = GameData.summon
	for c: Array in CURRENCIES:
		var currency: String = c[0]
		_balance[currency].text = str(PlayerData.summon_balance(currency))
		var info: Dictionary = cfg.get("currencies", {}).get(currency, {})
		_buttons[currency].text = "Invoquer · %d %s" % [int(info.get("cost", 0)), c[2]]
	_set_buttons_enabled(true)
	# Événement (optionnel, data/summon.json "event" : {"name", "text"}).
	var ev: Dictionary = cfg.get("event", {})
	_event.text = ("%s · %s" % [ev.get("name", ""), ev.get("text", "")]) if not ev.is_empty() else ""
	var left := PlayerData.summons_to_pity(cfg)
	_pity.text = "Légendaire garanti dans %d invocation%s." % [left, "s" if left > 1 else ""]
	for c in _pool_box.get_children():
		c.queue_free()
	_show_page()


## Raretés qui ont au moins un héros à l'autel, de la plus rare à la plus commune.
func _rarities() -> Array:
	var odds := Summon.odds(GameData.heroes, GameData.summon)
	var keys: Array = odds.keys().filter(func(r: int) -> bool: return float(odds[r]) > 0.0)
	keys.sort()
	keys.reverse()
	return keys


func _turn_page(dir: int) -> void:
	var keys := _rarities()
	if keys.is_empty():
		return
	var i := keys.find(_page)
	_page = keys[posmod(i + dir, keys.size())]
	_show_page()


## Remplit la bannière avec la page de la rareté `_page`.
func _show_page() -> void:
	var keys := _rarities()
	if not keys.has(_page) and not keys.is_empty():
		_page = keys[0]
	var r: Array = Palette.RARITIES.get(_page, ["?", Color.WHITE])
	_page_title.text = String(r[0])
	_page_title.add_theme_color_override("font_color", (r[1] as Color).lightened(0.25))
	var heroes: Array = GameData.heroes.keys().filter(func(id: String) -> bool:
		return int(GameData.heroes[id].get("rarity", 2)) == _page)
	var rate := float(Summon.odds(GameData.heroes, GameData.summon).get(_page, 0.0))
	_odds.text = "Taux : %.0f %%
Chaque héros : %.1f %%" % [rate, rate / maxf(1.0, heroes.size())]
	for c in _pool_box.get_children():
		c.queue_free()
	for id: String in heroes:
		_pool_box.add_child(_pool_row(GameData.hero(id)))


func _pool_row(hero: Dictionary) -> Control:
	var owned := PlayerData.owned_heroes().has(hero.id)
	var rarity := int(hero.get("rarity", 2))
	var m := Control.new()
	m.custom_minimum_size = Vector2(72, 72)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	var portrait := RoundPortrait.new().setup(hero, 72, 0.1)
	portrait.size = Vector2(72, 72)
	portrait.pivot_offset = Vector2(36, 36)
	portrait.set_grey(not owned)
	m.add_child(portrait)
	m.mouse_entered.connect(func() -> void:
		portrait.scale = Vector2(1.12, 1.12)
		_hover.show_at(m.get_global_rect().position - _hover.get_parent().get_global_rect().position + Vector2(0, 34),
			_hero_info(hero, owned, rarity)))
	m.mouse_exited.connect(func() -> void:
		portrait.scale = Vector2.ONE
		_hover.visible = false)
	return m


## Lignes de la fiche de survol : nom, rareté, classe, état, Échos, chance d'obtention.
func _hero_info(hero: Dictionary, owned: bool, rarity: int) -> Array:
	var r: Array = Palette.RARITIES.get(rarity, ["?", Color.WHITE])
	var info: Array = [[String(hero.name), 28, UiKit.WHITE], [String(r[0]), 21, (r[1] as Color).lightened(0.2)],
		["%s · %s" % [Palette.CLASS_NAMES.get(hero.get("class"), ""), Palette.ELEMENT_NAMES.get(hero.get("element"), "")],
			20, UiKit.PARCHMENT_DARK]]
	if owned:
		var echoes := PlayerData.hero_echoes(hero.id)
		info.append(["Réveillé · %d Écho%s" % [echoes, "s" if echoes > 1 else ""], 20, Color("9fe0b0")])
		info.append(["Niveau %d" % PlayerData.hero_level(hero.id), 20, UiKit.PARCHMENT_DARK])
	else:
		info.append(["Endormi : à réveiller ici", 20, Color("b0a8c0")])
	info.append(["Chance : %.1f %%" % _hero_chance(hero), 20, Color("f3d9a0")])
	return info


## Chance d'obtenir ce héros précis à une invocation (taux de sa rareté partagé entre ses pairs).
func _hero_chance(hero: Dictionary) -> float:
	var odds := Summon.odds(GameData.heroes, GameData.summon)
	var r := int(hero.get("rarity", 2))
	var peers := 0
	for h: Dictionary in GameData.heroes.values():
		if int(h.get("rarity", 2)) == r:
			peers += 1
	return float(odds.get(r, 0.0)) / maxf(1.0, peers)


func _set_buttons_enabled(on: bool) -> void:
	for currency: String in _buttons:
		_buttons[currency].disabled = not on or not PlayerData.can_summon(currency, GameData.summon)
