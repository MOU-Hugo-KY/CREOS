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
	_grid.columns = 4
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
	# Carte de collection en pixel : cadre de vitrine, salle d'armes et socle de l'élément, le héros
	# (première image de son repos de combat), badges de classe, d'élément et de rareté.
	var id: String = hero.id
	var owned: bool = PlayerData.state.heroes.has(id)
	var elem: String = ELEMENT_KEYS.get(hero.get("element"), "shadow")
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 430)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame := ScreenPack.nine(F, "vitrine_frame")
	card.add_theme_stylebox_override("normal", frame)
	var hover := ScreenPack.nine(F, "vitrine_frame")
	hover.modulate_color = Color(1.12, 1.06, 0.9)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		show_hero(id))
	card.set_meta("id", id)
	card.resized.connect(func() -> void: _layout_card(card))
	var room := TextureRect.new()
	room.name = "Room"
	room.texture = ScreenPack.tex(F, "fond_" + elem)
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.clip_contents = true
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(room)
	var socle := TextureRect.new()
	socle.name = "Socle"
	socle.texture = ScreenPack.tex(F, "socle_" + elem)
	socle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	socle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	socle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(socle)
	var art := TextureRect.new()
	art.name = "Art"
	var sheet := PixelSheet.for_actor(id)
	art.texture = sheet.anims.idle.frames[0][0] if sheet and sheet.anims.has("idle") else _fiche(hero)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not owned:
		art.modulate = Color(0.25, 0.23, 0.3)
	card.add_child(art)
	var info := Panel.new()
	info.name = "Info"
	info.add_theme_stylebox_override("panel", ScreenPack.nine(F, "hero_type_cartouche"))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(info)
	var rarity := int(hero.get("rarity", 2))
	var badge := ScreenPack.panel(card, F, "badge_" + RARITY_KEYS.get(rarity, "rare"), Rect2(20, 20, 128, 44))
	badge.name = "Rarity"
	ScreenPack.text(badge, Palette.RARITIES.get(rarity, ["?"])[0], Rect2(0, 0, 128, 44), 18, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var cls := _icon_square(ScreenPack.tex(F, "classe_%s_64" % CLASS_KEYS.get(hero.get("class"), "blade")), 52,
		Palette.CLASS_NAMES.get(hero.get("class"), ""))
	cls.name = "Class"
	card.add_child(cls)
	var el := _icon_square(ScreenPack.tex(F, "element_%s_64" % elem), 52, Palette.ELEMENT_NAMES.get(hero.get("element"), ""))
	el.name = "Element"
	card.add_child(el)
	if PlayerData.in_team(id):
		var t := _badge("ÉQUIPE", Color("1f5f59"))
		t.name = "Team"
		card.add_child(t)
	ScreenPack.text(info, String(hero.name), Rect2(20, 6, 400, 36), 28, UiKit.WHITE).name = "Name"
	var sub := "À recruter à la Lanterne" if not owned else "Niv. %d · %s · Force %d" % [PlayerData.hero_level(id),
		_echo_marks(id), _power(id)]
	ScreenPack.text(info, sub, Rect2(20, 42, 400, 30), 18, UiKit.PARCHMENT_DARK if owned else Color("f3d9a0")).name = "Sub"
	return card


## Place les éléments d'une carte de collection selon sa taille (la grille décide de la largeur).
func _layout_card(card: Control) -> void:
	var w := card.size.x
	var h := card.size.y
	var room: Control = card.get_node("Room")
	room.position = Vector2(14, 14)
	room.size = Vector2(w - 28, h - 112)
	var socle: Control = card.get_node("Socle")
	socle.size = Vector2(minf(220, w - 60), 120)
	socle.position = Vector2((w - socle.size.x) / 2.0, h - 210)
	var art: Control = card.get_node("Art")
	art.size = Vector2(288, 288)
	var feet := 96.0
	var ps := PixelSheet.for_actor(String(card.get_meta("id", "")))
	if ps:
		feet = ps.anchor.x  # pieds réels du dessin, posés au centre du socle
	art.position = Vector2(w / 2.0 - feet * 1.5, h - 112 - 219 - 40)
	var info: Control = card.get_node("Info")
	info.position = Vector2(10, h - 92)
	info.size = Vector2(w - 20, 82)
	for c in info.get_children():
		c.size.x = w - 50
	# Classe et élément : carrés dans les coins bas de la salle, de part et d'autre du socle.
	(card.get_node("Class") as Control).position = Vector2(26, h - 112 - 66)
	(card.get_node("Element") as Control).position = Vector2(w - 26 - 52, h - 112 - 66)
	if card.has_node("Team"):
		var t: Control = card.get_node("Team")
		t.position = Vector2(w - t.size.x - 22, 22)

func _build_detail(_page: VBoxContainer) -> void:
	# Fiche d'un héros, façon scène : la salle d'armes de son élément en fond, le héros en grand à
	# gauche (flèches pour passer au suivant), et à droite un parchemin (statistiques en barres,
	# actions, onglets marque-pages). Repère 1920 × 1080, pièces du pack fiche_heros.
	_detail = Control.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail.visible = false
	add_child(_detail)
	var root := ScreenPack.frame(_detail)
	# Fond : la salle d'armes sur tout l'écran, assombrie, plus sombre encore sous le parchemin.
	_d_room = ScreenPack.image(root, null, Rect2(0, 0, 1920, 1080))
	_d_room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_d_room.modulate = Color(0.55, 0.52, 0.58)
	var shade := _DetailShade.new()
	shade.size = Vector2(1920, 1080)
	root.add_child(shade)
	var back := ScreenPack.button(root, F, "collection", "← Collection", Rect2(24, 20, 260, 80), 28)
	back.pressed.connect(_on_back)
	_d_count = ScreenPack.text(root, "", Rect2(300, 20, 400, 80), 22, Color(1, 1, 1, 0.6))
	# Identité : nom en grand, insignes, rôle.
	_d_title = ScreenPack.text(root, "", Rect2(20, 108, 690, 84), 66, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_d_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_d_title.add_theme_constant_override("shadow_offset_x", 4)
	_d_title.add_theme_constant_override("shadow_offset_y", 4)
	var sq_c := _icon_square(null, 60)
	sq_c.position = Vector2(205, 200)
	root.add_child(sq_c)
	_d_class = sq_c.get_node("Icon")
	var sq_e := _icon_square(null, 60)
	sq_e.position = Vector2(275, 200)
	root.add_child(sq_e)
	_d_element = sq_e.get_node("Icon")
	var rr := Rect2(351, 204, 170, 52)
	_d_rarity = ScreenPack.panel(root, F, "badge_rare", rr)
	_d_rarity_label = ScreenPack.text(root, "", rr, 22, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_d_role = ScreenPack.text(root, "", Rect2(20, 272, 690, 36), 26, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER)
	_d_species = ScreenPack.text(root, "", Rect2(20, 306, 690, 30), 20, UiKit.PARCHMENT_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	# Le héros, grand, sur son socle.
	_d_socle = ScreenPack.image(root, null, Rect2(185, 735, 360, 225))
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.position = Vector2(40, 330)
	vpc.size = Vector2(650, 520)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vpc)
	_preview = HeroPreview.new()
	_preview.pedestal = false
	_preview.zoom = 0.85
	vpc.add_child(_preview)
	for dir: int in [-1, 1]:
		var arrow := SummonAltar._Arrow.new()
		arrow.dir = dir
		arrow.scale = Vector2(1.5, 1.5)
		arrow.position = Vector2(30 if dir < 0 else 640, 540)
		arrow.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_step_hero(dir))
		root.add_child(arrow)
	# Sous le héros : Échos, niveau, Force, expérience.
	for i in 5:
		_d_echoes.append(ScreenPack.image(root, ScreenPack.tex(F, "echo_empty"), Rect2(150 + i * 52, 900, 44, 44)))
	_d_echo_count = ScreenPack.text(root, "", Rect2(420, 900, 200, 44), 26, UiKit.WHITE)
	_d_level = ScreenPack.text(root, "", Rect2(71, 954, 300, 40), 28, UiKit.WHITE)
	_d_force = ScreenPack.text(root, "", Rect2(359, 954, 300, 40), 28, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_RIGHT)
	var xp_bg := ScreenPack.panel(root, F, "xp_bg", Rect2(71, 1000, 588, 18))
	_d_xp = ScreenPack.panel(xp_bg, F, "xp_fill", Rect2(0, 3, 588, 12))
	_d_xp_text = ScreenPack.text(root, "", Rect2(71, 1022, 588, 26), 18, UiKit.PARCHMENT_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_d_recruit = ScreenPack.text(root, "À recruter à la Lanterne des Serments", Rect2(40, 954, 650, 40), 26, Color("f3d9a0"),
		HORIZONTAL_ALIGNMENT_CENTER)
	# Le parchemin : statistiques en barres, actions, onglets, contenu.
	ScreenPack.panel(root, F, "stats_panel", Rect2(748, 20, 1144, 1040))
	for i in STAT_NAMES.size():
		var y := 66.0 + i * 44.0
		ScreenPack.text(root, STAT_NAMES[i][1], Rect2(790, y, 190, 36), 24)
		var bar := _StatBar.new()
		bar.position = Vector2(990, y + 9)
		bar.size = Vector2(700, 20)
		bar.color = STAT_COLORS.get(STAT_NAMES[i][0], UiKit.WOOD)
		root.add_child(bar)
		_d_bars.append(bar)
		_d_stats.append(ScreenPack.text(root, "", Rect2(1700, y, 160, 36), 24, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT))
	_d_upgrade = ScreenPack.button(root, F, "upgrade", "", Rect2(780, 386, 700, 84), 28, UiKit.INK)
	_d_upgrade.pressed.connect(_ask_level_up)
	_d_team = ScreenPack.button(root, F, "team_button", "", Rect2(1496, 386, 364, 84), 24)
	_d_team.pressed.connect(func() -> void:
		if PlayerData.toggle_team(selected):
			ui_sound.emit("ui_toggle"))
	for i in TABS.size():
		var t: String = TABS[i]
		var b := ScreenPack.button(root, F, "tab_inactive", t, Rect2(780 + i * 274, 498, 260, 76), 26)
		b.pressed.connect(func() -> void: _set_tab(t))
		_d_tabs.append(b)
	_path_panel = ScreenPack.panel(root, F, "stats_panel", Rect2(748, 20, 1144, 490))
	_path_panel.z_index = 5
	_path_title = ScreenPack.text(_path_panel, "", Rect2(34, 26, 1076, 48), 32)
	for k in 5:
		_path_lines.append(ScreenPack.text(_path_panel, "", Rect2(34, 92 + k * 78, 1076, 72), 23, UiKit.INK, 0, true))
	_path_panel.visible = false
	# Contenu des onglets : dessiné dans le repère de l'ancienne fiche (content_rect), décalé ici.
	_tab_box = Control.new()
	_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_box.size = Vector2(1920, 1080)
	_tab_box.position = Vector2(0, TAB_SHIFT)
	root.add_child(_tab_box)


## Décalage vertical du contenu des onglets par rapport aux rectangles de fiche_heros.json.
const TAB_SHIFT := -134.0
const STAT_COLORS := {"hp": Color("b9474f"), "atk": Color("d08a3a"), "mag": Color("7d5bd0"), "def": Color("5a7fa8"),
	"spd": Color("4fae8a"), "crit": Color("d9b44a"), "heal": Color("6fc06a")}


## Ombre du fond : voile sous le parchemin, bandes sombres en haut et en bas de la scène du héros.
class _DetailShade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(740, 0, 1180, 1080), Color(0.06, 0.05, 0.08, 0.55))
		for i in 16:
			draw_rect(Rect2(0, 1080 - (i + 1) * 14, 740, 14), Color(0.06, 0.05, 0.08, 0.75 * (1.0 - i / 16.0)))
			draw_rect(Rect2(0, i * 8, 740, 8), Color(0.06, 0.05, 0.08, 0.5 * (1.0 - i / 16.0)))


## Barre de statistique en pixels : fond d'encre, remplissage coloré avec reflet.
class _StatBar extends Control:
	var color := Color.WHITE
	var ratio := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("29262e"))
		var w := floorf((size.x - 6) * clampf(ratio, 0.0, 1.0))
		if w > 0:
			draw_rect(Rect2(3, 3, w, size.y - 6), color)
			draw_rect(Rect2(3, 3, w, 4), color.lightened(0.3))
		var step := size.x / 10.0
		for k in range(1, 10):
			draw_rect(Rect2(k * step, 3, 2, size.y - 6), Color(0, 0, 0, 0.25))


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
	_preview.show_hero(GameData.hero(id))
	refresh()


func _fill_detail() -> void:
	var id := selected
	var hero := GameData.hero(id)
	var L := ScreenPack.layout(F)
	var rarity := int(hero.get("rarity", 2))
	var elem: String = ELEMENT_KEYS.get(hero.get("element"), "shadow")
	var owned: bool = PlayerData.state.heroes.has(id)
	_d_title.text = String(hero.name).to_upper()
	_d_count.text = _count.text
	# Vitrine
	_d_room.texture = ScreenPack.tex(F, "fond_" + elem)
	_d_socle.texture = ScreenPack.tex(F, "socle_" + elem)
	_d_class.texture = ScreenPack.tex(F, "classe_%s_64" % CLASS_KEYS.get(hero.get("class"), "blade"))
	_d_element.texture = ScreenPack.tex(F, "element_%s_64" % elem)
	_d_rarity.add_theme_stylebox_override("panel", ScreenPack.nine(F, "badge_" + RARITY_KEYS.get(rarity, "rare")))
	_d_rarity_label.text = Palette.RARITIES.get(rarity, ["?"])[0]
	_d_role.text = "%s · %s" % [Palette.CLASS_NAMES.get(hero.get("class"), ""), Palette.ELEMENT_NAMES.get(hero.get("element"), "")]
	_d_species.text = String(hero.get("species", ""))
	var tier := PlayerData.hero_echo_tier(id)
	for i in _d_echoes.size():
		_d_echoes[i].texture = ScreenPack.tex(F, "echo_full" if i < tier else "echo_empty")
	var echoes := PlayerData.hero_echoes(id)
	_d_echo_count.text = "%d Écho%s" % [echoes, "s" if echoes > 1 else ""]
	var max_level := int(GameData.progression.get("max_level", 150))
	_d_level.text = "Niveau %d / %d" % [PlayerData.hero_level(id), PlayerData.hero_level_cap(id)]
	_d_force.text = "Force %d" % _power(id)
	var need := maxf(1.0, PlayerData.hero_xp_to_next(id))
	_d_xp.size.x = maxf(0.0, 588.0 * clampf(PlayerData.hero_xp(id) / need, 0.0, 1.0))
	_d_xp.visible = _d_xp.size.x >= 12.0
	_d_xp_text.text = "Expérience %d / %d · gagnée en chasse" % [PlayerData.hero_xp(id), PlayerData.hero_xp_to_next(id)]
	_d_recruit.visible = not owned
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
		var base := "tab_active" if TABS[i] == _tab else "tab_inactive"
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, ScreenPack.nine(F, base))
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
	var rows: Array = ScreenPack.layout(F).techniques.row_rects
	var attacks: Array = hero.get("attacks", [])
	for i in mini(attacks.size(), 3):
		var a: Dictionary = attacks[i]
		var r := ScreenPack.rect(rows[i])
		var kind := "Attaque de base"
		if i == BattleUnit.SLOT_COOLDOWN:
			kind = "Recharge %d s" % int(a.get("cooldown", 0))
		elif i == BattleUnit.SLOT_ULTIMATE:
			kind = "Ultime"
		var anim: String = a.get("clip", a.get("anim", ""))
		_technique_row(r, _attack_icon(a), "%s · %s" % [a.get("name", ""), kind], String(a.get("description", "")),
			func() -> void:
				ui_sound.emit("ui_click")
				_preview.play(anim))
	# Quatrième ligne : la technique secrète de la voie active (6 Échos).
	var secrets: Array = hero.get("secret_techniques", [])
	var path := PlayerData.hero_path(selected)
	var unlocked := PlayerData.hero_echo_tier(selected) >= 3
	var name := "Technique secrète · 6 Échos"
	var desc := "Débloquée par la voie d'Héritage."
	var clip := ""
	if path < secrets.size():
		var s: Dictionary = secrets[path]
		clip = String(s.get("clip", ""))
		if unlocked:
			name = "%s · Technique secrète" % s.get("name", "")
			desc = String(s.get("description", desc))
	# Icône : la pose de technique du héros (image la plus forte de son animation « skill »), grisée tant
	# qu'elle est verrouillée.
	var icon: Texture2D = _skill_icon(selected)
	_technique_row(ScreenPack.rect(rows[3]), icon, name, desc, func() -> void:
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


func _technique_row(r: Rect2, icon: Texture2D, title: String, desc: String, on_press: Callable, locked := false) -> void:
	var holder := Control.new()
	holder.position = r.position
	holder.size = Vector2(64, 64)
	holder.tooltip_text = "Voir l'attaque"
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
	ScreenPack.text(_tab_box, title, Rect2(r.position + Vector2(94, 0), Vector2(r.size.x - 100, 34)), 26)
	var d := ScreenPack.text(_tab_box, desc, Rect2(r.position + Vector2(94, 32), Vector2(r.size.x - 110, 28)), 20, UiKit.TEXT_SOFT)
	d.clip_text = true
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d.tooltip_text = desc
	d.mouse_filter = Control.MOUSE_FILTER_PASS


## Les trois voies d'Héritage : une seule active (changement gratuit hors combat), toutes
## progressent ensemble avec les Échos. Au palier 3 (6 Échos), une quatrième technique.
func _fill_paths(id: String, hero: Dictionary) -> void:
	var V: Dictionary = ScreenPack.layout(F).voies
	var tier := PlayerData.hero_echo_tier(id)
	var active := PlayerData.hero_path(id)
	var owned: bool = PlayerData.state.heroes.has(id)
	var thresholds: Array = GameData.progression.get("echoes", {}).get("thresholds", [1, 3, 6, 9, 12])
	var paths: Array = hero.get("paths", [])
	for i in mini(paths.size(), 3):
		var path: Dictionary = paths[i]
		var r := ScreenPack.rect(V.cards[i])
		var state := "voie_active" if i == active else ("voie_inactive" if owned else "voie_locked")
		var card := ScreenPack.panel(_tab_box, F, state, r)
		var lines: Array[String] = []
		var stages: Dictionary = path.get("stages", {})
		for k in thresholds.size():
			lines.append("%s %d Échos — %s" % ["◆" if tier > k else "◇", int(thresholds[k]), stages.get(str(int(thresholds[k])), "")])
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
		ScreenPack.text(card, String(path.get("name", "")), Rect2(16, 18, r.size.x - 32, 36), 25,
			UiKit.WHITE if light else UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.text(card, String(path.get("focus", "")) if owned else "Recrute le héros", Rect2(16, 58, r.size.x - 32, 30), 20,
			UiKit.PARCHMENT_DARK if light else UiKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.text(card, "Paliers : %d / 5 · survole pour voir" % tier, Rect2(16, 94, r.size.x - 32, 26), 17,
			UiKit.PARCHMENT_DARK if light else UiKit.WOOD, HORIZONTAL_ALIGNMENT_CENTER)
		var label := "Active" if i == active else ("Choisir" if owned else "Verrouillée")
		var cb := ScreenPack.button(_tab_box, F, "voie_choose", label, ScreenPack.rect(V.choose_touch_rects[i]), 26, UiKit.INK)
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
	var R: Dictionary = ScreenPack.layout(F).relic
	var relic: Dictionary = GameData.relics.get("relics", {}).get(id, {})
	if relic.is_empty():
		ScreenPack.text(_tab_box, "Pas de relique connue.", Rect2(790, 760, 900, 40), 26, UiKit.TEXT_SOFT)
		return
	if not PlayerData.relics_unlocked():
		ScreenPack.image(_tab_box, load("res://assets/ui/kit/lock.png"), Rect2(800, 790, 64, 64))
		ScreenPack.text(_tab_box, "%s · relique scellée" % relic.get("name", ""), Rect2(890, 770, 940, 44), 28)
		ScreenPack.text(_tab_box, "Les reliques s'éveillent après la Campagne 1 : bats Morvath au dernier niveau du monde 10 " +
			"pour ouvrir la Campagne Héroïque, où se trouvent leurs fragments.", Rect2(890, 820, 940, 120), 22, UiKit.TEXT_SOFT, 0, true)
		return
	var tier := PlayerData.relic_tier(id)
	var tiers: Array = GameData.progression.get("relic_tiers", [])
	var pr := Rect2(780, 752, 420, 210)
	var p := ScreenPack.panel(_tab_box, F, "relic_panel", pr)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.tooltip_text = "\n".join([
		"Où la trouver : %s (%s)" % [relic.get("dungeon", ""), relic.get("material", "")],
		"III · Éveillée : %s" % relic.get("awakening", ""), "IV · Accordée : %s" % relic.get("accord", ""),
		"V · Héritage : %s" % relic.get("contribution", ""), "Épreuve du palier V : %s" % relic.get("trial", "")])
	var img := ScreenPack.image(p, load(String(relic.sprite)) if ResourceLoader.exists(String(relic.get("sprite", ""))) else null,
		Rect2(pr.size.x - 112, 64, 84, 84))
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if tier == 0:
		img.modulate = Color(0.35, 0.33, 0.38)
	ScreenPack.text(p, String(relic.name), Rect2(20, 16, pr.size.x - 40, 34), 24, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var state_name := "Pas encore retrouvée" if tier == 0 else "Palier %d · %s" % [tier, tiers[tier - 1].get("name", "")]
	ScreenPack.text(p, state_name, Rect2(20, 52, pr.size.x - 40, 30), 21, UiKit.WOOD, HORIZONTAL_ALIGNMENT_CENTER)
	var cost := PlayerData.relic_next_cost(id)
	var need := int(cost.get("fragments", 0))
	ScreenPack.text(p, "Fragments : %d / %d" % [PlayerData.relic_fragments(id), need], Rect2(24, 128, 300, 28), 20)
	ScreenPack.text(p, String(relic.get("dungeon", "")), Rect2(24, 158, 300, 28), 20)
	# Les cinq paliers, chacun avec son bonus propre au héros (statistiques + effet sur ses attaques).
	ScreenPack.text(_tab_box, "LES CINQ PALIERS", Rect2(1234, 758, 500, 34), 24)
	for i in 5:
		var y := 796.0 + i * 31.0
		var st := "relic_step_full" if i < tier else ("relic_step_active" if i == tier else "relic_step_empty")
		ScreenPack.image(_tab_box, ScreenPack.tex(F, st), Rect2(1234, y, 28, 28))
		ScreenPack.text(_tab_box, str(i + 1), Rect2(1234, y, 28, 28), 15, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var line := ScreenPack.text(_tab_box, relic_tier_text(hero, i), Rect2(1270, y - 1, 584, 30), 17,
			UiKit.INK if i < tier else UiKit.TEXT_SOFT)
		line.tooltip_text = "Palier %d : %s" % [i + 1, relic_tier_text(hero, i)]
		line.mouse_filter = Control.MOUSE_FILTER_PASS
	if not cost.is_empty():
		var label := "Retrouver" if tier == 0 else "Améliorer"
		var b := ScreenPack.button(_tab_box, F, "upgrade", "%s · %d fragments%s" % [label, need,
			"" if int(cost.materials) == 0 else " + %d matériaux" % int(cost.materials)], Rect2(1234, 956, 620, 66), 24, UiKit.INK)
		b.disabled = not PlayerData.can_upgrade_relic(id)
		b.pressed.connect(func() -> void:
			if PlayerData.upgrade_relic(id):
				ui_sound.emit("ultimate_impact")
				_preview.play("cheer"))


## Les Échos (doublons du même héros) : paliers 1, 3, 6, 9, 12 et leurs gains de statistiques.
func _fill_echoes(id: String, hero: Dictionary) -> void:
	var rows: Array = ScreenPack.layout(F).echoes.row_rects
	var e: Dictionary = GameData.progression.get("echoes", {})
	var tier := PlayerData.hero_echo_tier(id)
	var thresholds: Array = e.get("thresholds", [])
	var unlocks: Array = e.get("unlocks", [])
	for k in mini(thresholds.size(), rows.size()):
		var r := ScreenPack.rect(rows[k])
		var reached := tier > k
		ScreenPack.image(_tab_box, ScreenPack.tex(F, "echo_full" if reached else "echo_empty"), Rect2(r.position + Vector2(0, 2), Vector2(36, 36)))
		var col := UiKit.INK if reached else UiKit.TEXT_SOFT
		ScreenPack.text(_tab_box, "%d Échos · %s" % [int(thresholds[k]), unlocks[k] if k < unlocks.size() else ""],
			Rect2(r.position + Vector2(44, 0), Vector2(300, r.size.y)), 19, col)
		ScreenPack.text(_tab_box, "+%d %% %s, +%d %% %s, +%d %% autres" % [int(float(e.primary[k]) * 100), hero.get("primary", ""),
			int(float(e.secondary[k]) * 100), hero.get("secondary", ""), int(float(e.other[k]) * 100)],
			Rect2(r.position + Vector2(350, 0), Vector2(300, r.size.y)), 17, col)
		# Bonus de compétence propre au héros à ce palier.
		var mods: Array = Progression.personal(hero, GameData.progression).get("echoes", [])
		var bonus := ""
		if k < mods.size():
			bonus = " · ".join((mods[k] as Array).map(func(m: Dictionary) -> String: return String(m.get("text", ""))))
		var bl := ScreenPack.text(_tab_box, bonus, Rect2(r.position + Vector2(660, 0), Vector2(r.size.x - 660, r.size.y)), 17,
			UiKit.WOOD if reached else UiKit.TEXT_SOFT)
		bl.tooltip_text = bonus
		bl.mouse_filter = Control.MOUSE_FILTER_PASS
	ScreenPack.text(_tab_box, "Un doublon donne un Écho. Aucune autre source.", Rect2(780, 998, 1072, 30), 19, UiKit.TEXT_SOFT)


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
