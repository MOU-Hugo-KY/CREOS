class_name HeroesScreen
extends Control
## « Loge des héros » : la collection (cartes filtrables par rôle, héros à recruter grisés) et la
## fiche d'un héros (héros animé, statistiques, Force, amélioration contre de l'or, onglets
## Techniques / Voies / Relique / Échos, place dans l'équipe de chasse). Style de la maquette CREOS : fond
## d'encre, panneaux ivoire cerclés d'encre, bordeaux, laiton et turquoise.

signal closed
signal ui_sound(sfx_name: String)

const ATTACK_ICON_DIR := "res://assets/ui/attacks/"
const BG := Color("19181e")
const CARD := Color("34323c")
const STAT_NAMES := [["hp", "Vie"], ["atk", "Attaque"], ["mag", "Magie"], ["def", "Défense"],
	["spd", "Vitesse"], ["crit", "Critique"], ["heal", "Soins"]]
const TABS := ["Techniques", "Voies", "Relique", "Échos"]
const F := "fiche_heros"
const ELEMENT_KEYS := {"feu": "fire", "eau": "water", "nature": "nature", "lumiere": "light", "ombre": "shadow"}
const CLASS_KEYS := {"gardien": "guardian", "lame": "blade", "arcaniste": "arcanist", "traqueur": "tracker",
	"mystique": "arcanist", "moine": "monk", "lancier": "lancer", "soutien": "support",
	"illusionniste": "illusionist", "automate": "automaton"}
const RARITY_KEYS := {2: "rare", 3: "epic", 4: "legendary"}

var selected := ""
var _filter := ""  # classe affichée ("" = toutes)
var _tab := "Techniques"

var _title: Label
var _count: Label
var _back: Button
var _collection: VBoxContainer
var _filters: HBoxContainer
var _grid: GridContainer
var _team_strip: HBoxContainer
var _page: MarginContainer  # en-tête et collection
var _detail: Control  # fiche d'un héros (pièces du pack)
var _preview: HeroPreview
var _tab_box: Control
var _d_title: Label
var _d_card: TarotCard
var _d_vpc: SubViewportContainer
var _d_count: Label
var _d_room: TextureRect
var _d_socle: TextureRect
var _d_class: TextureRect
var _d_element: TextureRect
var _d_rarity: Panel
var _d_rarity_label: Label
var _d_role: Label
var _d_species: Label
var _d_echoes: Array[TextureRect] = []
var _d_echo_count: Label
var _d_level: Label
var _d_force: Label
var _d_xp: Panel
var _d_xp_text: Label
var _d_recruit: Label
var _d_stats: Array[Label] = []
var _d_bars: Array = []
var _d_upgrade: Button
var _d_team: Button
var _d_tabs: Array[Button] = []
var _path_panel: Panel  # détail d'une voie (ses 5 paliers), par-dessus les statistiques
var _path_title: Label
var _path_lines: Array[Label] = []
var _confirm: UiWindow
var _confirm_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	_page = margin
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)

	# En-tête
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	page.add_child(head)
	_back = UiKit.button("Retour au port", "wood", 22, Vector2(230, 58))
	_back.pressed.connect(_on_back)
	head.add_child(_back)
	_title = UiKit.title("Loge des héros", 44, UiKit.PARCHMENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = UiKit.label("", 24, UiKit.PARCHMENT_DARK)
	head.add_child(_count)

	_build_collection(page)
	_build_detail(page)
	_build_confirm()
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	visible = true
	_show_collection()


func refresh() -> void:
	_count.text = "%d / %d héros" % [PlayerData.owned_heroes().size(), GameData.heroes.size()]
	if _detail.visible:
		_fill_detail()
	else:
		_fill_collection()


# --- Collection ---------------------------------------------------------------------

func _build_collection(page: VBoxContainer) -> void:
	_collection = VBoxContainer.new()
	_collection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection.add_theme_constant_override("separation", 16)
	page.add_child(_collection)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation", 10)
	_collection.add_child(_filters)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(_grid)
	var team_row := HBoxContainer.new()
	team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	team_row.add_theme_constant_override("separation", 18)
	_collection.add_child(team_row)
	team_row.add_child(UiKit.title("Équipe de chasse", 26, UiKit.WOOD_LIGHT))
	_team_strip = HBoxContainer.new()
	_team_strip.add_theme_constant_override("separation", 14)
	team_row.add_child(_team_strip)


func _show_collection() -> void:
	_detail.visible = false
	_page.visible = true
	_collection.visible = true
	_back.text = "Retour au port"
	_title.text = "Loge des héros"
	refresh()


func _fill_collection() -> void:
	for c in _filters.get_children():
		c.queue_free()
	var classes: Array = []
	for id: String in PlayerData.owned_heroes():
		var cl: String = GameData.hero(id).get("class", "")
		if cl not in classes:
			classes.append(cl)
	classes.sort()
	_filters.add_child(_tab_button("Tous", _filter == "", func() -> void: _set_filter("")))
	for cl: String in classes:
		var name := String(Palette.CLASS_NAMES.get(cl, cl)) + "s"
		_filters.add_child(_tab_button(name, _filter == cl, func() -> void: _set_filter(cl)))
	for c in _grid.get_children():
		c.queue_free()
	var ids: Array = PlayerData.owned_heroes()
	for id: String in GameData.heroes:
		if id not in ids:
			ids.append(id)  # les héros à recruter, après ceux qu'on possède
	for id: String in ids:
		var hero := GameData.hero(id)
		if _filter == "" or hero.get("class", "") == _filter:
			_grid.add_child(_hero_card(hero))
	for c in _team_strip.get_children():
		c.queue_free()
	var team := PlayerData.team()
	for i in PlayerData.TEAM_SIZE:
		if i < team.size():
			var p := RoundPortrait.new().setup(GameData.hero(team[i]), 72)
			_team_strip.add_child(p)
		else:
			var empty := Panel.new()
			empty.custom_minimum_size = Vector2(72, 72)
			empty.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.2), 36, 2))
			_team_strip.add_child(empty)


