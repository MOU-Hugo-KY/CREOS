class_name CampaignScreen
extends UiWindow
## « Table des chasses » : les 10 mondes de l'acte I et leurs 8 niveaux. À gauche les mondes
## (verrouillés tant que le premier niveau n'est pas ouvert), à droite le décor du monde choisi et
## ses niveaux avec leurs étoiles. Un niveau s'ouvre quand on a gagné celui d'avant.

signal hunt_chosen(dungeon_id: String)
signal ui_sound(sfx_name: String)

var region := ""
var _worlds: VBoxContainer
var _banner: TextureRect
var _world_name: Label
var _world_info: Label
var _levels: GridContainer


func _init() -> void:
	setup("Table des chasses", Vector2(1560, 900))


func _ready() -> void:
	super._ready()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	content.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_worlds = VBoxContainer.new()
	_worlds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_worlds.add_theme_constant_override("separation", 8)
	scroll.add_child(_worlds)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var frame := PanelContainer.new()
	var fsb := UiKit.box(UiKit.INK, UiKit.INK, 14, 3)
	frame.add_theme_stylebox_override("panel", fsb)
	right.add_child(frame)
	_banner = TextureRect.new()
	_banner.custom_minimum_size = Vector2(0, 250)
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_banner.clip_contents = true
	frame.add_child(_banner)
	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_END
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(over)
	_world_name = UiKit.title("", 40)
	_world_name.add_theme_constant_override("outline_size", 12)
	over.add_child(_world_name)
	_world_info = UiKit.label("", 20, UiKit.WHITE, 6, UiKit.INK)
	over.add_child(_world_info)
	_levels = GridContainer.new()
	_levels.columns = 4
	_levels.add_theme_constant_override("h_separation", 14)
	_levels.add_theme_constant_override("v_separation", 14)
	right.add_child(_levels)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())
	if FinPack.available(TC):
		_build_map()


## Ouvre la carte sur le monde où en est le joueur.
func open_current() -> void:
	var current := PlayerData.current_campaign_level()
	region = String(GameData.dungeon(current).get("region", GameData.region_ids()[0]))
	open()
	refresh()


func refresh() -> void:
	if _map:
		if region == "":
			region = String(GameData.dungeon(PlayerData.current_campaign_level()).get("region", GameData.region_ids()[0]))
		_fill_map()
		return
	for c in _worlds.get_children():
		c.queue_free()
	for rid: String in GameData.region_ids():
		_worlds.add_child(_world_button(rid))
	var info: Dictionary = GameData.regions.get(region, {})
	var fond := String(info.get("decor", "")) + "fond1.png"
	_banner.texture = load(fond) if ResourceLoader.exists(fond) else null
	_world_name.text = "Monde %d · %s" % [int(info.get("order", 0)), info.get("name", "")]
	var ids := GameData.region_dungeons(region)
	var stars := 0
	for id: String in ids:
		stars += PlayerData.best_stars(id)
	_world_info.text = "%d niveaux · %d / %d étoiles" % [ids.size(), stars, ids.size() * 3]
	for c in _levels.get_children():
		c.queue_free()
	for id: String in ids:
		_levels.add_child(_level_card(id))


func _world_button(rid: String) -> Button:
	var info: Dictionary = GameData.regions[rid]
	var ids := GameData.region_dungeons(rid)
	var open := not ids.is_empty() and PlayerData.dungeon_unlocked(ids[0])
	var stars := 0
	for id: String in ids:
		stars += PlayerData.best_stars(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 74)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "  %d · %s\n      %s" % [int(info.order), info.name, ("★ %d / %d" % [stars, ids.size() * 3]) if open else "🔒 verrouillé"]
	var active := rid == region
	var kind := "danger" if active else ("secondary" if open else "disabled")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := UiKit.kit("button_%s_%s" % [kind, "normal" if st == "disabled" else st], Color.WHITE, true)
		sb.content_margin_left = 14
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 19)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(st, UiKit.WHITE)
	b.disabled = not open
	b.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		region = rid
		refresh())
	return b


func _level_card(id: String) -> Control:
	var d := GameData.dungeon(id)
	var open := PlayerData.dungeon_unlocked(id)
	var stars := PlayerData.best_stars(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := id == PlayerData.current_campaign_level()
	var sb := UiKit.card(UiKit.TEAL if current else Color.TRANSPARENT)
	if not open:
		sb.modulate_color = Color(0.72, 0.68, 0.62)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not open
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 16
	v.offset_right = -24
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var level := int(d.get("level", 0))
	var t := UiKit.label("Niveau %d%s" % [level, "  ·  BOSS" if level == 8 else ""], 22, UiKit.INK)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(t)
	var waves: Array = d.get("waves", [])
	var boss_id := String(waves[-1][1]) if not waves.is_empty() and waves[-1].size() > 1 else ""  # [n, boss, n]
	var boss := String(GameData.monsters.get(boss_id, {}).get("name", ""))
	var bl := UiKit.label(boss if open else "???", 18, UiKit.TEXT_SOFT)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bl)
	v.add_child(UiKit.label("★".repeat(stars) + "☆".repeat(3 - stars) if open else "🔒", 24, UiKit.WOOD_LIGHT if open else UiKit.TEXT_SOFT))
	v.add_child(UiKit.label("⚡ %d énergie" % int(d.get("energy_cost", 0)), 16, UiKit.SLATE))
	b.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		hunt_chosen.emit(id))
	return b


