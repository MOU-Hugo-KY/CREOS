class_name QuestsScreen
extends UiWindow
## « Primes du jour » : les quêtes quotidiennes. Chaque prime finie se récupère (récompenses +
## points d'activité) ; les points ouvrent 4 coffres. Certaines primes attendent des parties du
## jeu pas encore faites : elles sont affichées « bientôt ». Règles dans `Quests`.

signal go_to(action_name: String)
signal ui_sound(sfx_name: String)

const ACTION_ICONS := {"campaign": "chasses", "altar": "autel", "heroes": "heros", "shop": "marche",
	"guild": "guilde", "tower": "tour", "": "primes"}
const REWARD_ICONS := {"gold": "or", "gems": "gemmes", "fragments_relique": "eclats", "energy": "energie", "materiaux_relique": "reliques"}

var _points_bar: ProgressBar
var _points_label: Label
var _chest_row: Control
var _timer_label: Label
var _list: VBoxContainer


func _init() -> void:
	setup(GameData.quests.get("title", "Primes du jour"), Vector2(1260, 840), Color("793b49"))


func _ready() -> void:
	super._ready()
	# Points d'activité et coffres
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.card(Color("c6a66c")))
	content.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	top.add_child(tv)
	var head := HBoxContainer.new()
	tv.add_child(head)
	_points_label = UiKit.label("", 26, UiKit.TEXT_ON_PARCHMENT)
	_points_label.add_theme_font_override("font", UiKit.FONT_BOLD)
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_points_label)
	_timer_label = UiKit.label("", 20, UiKit.TEXT_SOFT)
	head.add_child(_timer_label)
	_chest_row = Control.new()
	_chest_row.custom_minimum_size = Vector2(0, 104)
	tv.add_child(_chest_row)
	_points_bar = UiKit.progress(Color("c6a66c"), 26)
	_points_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_KEEP_HEIGHT)
	_points_bar.anchor_right = 1.0
	_points_bar.offset_left = 10
	_points_bar.offset_right = -46
	_points_bar.offset_top = -13
	_points_bar.offset_bottom = 13
	_chest_row.add_child(_points_bar)
	_chest_row.resized.connect(func() -> void:
		if visible:
			_build_chests(PlayerData.daily(), GameData.quests, _max_points()))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(_refresh_timer)
	add_child(timer)
	if FinPack.available(PR):
		_build_board()


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	var cfg: Dictionary = GameData.quests
	var daily := PlayerData.daily()
	var chests: Array = cfg.get("chests", [])
	var max_points := int(chests[-1].points) if not chests.is_empty() else 100
	var pts := Quests.points(daily, cfg)
	_points_label.text = "Points du jour : %d / %d" % [mini(pts, max_points), max_points]
	_points_bar.max_value = max_points
	_points_bar.value = pts
	_build_chests(daily, cfg, max_points)
	_refresh_timer()
	if _board:
		_fill_board()
		return
	for c in _list.get_children():
		c.queue_free()
	var quests: Array = cfg.get("quests", []).duplicate()
	quests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _rank(daily, a) < _rank(daily, b))
	for q: Dictionary in quests:
		_list.add_child(_quest_card(daily, q))


## Ordre d'affichage : à récupérer, en cours, bientôt, déjà récupérées.
func _rank(daily: Dictionary, q: Dictionary) -> int:
	if Quests.can_claim(daily, q):
		return 0
	if Quests.is_claimed(daily, q):
		return 3
	return 1 if Quests.is_available(q) else 2


func _max_points() -> int:
	var chests: Array = GameData.quests.get("chests", [])
	return int(chests[-1].points) if not chests.is_empty() else 100


