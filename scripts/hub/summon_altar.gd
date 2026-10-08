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
var _balance: Dictionary = {}  # monnaie -> Label
var _buttons: Dictionary = {}  # monnaie -> Button
var _odds: Label
var _pity: Label
var _rows: Array[Control] = []
var _pool_box: Control
var _event: Label
var _hover: Control
var _reveal: Control
var _reveal_preview: HeroPreview
var _reveal_name: Label
var _reveal_rarity: Panel
var _reveal_rarity_label: Label
var _reveal_trap: Label
var _reveal_trap_box: Panel
var _rng := RandomNumberGenerator.new()

const Anim := ScreenPack.Anim


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

	# La salle prend tout l'écran : une copie assombrie remplit les côtés, la salle nette au centre.
	var sr := ScreenPack.rect(L.central_scene_rect)
	var k := 1080.0 / sr.size.y
	var wide := ScreenPack.image(root, ScreenPack.tex(S, "fond"), Rect2(Vector2(0, -260), Vector2(1920, 1436)))
	wide.modulate = Color(0.32, 0.29, 0.36)
	_scene = Control.new()
	_scene.size = sr.size
	_scene.scale = Vector2(k, k)
	_scene.position = Vector2(round((1920.0 - sr.size.x * k) / 2.0), 0)
	_scene.clip_contents = true
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_scene)
	ScreenPack.image(_scene, ScreenPack.tex(S, "fond"), Rect2(Vector2.ZERO, sr.size))
	_sparks = _anim("particules", L.particles_anchor_in_scene)
	_lantern = ScreenPack.image(_scene, ScreenPack.tex(S, "lanterne"), ScreenPack.rect(L.lantern_sprite_rect_in_scene))
	_lit = _anim("lanterne_allumage", L.lantern_anchor_in_scene)
	_flame = ShaderMaterial.new()
	_flame.shader = Shader.new()
	_flame.shader.code = FLAME_SHADER
	_lit.material = _flame
	_lantern.material = _flame
	for c: String in ["rare", "epic", "legendary"]:
		_columns[c] = _anim("colonne_" + c, L.column_anchor_in_scene)
	_burst = _anim("eclat_final", L.final_anchor_in_scene)
	var fade := _SideFade.new()  # fondu entre la salle et ses bords assombris
	fade.inner = Rect2(_scene.position, sr.size * k)
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

	# Gauche : le tableau d'affichage accroché au mur (taux, garantie, événement).
	var board := _Board.new()
	board.position = Vector2(34, 190)
	board.size = Vector2(300, 520)
	root.add_child(board)
	ScreenPack.text(board, "SERMENTS", Rect2(0, 40, 300, 40), 28, UiKit.WOOD, HORIZONTAL_ALIGNMENT_CENTER)
	_event = ScreenPack.text(board, "", Rect2(30, 88, 240, 64), 20, Color("8a3a20"), HORIZONTAL_ALIGNMENT_CENTER, true)
	_odds = ScreenPack.text(board, "", Rect2(36, 160, 228, 160), 25, UiKit.INK, 0, true)
	_pity = ScreenPack.text(board, "", Rect2(36, 330, 228, 80), 21, UiKit.WOOD, 0, true)
	ScreenPack.text(board, "Un doublon devient un Écho.", Rect2(36, 420, 228, 60), 19, UiKit.TEXT_SOFT, 0, true)

	# Droite : les héros de l'autel en médaillons ; survoler un médaillon montre sa fiche.
	var banner := _Banner.new()
	banner.position = Vector2(1606, 128)
	banner.size = Vector2(280, 660)
	root.add_child(banner)
	ScreenPack.text(banner, "HÉROS DE L'AUTEL", Rect2(0, 22, 280, 34), 22, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2(26, 76)
	banner.add_child(grid)
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


## Fondu des bords de la salle vers les côtés assombris, et des bandes haut / bas pour le texte.
class _SideFade extends Control:
	var inner := Rect2()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dark := Color(0.09, 0.08, 0.11)
		for side in [0, 1]:
			for i in 24:
				var x: float = inner.position.x + i * 6.0 if side == 0 else inner.end.x - (i + 1) * 6.0
				draw_rect(Rect2(x, 0, 6, 1080), Color(dark, 0.6 * (1.0 - i / 24.0)))
		for i in 20:
			draw_rect(Rect2(0, i * 6, 1920, 6), Color(dark, 0.55 * (1.0 - i / 20.0)))
			draw_rect(Rect2(0, 1080 - (i + 1) * 7, 1920, 7), Color(dark, 0.6 * (1.0 - i / 20.0)))


## Tableau d'affichage pendu par deux chaînes : cadre de bois, coins de laiton, parchemin clouté.
class _Board extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		for x in [60.0, s.x - 60.0]:
			for y in range(-56, 0, 14):
				draw_rect(Rect2(x - 4, y, 8, 10), Color("6b5636"))
				draw_rect(Rect2(x - 2, y + 2, 4, 6), Color("2a2218"))
		draw_rect(Rect2(6, 8, s.x, s.y), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2.ZERO, s), Color("2e1d16"))
		draw_rect(Rect2(6, 6, s.x - 12, s.y - 12), Color("5a3a28"))
		for i in range(12, int(s.y) - 12, 18):
			draw_rect(Rect2(8, i, s.x - 16, 2), Color("4a2f22"))
		var p := Rect2(22, 24, s.x - 44, s.y - 48)
		draw_rect(p, Color("d9c9a3"))
		draw_rect(p.grow(-4), Color("eee4cd"))
		draw_rect(Rect2(p.position.x, p.end.y - 6, p.size.x, 6), Color("c9b68c"))
		for c in [Vector2(0, 0), Vector2(s.x - 22, 0), Vector2(0, s.y - 22), Vector2(s.x - 22, s.y - 22)]:
			draw_rect(Rect2(c, Vector2(22, 22)), Color("c6a66c"))
			draw_rect(Rect2(c + Vector2(4, 4), Vector2(14, 14)), Color("8a6a3a"))
		for n in [Vector2(40, 40), Vector2(s.x - 40, 40), Vector2(40, s.y - 40), Vector2(s.x - 40, s.y - 40)]:
			draw_rect(Rect2(n - Vector2(4, 4), Vector2(8, 8)), Color("6b5636"))
			draw_rect(Rect2(n - Vector2(2, 2), Vector2(3, 3)), Color("e6cf94"))


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


