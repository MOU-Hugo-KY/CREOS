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


## hero_stats : Array de {id, name, element, alive, damage, healing, level, xp, level_up}
## replay : {cost, possible, energy, player_level_up, player_level, chest}
func show_result(won: bool, stars: int, rewards: Dictionary, hero_stats: Array, dungeon_name: String, replay := {}) -> void:
	var R: Dictionary = ScreenPack.layout(P).results
	_window.add_theme_stylebox_override("panel", ScreenPack.nine(P, "result_victory_window" if won else "result_defeat_window"))
	_title.text = "VICTOIRE" if won else "DÉFAITE"
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
		icon = ScreenPack.tex("fiche_heros", "element_%s_64" % ELEMENT_KEYS.get(key.get_slice("_", 2), "shadow"))
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
	if key.begins_with("essence_"):
		return "Essence " + ("d'" if key.ends_with("ombre") or key.ends_with("eau") else "de ") + key.trim_prefix("essence_")
	if key.begins_with("relique_"):
		var relic: Dictionary = GameData.relics.get("relics", {}).get(key.trim_prefix("relique_"), {})
		return "Fragments · %s" % relic.get("name", key)
	return key.replace("_", " ").capitalize()