# --- La salle du cartographe (pack « Finitions ») ------------------------------------------------

## La carte de CREOS déroulée sur la table (assets/ui/finitions/table_chasses/) : 10 régions, les
## verrouillées sous le brouillard, la région choisie éclairée, ses 8 niveaux en marqueurs le long
## du chemin (étoiles gagnées, boss), un pion sur le niveau en cours. Le parchemin de droite décrit
## le niveau choisi ; « Chasser » mène à la préparation.
const TC := "table_chasses"
const TC_REWARD_ICONS := {"gold": "or", "gems": "gemme", "fragments_relique": "eclat", "materiaux_relique": "fragment_relique"}

var _map: Control
var _map_box: Control
var _pick := ""  # niveau choisi


func _build_map() -> void:
	_map = Control.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_map)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.add_child(bg)
	var root := ScreenPack.frame(_map)
	var D := FinPack.data(TC)
	var P: Dictionary = D.get("positions", {})
	FinPack.image(root, String(D.get("background", "table_chasses/carte_monde.png")), Rect2(0, 0, 1920, 1080))
	_map_box = Control.new()
	_map_box.size = Vector2(1920, 1080)
	_map_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_map_box)
	var tr := FinPack.rect(P.titre)
	FinPack.nine(root, "table_chasses/commun/bandeau_titre.png", tr, [130, 24, 130, 28])
	ScreenPack.shadow(ScreenPack.text(root, "TABLE DES CHASSES", Rect2(tr.position + Vector2(0, 24), Vector2(tr.size.x, 36)), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var back := FinPack.button(root, "table_chasses/commun/retour", FinPack.rect(P.retour), "Port", 26)
	back.get_node("Label").position.x = 30
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		region = ""
		close_window())


func _fill_map() -> void:
	for c in _map_box.get_children():
		_map_box.remove_child(c)
		c.queue_free()
	var D := FinPack.data(TC)
	var P: Dictionary = D.get("positions", {})
	var M: Dictionary = D.get("marqueurs", {})
	var current := PlayerData.current_campaign_level()
	# Énergie.
	var mr := FinPack.rect(P.monnaie)
	FinPack.nine(_map_box, "table_chasses/commun/cartouche_monnaie.png", mr, [74, 18, 22, 18])
	FinPack.image(_map_box, "table_chasses/icones/energie.png", Rect2(mr.position + Vector2(14, 12), Vector2(48, 48)))
	ScreenPack.shadow(ScreenPack.text(_map_box, "%d / %d" % [PlayerData.energy(), PlayerData.energy_max()],
		Rect2(mr.position + Vector2(66, 0), mr.size - Vector2(80, 0)), 28, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var rids := GameData.region_ids()
	if _pick == "" or GameData.dungeon(_pick).get("region", "") != region:
		_pick = current if GameData.dungeon(current).get("region", "") == region else (GameData.region_dungeons(region)[0]
			if not GameData.region_dungeons(region).is_empty() else "")
	for reg: Dictionary in D.get("regions", []):
		var i := int(reg.monde) - 1
		if i < 0 or i >= rids.size():
			continue
		var rid: String = rids[i]
		var ids := GameData.region_dungeons(rid)
		var open := not ids.is_empty() and PlayerData.dungeon_unlocked(ids[0])
		var rr := FinPack.rect(reg.rect)
		var sel := rid == region
		if sel:
			FinPack.image(_map_box, String(reg.eclaire), rr)
		if open:
			FinPack.image(_map_box, String(reg.chemin), rr)
		else:
			FinPack.image(_map_box, String(reg.brouillard), rr)
		var info: Dictionary = GameData.regions.get(rid, {})
		# Nom du monde sur un petit cartouche, au-dessus des cartes de la ligne suivante.
		var lbl := ScreenPack.text(_map_box, "%d. %s" % [i + 1, info.get("name", reg.nom)],
			Rect2(rr.position.x - 14, rr.end.y - 26, rr.size.x + 28, 24), 15, Color("fff1cf") if sel else UiKit.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER)
		ScreenPack.shadow(lbl, 2)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color("793b49") if sel else Color("29262e"))
		lbl.z_index = 2
		var hit := Control.new()
		hit.position = rr.position
		hit.size = rr.size
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_FORBIDDEN
		hit.tooltip_text = String(info.get("name", reg.nom)) + ("" if open else " · verrouillé")
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if open and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				ui_sound.emit("ui_click")
				region = rid
				_pick = ""
				_fill_map())
		_map_box.add_child(hit)
		# Les 8 niveaux.
		var pts: Array = reg.get("chemin_points", [])
		for k in mini(pts.size(), ids.size()):
			var id: String = ids[k]
			var pt: Dictionary = pts[k]
			var lvl_open := PlayerData.dungeon_unlocked(id)
			var stars := PlayerData.best_stars(id)
			var key := "verrouille"
			if bool(pt.boss):
				key = "boss_vaincu" if stars > 0 else ("boss" if lvl_open else "verrouille")
			elif lvl_open:
				key = "gagne_%d_etoiles" % stars if stars > 0 else "ouvert"
			var mk: Dictionary = M.get(key, {})
			var r := FinPack.rect(pt.rect)
			if key == "verrouille" and bool(pt.boss):
				r = r.grow(-8)
			var m := FinPack.image(_map_box, String(mk.get("file", "")), r)
			if id == _pick:
				m.modulate = Color(1.4, 1.3, 0.9)
			if lvl_open:
				m.mouse_filter = Control.MOUSE_FILTER_STOP
				m.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				m.tooltip_text = String(GameData.dungeon(id).get("name", id))
				m.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						ui_sound.emit("ui_click")
						region = rid
						_pick = id
						_fill_map())
			if id == current:
				var a: Dictionary = D.get("animations", {}).get("pion_courant", {})
				var s := FinPack.sheet(a)
				s.scale = Vector2(0.5, 0.5)
				s.position = Vector2(pt.center[0], pt.center[1]) - Vector2(0, 10)
				_map_box.add_child(s)
				s.play("a")
	_fill_panel()


