class_name QuestsScreen
extends UiWindow
## « Primes du jour » : les quêtes quotidiennes. Chaque prime finie se récupère (récompenses +
## points d'activité) ; les points ouvrent 4 coffres. Certaines primes attendent des parties du
## jeu pas encore faites : elles sont affichées « bientôt ». Règles dans `Quests`.

signal go_to(action_name: String)
signal ui_sound(sfx_name: String)

const ACTION_ICONS := {"campaign": "chasses", "altar": "autel", "heroes": "heros", "shop": "marche",
	"guild": "guilde", "tower": "tour", "": "primes"}
const REWARD_ICONS := {"gold": "or", "gems": "gemmes", "fragments_relique": "autel", "energy": "energie"}

var _points_bar: ProgressBar
var _points_label: Label
var _chest_row: Control
var _timer_label: Label
var _list: VBoxContainer


func _init() -> void:
	setup(GameData.quests.get("title", "Primes du jour"), Vector2(1260, 840), Color("b8462e"))


func _ready() -> void:
	super._ready()
	# Points d'activité et coffres
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.card(Color("d9a441")))
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
	_points_bar = UiKit.progress(Color("f0b43c"), 26)
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
	card.add_theme_stylebox_override("panel", UiKit.card(Color("6cc04a") if ready else Color.TRANSPARENT))
	if claimed or not available:
		card.modulate = Color(1, 1, 1, 0.6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	# Icône dans un médaillon
	var medal := PanelContainer.new()
	var mb := UiKit.box(Color("2f5aa8") if available else Color("8c857c"), UiKit.INK, 34, 3)
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
	var bar := UiKit.progress(Color("6cc04a") if available else Color("a9a39a"), 18)
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
	var pts := PanelContainer.new()
	var psb := UiKit.box(Color("2f5aa8"), Color("1d3a75"), 14, 2)
	psb.content_margin_left = 10
	psb.content_margin_right = 10
	pts.add_theme_stylebox_override("panel", psb)
	pts.add_child(UiKit.label("+%d pts" % int(q.get("points", 0)), 18, UiKit.WHITE, 4, Color("1d3a75")))
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


func _rewards_text(r: Dictionary) -> String:
	var names := {"gold": "or", "gems": "gemmes", "fragments_relique": "fragments de relique", "energy": "énergie"}
	var parts: Array[String] = []
	for key: String in r:
		parts.append("%d %s" % [int(r[key]), names.get(key, key)])
	return ", ".join(parts)