func _build_reveal(root: Control, R: Dictionary) -> void:
	_reveal = Control.new()
	_reveal.size = Vector2(1920, 1080)
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP  # un clic referme la révélation
	_reveal.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and not busy:
			_hide_reveal())
	root.add_child(_reveal)
	var pr := ScreenPack.rect(R.rect)
	ScreenPack.panel(_reveal, S, "reveal_panel", pr)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.position = pr.position + Vector2(60, 60)
	vpc.size = Vector2(pr.size.x - 120, R.name_rect[1] - pr.position.y - 70)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(vpc)
	_reveal_preview = HeroPreview.new()
	_reveal_preview.pedestal = false
	vpc.add_child(_reveal_preview)
	var nr := ScreenPack.rect(R.name_rect)
	ScreenPack.panel(_reveal, S, "reveal_name", nr)
	_reveal_name = ScreenPack.text(_reveal, "", nr, 40, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var rr := ScreenPack.rect(R.rarity_rect)
	_reveal_rarity = ScreenPack.panel(_reveal, S, "reveal_badge_rare", rr)
	_reveal_rarity_label = ScreenPack.text(_reveal, "", rr, 26, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var tr := ScreenPack.rect(R.trap_rect)
	_reveal_trap_box = ScreenPack.panel(_reveal, S, "reveal_trap", tr)
	_reveal_trap = ScreenPack.text(_reveal, "", tr, 28, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_reveal.visible = false


func open() -> void:
	visible = true
	_reset_scene()
	_reveal.visible = false
	_refresh()


func _reset_scene() -> void:
	for a: Anim in [_lit, _burst] + _columns.values():
		a.stop()
	_lantern.texture = ScreenPack.tex(S, "lanterne")
	_lantern.visible = true
	_sparks.loop = true
	_sparks.play()


func _hide_reveal() -> void:
	_reveal.visible = false
	_reveal_preview.clear_hero()
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
	_reveal_rarity.add_theme_stylebox_override("panel", ScreenPack.nine(S, "reveal_badge_" + key))
	_reveal_rarity_label.text = Palette.RARITIES.get(rarity, ["?"])[0]
	var lines: Array[String] = []
	if not r.new:
		lines.append("Déjà recruté : +1 Écho (%d)" % r.echoes)
	var traps: Array = r.get("traps", [])
	if not traps.is_empty():
		lines.append("+ Piège pour ta Loge : " + ", ".join(traps.map(func(t: String) -> String:
			return String(GameData.lodge.traps[t].name))))
	if lines.is_empty():
		lines.append("Nouveau héros ! Il t'attend dans la Loge.")
	_reveal_trap.text = "\n".join(lines)
	_reveal_trap.add_theme_font_size_override("font_size", 28 if lines.size() == 1 else 22)
	_reveal.visible = true
	ScreenPack.fit_all(_reveal)
	_reveal_preview.show_hero(hero)
	_reveal.modulate.a = 0.0
	create_tween().tween_property(_reveal, "modulate:a", 1.0, 0.25)


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
	var odds := Summon.odds(GameData.heroes, cfg)
	var keys := odds.keys()
	keys.sort()
	var lines := []
	for r: int in keys:
		lines.append("%s : %.0f %%" % [Palette.RARITIES.get(r, ["?"])[0], odds[r]])
	_odds.text = "\n".join(lines)
	# Événement (optionnel, data/summon.json "event" : {"name", "text"}) : en tête du tableau.
	var ev: Dictionary = cfg.get("event", {})
	_event.text = ("%s\n%s" % [ev.get("name", ""), ev.get("text", "")]) if not ev.is_empty() else "Taux d'invocation"
	var left := PlayerData.summons_to_pity(cfg)
	_pity.text = "Légendaire garanti dans %d invocation%s." % [left, "s" if left > 1 else ""]
	for c in _pool_box.get_children():
		c.queue_free()
	var ids := GameData.heroes.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(GameData.heroes[a].get("rarity", 1)) > int(GameData.heroes[b].get("rarity", 1)))
	for id: String in ids:
		_pool_box.add_child(_pool_row(GameData.hero(id)))


func _pool_row(hero: Dictionary) -> Control:
	var owned := PlayerData.owned_heroes().has(hero.id)
	var rarity := int(hero.get("rarity", 2))
	var m := Control.new()
	m.custom_minimum_size = Vector2(68, 68)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	var portrait := RoundPortrait.new().setup(hero, 68, 0.1)
	portrait.size = Vector2(68, 68)
	portrait.pivot_offset = Vector2(34, 34)
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
