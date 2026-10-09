class_name ShopScreen
extends Control
## L'Échoppe des masques (le Marchand), pack « Échoppe et Reliquaire » (assets/ui/echoppe/,
## positions dans ecrans.json). Plein écran 1920 × 1080 : la marchande derrière son comptoir à
## gauche, une bulle pour ses répliques, et à droite son étal à trois étagères. Trois enseignes :
## Articles (offres de `data/hub.json` "shop", posées sur des coussins avec leur étiquette de prix),
## Fusion des Esprits (balance : 5 Esprits du même stade → 1 du stade suivant) et Rachat du butin
## (matériaux des monstres posés sur le comptoir, contre de l'or).

signal closed
signal ui_sound(sfx_name: String)

const DIR := "res://assets/ui/echoppe/"
const ITEM_NAMES := {"fragments_relique": "Éclats de serment", "materiaux_relique": "Matériaux de relique",
	"essence_ombre": "Essences d'ombre", "gold": "or", "gems": "gemmes", "energy": "énergie"}
const TABS := [["articles", "Articles"], ["fusion", "Fusion"], ["rachat", "Rachat"]]
const LINES := {"articles": "Des masques, des babioles… et de quoi bâtir ton donjon. Choisis, chasseur.",
	"fusion": "Cinq Esprits du même stade, et ma balance t'en rend un plus grand. Pour 100 or.",
	"rachat": "Ton butin de chasse m'intéresse. Pose-le sur le comptoir.",
	"bought": "Bon choix ! Reviens quand tu veux.", "poor": "Ta bourse est trop légère pour ça…",
	"fused": "Et voilà, un Esprit plus grand !", "sold": "Marché conclu !"}

static var _layout: Dictionary = {}

var _mode := "articles"
var _root: Control
var _layer: Control  # contenu de l'onglet (vidé à chaque rafraîchissement)
var _talk: Label
var _gold: Label
var _gems: Label
var _tabs: Dictionary = {}  # id -> [TextureRect, Label]
var _fuse_pick := ""  # Esprit choisi pour la fusion
var _coin: MageRoom.Sheet


static func L() -> Dictionary:
	if _layout.is_empty():
		_layout = GameData.load_json(DIR + "ecrans.json")
	return _layout