func _set_filter(cl: String) -> void:
	ui_sound.emit("ui_click")
	_filter = cl
	_fill_collection()


func _hero_card(hero: Dictionary) -> Control:
	# Carte de tarot du héros (dos de carte s'il n'est pas recruté), avec niveau et Force dessous.
	var id: String = hero.id
	var owned: bool = PlayerData.state.heroes.has(id)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TarotCard.SIZE.x * CARD_SCALE, TarotCard.SIZE.y * CARD_SCALE + 66)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.set_meta("id", id)
	var card := TarotCard.new().setup(hero, owned)
	card.scale = Vector2.ONE * CARD_SCALE
	card.pivot_offset = Vector2.ZERO
	holder.add_child(card)
	var sub := "À recruter à la Lanterne" if not owned else "Niv. %d · Force %d" % [PlayerData.hero_level(id), _power(id)]
	var rcol: Color = (Palette.RARITIES.get(int(hero.get("rarity", 2)), ["?", Color.WHITE])[1] as Color).lightened(0.3)
	ScreenPack.shadow(ScreenPack.text(holder, String(TarotCard.arcane(id).title) if owned else "", Rect2(0, TarotCard.SIZE.y * CARD_SCALE + 4,
		TarotCard.SIZE.x * CARD_SCALE, 28), 20, rcol, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var info := ScreenPack.shadow(ScreenPack.text(holder, sub, Rect2(0, TarotCard.SIZE.y * CARD_SCALE + 32,
		TarotCard.SIZE.x * CARD_SCALE, 30), 19, UiKit.PARCHMENT_DARK if owned else Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	if PlayerData.in_team(id):
		info.text = "◆ Équipe · " + sub
		info.add_theme_color_override("font_color", Color("63c8be"))
	# Survol : la carte se soulève ; clic : elle se retourne et ouvre la fiche.
	holder.mouse_entered.connect(func() -> void:
		create_tween().tween_property(card, "position:y", -14.0, 0.12)
		card.modulate = Color(1.12, 1.08, 1.0)
		card.shine())
	holder.mouse_exited.connect(func() -> void:
		create_tween().tween_property(card, "position:y", 0.0, 0.12)
		card.modulate = Color.WHITE)
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			ui_sound.emit("ui_click")
			card.pivot_offset = TarotCard.SIZE / 2.0
			card.flip(func() -> void: card.set_face_up(true), 0.24)
			get_tree().create_timer(0.26).timeout.connect(func() -> void: show_hero(id)))
	return holder


## Taille des cartes de la collection.
const CARD_SCALE := 0.62


func _build_detail(_page: VBoxContainer) -> void:
	# Fiche d'un héros façon cartomancienne : la salle d'armes de son élément en fond, sa carte de
	# tarot en grand à gauche (le héros animé dans la fenêtre, flèches pour passer au suivant), et
	# à droite un grimoire ouvert (pack « Arcanes ») : statistiques et actions sur la page de
	# gauche, onglet choisi sur la page de droite, marque-pages sur la tranche. Repère 1920 × 1080.
	_detail = Control.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail.visible = false
	add_child(_detail)
	var root := ScreenPack.frame(_detail)
	_d_room = ScreenPack.image(root, null, Rect2(0, 0, 1920, 1080))
	_d_room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_d_room.modulate = Color(0.55, 0.52, 0.58)
	var shade := _DetailShade.new()
	shade.size = Vector2(1920, 1080)
	root.add_child(shade)
	var back := ScreenPack.button(root, F, "collection", "← Collection", Rect2(24, 20, 260, 80), 28)
	back.pressed.connect(_on_back)
	_d_count = ScreenPack.text(root, "", Rect2(300, 20, 360, 80), 22, Color(1, 1, 1, 0.6))
	# La carte de tarot, en grand ; le héros animé vit dans sa fenêtre.
	_d_card = TarotCard.new()
	_d_card.position = Vector2(147, 70)
	root.add_child(_d_card)
	_d_vpc = SubViewportContainer.new()
	_d_vpc.stretch = true
	_d_vpc.size = TarotCard.WINDOW.size
	_d_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview = HeroPreview.new()
	_preview.pedestal = false
	_preview.zoom = 1.0
	_preview.pull_back = false  # les techniques se jouent en grand dans la carte
	_d_vpc.add_child(_preview)
	for dir: int in [-1, 1]:
		var arrow := SummonAltar._Arrow.new()
		arrow.dir = dir
		arrow.scale = Vector2(1.5, 1.5)
		arrow.position = Vector2(48 if dir < 0 else 570, 360)
		arrow.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_step_hero(dir))
		root.add_child(arrow)
	# Sous la carte : rareté et titre, rôle, Échos, niveau, Force, expérience.
	_d_rarity_label = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(20, 734, 638, 32), 24, UiKit.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER), 2)
	_d_role = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(20, 766, 638, 30), 20, Color("f3d9a0"),
		HORIZONTAL_ALIGNMENT_CENTER), 2)
	for i in 5:
		_d_echoes.append(ScreenPack.image(root, ScreenPack.tex(F, "echo_empty"), Rect2(150 + i * 52, 812, 44, 44)))
	_d_echo_count = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(420, 812, 200, 44), 24, UiKit.WHITE), 2)
	_d_level = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(60, 872, 300, 40), 28, UiKit.WHITE), 2)
	_d_force = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(318, 872, 300, 40), 28, Color("f3d9a0"),
		HORIZONTAL_ALIGNMENT_RIGHT), 2)
	var xp_bg := ScreenPack.panel(root, F, "xp_bg", Rect2(60, 920, XP_W, 18))
	_d_xp = ScreenPack.panel(xp_bg, F, "xp_fill", Rect2(0, 3, XP_W, 12))
	_d_xp_text = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(60, 942, XP_W, 26), 18, UiKit.PARCHMENT_DARK,
		HORIZONTAL_ALIGNMENT_CENTER), 2)
	_d_recruit = ScreenPack.shadow(ScreenPack.text(root, "À recruter à la Lanterne des Serments", Rect2(20, 872, 638, 40), 26,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	# Le grimoire.
	ScreenPack.image(root, TarotCard.pack_tex("grimoire/grimoire.png"), Rect2(BOOK, Vector2(1100, 1000)))
	for i in TABS.size():
		var t: String = TABS[i]
		var b := Button.new()
		b.text = t
		b.focus_mode = Control.FOCUS_NONE
		b.position = BOOK + Vector2(1052, 172 + i * 128)
		b.size = Vector2(160, 64)
		b.add_theme_font_override("font", UiKit.FONT)
		b.add_theme_font_size_override("font_size", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(func() -> void: _set_tab(t))
		root.add_child(b)
		_d_tabs.append(b)
	# Page de gauche : statistiques avec icônes et barres, puis les actions.
	_page_title(root, PAGE_L, "Statistiques")
	for i in STAT_NAMES.size():
		var y := PAGE_L.position.y + 62.0 + i * 54.0
		var key: String = STAT_NAMES[i][0]
		ScreenPack.image(root, TarotCard.pack_tex("icones/stat_%s_32.png" % STAT_ICONS.get(key, "vie")),
			Rect2(PAGE_L.position.x, y + 4, 32, 32))
		ScreenPack.text(root, STAT_NAMES[i][1], Rect2(PAGE_L.position.x + 42, y - 2, 200, 28), 21)
		_d_stats.append(ScreenPack.text(root, "", Rect2(PAGE_L.end.x - 150, y - 2, 150, 28), 21, UiKit.INK,
			HORIZONTAL_ALIGNMENT_RIGHT))
		var bar := _StatBar.new()
		bar.position = Vector2(PAGE_L.position.x + 42, y + 28)
		bar.size = Vector2(PAGE_L.size.x - 42, 12)
		bar.color = STAT_COLORS.get(key, UiKit.WOOD)
		root.add_child(bar)
		_d_bars.append(bar)
	_separator(root, PAGE_L.position.y + 460)
	_d_upgrade = ScreenPack.button(root, F, "upgrade", "", Rect2(PAGE_L.position.x, PAGE_L.position.y + 500, PAGE_L.size.x, 76),
		24, UiKit.INK)
	_d_upgrade.pressed.connect(_ask_level_up)
	_d_team = ScreenPack.button(root, F, "team_button", "", Rect2(PAGE_L.position.x, PAGE_L.position.y + 592, PAGE_L.size.x, 64), 22)
	_d_team.pressed.connect(func() -> void:
		if PlayerData.toggle_team(selected):
			ui_sound.emit("ui_toggle"))
	# Détail d'une voie survolée : recouvre la page de gauche.
	_path_panel = Panel.new()
	var psb := Palette.stylebox(Color("efe3c8"), Color("c6a66c"), 4, 3)
	_path_panel.add_theme_stylebox_override("panel", psb)
	_path_panel.position = PAGE_L.position - Vector2(14, 14)
	_path_panel.size = PAGE_L.size + Vector2(28, 28)
	_path_panel.z_index = 5
	_path_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_path_panel)
	_path_title = ScreenPack.text(_path_panel, "", Rect2(14, 14, PAGE_L.size.x, 64), 22, UiKit.INK, 0, true)
	for k in 5:
		_path_lines.append(ScreenPack.text(_path_panel, "", Rect2(14, 92 + k * 124, PAGE_L.size.x, 116), 18, UiKit.INK, 0, true))
	_path_panel.visible = false
	# Page de droite : le contenu de l'onglet.
	_tab_box = Control.new()
	_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_box.position = PAGE_R.position
	_tab_box.size = PAGE_R.size
	root.add_child(_tab_box)


## Grimoire et ses pages écrivables (arcanes.json : writable_left / writable_right).
const BOOK := Vector2(660, 40)
const PAGE_L := Rect2(768, 168, 384, 728)
const PAGE_R := Rect2(1268, 168, 384, 728)
const XP_W := 558.0
const STAT_ICONS := {"hp": "vie", "atk": "attaque", "mag": "magie", "def": "defense", "spd": "vitesse",
	"crit": "critique", "heal": "soins"}
const STAT_COLORS := {"hp": Color("b9474f"), "atk": Color("d08a3a"), "mag": Color("7d5bd0"), "def": Color("5a7fa8"),
	"spd": Color("4fae8a"), "crit": Color("d9b44a"), "heal": Color("6fc06a")}


## Titre de page du grimoire, avec la frise dessous.
func _page_title(parent: Control, page: Rect2, text: String) -> void:
	ScreenPack.text(parent, text.to_upper(), Rect2(page.position, Vector2(page.size.x, 34)), 26, Color("793b49"),
		HORIZONTAL_ALIGNMENT_CENTER)
	_separator(parent, page.position.y + 36, page.position.x)


func _separator(parent: Control, y: float, x := PAGE_L.position.x) -> void:
	ScreenPack.image(parent, TarotCard.pack_tex("grimoire/separateur_grimoire.png"), Rect2(x - 8, y, PAGE_L.size.x + 16, 16))


## Style d'un marque-page (actif ou non).
func _bookmark_style(active: bool) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TarotCard.pack_tex("grimoire/marque_page_actif.png")  # même ruban, assombri s'il est inactif
	if not active:
		sb.modulate_color = Color(0.62, 0.56, 0.62)
	sb.content_margin_left = 18
	sb.content_margin_right = 26
	return sb


## Ombre du fond : voile derrière le grimoire, bandes sombres en haut et en bas de la carte.
class _DetailShade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(640, 0, 1280, 1080), Color(0.06, 0.05, 0.08, 0.55))
		for i in 16:
			draw_rect(Rect2(0, 1080 - (i + 1) * 16, 640, 16), Color(0.06, 0.05, 0.08, 0.8 * (1.0 - i / 16.0)))
			draw_rect(Rect2(0, i * 8, 640, 8), Color(0.06, 0.05, 0.08, 0.5 * (1.0 - i / 16.0)))


## Barre de statistique en pixels : fond d'encre, remplissage coloré avec reflet.
class _StatBar extends Control:
	var color := Color.WHITE
	var ratio := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("29262e"))
		var w := floorf((size.x - 4) * clampf(ratio, 0.0, 1.0))
		if w > 0:
			draw_rect(Rect2(2, 2, w, size.y - 4), color)
			draw_rect(Rect2(2, 2, w, 2), color.lightened(0.3))


