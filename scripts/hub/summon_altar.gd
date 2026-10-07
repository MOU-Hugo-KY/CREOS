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
	bg.color = Color("2a2530")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := ScreenPack.frame(self)

	# Salle centrale : fond, lanterne, effets.
	var sr := ScreenPack.rect(L.central_scene_rect)
	_scene = Control.new()
	_scene.position = sr.position
	_scene.size = sr.size
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
	for k: String in ["rare", "epic", "legendary"]:
		_columns[k] = _anim("colonne_" + k, L.column_anchor_in_scene)
	_burst = _anim("eclat_final", L.final_anchor_in_scene)

	# En-tête : retour, titre, soldes.
	var back := ScreenPack.button(root, S, "return", "Retour au port", ScreenPack.rect(L.return_rect), 28)
	back.pressed.connect(func() -> void:
		if busy:
			return
		ui_sound.emit("ui_click")
		closed.emit())
	var tr := ScreenPack.rect(L.title_rect)
	ScreenPack.image(root, ScreenPack.tex(S, "title"), tr)
	ScreenPack.text(root, String(GameData.summon.get("name", "Lanterne des Serments")).to_upper(), tr, 36,
		UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for i in CURRENCIES.size():
		var c: Array = CURRENCIES[i]
		var r := ScreenPack.rect(L.currency_rects[i])
		ScreenPack.panel(root, S, "currency_cartouche", r)
		ScreenPack.image(root, ScreenPack.tex(S, c[1]), Rect2(r.position + Vector2(22, 18), Vector2(40, 40)))
		_balance[c[0]] = ScreenPack.text(root, "", Rect2(r.position + Vector2(60, 0), r.size - Vector2(80, 0)),
			32, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	# Gauche : explications, taux, garantie.
	var ir := ScreenPack.rect(L.infos_rect)
	ScreenPack.panel(root, S, "infos_panel", ir)
	var info := ScreenPack.text(root, "Réveille un chasseur.\nPrête serment sous la grande lanterne. Un doublon devient un Écho et renforce ton héros.",
		Rect2(ir.position + Vector2(34, 36), Vector2(ir.size.x - 64, 240)), 24, UiKit.INK, 0, true)
	_odds = ScreenPack.text(root, "", Rect2(ir.position + Vector2(34, 320), Vector2(ir.size.x - 64, 200)), 26, UiKit.INK, 0, true)
	_pity = ScreenPack.text(root, "", Rect2(ir.position + Vector2(34, 540), Vector2(ir.size.x - 64, 90)), 24, UiKit.WOOD, 0, true)
	var tip := ScreenPack.text(root, "Les fragments se gagnent en chasse et chez le Marchand.",
		Rect2(ir.position + Vector2(34, 660), Vector2(ir.size.x - 64, 120)), 22, UiKit.TEXT_SOFT, 0, true)

	# Droite : les héros de l'autel (liste qui défile).
	var hr := ScreenPack.rect(L.heroes_rect)
	ScreenPack.panel(root, S, "heroes_panel", hr)
	ScreenPack.text(root, "HÉROS DE L'AUTEL", Rect2(hr.position + Vector2(24, 8), Vector2(hr.size.x - 40, 44)), 26)
	var scroll := ScrollContainer.new()
	var first: Array = L.hero_rows[0]
	scroll.position = Vector2(first[0], first[1])
	scroll.size = Vector2(first[2] + 8, hr.end.y - first[1] - 30)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	_pool_box = VBoxContainer.new()
	_pool_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_pool_box)

	# Boutons d'invocation.
	var ib: Dictionary = L.invocation_buttons
	for c: Array in CURRENCIES:
		var key := "fragments" if c[0] == "fragments_relique" else "gems"
		var b := ScreenPack.button(root, S, "invoke_" + key, "", ScreenPack.rect(ib[key]), 30, UiKit.INK if key == "fragments" else UiKit.WHITE)
		var currency: String = c[0]
		b.pressed.connect(func() -> void: _summon(currency))
		_buttons[currency] = b

	_build_reveal(root, L.reveal)
	PlayerData.changed.connect(_refresh)


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
	var lines := ["Taux d'invocation"]
	for r: int in keys:
		lines.append("%s  %.0f %%" % [Palette.RARITIES.get(r, ["?"])[0], odds[r]])
	_odds.text = "\n".join(lines)
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
	var row := Panel.new()
	row.custom_minimum_size = Vector2(292, 96)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", ScreenPack.nine(S, "hero_row"))
	var portrait := RoundPortrait.new().setup(hero, 64)
	portrait.position = Vector2(14, 16)
	portrait.size = Vector2(64, 64)
	portrait.set_grey(not owned)
	row.add_child(portrait)
	ScreenPack.text(row, hero.name, Rect2(90, 12, 196, 38), 26)
	var status := "Réveillé" if owned else "Endormi"
	var echoes := PlayerData.hero_echoes(hero.id)
	if echoes > 0:
		status = "%d Écho%s" % [echoes, "s" if echoes > 1 else ""]
	var rarity: String = Palette.RARITIES.get(int(hero.get("rarity", 1)), ["?"])[0]
	ScreenPack.text(row, "%s · %s" % [rarity, status], Rect2(90, 48, 196, 32), 19, UiKit.TEXT_SOFT)
	return row


func _set_buttons_enabled(on: bool) -> void:
	for currency: String in _buttons:
		_buttons[currency].disabled = not on or not PlayerData.can_summon(currency, GameData.summon)
