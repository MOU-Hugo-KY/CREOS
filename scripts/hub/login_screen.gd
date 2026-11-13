class_name LoginScreen
extends Control
## Cadeau du jour : 7 cartes (data/login.json), on prend celle du jour. Plein écran, sur le fond de fête
## du port ; la carte du jour brille et se balance, celles déjà prises portent un tampon, le 7e jour est
## un grand coffre. S'ouvre tout seul au port quand le cadeau du jour n'est pas encore pris.

signal closed
signal ui_sound(name: String)

const ICONS := {"gold": "or", "gems": "gemmes", "energy": "energie", "materiaux_relique": "reliques"}
const NAMES := {"gold": "or", "gems": "gemmes", "energy": "énergie", "materiaux_relique": "matériaux"}
const BG := "res://assets/ui/finitions/combat/victoire_fond.png"
const CHEST := "res://assets/ui/finitions/popups/coffres/legendaire_ferme.png"
const CARD := Vector2(214, 310)
const BIG := Vector2(310, 400)
const GAP := 22.0
const FLOOR_Y := 790.0  # bas des cartes

var _frame: Control
var _cards: Control
var _claim: Button
var _hint: Label
var _t := 0.0
var _today_card: Control
var _today_glow: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	visible = false
	var bg := TextureRect.new()
	bg.texture = load(BG) if ResourceLoader.exists(BG) else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()  # le fond passe derrière : les cartes d'abord
	dim.color = Color(0.07, 0.04, 0.12, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_frame = ScreenPack.frame(self)

	var ribbon := Panel.new()
	ribbon.add_theme_stylebox_override("panel", UiKit.kit("title_ribbon"))
	ribbon.position = Vector2(560, 96)
	ribbon.size = Vector2(800, 96)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(ribbon)
	var title := UiKit.title("Cadeau du jour", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(560, 104)
	title.size = Vector2(800, 64)
	_frame.add_child(title)
	_hint = ScreenPack.shadow(ScreenPack.text(_frame, "", Rect2(360, 214, 1200, 40), 28, Color("f6e7c4"),
		HORIZONTAL_ALIGNMENT_CENTER), 3)

	_cards = Control.new()
	_cards.size = Vector2(1920, 1080)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_cards)

	_claim = UiKit.button("Prendre", "green", 36, Vector2(420, 92))
	_claim.position = Vector2(750, 880)
	_claim.size = Vector2(420, 92)
	_claim.pressed.connect(_on_claim)
	_frame.add_child(_claim)
	var close := UiKit.close_button()
	close.position = Vector2(1790, 70)
	close.size = Vector2(72, 72)
	close.pressed.connect(close_window)
	_frame.add_child(close)


func open() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_fill(true)


func close_window() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_window()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _today_card == null:
		return
	_t += delta
	_today_card.rotation = sin(_t * 2.2) * 0.025  # la carte du jour se balance doucement
	if _today_glow:
		_today_glow.modulate.a = 0.55 + 0.25 * sin(_t * 3.0)
		_today_glow.rotation += delta * 0.4


func _fill(animate := false) -> void:
	for c in _cards.get_children():
		c.queue_free()
	_today_card = null
	_today_glow = null
	var days: Array = PlayerData.login_days()
	var today := PlayerData.login_day()
	var can := PlayerData.can_claim_login()
	var n := days.size()
	var total := (n - 1) * (CARD.x + GAP) + BIG.x
	var x := (1920.0 - total) / 2.0
	for i in n:
		var last := i == n - 1
		var sz := BIG if last else CARD
		var state := "taken" if i < today or (i == today and not can) else ("today" if i == today else "later")
		var card := _card(i, days[i], sz, state, last)
		card.position = Vector2(x, FLOOR_Y - sz.y)
		_cards.add_child(card)
		if state == "today":
			_today_card = card
		if animate:
			UiKit.pop_in(card, 0.05 * i)
		x += sz.x + GAP
	_claim.disabled = not can
	_claim.text = "Prendre" if can else "Reviens demain"
	_hint.text = "Jour %d sur %d — reviens chaque jour, le 7e jour un grand coffre t'attend." % [mini(today + 1, n), n]


## Une carte : bandeau « Jour N », le cadeau en grand, son montant ; `state` : taken, today ou later.
func _card(index: int, reward: Dictionary, sz: Vector2, state: String, big: bool) -> Control:
	var root := Control.new()
	root.size = sz
	root.pivot_offset = Vector2(sz.x / 2.0, 0)  # se balance depuis le haut, comme une affiche clouée
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state == "today":
		var glow := TextureRect.new()
		glow.texture = StageGrade.disc()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.size = sz * 1.9
		glow.position = (sz - glow.size) / 2.0
		glow.pivot_offset = glow.size / 2.0
		glow.modulate = Color(1.0, 0.85, 0.45, 0.7)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(glow)
		_today_glow = glow
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f3e9d2") if state != "taken" else Color("b9ae9a")
	sb.border_color = UiKit.TEAL if state == "today" else (Color("c6a66c") if big else UiKit.INK)
	sb.set_border_width_all(7 if state == "today" or big else 5)
	sb.set_corner_radius_all(24)
	sb.shadow_color = Color(0.05, 0.03, 0.08, 0.75)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 9)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = sz
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	# Bandeau du jour.
	var head := Panel.new()
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color("c6a66c") if big else UiKit.WOOD
	hb.corner_radius_top_left = 17
	hb.corner_radius_top_right = 17
	head.add_theme_stylebox_override("panel", hb)
	head.position = Vector2(7, 7)
	head.size = Vector2(sz.x - 14, 58)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)
	var day := UiKit.title("Jour %d" % (index + 1), 34 if big else 30)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day.position = Vector2(0, 14)
	day.size = Vector2(sz.x, 44)
	root.add_child(day)
	# Le cadeau.
	var keys: Array = reward.keys()
	if big:
		var chest := TextureRect.new()
		chest.texture = load(CHEST) if ResourceLoader.exists(CHEST) else null
		chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest.position = Vector2(sz.x / 2.0 - 110, 66)
		chest.size = Vector2(220, 220)
		chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(chest)
		for k in keys.size():
			var w := (sz.x - 30) / keys.size()
			_amount(root, String(keys[k]), int(reward[keys[k]]), Rect2(15 + k * w, 286, w, 96), 52.0, 26)
	elif not keys.is_empty():
		_amount(root, String(keys[0]), int(reward[keys[0]]), Rect2(0, 78, sz.x, sz.y - 90), 124.0, 36)
	if state == "taken":
		var stamp := UiKit.title("✓ Pris", 34, Color("2f7d5b"))
		stamp.add_theme_color_override("font_outline_color", Color("f3e9d2"))
		stamp.add_theme_constant_override("outline_size", 10)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.position = Vector2(0, sz.y * 0.42)
		stamp.size = Vector2(sz.x, 50)
		stamp.pivot_offset = stamp.size / 2.0
		stamp.rotation = -0.2
		root.add_child(stamp)
	elif state == "later":
		root.modulate = Color(0.86, 0.84, 0.9, 1.0)
	return root