## Passe au héros précédent / suivant, dans l'ordre de la collection.
func _step_hero(dir: int) -> void:
	var ids: Array = []
	for c in _grid.get_children():
		if c.has_meta("id"):
			ids.append(String(c.get_meta("id")))
	if ids.is_empty():
		ids = GameData.heroes.keys()
	var i := ids.find(selected)
	show_hero(String(ids[posmod(i + dir, ids.size())]), _tab)


func show_hero(id: String, tab := "Techniques") -> void:
	selected = id
	_tab = tab
	_collection.visible = false
	_page.visible = false
	_detail.visible = true
	refresh()  # pose d'abord la carte (et le héros animé dans sa fenêtre)
	_preview.show_hero(GameData.hero(id))
	_d_card.scale = Vector2(0.0, 1.0)
	create_tween().tween_property(_d_card, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fill_detail() -> void:
	var id := selected
	var hero := GameData.hero(id)
	var L := ScreenPack.layout(F)
	var rarity := int(hero.get("rarity", 2))
	var elem: String = ELEMENT_KEYS.get(hero.get("element"), "shadow")
	var owned: bool = PlayerData.state.heroes.has(id)
	_d_count.text = _count.text
	_d_room.texture = ScreenPack.tex(F, "fond_" + elem)
	# La carte : reconstruite, le héros animé replacé dans sa fenêtre.
	if _d_vpc.get_parent():
		_d_vpc.get_parent().remove_child(_d_vpc)
	_d_card.setup(hero, true, false)  # la fiche montre toujours la carte face visible
	_d_card.content.add_child(_d_vpc)
	var rcol: Color = (Palette.RARITIES.get(rarity, ["?", Color.WHITE])[1] as Color).lightened(0.25)
	_d_rarity_label.text = "%s · %s" % [String(Palette.RARITIES.get(rarity, ["?"])[0]).to_upper(),
		TarotCard.arcane(id).get("title", "")]
	_d_rarity_label.add_theme_color_override("font_color", rcol)
	_d_role.text = "%s · %s · %s" % [Palette.CLASS_NAMES.get(hero.get("class"), ""),
		Palette.ELEMENT_NAMES.get(hero.get("element"), ""), hero.get("species", "")]
	var tier := PlayerData.hero_echo_tier(id)
	for i in _d_echoes.size():
		_d_echoes[i].texture = ScreenPack.tex(F, "echo_full" if i < tier else "echo_empty")
	var echoes := PlayerData.hero_echoes(id)
	_d_echo_count.text = "%d Écho%s" % [echoes, "s" if echoes > 1 else ""]
	var max_level := int(GameData.progression.get("max_level", 150))
	_d_level.text = "Niveau %d / %d" % [PlayerData.hero_level(id), PlayerData.hero_level_cap(id)]
	_d_force.text = "Force %d" % _power(id)
	var need := maxf(1.0, PlayerData.hero_xp_to_next(id))
	_d_xp.size.x = maxf(0.0, XP_W * clampf(PlayerData.hero_xp(id) / need, 0.0, 1.0))
	_d_xp.visible = _d_xp.size.x >= 12.0
	_d_xp_text.text = "Expérience %d / %d · gagnée en chasse" % [PlayerData.hero_xp(id), PlayerData.hero_xp_to_next(id)]
	_d_recruit.visible = not owned
	for c: Control in [_d_level, _d_force, _d_xp_text, _d_xp.get_parent()]:
		c.visible = owned
	# Statistiques et actions
	var stats := PlayerData.hero_stats(id, hero)
	for i in STAT_NAMES.size():
		var key: String = STAT_NAMES[i][0]
		var v: float = stats.get(key, 0)
		_d_stats[i].text = "%d %%" % int(v * 100) if key == "crit" else str(int(v))
		if key == "heal":
			_d_stats[i].text = "+%d %%" % roundi(v * 100)
		var best := 0.0001
		for other: String in GameData.heroes:
			best = maxf(best, float(PlayerData.hero_stats(other, GameData.hero(other)).get(key, 0)))
		_d_bars[i].ratio = 0.08 + 0.92 * v / best if v > 0 else 0.0
		_d_bars[i].queue_redraw()
	var at_max := PlayerData.hero_level(id) >= max_level
	var cost := PlayerData.hero_level_up_cost(id)
	_d_upgrade.text = "Niveau max" if at_max else "Améliorer · %d or" % cost
	_d_upgrade.disabled = at_max or PlayerData.gold() < cost or not owned
	_d_upgrade.tooltip_text = ""
	if owned and PlayerData.hero_needs_awakening(id):
		# Palier d'éveil : nourrir des Esprits pour ouvrir les 10 niveaux suivants.
		var need_items := PlayerData.awaken_cost(id, hero)
		_d_upgrade.text = "Éveiller · " + esprit_cost_text(need_items)
		_d_upgrade.disabled = not PlayerData.can_awaken(id, hero)
		var have: Array[String] = []
		for item: String in need_items:
			have.append("%s : %d / %d" % [esprit_name(item), PlayerData.item_count(item), int(need_items[item])])
		_d_upgrade.tooltip_text = "Éveil du niveau %d
%s
Les Esprits se trouvent dans les coffres de fin de niveau." % [
			PlayerData.hero_level(id), "
".join(have)]
	var in_team := PlayerData.in_team(id)
	var full := PlayerData.team().size() >= PlayerData.TEAM_SIZE
	_d_team.text = "Dans l'équipe · retirer" if in_team else ("Équipe complète" if full else "Ajouter à l'équipe")
	_d_team.disabled = (in_team and PlayerData.team().size() <= 1) or (not in_team and full) or not owned
	# Onglets
	for i in TABS.size():
		var b: Button = _d_tabs[i]
		var active: bool = TABS[i] == _tab
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _bookmark_style(active or st == "hover"))
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(st, Color("793b49") if active else UiKit.INK)
		b.position.x = BOOK.x + (1052.0 if active else 1036.0)  # le marque-page actif dépasse davantage
	_path_panel.visible = false
	for c in _tab_box.get_children():
		c.queue_free()
	ScreenPack.fit_all(_detail)
	match _tab:
		"Techniques":
			_fill_skills(hero)
		"Voies":
			_fill_paths(id, hero)
		"Relique":
			_fill_relic(id, hero)
		_:
			_fill_echoes(id, hero)