func _build_chests(daily: Dictionary, cfg: Dictionary, max_points: int) -> void:
	for c in _chest_row.get_children():
		if c != _points_bar:
			c.queue_free()
	var chests: Array = cfg.get("chests", [])
	for i in chests.size():
		var need := int(chests[i].points)
		var opened: bool = daily.get("chests", []).has(i)
		var ready := Quests.can_open_chest(daily, cfg, i)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.icon = UiKit.icon("recompenses").texture
		b.expand_icon = true
		b.custom_minimum_size = Vector2(76, 76)
		b.tooltip_text = _rewards_text(chests[i].get("rewards", {}))
		b.modulate = Color(1, 1, 1, 0.45) if opened else (Color.WHITE if ready else Color(0.75, 0.72, 0.68))
		var x := 10.0 + (_chest_row.size.x - 56.0) * float(need) / max_points
		b.position = Vector2(x - 38.0, -2)
		var index := i
		b.pressed.connect(func() -> void: _open_chest(index))
		_chest_row.add_child(b)
		var tag := UiKit.label(("✓" if opened else str(need)), 18, UiKit.WHITE, 5, UiKit.INK)
		tag.position = Vector2(x - 20.0, 74)
		tag.size = Vector2(40, 24)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chest_row.add_child(tag)
		if ready:
			var badge := UiKit.badge("!")
			badge.position = Vector2(x + 14.0, -4)
			_chest_row.add_child(badge)
			var tw := b.create_tween().set_loops()
			b.pivot_offset = Vector2(38, 38)
			tw.tween_property(b, "scale", Vector2.ONE * 1.1, 0.4).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


func _quest_card(daily: Dictionary, q: Dictionary) -> Control:
	var available := Quests.is_available(q)
	var claimed := Quests.is_claimed(daily, q)
	var ready := Quests.can_claim(daily, q)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card(Color("63c8be") if ready else Color.TRANSPARENT))
	if claimed or not available:
		card.modulate = Color(1, 1, 1, 0.6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	# Icône dans un médaillon
	var medal := PanelContainer.new()
	var mb := UiKit.box(Color("505e75") if available else Color("8c857c"), UiKit.INK, 34, 3)
	mb.set_content_margin_all(6)
	medal.add_theme_stylebox_override("panel", mb)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.add_child(UiKit.icon(ACTION_ICONS.get(q.get("action", ""), "primes"), 52))
	h.add_child(medal)
	# Texte et progression
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	var name := UiKit.label(q.get("name", ""), 25, UiKit.TEXT_ON_PARCHMENT)
	name.add_theme_font_override("font", UiKit.FONT_BOLD)
	col.add_child(name)
	col.add_child(UiKit.label(q.get("description", "") if available else "%s  (bientôt disponible)" % q.get("description", ""), 19, UiKit.TEXT_SOFT))
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	col.add_child(prow)
	var target := int(q.get("target", 1))
	var bar := UiKit.progress(Color("63c8be") if available else Color("a9a39a"), 18)
	bar.custom_minimum_size.x = 300
	bar.max_value = target
	bar.value = target if claimed else Quests.progress(daily, q)
	prow.add_child(bar)
	prow.add_child(UiKit.label("%d / %d" % [int(bar.value), target], 18, UiKit.TEXT_SOFT))
	# Récompenses
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 6)
	rewards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rewards)
	var pts := UiKit.label("+%d pts" % int(q.get("points", 0)), 20, Color("505e75"))
	pts.custom_minimum_size.x = 84
	rewards.add_child(pts)
	var r: Dictionary = q.get("rewards", {})
	for key: String in r:
		rewards.add_child(UiKit.reward_chip(REWARD_ICONS.get(key, "recompenses"), int(r[key])))
	# Bouton
	var b: Button
	if ready:
		b = UiKit.button("Récupérer", "green", 22, Vector2(190, 60))
		b.pressed.connect(func() -> void: _claim(q.id))
	elif claimed:
		b = UiKit.button("Fait ✓", "wood", 22, Vector2(190, 60))
		b.disabled = true
	elif not available:
		b = UiKit.button("Bientôt", "grey", 22, Vector2(190, 60))
		b.disabled = true
	else:
		b = UiKit.button("Y aller", "blue", 22, Vector2(190, 60))
		var act: String = q.get("action", "")
		b.disabled = act == ""
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			close_window()
			go_to.emit(act))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return card


