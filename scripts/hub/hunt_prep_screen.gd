class_name HuntPrepScreen
extends Control
## « Préparer la chasse », en pixel (pièces des écrans du hub) : l'arène du monde en fond avec la
## formation telle qu'en combat (2 devant, 3 au milieu, 2 à l'arrière, ligne et bonus de chaque place),
## les héros animés à leur place ; à droite, tous les héros possédés. Toucher un héros de la liste
## l'ajoute ou le retire ; toucher deux places de la formation les échange.

signal start_requested(dungeon_id: String)
signal ui_sound(sfx_name: String)
signal closed

const S := "lanterne"
const F := "fiche_heros"
## Places de la formation à l'écran (pieds), même ordre que le combat : 0-1 devant, 2-4 milieu, 5-6 arrière.
const SPOTS := [Vector2(810, 520), Vector2(810, 760), Vector2(560, 430), Vector2(560, 640), Vector2(560, 850),
	Vector2(310, 520), Vector2(310, 760)]
const LINE_NAMES := ["Devant", "Milieu", "Arrière"]
const LINE_TIPS := ["Devant : protège les autres ; un combattant au corps-à-corps y subit 10 % de dégâts en moins.",
	"Milieu : un lanceur de magie a 15 % de chances d'enchaîner une attaque de base.",
	"Arrière : soins et boucliers +10 %, dégâts à distance +10 % ; protégé tant que la ligne de devant tient."]

var dungeon_id := ""
var _root: Control
var _arena: TextureRect
var _title: Label
var _info: Label
var _board: Control
var _pool: GridContainer
var _go: Button
var _picked := -1  # place choisie pour un échange


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = ScreenPack.frame(self)
	# Fond : l'arène du monde, assombrie, dans le cadre de la vitrine.
	ScreenPack.panel(_root, F, "vitrine_frame", Rect2(24, 104, 1060, 952))
	_arena = ScreenPack.image(_root, null, Rect2(48, 128, 1012, 904))
	_arena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_arena.modulate = Color(0.78, 0.76, 0.82)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.size = Vector2(1920, 1080)
	_root.add_child(_board)
	# En-tête.
	var back := ScreenPack.button(_root, S, "return", "← Retour", Rect2(24, 8, 240, 88), 28)
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		visible = false
		closed.emit())
	ScreenPack.image(_root, ScreenPack.tex(S, "title"), Rect2(290, 12, 800, 80))
	_title = ScreenPack.text(_root, "", Rect2(290, 12, 800, 80), 34, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# Droite : informations du niveau et héros possédés.
	ScreenPack.panel(_root, S, "infos_panel", Rect2(1108, 104, 788, 952))
	_info = ScreenPack.text(_root, "", Rect2(1146, 136, 712, 150), 23, UiKit.INK, 0, true)
	ScreenPack.text(_root, "TES HÉROS · touche pour ajouter ou retirer", Rect2(1146, 290, 712, 40), 23, UiKit.WOOD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1140, 336)
	scroll.size = Vector2(726, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_pool = GridContainer.new()
	_pool.columns = 6
	_pool.add_theme_constant_override("h_separation", 12)
	_pool.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_pool)
	_go = ScreenPack.button(_root, S, "invoke_gems", "", Rect2(1150, 920, 704, 100), 32)
	_go.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		start_requested.emit(dungeon_id))
	PlayerData.changed.connect(func() -> void:
		if visible:
			refresh())
	visible = false


func open_for(p_dungeon: String) -> void:
	dungeon_id = p_dungeon
	_picked = -1
	visible = true
	refresh()


func close_window() -> void:
	visible = false


func refresh() -> void:
	var d := GameData.dungeon(dungeon_id)
	var region := dungeon_id.get_slice("_", 0)
	var arena := "res://assets/decors/%s/arene1.png" % region
	_arena.texture = load(arena) if ResourceLoader.exists(arena) else null
	_title.text = String(d.get("name", dungeon_id)).to_upper()
	var team := PlayerData.team()
	var lines: Array[String] = ["%d vagues · meilleur score : %s" % [d.get("waves", []).size(),
		"★".repeat(PlayerData.best_stars(dungeon_id)) if PlayerData.best_stars(dungeon_id) > 0 else "aucun"]]
	var formed: Array = []
	for cid: String in GameData.team_combos():
		var c: Dictionary = GameData.team_combos()[cid]
		if c.members.all(func(m: String) -> bool: return m in team):
			formed.append("%s (%d)" % [c.name, c.members.size()])
	if not formed.is_empty():
		lines.append("Combos : " + ", ".join(formed))
	var active := synergy_lines(team)
	if not active.is_empty():
		lines.append("Synergies : " + ", ".join(active))
	_info.text = "\n".join(lines)
	_fill_board(team)
	_fill_pool(team)
	var cost := PlayerData.hunt_cost(dungeon_id)
	_go.text = "Partir en chasse · %d énergie" % cost
	_go.disabled = team.is_empty() or not PlayerData.can_start_hunt(dungeon_id)
	if PlayerData.energy() < cost:
		_go.text = "Pas assez d'énergie (%d / %d)" % [PlayerData.energy(), cost]


