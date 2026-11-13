class_name ProfileScreen
extends UiWindow
## Profil du chasseur : son héros fétiche, son nom et celui de sa loge (modifiables), son niveau,
## ses statistiques et son équipe de chasse.

signal ui_sound(sfx_name: String)

var _avatar_box: CenterContainer
var _level_label: Label
var _name_label: Label
var _lodge_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _edit_box: VBoxContainer
var _name_edit: LineEdit
var _lodge_edit: LineEdit
var _edit_error: Label
var _view_box: VBoxContainer
var _picker: GridContainer
var _stats: GridContainer
var _team: HBoxContainer
var _badges: HBoxContainer

# Succès : [titre, explication, icône, condition (Callable sur PlayerData)]
const BADGES := [
	["Premier sang", "Gagner une chasse", "chasses"],
	["Sans faute", "Gagner une chasse avec 3 étoiles", "classement"],
	["Invocateur", "Faire une invocation", "autel"],
	["Collectionneur", "Réveiller 5 héros", "heros"],
	["Fidèle", "Venir au port 7 jours", "primes"],
]


func _init() -> void:
	setup("Profil du chasseur", Vector2(1260, 800), Color("505e75"))


var _album: AlbumScreen


func _ready() -> void:
	super._ready()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	content.add_child(body)

	# --- Colonne de gauche : le chasseur -------------------------------------------
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_stylebox_override("panel", UiKit.card())
	body.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(lv)
	_avatar_box = CenterContainer.new()
	_avatar_box.custom_minimum_size = Vector2(0, 230)
	lv.add_child(_avatar_box)
	var change := UiKit.button("Changer de héros", "wood", 20, Vector2(0, 52))
	change.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_picker.visible = not _picker.visible
		_view_box.visible = not _picker.visible)
	lv.add_child(change)
	_picker = GridContainer.new()
	_picker.columns = 3
	_picker.add_theme_constant_override("h_separation", 14)
	_picker.add_theme_constant_override("v_separation", 14)
	_picker.visible = false
	lv.add_child(_picker)

	_view_box = VBoxContainer.new()
	_view_box.add_theme_constant_override("separation", 6)
	lv.add_child(_view_box)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	_view_box.add_child(name_row)
	_name_label = UiKit.label("", 36, UiKit.TEXT_ON_PARCHMENT)
	_name_label.add_theme_font_override("font", UiKit.FONT_BOLD)
	name_row.add_child(_name_label)
	var pencil := UiKit.button("✎", "gold", 24, Vector2(52, 52))
	pencil.tooltip_text = "Changer de nom"
	pencil.pressed.connect(func() -> void: _set_editing(true))
	name_row.add_child(pencil)
	_lodge_label = UiKit.label("", 22, UiKit.TEXT_SOFT)
	_lodge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_box.add_child(_lodge_label)
	_xp_bar = UiKit.progress(Color("63c8be"), 24)
	_view_box.add_child(_xp_bar)
	_xp_label = UiKit.label("", 18, UiKit.TEXT_SOFT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_box.add_child(_xp_label)

	_edit_box = VBoxContainer.new()
	_edit_box.add_theme_constant_override("separation", 8)
	_edit_box.visible = false
	lv.add_child(_edit_box)
	_edit_box.add_child(UiKit.label("Ton nom", 20, UiKit.TEXT_SOFT))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_edit_box.add_child(_name_edit)
	_edit_box.add_child(UiKit.label("Nom de ta loge", 20, UiKit.TEXT_SOFT))
	_lodge_edit = LineEdit.new()
	_lodge_edit.max_length = 24
	_edit_box.add_child(_lodge_edit)
	_edit_error = UiKit.label("", 17, Color("b8462e"))
	_edit_box.add_child(_edit_error)
	var edit_row := HBoxContainer.new()
	edit_row.add_theme_constant_override("separation", 10)
	_edit_box.add_child(edit_row)
	var cancel := UiKit.button("Annuler", "grey", 20, Vector2(150, 54))
	cancel.pressed.connect(func() -> void: _set_editing(false))
	edit_row.add_child(cancel)
	var ok := UiKit.button("Valider", "green", 20, Vector2(0, 54))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_save_names)
	edit_row.add_child(ok)

	# --- Colonne de droite : statistiques et équipe ---------------------------------
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	right.add_child(_section_title("Statistiques"))
	_stats = GridContainer.new()
	_stats.columns = 3
	_stats.add_theme_constant_override("h_separation", 12)
	_stats.add_theme_constant_override("v_separation", 12)
	right.add_child(_stats)
	right.add_child(_section_title("Équipe de chasse"))
	_team = HBoxContainer.new()
	_team.add_theme_constant_override("separation", 12)
	right.add_child(_team)
	right.add_child(_section_title("Succès"))
	_badges = HBoxContainer.new()
	_badges.add_theme_constant_override("separation", 12)
	right.add_child(_badges)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())
	if FinPack.available(PF_DIR):
		_build_desk()
	_album = AlbumScreen.new()
	_album.ui_sound.connect(func(n: String) -> void: ui_sound.emit(n))
	add_child(_album)