static func tex(path: String) -> Texture2D:
	return load(DIR + path) if ResourceLoader.exists(DIR + path) else null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = ScreenPack.frame(self)
	var E: Dictionary = L().get("echoppe", {})
	_img(_root, tex("echoppe/echoppe_fond.png"), Rect2(0, 0, 1920, 1080))
	# Masques suspendus qui se balancent.
	var masks := MageRoom.Sheet.new()
	masks.base_dir = DIR
	masks.anims = {"masques_balancent": _anim_def("masques_balancent")}
	var mr := _rect(E.get("masks_rect", [180, 140, 384, 256]))
	masks.position = mr.position + Vector2(192, 12)
	_root.add_child(masks)
	masks.visible = false  # les masques animés juraient avec le décor (déjà plein de masques)
	# La marchande, derrière le comptoir.
	var fiche := "res://assets/npcs2d/marchand_masques/fiche.png"
	var m := _img(_root, load(fiche) if ResourceLoader.exists(fiche) else null, _rect(E.get("merchant_rect", [120, 400, 440, 480])))
	m.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var fc: Dictionary = E.get("foreground_counter", {})
	_img(_root, tex(String(fc.get("file", "echoppe/comptoir_avant.png"))), _rect(fc.get("rect", [0, 632, 856, 245])))
	# Bulle de dialogue.
	var dr := _rect(E.get("dialogue_rect", [90, 860, 520, 210]))
	_nine(_root, "echoppe/bulle_marchande.png", dr)
	_talk = ScreenPack.text(_root, "", Rect2(dr.position + Vector2(56, 34), Vector2(dr.size.x - 96, dr.size.y - 92)), 22, UiKit.INK,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	_talk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Haut : retour, titre, bourses.
	var back := TextureButton.new()
	back.texture_normal = tex("commun/retour_normal.png")
	back.texture_hover = tex("commun/retour_survol.png")
	back.texture_pressed = tex("commun/retour_appuye.png")
	var br := _rect(E.get("return_rect", [30, 28, 220, 80]))
	back.position = br.position
	back.size = br.size
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_SCALE
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		visible = false
		closed.emit())
	_root.add_child(back)
	ScreenPack.shadow(ScreenPack.text(back, "Port", Rect2(70, 0, 140, br.size.y), 26, Color("f3d9a0"),
		HORIZONTAL_ALIGNMENT_CENTER), 2)
	_nine(_root, "commun/bandeau_titre.png", _rect(E.get("title_rect", [610, 24, 700, 90])))
	ScreenPack.shadow(ScreenPack.text(_root, "L'ÉCHOPPE DES MASQUES", _rect(E.get("title_writing_rect", [745, 48, 430, 34])), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var crs: Array = E.get("currency_rects", [[1420, 28, 220, 72], [1660, 28, 220, 72]])
	var cws: Array = E.get("currency_writing_rects", [[1496, 49, 120, 32], [1736, 49, 120, 32]])
	var icons := [ScreenPack.tex("combat", "reward_gold_64"), ScreenPack.tex("lanterne", "gemme_64")]
	var labels: Array[Label] = []
	for i in 2:
		var r := _rect(crs[i])
		_nine(_root, "commun/cartouche_monnaie.png", r)
		# Symbole centré dans le médaillon rond du cartouche (centre ≈ 40, 36).
		var ic := _img(_root, ScreenPack.trimmed(icons[i]), Rect2(r.position + Vector2(40, 36) - Vector2(17, 17), Vector2(34, 34)))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var wr := _rect(cws[i])
		labels.append(ScreenPack.shadow(ScreenPack.text(_root, "", Rect2(wr.position.x - 6, r.position.y, wr.size.x + 12, r.size.y), 24,
			Color("ffe7a8"), HORIZONTAL_ALIGNMENT_CENTER), 2))
	_gold = labels[0]
	_gems = labels[1]
	# Enseignes (onglets).
	for t: Dictionary in E.get("tabs", []):
		var id := String(t.id)
		if id == "fusion":
			continue  # la fusion des Esprits se fait chez le Druide (Lanterne)
		var shift := Vector2(170 if id == "articles" else -170, 0)
		var r := _rect(t.rect)
		r.position += shift
		var sign := _img(_root, null, r)
		sign.mouse_filter = Control.MOUSE_FILTER_STOP
		sign.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sign.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_set_mode(id))
		var name := ""
		for x: Array in TABS:
			if x[0] == id:
				name = x[1]
		var wr := _rect(t.writing_rect)
		wr.position += shift
		var l := ScreenPack.shadow(ScreenPack.text(_root, name, wr, 24, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
		_tabs[id] = [sign, l]
	_layer = Control.new()
	_layer.size = Vector2(1920, 1080)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_layer)
	_coin = MageRoom.Sheet.new()
	_coin.base_dir = DIR
	_coin.anims = {"piece_tombe": _anim_def("piece_tombe")}
	_coin.visible = false
	_root.add_child(_coin)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	visible = true
	_mode = "articles"
	_say(LINES.articles)
	refresh()


func close_window() -> void:
	visible = false
	closed.emit()


func _set_mode(mode: String) -> void:
	if mode == _mode:
		return
	ui_sound.emit("ui_click")
	_mode = mode
	_say(LINES.get(mode, ""))
	refresh()


func _say(text: String) -> void:
	_talk.text = text
	_talk.visible_ratio = 0.0
	create_tween().tween_property(_talk, "visible_ratio", 1.0, 0.4)


func refresh() -> void:
	_gold.text = str(PlayerData.gold())
	_gems.text = str(PlayerData.gems())
	for id: String in _tabs:
		var on := id == _mode
		(_tabs[id][0] as TextureRect).texture = tex("echoppe/onglets/%s_%s.png" % [id, "actif" if on else "inactif"])
		(_tabs[id][1] as Label).modulate = Color.WHITE if on else Color(0.75, 0.7, 0.75)
	for c in _layer.get_children():
		_layer.remove_child(c)
		c.queue_free()
	match _mode:
		"rachat":
			_fill_rachat()
		_:
			_fill_articles()


# --- Articles ----------------------------------------------------------------------------------

func _fill_articles() -> void:
	var E: Dictionary = L().get("echoppe", {})
	_img(_layer, tex("echoppe/etal.png"), _rect(E.get("etal_rect", [690, 260, 1150, 760])))
	var offers: Array = []
	for offer: Dictionary in GameData.hub.get("shop", []):
		if offer.get("gives", {}).has("materiaux_relique") and not PlayerData.relics_unlocked():
			continue  # les reliques sont scellées jusqu'à la fin de la Campagne 1
		offers.append(offer)
	var slots: Array = E.get("articles", [])
	for i in mini(offers.size(), slots.size()):
		_article(offers[i], slots[i])


func _article(offer: Dictionary, slot: Dictionary) -> void:
	var cost: Dictionary = offer.get("cost", {})
	var can := true
	for k: String in cost:
		var have := PlayerData.gold() if k == "gold" else (PlayerData.gems() if k == "gems" else PlayerData.item_count(k))
		can = can and have >= int(cost[k])
	var sr := _rect(slot.socle_rect)
	var socle := _img(_layer, tex("echoppe/socle_article_%s.png" % ("normal" if can else "vendu")), sr)
	var gives: Dictionary = offer.get("gives", {})
	var key: String = gives.keys()[0] if not gives.is_empty() else ""
	var ar := _rect(slot.article_rect)
	# Échelle entière (pixel net) : la plus grande qui tient dans la place de l'article.
	var t := ScreenPack.trimmed(_item_icon(key))
	var ks := maxf(1.0, floorf(96.0 / maxf(1.0, maxf(t.get_width(), t.get_height())))) if t else 1.0
	var isz := (t.get_size() * ks) if t else Vector2(96, 96)
	var item := _img(_layer, t, Rect2(Vector2(ar.get_center().x - isz.x / 2.0, ar.end.y - 26 - isz.y), isz))
	if not can:
		item.modulate = Color(0.55, 0.52, 0.58)
	if not gives.is_empty():
		ScreenPack.shadow(ScreenPack.text(_layer, "×%d" % int(gives[key]), Rect2(ar.end.x - 70, ar.end.y - 48, 80, 34), 24,
			Color("ffd27a"), HORIZONTAL_ALIGNMENT_RIGHT), 2)
	var pr := _rect(slot.prix_rect)
	var tag := _nine(_layer, "echoppe/etiquette_prix_normal.png", pr)
	var parts: Array = []
	for k: String in cost:
		parts.append("%d %s" % [int(cost[k]), ITEM_NAMES.get(k, k)])
	ScreenPack.text(_layer, ", ".join(parts), Rect2(pr.position + Vector2(30, 6), pr.size - Vector2(40, 12)), 20,
		UiKit.INK if can else Color("8a3a20"), HORIZONTAL_ALIGNMENT_CENTER)
	# Zone de clic : le coussin et l'objet ; survol : coussin éclairé et nom dans la bulle.
	var hit := Control.new()
	hit.position = Vector2(sr.position.x, ar.position.y)
	hit.size = Vector2(sr.size.x, pr.end.y - ar.position.y)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = "%s\n%s" % [offer.get("name", ""), offer.get("description", "")]
	_layer.add_child(hit)
	hit.mouse_entered.connect(func() -> void:
		if can:
			socle.texture = tex("echoppe/socle_article_survol.png")
			tag.texture = tex("echoppe/etiquette_prix_survol.png")
		_talk.text = "%s — %s" % [offer.get("name", ""), offer.get("description", "")]
		_talk.visible_ratio = 1.0)
	hit.mouse_exited.connect(func() -> void:
		if can:
			socle.texture = tex("echoppe/socle_article_normal.png")
			tag.texture = tex("echoppe/etiquette_prix_normal.png"))
	hit.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if PlayerData.buy(offer):
				ui_sound.emit("ui_ready")
				_drop_coin(ar.get_center())
				_say(LINES.bought)
			else:
				ui_sound.emit("ui_toggle")
				_say(LINES.poor))


func _drop_coin(at: Vector2) -> void:
	_coin.position = at + Vector2(0, 40)
	_coin.visible = true
	_coin.play("piece_tombe")
	_coin.finished.connect(func() -> void: _coin.visible = false, CONNECT_ONE_SHOT)


# --- Fusion des Esprits -----------------------------------------------------------------------

func _fill_fusion() -> void:
	var E: Dictionary = L().get("echoppe", {})
	var fr := _rect(E.get("fusion_rect", [1060, 410, 420, 360]))
	_img(_layer, tex("echoppe/balance_fusion.png"), fr)
	# Les Esprits fusionnables, en colonne à gauche de la balance (clic = choisir).
	var have: Array[String] = []
	for stage: String in Progression.ESPRIT_STAGES.slice(0, 3):
		for elem: String in Progression.ELEMENTS:
			var item := Progression.esprit_id(stage, elem)
			if PlayerData.item_count(item) > 0:
				have.append(item)
	if have.is_empty():
		ScreenPack.shadow(ScreenPack.text(_layer, "Tu n'as pas encore d'Esprit.\nLe Druide de la Lanterne en invoque, et les coffres de fin de niveau en donnent.",
			Rect2(760, 800, 1060, 100), 22, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true), 2)
		return
	if _fuse_pick not in have:
		_fuse_pick = have[0]
		for it: String in have:
			if PlayerData.item_count(it) >= PlayerData.FUSION_COUNT:
				_fuse_pick = it
				break
	var cols := 2
	for i in have.size():
		var it: String = have[i]
		var r := Rect2(760 + (i % cols) * 140, 300 + (i / cols) * 96, 128, 88)
		var b := Control.new()
		b.position = r.position
		b.size = r.size
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = HeroesScreen.esprit_name(it)
		_layer.add_child(b)
		var sel := it == _fuse_pick
		var bgp := Panel.new()
		bgp.add_theme_stylebox_override("panel", Palette.stylebox(Color(0.08, 0.05, 0.08, 0.75),
			Color("ffd27a") if sel else Color(1, 1, 1, 0.15), 10, 3 if sel else 1))
		bgp.size = r.size
		bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bgp)
		var ic := _img(b, ChestReveal.esprit_icon(it), Rect2(6, 12, 64, 64))
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ScreenPack.shadow(ScreenPack.text(b, "×%d" % PlayerData.item_count(it), Rect2(64, 24, 60, 40), 22, Color("ffd27a")), 2)
		b.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				ui_sound.emit("ui_click")
				_fuse_pick = it
				refresh())
	# Sur la balance : 5 coupelles (les Esprits donnés) → 1 (l'Esprit obtenu).
	var n := PlayerData.item_count(_fuse_pick)
	var parts := _fuse_pick.split("_")
	var up := Progression.esprit_id(Progression.ESPRIT_STAGES[Progression.ESPRIT_STAGES.find(parts[1]) + 1], parts[2])
	var inputs: Array = E.get("fusion_inputs", [])
	for i in inputs.size():
		var c := Vector2(inputs[i][0], inputs[i][1])
		var ic := _img(_layer, ChestReveal.esprit_icon(_fuse_pick), Rect2(c - Vector2(28, 28), Vector2(56, 56)))
		if i >= n:
			ic.modulate = Color(0.2, 0.2, 0.25, 0.6)
	var oc: Array = E.get("fusion_output", [1404, 550])
	var out := _img(_layer, ChestReveal.esprit_icon(up, 128), Rect2(Vector2(oc[0], oc[1]) - Vector2(44, 44), Vector2(88, 88)))
	if n < PlayerData.FUSION_COUNT:
		out.modulate = Color(0.45, 0.42, 0.5)
	ScreenPack.shadow(ScreenPack.text(_layer, "5 %s  →  1 %s" % [HeroesScreen.esprit_name(_fuse_pick, true),
		HeroesScreen.esprit_name(up)], Rect2(1000, 790, 760, 36), 24, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var b := UiKit.button("Fusionner · %d or" % PlayerData.FUSION_GOLD, "gold", 22, Vector2(320, 64))
	b.position = Vector2(1220, 836)
	b.disabled = n < PlayerData.FUSION_COUNT or PlayerData.gold() < PlayerData.FUSION_GOLD
	b.pressed.connect(func() -> void:
		if PlayerData.fuse_esprit(_fuse_pick):
			ui_sound.emit("ultimate_impact")
			_drop_coin(Vector2(oc[0], oc[1]))
			_say(LINES.fused))
	_layer.add_child(b)


# --- Rachat du butin --------------------------------------------------------------------------

func _fill_rachat() -> void:
	var E: Dictionary = L().get("echoppe", {})
	_img(_layer, tex("echoppe/comptoir_rachat.png"), _rect(E.get("rachat_rect", [850, 650, 700, 220])))
	var price := int(GameData.hub.get("sell_price", 25))
	var owned: Array[String] = []
	for item: String in _loot_items():
		if PlayerData.item_count(item) > 0:
			owned.append(item)
	ScreenPack.shadow(ScreenPack.text(_layer, "Chaque matériau : %d or · touche un objet pour tout vendre" % price,
		Rect2(760, 560, 1060, 40), 22, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	if owned.is_empty():
		ScreenPack.shadow(ScreenPack.text(_layer, "Rien à vendre pour l'instant : chasse des monstres pour récolter leurs matériaux.",
			Rect2(760, 900, 1060, 60), 21, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true), 2)
	var slots: Array = E.get("rachat_slots", [])
	for i in mini(owned.size(), slots.size()):
		var it: String = owned[i]
		var r := _rect(slots[i])
		var hit := Control.new()
		hit.position = r.position
		hit.size = r.size
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var n := PlayerData.item_count(it)
		hit.tooltip_text = "%s × %d · %d or" % [_item_name(it), n, n * price]
		_layer.add_child(hit)
		var ic := _img(hit, ScreenPack.tex("combat", "reward_materials_64"), Rect2(Vector2(13, 8), Vector2(64, 64)))
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ScreenPack.shadow(ScreenPack.text(hit, "×%d" % n, Rect2(0, 62, r.size.x, 28), 20, Color("ffd27a"), HORIZONTAL_ALIGNMENT_CENTER), 2)
		hit.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				if PlayerData.sell(it, PlayerData.item_count(it), price):
					ui_sound.emit("ui_ready")
					_drop_coin(r.get_center())
					_say(LINES.sold))
	if owned.size() > slots.size():
		ScreenPack.shadow(ScreenPack.text(_layer, "+ %d autres matériaux" % (owned.size() - slots.size()), Rect2(850, 880, 700, 30),
			18, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)


## Matériaux de monstres possédés (les « drop » des ennemis).
func _loot_items() -> Array:
	var out: Array = []
	for mid: String in GameData.monsters:
		var drop := String(GameData.monsters[mid].get("drop", ""))
		if drop != "" and drop not in out:
			out.append(drop)
	return out


func _item_name(item: String) -> String:
	if ITEM_NAMES.has(item):
		return ITEM_NAMES[item]
	var piece: Dictionary = GameData.summon.get("mechanic", {}).get("pieces", {}).get(item, {})
	if not piece.is_empty():
		return String(piece.name)
	return item.replace("_", " ").capitalize()


## Icône d'un objet vendu (énergie, éclats, pièces du Mécanicien, Esprits…).
func _item_icon(key: String) -> Texture2D:
	var piece: Dictionary = GameData.summon.get("mechanic", {}).get("pieces", {}).get(key, {})
	if not piece.is_empty():
		return MageRoom.tex(String(piece.get("icon", "")))
	if key.begins_with("esprit_"):
		return ChestReveal.esprit_icon(key, 128)
	match key:
		"energy":
			return ScreenPack.tex("combat", "reward_energy_64")
		"fragments_relique":
			return ScreenPack.tex("lanterne", "fragment_serment_64")
		"gems":
			return ScreenPack.tex("lanterne", "gemme_64")
		"gold":
			return ScreenPack.tex("combat", "reward_gold_64")
		"materiaux_relique":
			return ScreenPack.tex("combat", "reward_relic_fragment_64")
	return ScreenPack.tex("combat", "reward_materials_64")


# --- Outils ------------------------------------------------------------------------------------

func _anim_def(name: String) -> Dictionary:
	var a: Dictionary = L().get("animations", {}).get(name, {})
	var n := int(a.get("frames", 1))
	var d := {"file": a.get("file", ""), "frame_size": a.get("frame_size", [128, 128]), "frame_count": n,
		"duration_ms": a.get("duration_ms", 100), "loop": a.get("loop", false), "pivot": a.get("pivot", [0, 0])}
	return d


func _rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


func _img(parent: Control, t: Texture2D, r: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


## Panneau 9-slice du pack (marges de ecrans.json).
func _nine(parent: Control, path: String, r: Rect2) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = tex(path)
	var m: Array = L().get("nine_slice", {}).get(path, [16, 16, 16, 16])
	np.patch_margin_left = int(m[0])
	np.patch_margin_top = int(m[1])
	np.patch_margin_right = int(m[2])
	np.patch_margin_bottom = int(m[3])
	np.position = r.position
	np.size = r.size
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(np)
	return np