func _claim(id: String) -> void:
	if PlayerData.claim_quest(id).is_empty():
		return
	ui_sound.emit("ui_ready")
	refresh()


func _open_chest(index: int) -> void:
	var r := PlayerData.open_chest(index)
	if r.is_empty():
		ui_sound.emit("ui_toggle")
		return
	ui_sound.emit("ultimate_impact")
	refresh()


func _refresh_timer() -> void:
	var now := Time.get_datetime_dict_from_system()
	var left := 86400 - (int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second))
	_timer_label.text = "Nouvelles primes dans %d h %02d min" % [left / 3600, (left % 3600) / 60]
	if _board_timer:
		_board_timer.text = "%d h %02d" % [left / 3600, (left % 3600) / 60]
		_board_timer.tooltip_text = "Nouvelles primes dans %d h %02d min" % [left / 3600, (left % 3600) / 60]


func _rewards_text(r: Dictionary) -> String:
	var names := {"gold": "or", "gems": "gemmes", "fragments_relique": "fragments de relique", "energy": "énergie"}
	var parts: Array[String] = []
	for key: String in r:
		parts.append("%d %s" % [int(r[key]), names.get(key, key)])
	return ", ".join(parts)


# --- Le tableau des primes (pack « Finitions ») ----------------------------------------------------

## Taverne et tableau d'avis (assets/ui/finitions/primes/) : 3 affiches de prime par page (flèches
## s'il y en a plus), la barre des points du jour et ses coffres posés à leur seuil.
const PR := "primes"
const PR_ICONS := {"gold": "primes/icones/or.png", "gems": "primes/icones/gemme.png", "fragments_relique": "primes/icones/eclat.png"}

var _board: Control
var _board_box: Control
var _board_timer: Label
var _page := 0


func _build_board() -> void:
	_board = Control.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_board)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.add_child(bg)
	var root := ScreenPack.frame(_board)
	var D := FinPack.data(PR)
	var P: Dictionary = D.get("positions", {})
	FinPack.image(root, String(D.get("background", "primes/tableau_primes.png")), Rect2(0, 0, 1920, 1080))
	var tr := FinPack.rect(P.titre)
	FinPack.nine(root, "primes/commun/bandeau_titre.png", tr, [130, 24, 130, 28])
	ScreenPack.shadow(ScreenPack.text(root, "PRIMES DU JOUR", Rect2(tr.position + Vector2(0, 24), Vector2(tr.size.x, 36)), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var back := FinPack.button(root, "primes/commun/retour", FinPack.rect(P.retour), "Port", 26)
	back.get_node("Label").position.x = 30
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		close_window())
	var mr := FinPack.rect(P.monnaie)
	FinPack.nine(root, "primes/commun/cartouche_monnaie.png", mr, [74, 18, 22, 18])
	_board_timer = ScreenPack.text(root, "", Rect2(mr.position + Vector2(60, 0), mr.size - Vector2(70, 0)), 24, UiKit.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER)
	FinPack.image(root, "port_franc/icones/horloge.png", Rect2(mr.position + Vector2(22, 24), Vector2(24, 24)))
	_board_box = Control.new()
	_board_box.size = Vector2(1920, 1080)
	_board_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_board_box)


