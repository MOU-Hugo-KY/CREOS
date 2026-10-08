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
	["spd", "Vitesse"], ["crit", "Critique"]]
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
	var icons := HBoxContainer.new()
	icons.name = "Icons"
	icons.add_theme_constant_override("separation", 6)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icons)
	for path: String in ["classe_%s_32" % CLASS_KEYS.get(hero.get("class"), "blade"), "element_%s_32" % elem]:
		var ic := TextureRect.new()
		ic.texture = ScreenPack.tex(F, path)
		ic.custom_minimum_size = Vector2(32, 32)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(ic)
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
	var icons: Control = card.get_node("Icons")
	icons.position = Vector2(w - 98, h - 82)
	if card.has_node("Team"):
		var t: Control = card.get_node("Team")
		t.position = Vector2(w - t.size.x - 22, 22)

func _build_detail(_page: VBoxContainer) -> void:
	# Fiche d'un héros : pièces pixel du pack partie 2 (assets/ui/ecrans/fiche_heros), placées
	# d'après fiche_heros.json dans un repère 1920 × 1080.
	_detail = Control.new()
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail.visible = false
	add_child(_detail)
	var root := ScreenPack.frame(_detail)
	var L := ScreenPack.layout(F)
	var back := ScreenPack.button(root, F, "collection", "← Collection", Rect2(24, 8, 300, 96), 30)
	back.pressed.connect(_on_back)
	_d_title = ScreenPack.text(root, "", Rect2(355, 8, 900, 90), 48, UiKit.WHITE)
	_d_count = ScreenPack.text(root, "", Rect2(1460, 8, 420, 80), 28, UiKit.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	# Vitrine : salle d'armes de l'élément, socle, héros animé, identité, Échos, niveau.
	ScreenPack.panel(root, F, "vitrine_frame", ScreenPack.rect(L.vitrine_rect))
	_d_room = ScreenPack.image(root, null, ScreenPack.rect(L.background_rect))
	_d_socle = ScreenPack.image(root, null, ScreenPack.rect(L.pedestal_rect))
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	var br := ScreenPack.rect(L.background_rect)
	vpc.position = br.position
	vpc.size = Vector2(br.size.x, (L.hero_anchor[1] - br.position.y) / 0.86)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vpc)
	_preview = HeroPreview.new()
	_preview.pedestal = false
	_preview.zoom = 0.62
	vpc.add_child(_preview)
	_d_class = ScreenPack.image(root, null, ScreenPack.rect(L.class_badge_rect))
	_d_element = ScreenPack.image(root, null, ScreenPack.rect(L.element_badge_rect))
	var rr := ScreenPack.rect(L.rarity_rect)
	_d_rarity = ScreenPack.panel(root, F, "badge_rare", rr)
	_d_rarity_label = ScreenPack.text(root, "", rr, 22, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var tr := ScreenPack.rect(L.hero_type_rect)
	ScreenPack.panel(root, F, "hero_type_cartouche", tr)
	_d_role = ScreenPack.text(root, "", Rect2(tr.position + Vector2(26, 6), Vector2(tr.size.x - 50, 42)), 30, UiKit.WHITE)
	_d_species = ScreenPack.text(root, "", Rect2(tr.position + Vector2(26, 46), Vector2(tr.size.x - 50, 34)), 22, UiKit.PARCHMENT_DARK)
	for r: Array in L.echo_rects:
		_d_echoes.append(ScreenPack.image(root, ScreenPack.tex(F, "echo_empty"), ScreenPack.rect(r)))
	var er: Array = L.echo_rects[4]
	_d_echo_count = ScreenPack.text(root, "", Rect2(er[0] + 80, er[1], 260, er[3]), 28)
	_d_level = ScreenPack.text(root, "", ScreenPack.rect(L.level_rect), 30)
	_d_force = ScreenPack.text(root, "", ScreenPack.rect(L.force_rect), 30)
	var xr := ScreenPack.rect(L.xp_rect)
	var xp_bg := ScreenPack.panel(root, F, "xp_bg", xr)
	_d_xp = ScreenPack.panel(xp_bg, F, "xp_fill", Rect2(0, 3, xr.size.x, 12))
	_d_xp_text = ScreenPack.text(root, "", Rect2(xr.position + Vector2(0, 22), Vector2(xr.size.x, 30)), 20)
	_d_recruit = ScreenPack.text(root, "À recruter à la Lanterne des Serments", Rect2(82, 820, 580, 40), 24, UiKit.WOOD,
		HORIZONTAL_ALIGNMENT_CENTER)
	# Statistiques et actions.
	var sr := ScreenPack.rect(L.stats_rect)
	ScreenPack.panel(root, F, "stats_panel", sr)
	ScreenPack.text(root, "STATISTIQUES", Rect2(sr.position + Vector2(34, 30), Vector2(400, 44)), 32)
	for i in STAT_NAMES.size():
		var y := sr.position.y + 86 + i * 30
		ScreenPack.text(root, STAT_NAMES[i][1], Rect2(sr.position.x + 36, y, 400, 30), 25)
		_d_stats.append(ScreenPack.text(root, "", Rect2(sr.end.x - 436, y, 400, 30), 25, UiKit.INK, HORIZONTAL_ALIGNMENT_RIGHT))
	var A: Dictionary = L.actions
	_d_upgrade = ScreenPack.button(root, F, "upgrade", "", ScreenPack.rect(A.upgrade), 28, UiKit.INK)
	_d_upgrade.pressed.connect(_ask_level_up)
	var relic_b := ScreenPack.button(root, F, "relic_button", "Relique", ScreenPack.rect(A.relic), 28)
	relic_b.pressed.connect(func() -> void: _set_tab("Relique"))
	_d_team = ScreenPack.button(root, F, "team_button", "", ScreenPack.rect(A.team), 28)
	_d_team.pressed.connect(func() -> void:
		if PlayerData.toggle_team(selected):
			ui_sound.emit("ui_toggle"))
	# Onglets et contenu.
	var T: Dictionary = L.tabs
	for i in TABS.size():
		var t: String = TABS[i]
		var b := ScreenPack.button(root, F, "tab_inactive", t, ScreenPack.rect(T.rects[i]), 28)
		b.pressed.connect(func() -> void: _set_tab(t))
		_d_tabs.append(b)
	_path_panel = ScreenPack.panel(root, F, "stats_panel", ScreenPack.rect(L.stats_rect))
	_path_panel.z_index = 5
	_path_title = ScreenPack.text(_path_panel, "", Rect2(34, 26, 1076, 48), 32)
	for k in 5:
		_path_lines.append(ScreenPack.text(_path_panel, "", Rect2(34, 92 + k * 78, 1076, 72), 23, UiKit.INK, 0, true))
	_path_panel.visible = false
	var cr := ScreenPack.rect(L.content_rect)
	ScreenPack.panel(root, F, "content_panel", cr)
	_tab_box = Control.new()
	_tab_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_box.size = Vector2(1920, 1080)
	root.add_child(_tab_box)


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
	ScreenPack.text(_tab_box, "LES CINQ PALIERS", Rect2(1234, 770, 500, 40), 26)
	var steps: Array = R.step_rects
	for i in steps.size():
		var r := ScreenPack.rect(steps[i])
		if i > 0:
			var prev := ScreenPack.rect(steps[i - 1])
			var con := ScreenPack.panel(_tab_box, F, "relic_connector", Rect2(prev.end.x - 2, r.position.y + 32, r.position.x - prev.end.x + 4, 8))
			con.z_index = 0
		var st := "relic_step_full" if i < tier else ("relic_step_active" if i == tier else "relic_step_empty")
		ScreenPack.image(_tab_box, ScreenPack.tex(F, st), r)
		ScreenPack.text(_tab_box, str(i + 1), r, 28, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var bonus := "Palier 1 : la relique est retrouvée."
	if tier > 0:
		var tt: Dictionary = tiers[tier - 1]
		bonus = "+%d %% %s · +%d %% %s" % [int(float(tt.primary) * 100), hero.get("primary", ""),
			int(float(tt.secondary) * 100), hero.get("secondary", "")]
	ScreenPack.text(_tab_box, bonus, Rect2(1234, 912, 620, 32), 22)
	if not cost.is_empty():
		var label := "Retrouver" if tier == 0 else "Améliorer"
		var b := ScreenPack.button(_tab_box, F, "upgrade", "%s · %d fragments%s" % [label, need,
			"" if int(cost.materials) == 0 else " + %d matériaux" % int(cost.materials)], Rect2(1234, 950, 620, 72), 24, UiKit.INK)
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
		ScreenPack.text(_tab_box, "%d Échos · %s" % [int(thresholds[k]), unlocks[k] if k < unlocks.size() else ""],
			Rect2(r.position + Vector2(52, 0), Vector2(520, r.size.y)), 25, UiKit.INK if reached else UiKit.TEXT_SOFT)
		ScreenPack.text(_tab_box, "+%d %% %s, +%d %% %s, +%d %% autres" % [int(float(e.primary[k]) * 100), hero.get("primary", ""),
			int(float(e.secondary[k]) * 100), hero.get("secondary", ""), int(float(e.other[k]) * 100)],
			Rect2(r.position + Vector2(560, 0), Vector2(r.size.x - 560, r.size.y)), 21, UiKit.TEXT_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
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