func _fill_skills(hero: Dictionary) -> void:
	_page_title(_tab_box, Rect2(Vector2.ZERO, PAGE_R.size), "Techniques")
	var attacks: Array = hero.get("attacks", [])
	for i in mini(attacks.size(), 3):
		var a: Dictionary = attacks[i]
		var kind := "Attaque de base"
		if i == BattleUnit.SLOT_COOLDOWN:
			kind = "Recharge %d s" % int(a.get("cooldown", 0))
		elif i == BattleUnit.SLOT_ULTIMATE:
			kind = "Ultime"
		var anim: String = a.get("clip", a.get("anim", ""))
		_technique_row(62.0 + i * 166.0, _attack_icon(a), String(a.get("name", "")), kind, String(a.get("description", "")),
			func() -> void:
				ui_sound.emit("ui_click")
				_preview.play(anim))
	# Quatrième ligne : la technique secrète de la voie active (6 Échos).
	var secrets: Array = hero.get("secret_techniques", [])
	var path := PlayerData.hero_path(selected)
	var unlocked := PlayerData.hero_echo_tier(selected) >= 3
	var name := "Technique secrète"
	var kind2 := "6 Échos"
	var desc := "Débloquée par la voie d'Héritage."
	var clip := ""
	if path < secrets.size():
		var s: Dictionary = secrets[path]
		clip = String(s.get("clip", ""))
		if unlocked:
			name = String(s.get("name", ""))
			kind2 = "Technique secrète"
			desc = String(s.get("description", desc))
	_technique_row(62.0 + 3 * 166.0, _skill_icon(selected), name, kind2, desc, func() -> void:
		if clip != "":
			ui_sound.emit("ui_click")
			_preview.play(clip), not unlocked)