## La formation : étiquettes des trois lignes, une place par héros (animé), échange en touchant deux places.
func _fill_board(team: Array) -> void:
	for c in _board.get_children():
		c.queue_free()
	for line in 3:
		var x: float = [810.0, 560.0, 310.0][line]
		var tag := ScreenPack.shadow(ScreenPack.text(_board, LINE_NAMES[line].to_upper(), Rect2(x - 120, 146, 240, 52), 32,
			Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER))
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
		tag.tooltip_text = LINE_TIPS[line]
	var hint := ScreenPack.text(_board, "Touche deux héros pour échanger leurs places · survole une ligne pour son bonus",
		Rect2(70, 940, 970, 40), 22, UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("shadow_offset_y", 2)
	for i in SPOTS.size():
		var foot: Vector2 = SPOTS[i]
		var spot := Control.new()
		spot.position = foot - Vector2(80, 170)
		spot.size = Vector2(160, 200)
		spot.mouse_filter = Control.MOUSE_FILTER_STOP
		spot.tooltip_text = LINE_TIPS[0 if i < 2 else (1 if i < 5 else 2)]
		_board.add_child(spot)
		var ring := _Ring.new()
		ring.position = Vector2(80, 170)
		ring.picked = i == _picked
		spot.add_child(ring)
		if i < team.size():
			var id: String = team[i]
			var p := ClipPlayer.new()
			p.bundle = "res://assets/anim/heroes/"
			p.idle_clip = id + "_idle"
			p.position = Vector2(80, 170)
			p.scale = Vector2.ONE * 0.36
			spot.add_child(p)
			p.play(id + "_idle")
			ScreenPack.text(spot, String(GameData.hero(id).get("short", GameData.hero(id).name)), Rect2(0, 176, 160, 26), 20,
				UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		var slot := i
		spot.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_on_spot(slot, team))


func _on_spot(slot: int, team: Array) -> void:
	if slot >= team.size():
		_picked = -1
		refresh()
		return
	if _picked == -1:
		_picked = slot
		ui_sound.emit("ui_click")
		refresh()
		return
	if _picked != slot:
		var t: Array = team.duplicate()
		var a: String = t[_picked]
		t[_picked] = t[slot]
		t[slot] = a
		PlayerData.state["team"] = t
		PlayerData.save_game()
		ui_sound.emit("ui_toggle")
	_picked = -1
	PlayerData.changed.emit()


func _fill_pool(team: Array) -> void:
	for c in _pool.get_children():
		c.queue_free()
	for id: String in PlayerData.owned_heroes():
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(110, 0)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(96, 96)
		var p := RoundPortrait.new().setup(GameData.hero(id), 96, 0.09 if id in team else 0.05)
		if id in team:
			p.modulate = Color(1, 1, 1, 0.45)
		b.add_child(p)
		var hid := id
		b.pressed.connect(func() -> void:
			if PlayerData.toggle_team(hid):
				_picked = -1
				ui_sound.emit("ui_toggle"))
		var center := CenterContainer.new()
		center.add_child(b)
		col.add_child(center)
		var n := UiKit.label("%s · %d" % [String(GameData.hero(id).get("short", GameData.hero(id).name)), PlayerData.hero_level(id)],
			16, UiKit.INK if id in team else UiKit.TEXT_SOFT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		_pool.add_child(col)


## Synergies que l'équipe déclenche : « Ardeur ×2 », « Rempart ×4 »…
static func synergy_lines(team: Array) -> Array:
	var out: Array = []
	var table := GameData.synergies()
	for kind: String in ["element", "class"]:
		var counts := {}
		for id: String in team:
			var key := String(GameData.hero(id).get(kind, ""))
			counts[key] = int(counts.get(key, 0)) + 1
		for key: String in counts:
			if not table.get(kind, {}).has(key):
				continue
			var reached := 0
			for level: Array in table[kind][key].levels:
				if counts[key] >= int(level[0]):
					reached = int(level[0])
			if reached > 0:
				out.append("%s ×%d" % [table[kind][key].name, counts[key]])
	return out


## Anneau au sol d'une place (doré quand la place est choisie pour un échange).
class _Ring extends Node2D:
	var picked := false

	func _draw() -> void:
		var c := Color("f2c75c") if picked else Color(1, 1, 1, 0.35)
		var pts := PackedVector2Array()
		for k in 33:
			var a := TAU * k / 32.0
			pts.append(Vector2(cos(a) * 62.0, sin(a) * 20.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.3))
		draw_polyline(pts, c, 3.0 if picked else 2.0)