func _fill_board() -> void:
	for c in _board_box.get_children():
		_board_box.remove_child(c)
		c.queue_free()
	var D := FinPack.data(PR)
	var P: Dictionary = D.get("positions", {})
	var cfg: Dictionary = GameData.quests
	var daily := PlayerData.daily()
	var quests: Array = cfg.get("quests", []).duplicate()
	quests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _rank(daily, a) < _rank(daily, b))
	var posters: Array = D.get("posters", [])
	var pages := maxi(1, ceili(float(quests.size()) / posters.size()))
	_page = clampi(_page, 0, pages - 1)
	for i in posters.size():
		var k := _page * posters.size() + i
		if k < quests.size():
			_poster(posters[i], daily, quests[k])
	if pages > 1:
		for dir: int in [-1, 1]:
			var a := TextureButton.new()
			var side := "precedente" if dir < 0 else "suivante"
			a.texture_normal = MageRoom.tex("jardin/fleche_salle_%s_normal.png" % side)
			a.texture_hover = MageRoom.tex("jardin/fleche_salle_%s_survol.png" % side)
			a.ignore_texture_size = true
			a.stretch_mode = TextureButton.STRETCH_SCALE
			a.size = Vector2(120, 90)
			a.position = Vector2(320 if dir < 0 else 1480, 425)
			a.disabled = (_page == 0 and dir < 0) or (_page == pages - 1 and dir > 0)
			a.modulate.a = 0.35 if a.disabled else 1.0
			a.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			a.pressed.connect(func() -> void:
				ui_sound.emit("ui_click")
				_page += dir
				_fill_board())
			_board_box.add_child(a)
		ScreenPack.shadow(ScreenPack.text(_board_box, "Page %d / %d" % [_page + 1, pages], Rect2(860, 214, 200, 32), 22, Color("f3d9a0"),
			HORIZONTAL_ALIGNMENT_CENTER), 3)
	# Points du jour et coffres posés à leur seuil.
	var chests: Array = cfg.get("chests", [])
	var max_points := _max_points()
	var pts := Quests.points(daily, cfg)
	ScreenPack.shadow(ScreenPack.text(_board_box, "Points du jour : %d / %d" % [mini(pts, max_points), max_points],
		FinPack.rect(P.progression_label), 24, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var fr := FinPack.rect(P.progression_jour_remplissage)
	var g := FinPack.Gauge.new().setup("primes/progression_fond.png", FinPack.rect(P.progression_jour_fond), [8, 8, 8, 8],
		"primes/progression_remplissage.png", fr)
	g.set_ratio(float(pts) / max_points)
	_board_box.add_child(g)
	var anim: Dictionary = D.get("animations", {}).get("coffre_pret", {})
	for i in chests.size():
		var need := int(chests[i].points)
		var opened: bool = daily.get("chests", []).has(i)
		var ready := Quests.can_open_chest(daily, cfg, i)
		# Chaque coffre sous son seuil sur la barre (le dernier calé au bout).
		var cx := clampf(fr.position.x + fr.size.x * float(need) / max_points, fr.position.x + 60, fr.end.x - 60)
		var box := Control.new()
		box.size = Vector2(120, 120)
		box.position = Vector2(cx - 60, 900)
		box.tooltip_text = "%d points : %s%s" % [need, _rewards_text(chests[i].get("rewards", {})),
			"
(déjà ouvert)" if opened else ("
Prêt : touche pour l'ouvrir" if ready else "
Pas encore atteint")]
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var index := i
		box.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_open_chest(index))
		_board_box.add_child(box)
		if ready:
			var s := FinPack.sheet(anim)
			s.position = Vector2(60, 112)
			s.scale = Vector2.ONE * 0.75
			box.add_child(s)
			s.play("a")
		else:
			var ci := FinPack.image(box, "primes/coffre_%s.png" % ("ouvert" if opened else "ferme"), Rect2(Vector2.ZERO, box.size))
			if not opened:
				ci.modulate = Color(0.55, 0.53, 0.58)  # pas encore atteint
		ScreenPack.shadow(ScreenPack.text(_board_box, "✓" if opened else str(need), Rect2(cx - 40, 864, 80, 30), 22,
			Color("ffd27a") if ready else UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	_fill_weekly()
	_refresh_timer()


## Prime de la semaine, à gauche de la barre des points : jours de venue et récompense.
func _fill_weekly() -> void:
	var W: Dictionary = GameData.quests.get("weekly", {})
	if W.is_empty():
		return
	var w := PlayerData.weekly()
	var r := Rect2(110, 255, 290, 400)
	FinPack.nine(_board_box, "primes/affiche_%s.png" % ("reclamee" if w.claimed else ("terminee" if PlayerData.can_claim_weekly() else "en_cours")),
		r, [44, 56, 62, 96])
	var need := int(W.get("days", 5))
	var days := mini((w.days as Array).size(), need)
	ScreenPack.text(_board_box, String(W.get("name", "Prime de la semaine")), Rect2(r.position + Vector2(24, 66), Vector2(240, 50)), 20,
		Color("793b49"), HORIZONTAL_ALIGNMENT_CENTER, true)
	ScreenPack.text(_board_box, "%s

%d / %d jours

+%d gemmes" % [W.get("description", ""), days, need,
		int(W.get("rewards", {}).get("gems", 0))], Rect2(r.position + Vector2(24, 124), Vector2(240, 180)), 18, UiKit.INK,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	var b := FinPack.button(_board_box, "primes/bouton_reclamer", Rect2(r.position + Vector2(10, r.size.y + 2), Vector2(270, 64)),
		"Fait" if w.claimed else "Réclamer", 20)
	b.disabled = not PlayerData.can_claim_weekly()
	b.pressed.connect(func() -> void:
		if not PlayerData.claim_weekly().is_empty():
			ui_sound.emit("ultimate_impact")
			refresh())


## Une affiche : en cours, terminée (sceau, à réclamer) ou réclamée (pliée, grisée).
func _poster(p: Dictionary, daily: Dictionary, q: Dictionary) -> void:
	var available := Quests.is_available(q)
	var claimed := Quests.is_claimed(daily, q)
	var ready := Quests.can_claim(daily, q)
	var state := "reclamee" if claimed else ("terminee" if ready else "en_cours")
	var file := "primes/affiche_%s.png" % state
	var card := FinPack.nine(_board_box, file, FinPack.rect(p.rect), FinPack.margins(PR, file))
	if not available:
		card.modulate = Color(0.8, 0.78, 0.75)
	var o := -FinPack.rect(p.rect).position
	var at := func(a: Array) -> Rect2: return Rect2(FinPack.rect(a).position + o, FinPack.rect(a).size)
	ScreenPack.text(card, String(q.get("name", "")), at.call(p.title_rect), 22, Color("793b49"), HORIZONTAL_ALIGNMENT_CENTER, true)
	var desc := String(q.get("description", ""))
	if not available:
		desc += "\n(bientôt disponible)"
	ScreenPack.text(card, desc + "\n\n+%d points" % int(q.get("points", 0)), at.call(p.body_rect), 18, UiKit.INK,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	var target := int(q.get("target", 1))
	var done := target if claimed else mini(Quests.progress(daily, q), target)
	var pr: Rect2 = at.call(p.progress_rect)
	var fr: Rect2 = at.call(p.progress_fill_rect)
	var g := FinPack.Gauge.new().setup("primes/progression_fond.png", pr, [8, 8, 8, 8], "primes/progression_remplissage.png", fr)
	g.set_ratio(float(done) / target)
	card.add_child(g)
	ScreenPack.shadow(ScreenPack.text(card, "%d / %d" % [done, target], pr, 16, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var rr: Rect2 = at.call(p.reward_rect)
	var x := rr.position.x
	var r: Dictionary = q.get("rewards", {})
	for key: String in r:
		var t := ScreenPack.image(card, FinPack.tex(PR_ICONS[key]) if PR_ICONS.has(key) else UiKit.icon(REWARD_ICONS.get(key, "recompenses")).texture,
			Rect2(x, rr.position.y + 3, 36, 36))
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ScreenPack.text(card, str(int(r[key])), Rect2(x + 38, rr.position.y, 70, rr.size.y), 20, UiKit.INK)
		x += 100
	var label := "Réclamer" if ready else ("Fait" if claimed else ("Bientôt" if not available else "Y aller"))
	var b := FinPack.button(card, "primes/bouton_reclamer", at.call(p.button_rect), label, 24)
	b.disabled = claimed or not available or (not ready and String(q.get("action", "")) == "")
	if ready:
		b.pressed.connect(func() -> void: _claim(q.id))
	else:
		var act: String = q.get("action", "")
		b.pressed.connect(func() -> void:
			ui_sound.emit("ui_click")
			close_window()
			go_to.emit(act))