## L'icône du cadeau au-dessus de son montant, centrés dans `r`.
func _amount(parent: Control, key: String, amount: int, r: Rect2, icon_px: float, font: int) -> void:
	var ic := UiKit.icon(String(ICONS.get(key, "recompenses")), icon_px)
	ic.position = Vector2(r.position.x + (r.size.x - icon_px) / 2.0, r.position.y)
	ic.size = Vector2(icon_px, icon_px)
	parent.add_child(ic)
	var l := UiKit.title("%d" % amount, font, UiKit.INK)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(r.position.x, r.position.y + icon_px + 2)
	l.size = Vector2(r.size.x, font + 10)
	parent.add_child(l)
	if icon_px > 80.0:
		var name := UiKit.label(String(NAMES.get(key, "")), 22, UiKit.TEXT_SOFT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.position = Vector2(r.position.x, r.position.y + icon_px + font + 10)
		name.size = Vector2(r.size.x, 30)
		parent.add_child(name)


func _on_claim() -> void:
	if PlayerData.claim_login().is_empty():
		return
	ui_sound.emit("ui_ready")
	Input.vibrate_handheld(60)
	if _today_card:  # la carte saute avant de recevoir son tampon
		var card := _today_card
		_today_card = null
		card.rotation = 0.0
		var tw := create_tween()
		tw.tween_property(card, "scale", Vector2(1.14, 1.14), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE, 0.18)
		tw.tween_callback(_fill)
	else:
		_fill()
