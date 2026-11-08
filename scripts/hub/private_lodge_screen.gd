class_name PrivateLodgeScreen
extends UiWindow
## « Ma Loge » : le donjon du joueur (règles dans `Lodge`, données dans data/lodge.json).
## Onglet « Mon donjon » : trois salles où poser des héros en défense et des pièges, la récompense mise
## en jeu, et un combat d'essai contre son propre donjon. Onglet « Chasseurs rivaux » : les donjons du
## jour à attaquer (seulement ceux au moins aussi forts que l'équipe), mise d'entrée et gain.

signal battle_requested
signal ui_sound(sfx_name: String)

const TAB_OWN := 0
const TAB_RIVALS := 1

var _tab := TAB_OWN
var _tabs: Array[Button] = []
var _summary: Label
var _stake_label: Label
var _body: VBoxContainer
var _picker: Control


func _init() -> void:
	setup(String(GameData.lodge.get("title", "Mon donjon")), Vector2(1500, 880), Color("793b49"))


func _ready() -> void:
	super._ready()
	content.add_theme_constant_override("separation", 12)
	var intro := UiKit.label(String(GameData.lodge.get("description", "")), 19, UiKit.TEXT_SOFT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	content.add_child(bar)
	for i in 2:
		var b := UiKit.button(["Mon donjon", "Chasseurs rivaux"][i], "blue", 22, Vector2(230, 54))
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			_tab = i
			refresh())
		bar.add_child(b)
		_tabs.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_summary = UiKit.label("", 21, UiKit.INK)
	_summary.add_theme_font_override("font", UiKit.FONT_BOLD)
	bar.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())
	if FinPack.available(ML):
		_build_crypt()


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	for i in _tabs.size():
		UiKit.style_button(_tabs[i], "red" if i == _tab else "blue", 22)
	_summary.text = "Force moyenne · donjon : %d   ·   ton équipe : %d" % [PlayerData.lodge_power(), PlayerData.team_power()]
	for c in _body.get_children():
		c.queue_free()
	if _crypt:
		_fill_crypt()
		return
	if _tab == TAB_OWN:
		_build_own()
	else:
		_build_rivals()


# --- Mon donjon ------------------------------------------------------------------------------

func _build_own() -> void:
	var cfg: Dictionary = GameData.lodge
	var l := PlayerData.lodge()
	var rooms := HBoxContainer.new()
	rooms.add_theme_constant_override("separation", 12)
	_body.add_child(rooms)
	for r in cfg.rooms.size():
		rooms.add_child(_room_card(r, cfg.rooms[r], l))

	# Récompense mise en jeu et combat d'essai
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UiKit.card(UiKit.WOOD_LIGHT))
	_body.add_child(foot)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	foot.add_child(h)
	h.add_child(UiKit.icon("or", 44))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_stake_label = UiKit.label("Récompense mise en jeu : %d or" % int(l.stake), 22, UiKit.INK)
	_stake_label.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(_stake_label)
	var share := int(round(float(cfg.get("win_share", 0.3)) * 100))
	var hint := UiKit.label("Un chasseur qui te bat en emporte %d %%. Bientôt en ligne : tu gagneras sa mise quand tu tiens bon." % share,
		17, UiKit.TEXT_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var step := int(cfg.get("stake_step", 500))
	for d in [-step, step]:
		var b := UiKit.button("%+d" % d, "gold" if d > 0 else "wood", 22, Vector2(96, 54))
		b.disabled = (d < 0 and int(l.stake) <= 0) or (d > 0 and PlayerData.gold() < d)
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			PlayerData.lodge_set_stake(int(PlayerData.lodge().stake) + d))
		h.add_child(b)
	var test := UiKit.button("Tester mon donjon", "green", 22, Vector2(260, 54))
	test.disabled = not Lodge.is_ready(l)
	test.tooltip_text = "Ton équipe de chasse affronte ton donjon (sans gain ni énergie)."
	test.pressed.connect(func() -> void: _start({}))
	h.add_child(test)