func open() -> void:
	super.open()
	_picker.visible = false
	_view_box.visible = true
	_set_editing(false)
	refresh()


func refresh() -> void:
	if _desk:
		_desk_picker.visible = false
		_fill_desk()
	for c in _avatar_box.get_children():
		c.queue_free()
	var avatar := PlayerData.avatar()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(220, 220)
	_avatar_box.add_child(holder)
	if avatar != "":
		holder.add_child(RoundPortrait.new().setup(GameData.hero(avatar), 220, 0.06))
	var lvl := PanelContainer.new()
	var lsb := UiKit.box(Color("c6a66c"), UiKit.INK, 32, 4)
	lsb.border_width_bottom = 8
	lsb.content_margin_left = 14
	lsb.content_margin_right = 14
	lvl.add_theme_stylebox_override("panel", lsb)
	lvl.position = Vector2(-4, 150)
	_level_label = UiKit.title(str(PlayerData.level()), 40)
	lvl.add_child(_level_label)
	holder.add_child(lvl)

	_name_label.text = PlayerData.player_name()
	_lodge_label.text = PlayerData.lodge_name()
	_xp_bar.max_value = maxf(1.0, PlayerData.xp_to_next())
	_xp_bar.value = PlayerData.xp()
	_xp_label.text = "Niveau %d  ·  %d / %d XP" % [PlayerData.level(), PlayerData.xp(), PlayerData.xp_to_next()]

	for c in _picker.get_children():
		c.queue_free()
	for id: String in PlayerData.owned_heroes():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(108, 108)
		var p := RoundPortrait.new().setup(GameData.hero(id), 100, 0.1 if id == avatar else 0.05)
		p.position = Vector2(4, 4)
		b.add_child(p)
		var hero_id := id
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			PlayerData.set_avatar(hero_id)
			_picker.visible = false
			_view_box.visible = true)
		_picker.add_child(b)

	for c in _stats.get_children():
		c.queue_free()
	var stats := [
		["heros", str(PlayerData.owned_heroes().size()) + " / " + str(GameData.heroes.size()), "Héros réveillés"],
		["chasses", str(PlayerData.stat("hunts_won")), "Chasses gagnées"],
		["classement", str(PlayerData.total_stars()), "Étoiles gagnées"],
		["autel", str(int(PlayerData.state.get("summon_count", 0))), "Invocations"],
		["or", _fmt(PlayerData.stat("gold_earned")), "Or gagné"],
		["primes", str(maxi(1, PlayerData.stat("days_played"))), "Jours au port"],
	]
	for s: Array in stats:
		_stats.add_child(_stat_card(s[0], s[1], s[2]))

	for c in _team.get_children():
		c.queue_free()
	for id: String in PlayerData.team():
		var hero := GameData.hero(id)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.custom_minimum_size = Vector2(170, 0)
		var pc := CenterContainer.new()
		pc.add_child(RoundPortrait.new().setup(hero, 104))
		col.add_child(pc)
		var n := UiKit.label(String(hero.get("short", hero.name)), 20, UiKit.TEXT_ON_PARCHMENT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var l := UiKit.label("Niv. %d" % PlayerData.hero_level(id), 17, UiKit.TEXT_SOFT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		_team.add_child(col)

	for c in _badges.get_children():
		c.queue_free()
	for i in BADGES.size():
		_badges.add_child(_badge(i))


func _badge_unlocked(index: int) -> bool:
	match index:
		0: return PlayerData.stat("hunts_won") >= 1
		1: return PlayerData.total_stars() >= 3
		2: return int(PlayerData.state.get("summon_count", 0)) >= 1
		3: return PlayerData.owned_heroes().size() >= 5
		4: return PlayerData.stat("days_played") >= 7
	return false


func _badge(index: int) -> Control:
	var info: Array = BADGES[index]
	var on := _badge_unlocked(index)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(108, 0)
	col.tooltip_text = "%s : %s" % [info[0], info[1]]
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	var medal := PanelContainer.new()
	var sb := UiKit.box(Color("c6a66c") if on else Color("cfc6b8"), UiKit.INK if on else Color("9b9286"), 40, 4)
	sb.border_width_bottom = 8
	sb.set_content_margin_all(10)
	medal.add_theme_stylebox_override("panel", sb)
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UiKit.icon(info[2], 52)
	if not on:
		ic.modulate = Color(0.35, 0.33, 0.3, 0.6)
	medal.add_child(ic)
	col.add_child(medal)
	var l := UiKit.label(info[0], 16, UiKit.TEXT_ON_PARCHMENT if on else UiKit.TEXT_SOFT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col


func _stat_card(icon_name: String, value: String, caption: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(UiKit.icon(icon_name, 54))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	h.add_child(v)
	var big := UiKit.label(value, 32, UiKit.TEXT_ON_PARCHMENT)
	big.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(big)
	v.add_child(UiKit.label(caption, 17, UiKit.TEXT_SOFT))
	return card


func _section_title(text: String) -> Label:
	var l := UiKit.label(text, 26, UiKit.WOOD)
	l.add_theme_font_override("font", UiKit.FONT_BOLD)
	return l


func _set_editing(on: bool) -> void:
	_edit_box.visible = on
	_view_box.visible = not on
	_edit_error.text = ""
	if on:
		_picker.visible = false
		_name_edit.text = PlayerData.player_name()
		_lodge_edit.text = PlayerData.lodge_name()


func _save_names() -> void:
	if PlayerData.rename(_name_edit.text, _lodge_edit.text):
		ui_sound.emit("ui_ready")
		_set_editing(false)
	else:
		ui_sound.emit("ui_toggle")
		_edit_error.text = "Nom : 3 à 16 lettres. Loge : 3 à 24 lettres."


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


# --- Le bureau du chasseur (pack « Finitions ») -------------------------------------------------

## Bureau en plein écran (assets/ui/finitions/profil/) : portrait dans un cadre qui s'embellit avec le
## niveau (toucher = changer de héros), nom et loge modifiables dans leurs cartouches, 6 plaques de
## statistiques, mur de 12 trophées (verrouillés tant que l'exploit n'est pas fait).
const PF_DIR := "profil"
## Trophées du mur : id du pack -> [nom, exploit]
const TROPHIES := {
	"lames": ["Premier sang", "Gagner une chasse."], "couronne_slime": ["Roi des slimes", "Gagner 25 chasses."],
	"ancre": ["Fidèle au port", "Venir au port 7 jours."], "dragon": ["Tueur de boss", "Vaincre le boss du monde 1."],
	"bouclier": ["Sans faute", "Gagner 3 étoiles."], "grimoire": ["Érudit", "Réveiller 5 héros."],
	"lanterne": ["Invocateur", "Faire une invocation."], "gemme": ["Collectionneur", "Réveiller 10 héros."],
	"relique": ["Gardien des reliques", "Ouvrir les reliques (finir la Campagne 1)."],
	"calice": ["Maître chasseur", "Gagner 60 étoiles."], "forteresse": ["Conquérant", "Vaincre le boss du monde 5."],
	"sablier": ["Vétéran", "Venir au port 30 jours."]}
const FRAME_LEVELS := [[60, "mythique"], [50, "legendaire"], [40, "epique"], [30, "rare"], [20, "inhabituel"], [10, "commun"]]

var _desk: Control
var _desk_box: Control
var _desk_picker: Control
var _desk_name: LineEdit
var _desk_lodge: LineEdit


func _build_desk() -> void:
	_desk = Control.new()
	_desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desk.mouse_filter = Control.MOUSE_FILTER_STOP
	_desk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_desk)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desk.add_child(bg)
	var root := ScreenPack.frame(_desk)
	var D := FinPack.data(PF_DIR)
	var P: Dictionary = D.get("positions", {})
	FinPack.image(root, String(D.get("background", "profil/bureau_chasseur.png")), Rect2(0, 0, 1920, 1080))
	var tr := FinPack.rect(P.titre)
	FinPack.nine(root, "profil/commun/bandeau_titre.png", tr, [130, 24, 130, 28])
	ScreenPack.shadow(ScreenPack.text(root, "PROFIL DU CHASSEUR", Rect2(tr.position + Vector2(0, 24), Vector2(tr.size.x, 36)), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var back := FinPack.button(root, "profil/commun/retour", FinPack.rect(P.retour), "Port", 26)
	back.get_node("Label").position.x = 30
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		close_window())
	# Album des monstres : même bouton, en miroir à droite.
	var rr := FinPack.rect(P.retour)
	var album_btn := FinPack.button(root, "profil/commun/retour", Rect2(1920 - rr.end.x, rr.position.y, rr.size.x, rr.size.y), "Album", 26)
	album_btn.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_album.open())
	# Nom et loge : cartouches où l'on écrit directement (Entrée ou clic ailleurs pour garder).
	for k: String in ["nom", "loge"]:
		FinPack.nine(root, "profil/cartouches/%s.png" % k, FinPack.rect(P[k]), [62, 26, 62, 26])
		var e := LineEdit.new()
		var er := FinPack.rect(P[k + "_texte"])
		e.position = er.position
		e.size = er.size
		e.flat = true
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.add_theme_font_override("font", UiKit.FONT_BOLD)
		e.add_theme_font_size_override("font_size", 28 if k == "nom" else 19)
		e.add_theme_color_override("font_color", UiKit.WHITE if k == "nom" else UiKit.INK)
		e.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		e.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		e.max_length = 16 if k == "nom" else 24
		e.tooltip_text = "Toucher pour renommer"
		e.text_submitted.connect(func(_t: String) -> void: e.release_focus())
		e.focus_exited.connect(_desk_rename)
		root.add_child(e)
		if k == "nom":
			_desk_name = e
		else:
			_desk_lodge = e
	_desk_box = Control.new()
	_desk_box.size = Vector2(1920, 1080)
	_desk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_desk_box)
	root.move_child(_desk_box, 2)
	_desk_picker = Control.new()
	_desk_picker.visible = false
	root.add_child(_desk_picker)


func _desk_rename() -> void:
	if _desk_name.text == PlayerData.player_name() and _desk_lodge.text == PlayerData.lodge_name():
		return
	if PlayerData.rename(_desk_name.text, _desk_lodge.text):
		ui_sound.emit("ui_ready")
	else:
		ui_sound.emit("ui_toggle")
		_desk_name.text = PlayerData.player_name()
		_desk_lodge.text = PlayerData.lodge_name()


func _trophy_unlocked(id: String) -> bool:
	var won := func(d: String) -> bool: return int(PlayerData.state.get("dungeons", {}).get(d, {}).get("stars", 0)) > 0
	match id:
		"lames": return PlayerData.stat("hunts_won") >= 1
		"couronne_slime": return PlayerData.stat("hunts_won") >= 25
		"ancre": return PlayerData.stat("days_played") >= 7
		"dragon": return won.call("monde01_8")
		"bouclier": return PlayerData.total_stars() >= 3
		"grimoire": return PlayerData.owned_heroes().size() >= 5
		"lanterne": return int(PlayerData.state.get("summon_count", 0)) >= 1
		"gemme": return PlayerData.owned_heroes().size() >= 10
		"relique": return PlayerData.relics_unlocked()
		"calice": return PlayerData.total_stars() >= 60
		"forteresse": return won.call("monde05_8")
		"sablier": return PlayerData.stat("days_played") >= 30
	return false


func _fill_desk() -> void:
	for c in _desk_box.get_children():
		_desk_box.remove_child(c)
		c.queue_free()
	var D := FinPack.data(PF_DIR)
	var P: Dictionary = D.get("positions", {})
	_desk_name.text = PlayerData.player_name()
	_desk_lodge.text = PlayerData.lodge_name()
	# Portrait et cadre selon le niveau.
	var frame := "base"
	for fl: Array in FRAME_LEVELS:
		if PlayerData.level() >= int(fl[0]):
			frame = fl[1]
			break
	var ar := FinPack.rect(P.avatar)
	var avatar := PlayerData.avatar()
	if avatar != "":
		var p := RoundPortrait.new().setup(GameData.hero(avatar), ar.size.x, 0.0)
		p.position = ar.position
		_desk_box.add_child(p)
	var pr := FinPack.rect(P.portrait)
	var fr := FinPack.image(_desk_box, String(D.frames[frame].file), pr)
	fr.mouse_filter = Control.MOUSE_FILTER_STOP
	fr.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fr.tooltip_text = "Changer de héros"
	fr.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			ui_sound.emit("ui_click")
			_desk_picker.visible = not _desk_picker.visible
			_fill_desk_picker())
	ScreenPack.shadow(ScreenPack.text(_desk_box, "Niveau %d" % PlayerData.level(), Rect2(pr.position + Vector2(0, pr.size.y - 6),
		Vector2(pr.size.x, 30)), 22, Color("ffd27a"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	# Statistiques.
	var values := {"combats_gagnes": ["Combats gagnés", str(PlayerData.stat("hunts_won"))],
		"heros": ["Héros recrutés", "%d / %d" % [PlayerData.owned_heroes().size(), GameData.heroes.size()]],
		"etoiles": ["Étoiles obtenues", str(PlayerData.total_stars())],
		"chasses": ["Chasses terminées", str(PlayerData.state.get("dungeons", {}).size())],
		"invocations": ["Invocations", str(int(PlayerData.state.get("summon_count", 0)))],
		"niveau_loge": ["Niveau de la loge", str(PlayerData.level())]}
	for s: Dictionary in D.get("stats", []):
		FinPack.nine(_desk_box, String(s.asset), FinPack.rect(s.rect), [62, 26, 62, 26])
		var v: Array = values.get(String(s.id), [String(s.id), ""])
		ScreenPack.text(_desk_box, v[0], FinPack.rect(s.label_rect), 20, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.shadow(ScreenPack.text(_desk_box, v[1], FinPack.rect(s.value_rect), 28, Color("ffd27a"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	# Mur des trophées.
	var got := 0
	for t: Dictionary in D.get("trophies", []):
		var id := String(t.id)
		var on := _trophy_unlocked(id)
		got += 1 if on else 0
		var ti := FinPack.image(_desk_box, String(t.states["debloque" if on else "verrouille"]), FinPack.rect(t.rect))
		ti.mouse_filter = Control.MOUSE_FILTER_STOP
		var info: Array = TROPHIES.get(id, [id, ""])
		var tr2 := FinPack.rect(t.rect)
		ScreenPack.shadow(ScreenPack.text(_desk_box, info[0], Rect2(tr2.position.x - 50, tr2.end.y + 2, tr2.size.x + 100, 24), 16,
			Color("f3d9a0") if on else Color("a89d8e"), HORIZONTAL_ALIGNMENT_CENTER), 2)
		ti.tooltip_text = "%s\n%s%s" % [info[0], info[1], "" if on else "  (à faire)"]
	ScreenPack.shadow(ScreenPack.text(_desk_box, "TROPHÉES · %d / %d" % [got, D.get("trophies", []).size()],
		FinPack.rect(P.trophees_titre), 30, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)


## Choix du héros fétiche : une planche de portraits posée sur le mur des trophées.
func _fill_desk_picker() -> void:
	for c in _desk_picker.get_children():
		c.queue_free()
	if not _desk_picker.visible:
		return
	var owned := PlayerData.owned_heroes()
	var cols := 6
	var rows := ceili(owned.size() / float(cols))
	var r := Rect2(960, 170, 830, 120 + rows * 124)
	FinPack.nine(_desk_picker, "profil/commun/parchemin.png", r, [140, 24, 140, 24])
	ScreenPack.text(_desk_picker, "Ton héros fétiche", Rect2(r.position + Vector2(0, 26), Vector2(r.size.x, 34)), 24,
		Color("793b49"), HORIZONTAL_ALIGNMENT_CENTER)
	for i in owned.size():
		var id: String = owned[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = r.position + Vector2(55 + (i % cols) * 124, 74 + (i / cols) * 124)
		b.size = Vector2(110, 110)
		b.tooltip_text = String(GameData.hero(id).get("name", id))
		b.add_child(RoundPortrait.new().setup(GameData.hero(id), 104, 0.1 if id == PlayerData.avatar() else 0.05))
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			PlayerData.set_avatar(id)
			_desk_picker.visible = false
			_fill_desk())
		_desk_picker.add_child(b)
