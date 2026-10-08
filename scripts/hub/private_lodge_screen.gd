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


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	for i in _tabs.size():
		UiKit.style_button(_tabs[i], "red" if i == _tab else "blue", 22)
	_summary.text = "Force moyenne · donjon : %d   ·   ton équipe : %d" % [PlayerData.lodge_power(), PlayerData.team_power()]
	for c in _body.get_children():
		c.queue_free()
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
		return
	battle_requested.emit()