func _skill_icon(id: String) -> Texture2D:
	var ps := PixelSheet.for_actor(id)
	if ps == null or not ps.anims.has("skill"):
		return load("res://assets/ui/kit/lock.png")
	var frames: Array = ps.anims.skill.frames
	var tex: Texture2D = frames[mini(4, frames.size() - 1)][0]
	var img: Image = tex.get_image()
	var used := img.get_used_rect()
	var side := maxi(used.size.x, used.size.y)
	var c := used.get_center()
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(c.x - side / 2, c.y - side / 2, side, side)
	return at


## Une technique sur la page : icône (clic = la voir jouée sur la carte), nom, type, description.
func _technique_row(y: float, icon: Texture2D, title: String, kind: String, desc: String, on_press: Callable,
		locked := false) -> void:
	var holder := Control.new()
	holder.position = Vector2(0, y)
	holder.size = Vector2(64, 64)
	holder.tooltip_text = "Voir l'attaque"
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	_tab_box.add_child(holder)
	ScreenPack.panel(holder, F, "technique_icon_frame", Rect2(0, 0, 64, 64))
	if icon:
		var ic := ScreenPack.image(holder, icon, Rect2(6, 6, 52, 52))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if locked:
			ic.modulate = Color(0.35, 0.33, 0.4)
			ScreenPack.image(holder, load("res://assets/ui/kit/lock.png"), Rect2(20, 20, 28, 28))
	ScreenPack.text(_tab_box, title, Rect2(76, y, 308, 32), 22)
	ScreenPack.text(_tab_box, kind, Rect2(76, y + 32, 308, 26), 17, Color("793b49"))
	ScreenPack.text(_tab_box, desc, Rect2(0, y + 70, 384, 84), 16, UiKit.TEXT_SOFT, 0, true)