## Parchemin de droite : le niveau choisi.
func _fill_panel() -> void:
	var D := FinPack.data(TC)
	var P: Dictionary = D.get("positions", {})
	var pr := FinPack.rect(P.panneau_niveau)
	FinPack.nine(_map_box, "table_chasses/commun/parchemin.png", pr, [140, 50, 140, 50])
	var cr := FinPack.rect(P.contenu_panneau).grow_individual(-12, 0, -12, 0)  # marges dans le papier
	var go := FinPack.button(_map_box, "table_chasses/bouton_chasser", FinPack.rect(P.bouton_chasser), "Chasser", 30)
	if _pick == "":
		go.disabled = true
		return
	var d := GameData.dungeon(_pick)
	var info: Dictionary = GameData.regions.get(region, {})
	var at := [cr.position.y]  # hauteur courante (tableau : modifiable depuis la fonction ci-dessous)
	var line := func(text: String, size: int, color: Color, h: float) -> void:
		ScreenPack.text(_map_box, text, Rect2(cr.position.x, at[0], cr.size.x, h), size, color, HORIZONTAL_ALIGNMENT_CENTER, true)
		at[0] += h
	line.call(String(info.get("name", "")), 22, Color("793b49"), 40)
	line.call("Niveau %d%s" % [int(d.get("level", 0)), " · BOSS" if int(d.get("level", 0)) == 8 else ""], 20, UiKit.INK, 34)
	var waves: Array = d.get("waves", [])
	var foes := {}
	for w: Array in waves:
		for m: String in w:
			foes[String(GameData.monsters.get(m, {}).get("name", m))] = true
	at[0] += 10
	line.call("Ennemis", 22, Color("793b49"), 32)
	line.call(", ".join(foes.keys().slice(0, 4)), 17, UiKit.INK, 70)
	line.call("Récompenses", 22, Color("793b49"), 34)
	var x := cr.position.x + 10
	var shown := 0
	var rewards: Dictionary = d.get("rewards", {})
	for key: String in rewards:
		if not TC_REWARD_ICONS.has(key) or shown >= 4:
			continue
		var ic := FinPack.image(_map_box, "table_chasses/icones/%s.png" % TC_REWARD_ICONS[key], Rect2(x, at[0], 44, 44))
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		ic.tooltip_text = "%d" % int(rewards[key])
		ScreenPack.text(_map_box, str(int(rewards[key])), Rect2(x - 10, at[0] + 44, 64, 24), 16, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		x += 64
		shown += 1
	at[0] += 80
	var stars := PlayerData.best_stars(_pick)
	for k in 3:
		FinPack.image(_map_box, "table_chasses/icones/etoile_%s.png" % ("pleine" if k < stars else "vide"),
			Rect2(cr.get_center().x - 78 + k * 52, at[0], 48, 48))
	at[0] += 60
	line.call("Énergie : %d" % PlayerData.hunt_cost(_pick), 20, UiKit.INK, 30)
	at[0] += 14
	line.call("Vagues : %d" % waves.size(), 18, UiKit.INK, 28)
	line.call("Ta Force d'équipe : %d" % PlayerData.team_power(), 18, UiKit.INK, 28)
	if int(d.get("level", 0)) == 8:
		line.call("Boss : %s" % String(GameData.monsters.get(String(waves[-1][1]) if waves[-1].size() > 1 else "", {}).get("name", "?")),
			18, Color("793b49"), 52)
	var id := _pick
	go.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		hunt_chosen.emit(id))