func _room_card(r: int, room: Dictionary, l: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var t := UiKit.label("Salle %d · %s" % [r + 1, room.name], 22, UiKit.WOOD)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(t)

	var defenders: Array = l.rooms[r]
	v.add_child(UiKit.label("Défenseurs  %d / %d" % [defenders.size(), int(room.defenders)], 18, UiKit.TEXT_SOFT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	v.add_child(grid)
	for i in int(room.defenders):
		if i < defenders.size():
			var id: String = defenders[i]
			grid.add_child(_hero_slot(id, func() -> void:
				ui_sound.emit("ui_click")
				PlayerData.lodge_remove_defender(r, id), "Retirer %s de la salle" % GameData.hero(id).name))
		else:
			grid.add_child(_empty_slot("slot_common", "+", func() -> void: _pick_defender(r)))

	var built: Array = l.defenses[r]
	v.add_child(UiKit.label("Défenses  %d / %d" % [built.size(), int(room.get("defenses", 1))], 18, UiKit.TEXT_SOFT))
	for i in int(room.get("defenses", 1)):
		if i < built.size():
			var did: String = built[i]
			var idx := i
			v.add_child(_defense_chip(did, func() -> void:
				ui_sound.emit("ui_click")
				PlayerData.lodge_remove_defense(r, idx)))
		else:
			var add_def := UiKit.button("Construire une défense", "blue", 18, Vector2(0, 46))
			add_def.pressed.connect(func() -> void: _pick_defense(r))
			v.add_child(add_def)

	var traps: Array = l.traps[r]
	v.add_child(UiKit.label("Pièges  %d / %d" % [traps.size(), int(room.traps)], 18, UiKit.TEXT_SOFT))
	for i in int(room.traps):
		if i < traps.size():
			var tid: String = traps[i]
			v.add_child(_trap_chip(tid, func() -> void:
				ui_sound.emit("ui_click")
				PlayerData.lodge_toggle_trap(r, tid)))
		else:
			var add := UiKit.button("Poser un piège", "wood", 18, Vector2(0, 46))
			add.pressed.connect(func() -> void: _pick_trap(r))
			v.add_child(add)
	return card


func _hero_slot(id: String, on_press: Callable, tip: String) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 108)
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var p := RoundPortrait.new().setup(GameData.hero(id), 80, 0.08)
	p.position = Vector2(4, 0)
	b.add_child(p)
	var n := UiKit.label(String(GameData.hero(id).get("short", GameData.hero(id).name)), 15, UiKit.INK)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.position = Vector2(0, 82)
	n.size = Vector2(88, 22)
	b.add_child(n)
	b.pressed.connect(on_press)
	return b


func _empty_slot(kit_name: String, text: String, on_press: Callable) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 88)
	var sb := UiKit.kit(kit_name)
	sb.set_content_margin_all(0)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb if st != "hover" else UiKit.kit(kit_name, Color(1.15, 1.1, 1.0)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = text
	b.add_theme_font_override("font", UiKit.FONT_BOLD)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", UiKit.WHITE)
	b.pressed.connect(on_press)
	return b


func _defense_chip(did: String, on_press: Callable) -> Control:
	var spec: Dictionary = GameData.lodge.defenses[did]
	var b := UiKit.button(String(spec.name), "gold", 18, Vector2(0, 46))
	b.icon = load(String(spec.get("prop", "")))
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 30)
	b.tooltip_text = String(spec.description) + "\n(Toucher pour la démolir : son prix est rendu.)"
	b.pressed.connect(on_press)
	return b


func _trap_chip(tid: String, on_press: Callable) -> Control:
	var trap: Dictionary = GameData.lodge.traps[tid]
	var b := UiKit.button(String(trap.name), "purple", 18, Vector2(0, 46))
	var color := Palette.element_color(String(trap.get("element", "")))
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBox = b.get_theme_stylebox(st)
		if sb is StyleBoxTexture:
			(sb as StyleBoxTexture).modulate_color = color.lightened(0.15)
	b.tooltip_text = String(trap.description) + "\n(Toucher pour le retirer.)"
	b.pressed.connect(on_press)
	return b


# --- Choix d'un défenseur ou d'un piège (fenêtre par-dessus) ------------------------------------

func _pick_defender(room: int) -> void:
	ui_sound.emit("ui_click")
	var used: Array = []
	for r: Array in PlayerData.lodge().rooms:
		used.append_array(r)
	var ids: Array = PlayerData.owned_heroes().filter(func(id: String) -> bool: return id not in used)
	ids.sort_custom(func(a: String, b: String) -> bool: return PlayerData.hero_power(a) > PlayerData.hero_power(b))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for id: String in ids:
		grid.add_child(_hero_slot(id, func() -> void:
			ui_sound.emit("ui_click")
			_close_picker()
			PlayerData.lodge_add_defender(room, id), "Force %d" % PlayerData.hero_power(id)))
	_open_picker("Choisis un défenseur", grid)


func _pick_defense(room: int) -> void:
	ui_sound.emit("ui_click")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	for did: String in GameData.lodge.get("defenses", {}):
		var spec: Dictionary = GameData.lodge.defenses[did]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var chip := _defense_chip(did, func() -> void:
			ui_sound.emit("ui_click")
			_close_picker()
			PlayerData.lodge_add_defense(room, did))
		var recipe: Dictionary = spec.get("pieces", {})
		var mech: Dictionary = GameData.summon.get("mechanic", {}).get("pieces", {})
		chip.text = "%s · %s" % [spec.name, " ".join(recipe.keys().map(func(k: String) -> String:
			return "%d %s" % [int(recipe[k]), String(mech.get(k, {}).get("name", k)).split(" ")[0]]))]
		chip.tooltip_text = "Pièces du Mécanicien (Lanterne) :\n" + "\n".join(recipe.keys().map(func(k: String) -> String:
			return "%s : %d / %d" % [mech.get(k, {}).get("name", k), PlayerData.item_count(k), int(recipe[k])]))
		chip.custom_minimum_size = Vector2(330, 50)
		chip.disabled = not PlayerData.can_build_defense(did)
		row.add_child(chip)
		var d := UiKit.label(String(spec.description), 18, UiKit.INK)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
	_open_picker("Construire une défense", list)


func _pick_trap(room: int) -> void:
	ui_sound.emit("ui_click")
	var placed: Array = PlayerData.lodge().traps[room]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	var hint := UiKit.label("Les pièges se gagnent à la Lanterne des Serments (un par invocation). Poser un piège le consomme ; le retirer le rend.",
		17, UiKit.TEXT_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(hint)
	for tid: String in GameData.lodge.traps:
		if tid in placed:
			continue
		var trap: Dictionary = GameData.lodge.traps[tid]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var owned := PlayerData.trap_count(tid)
		var chip := _trap_chip(tid, func() -> void:
			ui_sound.emit("ui_click")
			_close_picker()
			PlayerData.lodge_toggle_trap(room, tid))
		chip.text = "%s  ×%d" % [trap.name, owned]
		chip.custom_minimum_size = Vector2(300, 50)
		chip.tooltip_text = ""
		chip.disabled = owned <= 0
		row.add_child(chip)
		var d := UiKit.label(String(trap.description), 18, UiKit.INK)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
	_open_picker("Choisis un piège", list)


func _open_picker(title: String, inner: Control) -> void:
	_close_picker()
	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.parchment())
	panel.custom_minimum_size = Vector2(980, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := UiKit.label(title, 28, UiKit.WOOD)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	v.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	v.add_child(scroll)
	var cancel := UiKit.button("Annuler", "red", 22, Vector2(200, 54))
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		_close_picker())
	v.add_child(cancel)


func _close_picker() -> void:
	if is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null


# --- Chasseurs rivaux -------------------------------------------------------------------------

func _build_rivals() -> void:
	var cfg: Dictionary = GameData.lodge
	var note := UiKit.label("Donjons de chasseurs du jour (en attendant le jeu en ligne). Une attaque par donjon et par jour : tu paies une mise d'entrée, et si tu gagnes tu emportes une part de leur récompense.",
		18, UiKit.TEXT_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(note)
	var team_power := PlayerData.team_power()
	for rival: Dictionary in PlayerData.lodge_rivals():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.card())
		_body.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var t := UiKit.label("%s  ·  Force %d  ·  niveau %d" % [rival.name, int(rival.power), int(rival.level)], 22, UiKit.INK)
		t.add_theme_font_override("font", UiKit.FONT_BOLD)
		v.add_child(t)
		var faces := HBoxContainer.new()
		faces.add_theme_constant_override("separation", 4)
		v.add_child(faces)
		for room: Array in rival.rooms:
			for id: String in room:
				faces.add_child(RoundPortrait.new().setup(GameData.hero(id), 52, 0.08))
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(14, 0)
			faces.add_child(gap)
		var trap_names: Array = []
		for room_traps: Array in rival.traps:
			for tid: String in room_traps:
				trap_names.append(String(cfg.traps[tid].name))
		var def_names: Array = []
		for built: Array in rival.get("defenses", []):
			for did: String in built:
				def_names.append(String(cfg.defenses[did].name))
		v.add_child(UiKit.label("Pièges : " + ", ".join(trap_names), 17, UiKit.TEXT_SOFT))
		if not def_names.is_empty():
			v.add_child(UiKit.label("Défenses : " + ", ".join(def_names), 17, UiKit.TEXT_SOFT))
		var reward := Lodge.win_reward(int(rival.stake), cfg)
		var fee := Lodge.entry_fee(int(rival.stake), cfg)
		v.add_child(UiKit.label("Récompense en jeu : %d or  ·  tu emportes %d or si tu gagnes" % [int(rival.stake), reward], 18, UiKit.WOOD))
		var b := UiKit.button("Attaquer  ·  mise %d or" % fee, "red", 22, Vector2(300, 60))
		if PlayerData.lodge_rival_done(rival.id):
			b.text = "Déjà affronté aujourd'hui"
			b.disabled = true
		elif not Lodge.can_attack(team_power, int(rival.power)):
			b.text = "Équipe trop forte"
			b.disabled = true
		elif PlayerData.gold() < fee:
			b.disabled = true
		b.pressed.connect(func() -> void: _start(rival))
		h.add_child(b)


func _start(rival: Dictionary) -> void:
	ui_sound.emit("ui_click")
	var err := PlayerData.start_lodge_battle(rival)
	if err != "":
		_summary.text = err
		if _crypt_status:
			_crypt_status.text = err
		return
	battle_requested.emit()


# --- Le donjon en coupe (pack « Finitions ») ----------------------------------------------------

## Vue en coupe (assets/ui/finitions/ma_loge/) : trois salles (entrée, galerie, trésor) avec leurs
## tapis de défenseur (héros animés), dalles de piège et défenses construites (animées) ; coffre du
## trésor selon la mise ; en bas, le blason de la loge, le tableau des trois rivaux du jour et
## « Attaquer » ; à droite, la mise, la Force et l'essai du donjon.
const ML := "ma_loge"
## Pièges du jeu -> visuel du pack (icône et déclenchement).
const TRAP_ART := {"pieux": "pointes", "flaque": "fosse", "brasero": "rune_feu", "flechettes": "pointes",
	"glu": "filet", "gaz": "gaz_poison", "rune": "rune_feu", "cloche": "filet"}
const DEFENSE_ART := {"tour_mage": "tour_mage", "mur": "mur_provocateur", "baliste": "baliste", "autel": "autel"}
const ROOM_NAMES := ["Entrée", "Galerie", "Trésor"]

var _crypt: Control
var _crypt_box: Control
var _crypt_status: Label
var _rival_pick := 0


func _build_crypt() -> void:
	_crypt = Control.new()
	_crypt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crypt.mouse_filter = Control.MOUSE_FILTER_STOP
	_crypt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_crypt)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crypt.add_child(bg)
	var root := ScreenPack.frame(_crypt)
	var D := FinPack.data(ML)
	var P: Dictionary = D.get("positions", {})
	FinPack.image(root, String(D.get("background", "ma_loge/loge_coupe.png")), Rect2(0, 0, 1920, 1080))
	var tr := FinPack.rect(P.titre)
	FinPack.nine(root, "ma_loge/commun/bandeau_titre.png", tr, [130, 24, 130, 28])
	ScreenPack.shadow(ScreenPack.text(root, "MON DONJON", Rect2(tr.position + Vector2(0, 24), Vector2(tr.size.x, 36)), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var back := FinPack.button(root, "ma_loge/commun/retour", FinPack.rect(P.retour), "Port", 26)
	back.get_node("Label").position.x = 30
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		close_window())
	_crypt_box = Control.new()
	_crypt_box.size = Vector2(1920, 1080)
	_crypt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crypt_box)
	_crypt_status = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(430, 610, 1060, 30), 20, Color("ffb070"),
		HORIZONTAL_ALIGNMENT_CENTER), 2)


