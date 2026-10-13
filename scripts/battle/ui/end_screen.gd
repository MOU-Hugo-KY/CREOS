class_name EndScreen
extends Control
## Écran de fin de combat en pixel (pack de l'interface de combat, disposition « results » de
## combat_ui.json) : grande fenêtre ivoire (victoire) ou sombre (défaite), ruban de titre, étoiles,
## cases de butin avec leur icône, carte de chaque chasseur (portrait, niveau, XP, dégâts, soins,
## meilleur chasseur, voile K.O.), coffre de fin de niveau, boutons Rejouer et Retour au port.

signal restart_pressed
signal continue_pressed
signal sound(sfx_name: String)

const P := "combat"
const REWARD_ICONS := {"gold": "reward_gold_64", "xp": "reward_experience_64", "gems": "reward_gems_64",
	"energy": "reward_energy_64", "materiaux_relique": "reward_materials_64", "fragments_relique": "reward_relic_fragment_64"}
const REWARD_NAMES := {"gold": "Or", "xp": "Expérience", "gems": "Gemmes", "energy": "Énergie",
	"materiaux_relique": "Matériaux de relique", "fragments_relique": "Éclats de serment"}
const CHEST_COLORS := {"bois": Color("8a5a2b"), "fer": Color("4f6178"), "or": Color("a8771a"), "serment": Color("7a3fb0")}
const ELEMENT_KEYS := {"feu": "fire", "eau": "water", "nature": "nature", "lumiere": "light", "ombre": "shadow"}

