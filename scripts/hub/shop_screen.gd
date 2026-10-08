class_name ShopScreen
extends UiWindow
## Le Marchand (le vendeur de masques et son échoppe) : il vend ce qui sert à progresser (offres
## de `data/hub.json` "shop", payées en or ou en gemmes gagnées en jouant) et rachète le butin de
## chasse (matériaux des monstres) contre de l'or.

signal ui_sound(sfx_name: String)

const ITEM_NAMES := {"fragments_relique": "Éclats de serment", "materiaux_relique": "Matériaux de relique",
	"essence_ombre": "Essences d'ombre", "gold": "or", "gems": "gemmes", "energy": "énergie"}

var _offers: VBoxContainer
var _loot: VBoxContainer
var _purse: Label
var _fusion: VBoxContainer


func _init() -> void:
	setup("Marchand", Vector2(1380, 860))


func _ready() -> void:
	super._ready()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	body.add_child(left)
	var art := TextureRect.new()
	var fiche := "res://assets/npcs2d/marchand_masques/fiche.png"
	art.texture = load(fiche) if ResourceLoader.exists(fiche) else null
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(330, 420)
	left.add_child(art)
	var hello := UiKit.label("« Des masques, des reliques, des babioles… Et ton butin m'intéresse, chasseur. »", 19, UiKit.TEXT_SOFT)
	hello.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hello)
	_purse = UiKit.label("", 21, UiKit.INK)
	left.add_child(_purse)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	scroll.add_child(right)
	right.add_child(_section("À vendre"))
	_offers = VBoxContainer.new()
	_offers.add_theme_constant_override("separation", 10)
	right.add_child(_offers)
	right.add_child(_section("Fusion des Esprits"))
	_fusion = VBoxContainer.new()
	_fusion.add_theme_constant_override("separation", 8)
	right.add_child(_fusion)
	right.add_child(_section("Il rachète ton butin"))
	_loot = VBoxContainer.new()
	_loot.add_theme_constant_override("separation", 8)
	right.add_child(_loot)
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	super.open()
	refresh()


func refresh() -> void:
	_purse.text = "Ta bourse : %d or · %d gemmes" % [PlayerData.gold(), PlayerData.gems()]
	for c in _offers.get_children():
		c.queue_free()
	for offer: Dictionary in GameData.hub.get("shop", []):
		if offer.get("gives", {}).has("materiaux_relique") and not PlayerData.relics_unlocked():
			continue  # les reliques sont scellées jusqu'à la fin de la Campagne 1
		_offers.add_child(_offer_card(offer))
	for c in _fusion.get_children():
		c.queue_free()
	var fusable := 0
	for stage: String in Progression.ESPRIT_STAGES.slice(0, 3):
		for elem: String in Progression.ELEMENTS:
			var item := Progression.esprit_id(stage, elem)
			var n := PlayerData.item_count(item)
			if n <= 0:
				continue
			fusable += 1
			var up := Progression.esprit_id(Progression.ESPRIT_STAGES[Progression.ESPRIT_STAGES.find(stage) + 1], elem)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			for it: String in [item, up]:
				var ic := TextureRect.new()
				ic.texture = ChestReveal.esprit_icon(it)
				ic.custom_minimum_size = Vector2(48, 48)
				ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				row.add_child(ic)
			var name := UiKit.label("%s × %d   →   5 pour 1 %s" % [HeroesScreen.esprit_name(item, true), n,
				HeroesScreen.esprit_name(up)], 19, UiKit.INK)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
			var b := UiKit.button("Fusionner · %d or" % PlayerData.FUSION_GOLD, "blue", 18, Vector2(230, 48))
			b.disabled = n < PlayerData.FUSION_COUNT or PlayerData.gold() < PlayerData.FUSION_GOLD
			b.pressed.connect(func() -> void:
				if PlayerData.fuse_esprit(item):
					ui_sound.emit("ultimate_impact"))
			row.add_child(b)
			_fusion.add_child(row)
	if fusable == 0:
		_fusion.add_child(UiKit.label("Tes Esprits apparaîtront ici : 5 du même stade donnent 1 Esprit plus grand.", 18, UiKit.TEXT_SOFT))
	for c in _loot.get_children():
		c.queue_free()
	var price := int(GameData.hub.get("sell_price", 25))
	var any := false
	for item: String in _loot_items():
		var n := PlayerData.item_count(item)
		if n <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name := UiKit.label("%s × %d" % [_item_name(item), n], 20, UiKit.INK)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var b := UiKit.button("Vendre · %d or" % (n * price), "gold", 18, Vector2(220, 48))
		var it := item
		b.pressed.connect(func() -> void:
			if PlayerData.sell(it, PlayerData.item_count(it), price):
				ui_sound.emit("ui_ready"))
		row.add_child(b)
		_loot.add_child(row)
	if not any:
		_loot.add_child(UiKit.label("Rien à vendre pour l'instant : chasse des monstres pour récolter leurs matériaux.", 18, UiKit.TEXT_SOFT))


func _offer_card(offer: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.card())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := UiKit.label(String(offer.get("name", "")), 22, UiKit.INK)
	t.add_theme_font_override("font", UiKit.FONT_BOLD)
	col.add_child(t)
	col.add_child(UiKit.label(String(offer.get("description", "")), 17, UiKit.TEXT_SOFT))
	var cost: Dictionary = offer.get("cost", {})
	var parts: Array = []
	for k: String in cost:
		parts.append("%d %s" % [int(cost[k]), ITEM_NAMES.get(k, k)])
	var b := UiKit.button("Acheter · " + ", ".join(parts), "green", 18, Vector2(260, 52))
	b.pressed.connect(func() -> void:
		if PlayerData.buy(offer):
			ui_sound.emit("ui_ready")
		else:
			ui_sound.emit("ui_toggle"))
	row.add_child(b)
	return p


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
	return item.replace("_", " ").capitalize()


func _section(text: String) -> Label:
	var l := UiKit.title(text, 28, UiKit.WOOD)
	l.add_theme_constant_override("outline_size", 0)
	return l