## Les trois voies d'Héritage : une seule active (changement gratuit hors combat), toutes
## progressent ensemble avec les Échos. Survoler une voie montre ses 5 paliers sur l'autre page.
func _fill_paths(id: String, hero: Dictionary) -> void:
	_page_title(_tab_box, Rect2(Vector2.ZERO, PAGE_R.size), "Voies d'Héritage")
	var tier := PlayerData.hero_echo_tier(id)
	var active := PlayerData.hero_path(id)
	var owned: bool = PlayerData.state.heroes.has(id)
	var thresholds: Array = GameData.progression.get("echoes", {}).get("thresholds", [1, 3, 6, 9, 12])
	var paths: Array = hero.get("paths", [])
	for i in mini(paths.size(), 3):
		var path: Dictionary = paths[i]
		var r := Rect2(0, 60 + i * 222, 384, 206)
		var state := "voie_active" if i == active else ("voie_inactive" if owned else "voie_locked")
		var card := ScreenPack.panel(_tab_box, F, state, r)
		var lines: Array[String] = []
		var stages: Dictionary = path.get("stages", {})
		for k in thresholds.size():
			lines.append("%s %d Échos · %s" % ["◆" if tier > k else "◇", int(thresholds[k]), stages.get(str(int(thresholds[k])), "")])
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var show := func() -> void:
			_path_title.text = "%s · %s%s" % [path.get("name", ""), path.get("focus", ""), "  (active)" if i == active else ""]
			for k in _path_lines.size():
				_path_lines[k].text = lines[k] if k < lines.size() else ""
				_path_lines[k].add_theme_color_override("font_color", UiKit.INK if tier > k else UiKit.TEXT_SOFT)
			_path_panel.visible = true
		card.mouse_entered.connect(show)
		card.mouse_exited.connect(func() -> void: _path_panel.visible = false)
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventScreenTouch and e.pressed:
				show.call())
		var light := state == "voie_locked"
		ScreenPack.text(card, String(path.get("name", "")), Rect2(16, 16, r.size.x - 32, 32), 22,
			UiKit.WHITE if light else UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.text(card, String(path.get("focus", "")) if owned else "Recrute le héros", Rect2(16, 50, r.size.x - 32, 26), 18,
			UiKit.PARCHMENT_DARK if light else UiKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.text(card, "Paliers : %d / 5 · survole pour voir" % tier, Rect2(16, 78, r.size.x - 32, 24), 15,
			UiKit.PARCHMENT_DARK if light else UiKit.WOOD, HORIZONTAL_ALIGNMENT_CENTER)
		var label := "Active" if i == active else ("Choisir" if owned else "Verrouillée")
		var cb := ScreenPack.button(_tab_box, F, "voie_choose", label, Rect2(72, r.position.y + 112, 240, 76), 22, UiKit.INK)
		cb.disabled = i == active or not owned
		if i == active:
			cb.add_theme_stylebox_override("disabled", ScreenPack.nine(F, "voie_choose_normal"))
			cb.add_theme_color_override("font_disabled_color", UiKit.INK)
		elif not owned:
			cb.add_theme_color_override("font_disabled_color", UiKit.WHITE)
		var path_index := i
		cb.pressed.connect(func() -> void:
			ui_sound.emit("ui_toggle")
			PlayerData.set_hero_path(id, path_index))


## La relique ancienne du héros : cinq paliers, fragments gagnés en chasse.
func _fill_relic(id: String, hero: Dictionary) -> void:
	_page_title(_tab_box, Rect2(Vector2.ZERO, PAGE_R.size), "Relique")
	var relic: Dictionary = GameData.relics.get("relics", {}).get(id, {})
	if relic.is_empty():
		ScreenPack.text(_tab_box, "Pas de relique connue.", Rect2(0, 70, 384, 40), 22, UiKit.TEXT_SOFT)
		return
	if not PlayerData.relics_unlocked():
		ScreenPack.image(_tab_box, load("res://assets/ui/kit/lock.png"), Rect2(160, 80, 64, 64))
		ScreenPack.text(_tab_box, "%s · relique scellée" % relic.get("name", ""), Rect2(0, 160, 384, 64), 22, UiKit.INK,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		ScreenPack.text(_tab_box, "Les reliques s'éveillent après la Campagne 1 : bats Morvath au dernier niveau du monde 10 " +
			"pour ouvrir la Campagne Héroïque, où se trouvent leurs fragments.", Rect2(0, 236, 384, 200), 18, UiKit.TEXT_SOFT,
			HORIZONTAL_ALIGNMENT_CENTER, true)
		return
	var tier := PlayerData.relic_tier(id)
	var tiers: Array = GameData.progression.get("relic_tiers", [])
	var img := ScreenPack.image(_tab_box, load(String(relic.sprite)) if ResourceLoader.exists(String(relic.get("sprite", ""))) else null,
		Rect2(0, 56, 96, 96))
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.tooltip_text = "\n".join([
		"Où la trouver : %s (%s)" % [relic.get("dungeon", ""), relic.get("material", "")],
		"Épreuve du palier V : %s" % relic.get("trial", "")])
	img.mouse_filter = Control.MOUSE_FILTER_PASS
	if tier == 0:
		img.modulate = Color(0.35, 0.33, 0.38)
	ScreenPack.text(_tab_box, String(relic.name), Rect2(108, 56, 276, 56), 20, UiKit.INK, 0, true)
	var state_name := "Pas encore retrouvée" if tier == 0 else "Palier %d · %s" % [tier, tiers[tier - 1].get("name", "")]
	ScreenPack.text(_tab_box, state_name, Rect2(108, 112, 276, 26), 17, Color("793b49"))
	var cost := PlayerData.relic_next_cost(id)
	var need := int(cost.get("fragments", 0))
	ScreenPack.text(_tab_box, "Fragments : %d / %d · %s" % [PlayerData.relic_fragments(id), need, relic.get("dungeon", "")],
		Rect2(0, 160, 384, 48), 16, UiKit.TEXT_SOFT, 0, true)
	_separator(_tab_box, 214, 0)
	for i in 5:
		var y := 240.0 + i * 70.0
		var st := "relic_step_full" if i < tier else ("relic_step_active" if i == tier else "relic_step_empty")
		ScreenPack.image(_tab_box, ScreenPack.tex(F, st), Rect2(0, y, 28, 28))
		ScreenPack.text(_tab_box, str(i + 1), Rect2(0, y, 28, 28), 15, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.text(_tab_box, relic_tier_text(hero, i), Rect2(38, y - 2, 346, 66), 16,
			UiKit.INK if i < tier else UiKit.TEXT_SOFT, 0, true)
	if not cost.is_empty():
		var label := "Retrouver" if tier == 0 else "Améliorer"
		var b := ScreenPack.button(_tab_box, F, "upgrade", "%s · %d fragments%s" % [label, need,
			"" if int(cost.materials) == 0 else " + %d mat." % int(cost.materials)], Rect2(0, 600, 384, 72), 20, UiKit.INK)
		b.disabled = not PlayerData.can_upgrade_relic(id)
		b.pressed.connect(func() -> void:
			if PlayerData.upgrade_relic(id):
				ui_sound.emit("ultimate_impact")
				_preview.play("cheer"))


## Les Échos (doublons du même héros) : paliers 1, 3, 6, 9, 12, leurs statistiques et leur bonus.
func _fill_echoes(id: String, hero: Dictionary) -> void:
	_page_title(_tab_box, Rect2(Vector2.ZERO, PAGE_R.size), "Échos")
	var e: Dictionary = GameData.progression.get("echoes", {})
	var tier := PlayerData.hero_echo_tier(id)
	var thresholds: Array = e.get("thresholds", [])
	var unlocks: Array = e.get("unlocks", [])
	var mods: Array = Progression.personal(hero, GameData.progression).get("echoes", [])
	for k in mini(thresholds.size(), 5):
		var y := 58.0 + k * 122.0
		var reached := tier > k
		var col := UiKit.INK if reached else UiKit.TEXT_SOFT
		ScreenPack.image(_tab_box, ScreenPack.tex(F, "echo_full" if reached else "echo_empty"), Rect2(0, y, 32, 32))
		ScreenPack.text(_tab_box, "%d Échos · %s" % [int(thresholds[k]), unlocks[k] if k < unlocks.size() else ""],
			Rect2(40, y, 344, 30), 19, col)
		ScreenPack.text(_tab_box, "+%d %% %s, +%d %% %s, +%d %% autres" % [int(float(e.primary[k]) * 100), hero.get("primary", ""),
			int(float(e.secondary[k]) * 100), hero.get("secondary", ""), int(float(e.other[k]) * 100)],
			Rect2(40, y + 30, 344, 26), 15, col)
		var bonus := ""
		if k < mods.size():
			bonus = " · ".join((mods[k] as Array).map(func(m: Dictionary) -> String: return String(m.get("text", ""))))
		ScreenPack.text(_tab_box, bonus, Rect2(40, y + 56, 344, 56), 15, Color("793b49") if reached else UiKit.TEXT_SOFT, 0, true)
	ScreenPack.text(_tab_box, "Un doublon donne un Écho. Aucune autre source.", Rect2(0, 680, 384, 30), 15, UiKit.TEXT_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER)


func _set_tab(t: String) -> void:
	ui_sound.emit("ui_click")
	_tab = t
	_fill_detail()


# --- Confirmation de l'amélioration -----------------------------------------------

func _build_confirm() -> void:
	_confirm = UiWindow.new().setup("Améliorer", Vector2(620, 330))
	add_child(_confirm)
	_confirm_text = UiKit.label("", 24, UiKit.INK)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_confirm.content.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_confirm.content.add_child(row)
	var ok := UiKit.button("Améliorer", "red", 22, Vector2(220, 60))
	ok.pressed.connect(func() -> void:
		_confirm.close_window()
		if PlayerData.level_up_hero(selected):
			ui_sound.emit("ui_ready")
			_preview.play("cheer"))
	row.add_child(ok)
	var cancel := UiKit.button("Annuler", "grey", 22, Vector2(180, 60))
	cancel.pressed.connect(_confirm.close_window)
	row.add_child(cancel)


func _ask_level_up() -> void:
	ui_sound.emit("ui_click")
	var hero := GameData.hero(selected)
	if PlayerData.hero_needs_awakening(selected):
		if PlayerData.awaken_hero(selected, hero):
			ui_sound.emit("ultimate_impact")
			_preview.play("cheer")
		return
	var lv := PlayerData.hero_level(selected)
	_confirm_text.text = "Passer %s du niveau %d au niveau %d pour %d or ?" % [hero.name, lv, lv + 1, PlayerData.hero_level_up_cost(selected)]
	_confirm.open()


# --- Petits éléments ----------------------------------------------------------------

const STAT_LABELS := {"hp": "Vie", "atk": "Attaque", "mag": "Magie", "def": "Défense", "res": "Résistance",
	"spd": "Vitesse", "crit": "Critique", "heal": "Soins"}


## Texte d'un palier de relique propre au héros : « +15 % Attaque, +3 pts Critique · Banquet : un 5e coup ».
static func relic_tier_text(hero: Dictionary, i: int) -> String:
	var tiers: Array = Progression.personal(hero, GameData.progression).get("relic", [])
	if i < 0 or i >= tiers.size():
		return ""
	var bits: Array[String] = []
	var st: Dictionary = tiers[i].get("stats", {})
	for key: String in st:
		if key == "heal":
			bits.append("+%d %% Soins" % roundi(float(st[key]) * 100))
		elif key == "crit":
			bits.append("+%d pts %s" % [roundi(float(st[key]) * 100), STAT_LABELS[key]])
		else:
			bits.append("+%d %% %s" % [roundi(float(st[key]) * 100), STAT_LABELS.get(key, key)])
	var text := ", ".join(bits)
	for m: Dictionary in tiers[i].get("mods", []):
		text += " · " + String(m.get("text", ""))
	return text


const ESPRIT_NAMES := {"oeuf": ["Œuf", "Œufs"], "petit": ["Petit", "Petits"], "grand": ["Grand", "Grands"],
	"celeste": ["Céleste", "Célestes"]}


## « Œuf de feu » à partir de « esprit_oeuf_feu ».
static func esprit_name(item: String, plural := false) -> String:
	var parts := item.split("_")
	if parts.size() < 3:
		return item
	var n: Array = ESPRIT_NAMES.get(parts[1], [parts[1], parts[1]])
	var elem := String(Palette.ELEMENT_NAMES.get(parts[2], parts[2])).to_lower()
	return "%s %s%s" % [n[1] if plural else n[0], "d'" if elem.begins_with("e") or elem.begins_with("o") else "de ", elem]


static func esprit_cost_text(cost: Dictionary) -> String:
	var bits: Array[String] = []
	for item: String in cost:
		bits.append("%d %s" % [int(cost[item]), esprit_name(item, int(cost[item]) > 1)])
	return ", ".join(bits)

func _on_back() -> void:
	ui_sound.emit("ui_click")
	if _detail.visible:
		_show_collection()
	else:
		closed.emit()


func _tab_button(text: String, active: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	var sb := UiKit.box(UiKit.PARCHMENT if active else CARD, UiKit.INK if active else Color("726552"), 10, 2)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, UiKit.INK if active else UiKit.PARCHMENT)
	b.pressed.connect(on_press)
	return b


## Carré d'insigne (classe ou élément) : tuile d'encre cerclée de laiton, icône centrée.
## Emblème posé sur le fond (classe ou élément) : l'icône seule, avec une ombre portée douce.
func _emblem(parent: Control, at: Vector2) -> TextureRect:
	var sh := TextureRect.new()
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sh.position = at + Vector2(3, 4)
	sh.size = Vector2(72, 72)
	sh.modulate = Color(0, 0, 0, 0.6)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sh)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.position = at
	ic.size = Vector2(72, 72)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_meta("shadow", sh)
	parent.add_child(ic)
	return ic


func _icon_square(tex: Texture2D, side: float, tip := "") -> Panel:
	var sq := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("29262e")
	sb.border_color = Color("c6a66c")
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(3, 3)
	sb.shadow_size = 1
	sq.add_theme_stylebox_override("panel", sb)
	sq.size = Vector2(side, side)
	sq.tooltip_text = tip
	sq.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.position = Vector2(3, 3)
	ic.size = Vector2(side - 6, side - 6)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.add_child(ic)
	return sq


func _badge(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.box(color, UiKit.INK, 8, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiKit.label(text, 16, UiKit.WHITE))
	return p


func _section(text: String) -> Label:
	var l := UiKit.title(text, 28, UiKit.WOOD)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _role(hero: Dictionary) -> String:
	var role := String(hero.get("role", Palette.CLASS_NAMES.get(hero.get("class"), "")))
	return "%s · %s" % [role, Palette.ELEMENT_NAMES.get(hero.get("element"), "")]


## Paliers d'Échos atteints : ◆ plein par palier (5 au plus), et le nombre d'Échos.
func _echo_marks(id: String) -> String:
	var tier := PlayerData.hero_echo_tier(id)
	return "%s  %d Écho%s" % ["◆".repeat(tier) + "◇".repeat(5 - tier), PlayerData.hero_echoes(id),
		"s" if PlayerData.hero_echoes(id) > 1 else ""]


func _power(id: String) -> int:
	return Progression.power(PlayerData.hero_stats(id, GameData.hero(id)))


func _fiche(hero: Dictionary) -> Texture2D:
	if ResourceLoader.exists(String(hero.get("fiche", ""))):
		return load(String(hero.fiche))
	if hero.has("puppet"):
		var path := String(hero.puppet).path_join("fiche.png")
		if ResourceLoader.exists(path):
			return load(path)
	return RoundPortrait.portrait_texture(hero)


func _attack_icon(a: Dictionary) -> Texture2D:
	var path := ATTACK_ICON_DIR + String(a.get("id", "")) + ".png"
	return load(path) if ResourceLoader.exists(path) else null