func _fill_crypt() -> void:
	for c in _crypt_box.get_children():
		_crypt_box.remove_child(c)
		c.queue_free()
	var D := FinPack.data(ML)
	var P: Dictionary = D.get("positions", {})
	var cfg: Dictionary = GameData.lodge
	var l := PlayerData.lodge()
	var anims: Dictionary = D.get("animations", {})
	# Or du joueur.
	var mr := FinPack.rect(P.monnaie)
	FinPack.nine(_crypt_box, "ma_loge/commun/cartouche_monnaie.png", mr, [74, 18, 22, 18])
	FinPack.image(_crypt_box, "port_franc/icones/or.png", Rect2(mr.position + Vector2(14, 12), Vector2(48, 48)))
	ScreenPack.shadow(ScreenPack.text(_crypt_box, HubHud._fmt(PlayerData.gold()), Rect2(mr.position + Vector2(66, 0), mr.size - Vector2(80, 0)),
		28, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var rooms: Array = D.get("rooms", [])
	for r in mini(rooms.size(), cfg.rooms.size()):
		var room: Dictionary = rooms[r]
		var spec: Dictionary = cfg.rooms[r]
		var rr := FinPack.rect(room.rect)
		var title := ScreenPack.shadow(ScreenPack.text(_crypt_box, "%s · %s" % [ROOM_NAMES[r] if r < ROOM_NAMES.size() else "", spec.name],
			Rect2(rr.position.x, 612, rr.size.x, 30), 21, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
		title.z_index = 1
		# Défenses (autour du point de construction).
		var built: Array = l.defenses[r]
		var anchor := Vector2(room.construction_anchor[0], room.construction_anchor[1])
		if r == 2:
			anchor.x -= 120  # salle du trésor : les défenses à gauche du coffre
		var nd := int(spec.get("defenses", 1))
		for k in nd:
			var at := anchor + Vector2((k - (nd - 1) / 2.0) * 172.0, -6)
			if k < built.size():
				var did: String = built[k]
				var art: Dictionary = anims.get(DEFENSE_ART.get(did, did) + "_repos", {})
				var holder := Control.new()
				holder.position = at - Vector2(80, 150)
				holder.size = Vector2(160, 150)
				holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				holder.tooltip_text = "%s\n%s\n(Toucher pour la démolir : ses pièces sont rendues.)" % [cfg.defenses[did].name,
					cfg.defenses[did].description]
				_crypt_box.add_child(holder)
				if not art.is_empty():
					var s := FinPack.sheet(art)
					s.position = Vector2(80, 150)
					var ds: Array = art.get("draw_size", art.frame_size)
					s.scale = Vector2.ONE * float(ds[1]) / float(art.frame_size[1]) * 0.85
					holder.add_child(s)
					s.play("a")
				var idx := k
				holder.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						ui_sound.emit("ui_click")
						PlayerData.lodge_remove_defense(r, idx))
			else:
				var add := FinPack.button(_crypt_box, "ma_loge/bouton_attaquer", Rect2(at - Vector2(72, 160), Vector2(144, 56)),
					"+ Défense", 19)
				add.modulate.a = 0.85
				add.pressed.connect(func() -> void: _pick_defense(r))
		# Pièges : une rangée de cases sous la salle (ce qui est posé, et où), pas sur le sol des héros.
		var traps: Array = l.traps[r]
		var nt := int(spec.traps)
		var cx := rr.get_center().x
		ScreenPack.shadow(ScreenPack.text(_crypt_box, "Pièges", Rect2(cx - nt * 44.0 - 112, 668, 100, 30), 19, Color("cbbfae"),
			HORIZONTAL_ALIGNMENT_RIGHT), 2)
		for k in nt:
			var cell := Rect2(cx - nt * 44.0 + k * 88.0, 646, 72, 72)
			var on := k < traps.size()
			var frame := FinPack.image(_crypt_box, "preparation_chasse/portrait_%s.png" % ("choisi" if on else "normal"), cell)
			frame.mouse_filter = Control.MOUSE_FILTER_STOP
			frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if on:
				var tid: String = traps[k]
				FinPack.image(_crypt_box, "ma_loge/icones/piege_%s.png" % String(TRAP_ART.get(tid, "pointes")), cell.grow(-12))
				frame.tooltip_text = "%s
%s
(Toucher pour le retirer.)" % [cfg.traps[tid].name, cfg.traps[tid].description]
				frame.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						ui_sound.emit("ui_click")
						PlayerData.lodge_toggle_trap(r, tid))
			else:
				ScreenPack.shadow(ScreenPack.text(_crypt_box, "+", cell, 34, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
				frame.tooltip_text = "Poser un piège"
				frame.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						_pick_trap(r))
		# Défenseurs (la dernière salle peut en avoir 4 : places réparties entre la première et la dernière).
		var defenders: Array = l.rooms[r]
		var dslots: Array = room.get("defenders", [])
		var nh := int(spec.defenders)
		var first := FinPack.rect(dslots[0].rect)
		var last := FinPack.rect(dslots[-1].rect)
		if nh > dslots.size():  # place en plus : socles un peu plus petits, resserrés à gauche du coffre
			var small := first.size * 0.84
			first = Rect2(first.position + (first.size - small) * Vector2(0.5, 1.0) - Vector2(67, 0), small)
			last = Rect2(Vector2(1686 - small.x, first.position.y), small)
		for k in nh:
			var t := 0.0 if nh <= 1 else float(k) / (nh - 1)
			var dr := Rect2(first.position.lerp(last.position, t), first.size)
			var on := k < defenders.size()
			var mat := FinPack.image(_crypt_box, "ma_loge/emplacements/defenseur_%s.png" % ("occupe" if on else "vide"), dr)
			mat.mouse_filter = Control.MOUSE_FILTER_STOP
			mat.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if on:
				var id: String = defenders[k]
				var p := ClipPlayer.new()
				p.bundle = "res://assets/anim/heroes/"
				p.idle_clip = id + "_idle"
				p.position = dr.position + Vector2(60, 38)
				p.scale = Vector2(-0.3, 0.3)  # tournés vers l'entrée (les assaillants viennent de la gauche)
				_crypt_box.add_child(p)
				p.play(id + "_idle")
				p.speed = 0.0
				var hit := Control.new()
				hit.position = dr.position + Vector2(0, -120)
				hit.size = Vector2(dr.size.x, 176)
				hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hit.tooltip_text = "%s · Force %d\n(Toucher pour le retirer.)" % [GameData.hero(id).name, PlayerData.hero_power(id)]
				hit.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						ui_sound.emit("ui_click")
						PlayerData.lodge_remove_defender(r, id))
				_crypt_box.add_child(hit)
			else:
				mat.tooltip_text = "Placer un défenseur"
				mat.gui_input.connect(func(e: InputEvent) -> void:
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
						_pick_defender(r))
	# Coffre du trésor selon la mise.
	var stake := int(l.stake)
	var smax := maxi(1, int(cfg.get("stake_max", 20000)))
	var chest := "vide" if stake <= 0 else ("plein" if stake >= smax / 2 else "moitie")
	var cr := FinPack.rect(P.coffre)
	cr = Rect2(Vector2(1832 - 142, cr.end.y - 146), Vector2(142, 142))  # calé contre le pilier : les socles restent dégagés
	var ch := FinPack.image(_crypt_box, "ma_loge/coffre_%s.png" % chest, cr)
	ch.mouse_filter = Control.MOUSE_FILTER_STOP
	ch.tooltip_text = "Récompense mise en jeu : %d or.\nUn chasseur qui te bat en emporte %d %%." % [stake,
		int(round(float(cfg.get("win_share", 0.3)) * 100))]
	# Blason et nom de la loge.
	FinPack.image(_crypt_box, "ma_loge/blason.png", FinPack.rect(P.blason))
	var ln := ScreenPack.text(_crypt_box, PlayerData.lodge_name(), FinPack.rect(P.nom_loge).grow_individual(-4, 0, -4, 0),
		13 if PlayerData.lodge_name().length() > 14 else 15, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	ln.clip_text = true
	# Mise, Force et essai, à droite.
	var x0 := 1440.0
	ScreenPack.shadow(ScreenPack.text(_crypt_box, "Mise du trésor : %s or" % HubHud._fmt(stake), Rect2(x0, 734, 440, 32), 22,
		Color("ffd27a"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var step := int(cfg.get("stake_step", 500))
	for d in [-step, step]:
		var b := FinPack.button(_crypt_box, "stele/bouton_%s" % ("moins" if d < 0 else "plus"),
			Rect2(x0 + (110 if d < 0 else 234), 770, 96, 80))
		b.texture_normal = MageRoom.tex("stele/bouton_%s_normal.png" % ("moins" if d < 0 else "plus"))
		b.texture_hover = MageRoom.tex("stele/bouton_%s_survol.png" % ("moins" if d < 0 else "plus"))
		b.texture_pressed = MageRoom.tex("stele/bouton_%s_appuye.png" % ("moins" if d < 0 else "plus"))
		b.texture_disabled = MageRoom.tex("stele/bouton_%s_desactive.png" % ("moins" if d < 0 else "plus"))
		b.tooltip_text = "%+d or" % d
		b.disabled = (d < 0 and stake <= 0) or (d > 0 and (PlayerData.gold() < d or stake + d > smax))
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			PlayerData.lodge_set_stake(stake + d))
	ScreenPack.shadow(ScreenPack.text(_crypt_box, "Force du donjon : %d\nForce de ton équipe : %d" % [PlayerData.lodge_power(),
		PlayerData.team_power()], Rect2(x0, 846, 440, 60), 19, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var test := FinPack.button(_crypt_box, "ma_loge/bouton_attaquer", Rect2(x0 + 30, 912, 380, 84), "Tester mon donjon", 22)
	test.disabled = not Lodge.is_ready(l)
	test.tooltip_text = "Ton équipe de chasse affronte ton donjon (sans gain ni énergie)."
	test.pressed.connect(func() -> void: _start({}))
	_fill_rivals_board()


## Le tableau des rivaux : trois avis (nom, Force, récompense) ; toucher un avis le choisit.
func _fill_rivals_board() -> void:
	var D := FinPack.data(ML)
	var P: Dictionary = D.get("positions", {})
	var cfg: Dictionary = GameData.lodge
	var board := Rect2(430, 730, 970, 262)
	FinPack.image(_crypt_box, "ma_loge/panneau_rivaux.png", board)
	var rivals: Array = PlayerData.lodge_rivals()
	_rival_pick = clampi(_rival_pick, 0, maxi(0, rivals.size() - 1))
	var team_power := PlayerData.team_power()
	for i in mini(3, rivals.size()):
		var rv: Dictionary = rivals[i]
		var pr := Rect2(board.position + Vector2(168 + i * 225, 64), Vector2(190, 150))
		var card := Control.new()
		card.position = pr.position
		card.size = pr.size
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_crypt_box.add_child(card)
		var done := PlayerData.lodge_rival_done(rv.id)
		var too_strong := not Lodge.can_attack(team_power, int(rv.power))
		var traps: Array = []
		for room_traps: Array in rv.traps:
			for tid: String in room_traps:
				traps.append(String(cfg.traps[tid].name))
		card.tooltip_text = "Pièges : " + ", ".join(traps)
		if i == _rival_pick:
			var sel := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color("63c8be")
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(4)
			sel.add_theme_stylebox_override("panel", sb)
			sel.position = Vector2(-12, -14)
			sel.size = pr.size + Vector2(24, 20)
			sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(sel)
		ScreenPack.text(card, String(rv.name), Rect2(14, 0, pr.size.x - 28, 52), 15, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
		ScreenPack.text(card, "Force : %d" % int(rv.power), Rect2(0, 54, pr.size.x, 26), 18, Color("793b49"), HORIZONTAL_ALIGNMENT_CENTER)
		var state := "Déjà affronté" if done else ("Trop faible pour toi" if too_strong else "Trésor : %d or" % Lodge.win_reward(int(rv.stake), cfg))
		ScreenPack.text(card, state, Rect2(0, 86, pr.size.x, 50), 16, UiKit.INK if not (done or too_strong) else Color("8c857c"),
			HORIZONTAL_ALIGNMENT_CENTER, true)
		var idx := i
		card.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				ui_sound.emit("ui_click")
				_rival_pick = idx
				_fill_crypt())
	var ab: Dictionary = D.get("buttons", {}).get("attaquer", {})
	var go := FinPack.button(_crypt_box, "ma_loge/bouton_attaquer", Rect2(700, 970, 420, 88), "Attaquer", 24)
	if rivals.is_empty():
		go.disabled = true
		return
	var target: Dictionary = rivals[_rival_pick]
	var fee := Lodge.entry_fee(int(target.stake), cfg)
	(go.get_node("Label") as Label).text = "Attaquer · %d or" % fee  # le rival choisi est la carte cerclée ; son premier mot seul donnait « Attaquer Mère »
	go.disabled = PlayerData.lodge_rival_done(target.id) or not Lodge.can_attack(team_power, int(target.power)) \
		or PlayerData.gold() < fee
	go.pressed.connect(func() -> void: _start(target))