var _root: Control
var _window: Panel
var _title: Label
var _stars: Array[StarIcon] = []
var _content: Control
var _restart: Button
var _next: Button
var _chest_reveal: ChestReveal


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_root = ScreenPack.frame(self)
	var R: Dictionary = ScreenPack.layout(P).results
	_window = ScreenPack.panel(_root, P, "result_victory_window", ScreenPack.rect(R.window_rect))
	var tr := ScreenPack.rect(R.title_rect)
	ScreenPack.image(_root, ScreenPack.tex(P, "result_title"), tr)
	_title = ScreenPack.text(_root, "", tr, 46, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for r: Array in R.stars_rects:
		var st := StarIcon.new()
		st.position = Vector2(r[0], r[1])
		st.custom_minimum_size = Vector2(r[2], r[3])
		st.size = Vector2(r[2], r[3])
		_root.add_child(st)
		_stars.append(st)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = Vector2(1920, 1080)
	_root.add_child(_content)
	var B: Dictionary = R.buttons
	_restart = ScreenPack.button(_root, P, "replay", "Rejouer", ScreenPack.rect(B.replay_rect), 30, UiKit.INK)
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	_next = ScreenPack.button(_root, P, "return", "Retour au port", ScreenPack.rect(B.return_rect), 30)
	_next.pressed.connect(func() -> void: continue_pressed.emit())
	_chest_reveal = ChestReveal.new()
	add_child(_chest_reveal)
	if FinPack.available(FC):
		_ready_pack()


## hero_stats : Array de {id, name, element, alive, damage, healing, level, xp, level_up}
## replay : {cost, possible, energy, player_level_up, player_level, chest}
func show_result(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String, replay := {}) -> void:
	if _pack:
		_show_pack(won, stars, rewards, hero_stats, dungeon_name, replay)
		return
	var R: Dictionary = ScreenPack.layout(P).results
	_window.add_theme_stylebox_override("panel", ScreenPack.nine(P, "result_victory_window" if won else "result_defeat_window"))
	var draw: bool = replay.get("draw", false)
	_title.text = "ÉGALITÉ" if draw else ("VICTOIRE" if won else "DÉFAITE")
	for c in _content.get_children():
		c.queue_free()
	var ink := UiKit.INK if won else UiKit.WHITE
	var wr := ScreenPack.rect(R.window_rect)
	ScreenPack.text(_content, dungeon_name, Rect2(wr.position.x + 60, 196, 560, 40), 24, ink)
	# Butin : une case par récompense, avec son icône et la quantité.
	ScreenPack.text(_content, "BUTIN" if won else "AUCUN BUTIN", Rect2(178, 280, 400, 40), 26, ink)
	var slots: Array = R.rewards.slot_rects
	var i := 0
	for key: String in rewards:
		if i >= slots.size():
			break
		_reward_slot(ScreenPack.rect(slots[i]), key, int(rewards[key]), ink)
		i += 1
	if replay.get("player_level_up", false):
		ScreenPack.text(_content, "Ta loge passe au niveau %d !" % int(replay.player_level), Rect2(1100, 280, 650, 40), 24,
			UiKit.WOOD, HORIZONTAL_ALIGNMENT_RIGHT)
	# Les chasseurs.
	var best := 0.0
	for h: Dictionary in hero_stats:
		best = maxf(best, float(h.damage))
	var cards: Array = R.hunter_cards.rects
	var offset := (cards.size() - mini(hero_stats.size(), cards.size())) * 114.0  # centrer une petite équipe
	for k in mini(hero_stats.size(), cards.size()):
		var r := ScreenPack.rect(cards[k])
		r.position.x += offset
		_hunter_card(r, hero_stats[k], R.hunter_cards, float(hero_stats[k].damage) > 0.0 and float(hero_stats[k].damage) == best)
	# Coffre de fin de niveau (après les étoiles) ou conseil après une défaite.
	var ar := ScreenPack.rect(R.advice_rect)
	var chest: Dictionary = replay.get("chest", {})
	var chest_line: Label = null
	if not chest.is_empty():
		var bits: Array[String] = []
		for key: String in chest.rewards:
			bits.append("+%d %s" % [int(chest.rewards[key]), _reward_name(key, int(chest.rewards[key])).to_lower()])
		chest_line = ScreenPack.text(_content, "%s !   %s" % [chest.name, "  ·  ".join(bits)], ar, 28,
			CHEST_COLORS.get(chest.kind, UiKit.WOOD), HORIZONTAL_ALIGNMENT_CENTER)
		chest_line.modulate.a = 0.0
	elif draw:
		ScreenPack.text(_content, "Combat arrêté : pas de butin, ton énergie t'est rendue.", ar, 24, UiKit.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, true)
	elif not won:
		ScreenPack.text(_content, "Conseil : améliore tes héros chez la Loge, éveille-les avec des Esprits et change ta formation.",
			ar, 24, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	var cost: int = replay.get("cost", 0)
	_restart.text = "Rejouer" if cost <= 0 else "Rejouer · %d énergie" % cost
	_restart.disabled = not replay.get("possible", true)
	_restart.tooltip_text = "" if not _restart.disabled else "Pas assez d'énergie (%d)." % int(replay.get("energy", 0))

	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	for s in _stars:
		s.lit = false
		s.scale = Vector2.ONE
		s.queue_redraw()
	var seq := create_tween()
	seq.tween_interval(0.5)
	for k in stars:
		var star := _stars[k]
		seq.tween_callback(func() -> void:
			star.pivot_offset = star.size / 2.0
			star.lit = true
			star.scale = Vector2.ONE * 1.6
			star.queue_redraw()
			sound.emit("ui_ready"))
		seq.tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		seq.tween_interval(0.18)
	if chest_line:
		seq.tween_interval(0.3)
		# Le coffre s'ouvre en grand par-dessus l'écran ; sa ligne reste ensuite dans le bilan.
		seq.tween_callback(func() -> void: _chest_reveal.show_chest(chest, _reward_name))
		seq.tween_callback(func() -> void: sound.emit("ultimate_impact" if chest.kind in ["or", "serment"] else "ui_ready"))
		chest_line.pivot_offset = chest_line.size / 2.0
		chest_line.scale = Vector2.ONE * 1.3
		seq.tween_property(chest_line, "modulate:a", 1.0, 0.2)
		seq.parallel().tween_property(chest_line, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _reward_slot(r: Rect2, key: String, amount: int, ink: Color) -> void:
	var slot := ScreenPack.panel(_content, P, "reward_slot", r)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.tooltip_text = _reward_name(key, amount)
	var icon := ScreenPack.tex(P, _reward_icon(key))
	if key.begins_with("esprit_"):
		icon = ChestReveal.esprit_icon(key)
	ScreenPack.image(slot, icon, Rect2(28, 18, 64, 64))
	ScreenPack.text(_content, str(amount), Rect2(r.position.x, r.end.y - 38, r.size.x, 30), 24, UiKit.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER)
	ScreenPack.text(_content, _reward_name(key, amount), Rect2(r.position.x - 30, r.end.y + 6, r.size.x + 60, 26), 17, ink,
		HORIZONTAL_ALIGNMENT_CENTER)


func _hunter_card(r: Rect2, h: Dictionary, C: Dictionary, mvp: bool) -> void:
	var card := ScreenPack.panel(_content, P, "hunter_card" if h.alive else "hunter_card_ko", r)
	var at := func(o: Array) -> Rect2: return Rect2(Vector2(o[0], o[1]), Vector2(o[2], o[3]))
	var hero := GameData.hero(String(h.get("id", "")))
	if not hero.is_empty():
		var pr: Rect2 = at.call(C.portrait_offset)
		var portrait := RoundPortrait.new().setup(hero, pr.size.x)
		portrait.position = pr.position
		portrait.size = pr.size
		portrait.set_grey(not h.alive)
		card.add_child(portrait)
	ScreenPack.text(card, String(h.name), at.call(C.name_offset), 24, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var lv := "Niv. %d · +%d XP" % [int(h.level), int(h.xp)]
	if h.get("level_up", false):
		lv = "Niv. %d · niveau +1 !" % int(h.level)
	ScreenPack.text(card, lv, at.call(C.level_xp_offset), 18, UiKit.TEAL.darkened(0.35) if h.get("level_up", false) else UiKit.TEXT_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER)
	var xb: Rect2 = at.call(C.xp_bar_offset)
	var bar := ColorRect.new()
	bar.color = Color("29262e")
	bar.position = xb.position
	bar.size = xb.size
	card.add_child(bar)
	var need := maxf(1.0, PlayerData.hero_xp_to_next(String(h.get("id", ""))))
	var fill := ColorRect.new()
	fill.color = UiKit.TEAL
	fill.position = xb.position + Vector2(2, 2)
	fill.size = Vector2((xb.size.x - 4) * clampf(PlayerData.hero_xp(String(h.get("id", ""))) / need, 0.0, 1.0), xb.size.y - 4)
	card.add_child(fill)
	var d: Array = C.damage_offset
	ScreenPack.text(card, "Dégâts  %d" % int(h.damage), Rect2(d[0], d[1], 170, 26), 19)
	var hl: Array = C.healing_offset
	if float(h.healing) > 0.0:
		ScreenPack.text(card, "Soins  %d" % int(h.healing), Rect2(hl[0], hl[1], 170, 26), 19, Color("2f7d4f"))
	if not h.alive:
		ScreenPack.text(card, "K.O.", Rect2(0, 286, r.size.x, 26), 18, Color("a0353b"), HORIZONTAL_ALIGNMENT_CENTER)
	if mvp:
		ScreenPack.image(card, ScreenPack.tex(P, "reward_best_hunter_medal_64"), Rect2(r.size.x - 62, 6, 52, 52))
		ScreenPack.text(card, "Meilleur chasseur", Rect2(0, 286, r.size.x, 26), 17, UiKit.WOOD, HORIZONTAL_ALIGNMENT_CENTER)


func _reward_icon(key: String) -> String:
	if REWARD_ICONS.has(key):
		return REWARD_ICONS[key]
	if key.begins_with("essence_"):
		return "reward_essences_64"
	if key.begins_with("relique_"):
		return "reward_relic_fragment_64"
	return "reward_materials_64"


## Nom lisible d'un butin : fragments d'une relique, Esprits, matériaux de monstres…
func _reward_name(key: String, amount := 1) -> String:
	if REWARD_NAMES.has(key):
		return REWARD_NAMES[key]
	if key.begins_with("esprit_"):
		return HeroesScreen.esprit_name(key, amount > 1)
	if key.begins_with("parchemin_xp_"):
		return String(GameData.progression.get("xp_scrolls", {}).get(key, {}).get("name", "Parchemin d'expérience"))
	if key.begins_with("essence_"):
		return "Essence " + ("d'" if key.ends_with("ombre") or key.ends_with("eau") else "de ") + key.trim_prefix("essence_")
	if key.begins_with("relique_"):
		var relic: Dictionary = GameData.relics.get("relics", {}).get(key.trim_prefix("relique_"), {})
		return "Fragments · %s" % relic.get("name", key)
	return key.replace("_", " ").capitalize()


# --- Victoire / Défaite en plein écran (pack « Finitions ») -------------------------------------

## Décor de victoire (port en fête) ou de défaite, ruban du titre, 3 étoiles qui s'allument l'une
## après l'autre, rangée des chasseurs (portrait, niveau, survol = dégâts et soins), butin sur un
## parchemin, coffre de fin de niveau, boutons Rejouer et Retour au port.
const FC := "combat"
const PACK_REWARD_ICONS := {"gold": "combat/icones/or.png", "gems": "combat/icones/gemme.png",
	"fragments_relique": "combat/icones/eclat.png", "materiaux_relique": "combat/icones/fragment_relique.png"}

var _pack := false
var _p_bg: TextureRect
var _p_title: Label
var _p_stars: Array[Control] = []
var _p_box: Control
var _p_restart: TextureButton
var _p_next: TextureButton


func _ready_pack() -> void:
	_pack = true
	for c in get_children():
		if c != _chest_reveal:
			c.visible = false
	var root := ScreenPack.frame(self)
	move_child(root, 0)
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	var S: Dictionary = FinPack.data(FC).get("screens", {}).get("victoire", {})
	_p_bg = FinPack.image(root, "combat/victoire_fond.png", Rect2(0, 0, 1920, 1080))
	var br := FinPack.rect(S.get("banner_rect", [560, 150, 800, 110]))
	FinPack.nine(root, "combat/commun/bandeau_titre.png", br, [130, 24, 130, 28])
	_p_title = ScreenPack.shadow(ScreenPack.text(root, "", Rect2(br.position + Vector2(0, 28), Vector2(br.size.x, 50)), 42,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 3)
	for st: Dictionary in S.get("stars", []):
		var r := FinPack.rect(st.rect)
		var holder := Control.new()
		holder.position = r.position
		holder.size = r.size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(holder)
		FinPack.image(holder, "combat/etoile_vide.png", Rect2(r.size / 2.0 - Vector2(72, 72), Vector2(144, 144)))
		_p_stars.append(holder)
	_p_box = Control.new()
	_p_box.size = Vector2(1920, 1080)
	_p_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_p_box)
	var cr := FinPack.rect(S.get("continue_rect", [750, 900, 420, 96]))
	_p_restart = FinPack.button(root, "combat/bouton_continuer", Rect2(cr.position - Vector2(250, 0), cr.size), "Rejouer", 26)
	_p_restart.pressed.connect(func() -> void: restart_pressed.emit())
	_p_next = FinPack.button(root, "combat/bouton_continuer", Rect2(cr.position + Vector2(250, 0), cr.size), "Retour au port", 26)
	_p_next.pressed.connect(func() -> void: continue_pressed.emit())
	move_child(_chest_reveal, get_child_count() - 1)


func _show_pack(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String, replay: Dictionary) -> void:
	var S: Dictionary = FinPack.data(FC).get("screens", {}).get("victoire" if won else "defaite", {})
	_p_bg.texture = FinPack.tex(String(S.get("background", "combat/victoire_fond.png")))
	var draw: bool = replay.get("draw", false)
	_p_title.text = "ÉGALITÉ" if draw else ("VICTOIRE" if won else "DÉFAITE")
	for c in _p_box.get_children():
		_p_box.remove_child(c)
		c.queue_free()
	for h in _p_stars:
		h.get_child(0).visible = true
		for k in range(h.get_child_count() - 1, 0, -1):
			h.get_child(k).queue_free()
	ScreenPack.shadow(ScreenPack.text(_p_box, dungeon_name, Rect2(560, 268, 800, 34), 24, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	# Les chasseurs : une petite rangée de portraits sous les étoiles.
	var best := 0.0
	for h: Dictionary in hero_stats:
		best = maxf(best, float(h.damage))
	var n := hero_stats.size()
	for k in n:
		var h: Dictionary = hero_stats[k]
		var hero := GameData.hero(String(h.get("id", "")))
		var x := 960.0 - n * 52.0 + k * 104.0
		var cell := Control.new()
		cell.position = Vector2(x, 524)
		cell.size = Vector2(96, 96)
		var tip := "%s · niveau %d\nDégâts : %d" % [h.name, int(h.level), int(h.damage)]
		if float(h.healing) > 0.0:
			tip += "\nSoins : %d" % int(h.healing)
		cell.tooltip_text = tip + ("" if h.alive else "\nK.O.")
		_p_box.add_child(cell)
		if not hero.is_empty():
			var p := RoundPortrait.new().setup(hero, 72, 0.08)
			p.position = Vector2(12, 0)
			p.set_grey(not h.alive)
			cell.add_child(p)
		var up: bool = h.get("level_up", false)
		ScreenPack.shadow(ScreenPack.text(cell, ("Niv. %d ▲" if up else "+%d XP") % (int(h.level) if up else int(h.xp)),
			Rect2(-10, 70, 116, 24), 15, Color("63c8be") if up else UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
		if float(h.damage) > 0.0 and float(h.damage) == best:
			FinPack.image(cell, "combat/etoile_pleine.png", Rect2(64, -6, 30, 30))
	# Butin sur le parchemin.
	var rr := FinPack.rect(S.get("rewards_rect", [550, 610, 820, 220]))
	FinPack.nine(_p_box, "combat/commun/parchemin.png", rr, [140, 50, 140, 50])
	var icons: Array = S.get("reward_icons", [])
	var values: Array = S.get("reward_values", [])
	if rewards.is_empty():
		ScreenPack.text(_p_box, "Aucun butin", rr, 26, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var i := 0
	for key: String in rewards:
		if i >= icons.size():
			break
		var ir := FinPack.rect(icons[i])
		ir.position.x += 40.0
		var t: Texture2D = FinPack.tex(PACK_REWARD_ICONS[key]) if PACK_REWARD_ICONS.has(key) else (
			ChestReveal.esprit_icon(key) if key.begins_with("esprit_") else (ChestReveal.scroll_icon(key)
			if key.begins_with("parchemin_xp_") else ScreenPack.tex(P, _reward_icon(key))))
		var img := ScreenPack.image(_p_box, ScreenPack.trimmed(t), ir.grow(-6))
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.mouse_filter = Control.MOUSE_FILTER_PASS
		img.tooltip_text = _reward_name(key, int(rewards[key]))
		ScreenPack.text(_p_box, str(int(rewards[key])), FinPack.rect(values[i]).grow_individual(-20, 0, 60, 0), 24, UiKit.INK,
			HORIZONTAL_ALIGNMENT_CENTER)
		i += 1
	# Ligne du coffre, niveau de la loge, ou conseil.
	var chest: Dictionary = replay.get("chest", {})
	var line := ""
	var color := UiKit.WHITE
	if not chest.is_empty():
		var bits: Array[String] = []
		for key: String in chest.rewards:
			bits.append("+%d %s" % [int(chest.rewards[key]), _reward_name(key, int(chest.rewards[key])).to_lower()])
		line = "%s !   %s" % [chest.name, "  ·  ".join(bits)]
		color = CHEST_COLORS.get(chest.kind, UiKit.WOOD).lightened(0.4)
	elif replay.get("player_level_up", false):
		line = "Ta loge passe au niveau %d !" % int(replay.player_level)
		color = Color("63c8be")
	elif draw:
		line = "Combat arrêté : pas de butin, ton énergie t'est rendue."
	elif not won:
		line = "Conseil : améliore tes héros, éveille-les avec des Esprits et change ta formation."
	var cl: Label = null
	if line != "":
		cl = ScreenPack.shadow(ScreenPack.text(_p_box, line, Rect2(360, 842, 1200, 40), 24, color, HORIZONTAL_ALIGNMENT_CENTER), 2)
	var cost: int = replay.get("cost", 0)
	(_p_restart.get_node("Label") as Label).text = "Rejouer" if cost <= 0 else "Rejouer · %d énergie" % cost
	_p_restart.disabled = not replay.get("possible", true)
	_p_restart.tooltip_text = "" if not _p_restart.disabled else "Pas assez d'énergie (%d)." % int(replay.get("energy", 0))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	# Les étoiles s'allument l'une après l'autre (décalage du pack).
	var anim: Dictionary = FinPack.data(FC).get("animations", {}).get("etoile_allumage", {})
	var stars_def: Array = S.get("stars", [])
	for k in mini(stars, _p_stars.size()):
		var holder := _p_stars[k]
		var delay := 0.5 + float(stars_def[k].get("start_delay_ms", k * 180)) / 1000.0 * 2.0
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(holder):
				return
			holder.get_child(0).visible = false  # l'étoile vide s'efface derrière celle qui s'allume
			var s := FinPack.sheet(anim)
			s.position = holder.size / 2.0
			holder.add_child(s)
			s.play("a")
			sound.emit("ui_ready"))
	if not chest.is_empty():
		get_tree().create_timer(0.9 + stars * 0.4).timeout.connect(func() -> void:
			_chest_reveal.show_chest(chest, _reward_name)
			sound.emit("ultimate_impact" if chest.kind in ["or", "serment"] else "ui_ready"))
	if cl:
		cl.modulate.a = 0.0
		create_tween().tween_property(cl, "modulate:a", 1.0, 0.3).set_delay(1.0 + stars * 0.4)
