class_name HuntPrepScreen
extends Control
## « Préparer la chasse » : le campement des chasseurs (pack « Finitions », assets/ui/finitions/
## preparation_chasse/). Au milieu, la formation en losange telle qu'en combat (2 devant à droite,
## 3 au milieu, 2 à l'arrière), les héros animés sur leurs tapis ; en bas, le tiroir des héros
## possédés (toucher = ajouter ou retirer) ; à droite, le niveau, la Force d'équipe, les synergies et
## le bouton « Partir en chasse ». Toucher deux places de la formation les échange.

signal start_requested(dungeon_id: String)
signal ui_sound(sfx_name: String)
signal closed

const PC := "preparation_chasse"
## Place de la formation (ordre du combat : 0-1 devant, 2-4 milieu, 5-6 arrière) -> id du pack.
const SPOT_IDS := ["avant_1", "avant_2", "milieu_1", "milieu_2", "milieu_3", "arriere_1", "arriere_2"]
const LINE_TIPS := ["Devant : protège les autres ; un combattant au corps-à-corps y subit 10 % de dégâts en moins.",
	"Milieu : un lanceur de magie a 15 % de chances d'enchaîner une attaque de base.",
	"Arrière : soins et boucliers +10 %, dégâts à distance +10 % ; protégé tant que la ligne de devant tient."]
## Pastilles de synergie : 5 éléments puis 5 classes (icône du pack -> clé de combos.json).
const PASTILLES := [["feu", "element", "feu"], ["eau", "element", "eau"], ["nature", "element", "nature"],
	["lumiere", "element", "lumiere"], ["ombre", "element", "ombre"], ["tank", "class", "gardien"],
	["guerrier", "class", "lame"], ["archer", "class", "traqueur"], ["mage", "class", "arcaniste"],
	["soigneur", "class", "soutien"]]

var dungeon_id := ""
var _root: Control
var _title: Label
var _info: Label
var _energy: Label
var _board: Control
var _drawer: Control
var _force_label: Label
var _force: FinPack.Gauge
var _pastilles: Array[TextureRect] = []
var _go: TextureButton
var _go_label: Label
var _picked := -1  # place choisie pour un échange
var _page := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_root = ScreenPack.frame(self)
	var D := FinPack.data(PC)
	var P: Dictionary = D.get("positions", {})
	FinPack.image(_root, String(D.get("background", "preparation_chasse/campement.png")), Rect2(0, 0, 1920, 1080))
	var fire: Dictionary = D.get("animations", {}).get("feu_camp", {})
	# Le décor a sa fosse vide : on y pose seulement les flammes et les bûches (pierres de la planche retirées).
	if not fire.is_empty():
		var f2 := fire.duplicate()
		f2.file = "preparation_chasse/animations/feu_camp_flammes.png"
		f2.frame_size = [224, 170]
		f2.pivot = [112, 160]
		var s := FinPack.sheet(f2)
		s.position = Vector2(270, 506)
		_root.add_child(s)
		s.play("a")
	var tr := FinPack.rect(P.titre)
	FinPack.nine(_root, "preparation_chasse/commun/bandeau_titre.png", tr, [130, 24, 130, 28])
	_title = ScreenPack.shadow(ScreenPack.text(_root, "", Rect2(tr.position + Vector2(40, 24), Vector2(tr.size.x - 80, 36)), 28,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var back := FinPack.button(_root, "preparation_chasse/commun/retour", FinPack.rect(P.retour), "Retour", 24)
	back.get_node("Label").position.x = 30
	back.pressed.connect(func() -> void:
		ui_sound.emit("ui_click")
		visible = false
		closed.emit())
	var mr := FinPack.rect(P.monnaie)
	FinPack.nine(_root, "preparation_chasse/commun/cartouche_monnaie.png", mr, [74, 18, 22, 18])
	FinPack.image(_root, "port_franc/icones/energie.png", Rect2(mr.position + Vector2(14, 12), Vector2(48, 48)))
	_energy = ScreenPack.shadow(ScreenPack.text(_root, "", Rect2(mr.position + Vector2(66, 0), mr.size - Vector2(80, 0)), 28,
		UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
	# Le niveau : un parchemin à droite.
	var ir := Rect2(1400, 440, 510, 300)
	FinPack.nine(_root, "preparation_chasse/commun/parchemin.png", ir, [140, 24, 140, 24])
	_info = ScreenPack.text(_root, "", Rect2(ir.position + Vector2(100, 100), ir.size - Vector2(200, 160)), 17, UiKit.INK,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.size = Vector2(1920, 1080)
	_root.add_child(_board)
	FinPack.nine(_root, "preparation_chasse/tiroir_heros.png", FinPack.rect(P.tiroir), [79, 22, 79, 22])
	_drawer = Control.new()
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawer.size = Vector2(1920, 1080)
	_root.add_child(_drawer)
	_force_label = ScreenPack.shadow(ScreenPack.text(_root, "", FinPack.rect(P.force_label), 24, Color("f3d9a0")), 2)
	_force = FinPack.Gauge.new().setup("preparation_chasse/jauge_force_fond.png", FinPack.rect(P.force_fond), [12, 12, 12, 12],
		"preparation_chasse/jauge_force_remplissage.png", FinPack.rect(P.force_remplissage))
	_root.add_child(_force)
	for i in mini(PASTILLES.size(), P.synergies.size()):
		var t := FinPack.image(_root, "", FinPack.rect(P.synergies[i]))
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		_pastilles.append(t)
	var go: Dictionary = D.get("buttons", {}).get("partir", {})
	_go = FinPack.button(_root, "preparation_chasse/bouton_partir", FinPack.rect(go.get("rect", [1450, 920, 420, 96])), " ", 24)
	_go_label = _go.get_node("Label")
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
	_title.text = String(d.get("name", dungeon_id)).to_upper()
	_energy.text = "%d / %d" % [PlayerData.energy(), PlayerData.energy_max()]
	var team := PlayerData.team()
	var lines: Array[String] = ["%d vagues · meilleur score : %s" % [d.get("waves", []).size(),
		"★".repeat(PlayerData.best_stars(dungeon_id)) if PlayerData.best_stars(dungeon_id) > 0 else "aucun"]]
	var formed: Array = []
	for cid: String in GameData.team_combos():
		var c: Dictionary = GameData.team_combos()[cid]
		if c.members.all(func(m: String) -> bool: return m in team):
			formed.append(String(c.name))
	if not formed.is_empty():
		lines.append("Combos : " + ", ".join(formed))
	var active := synergy_lines(team)
	if not active.is_empty():
		lines.append("Synergies : " + ", ".join(active))
	_info.text = "\n".join(lines)
	# Force : celle de l'équipe, comparée aux 7 meilleurs héros possédés.
	var best: Array = PlayerData.owned_heroes().map(func(h: String) -> int: return PlayerData.hero_power(h))
	best.sort()
	best.reverse()
	var top := 0
	for k in mini(7, best.size()):
		top += int(best[k])
	var tp := PlayerData.team_power()
	_force_label.text = "Force d'équipe : %s" % HubHud._fmt(tp)
	_force.set_ratio(float(tp) / maxf(1.0, top))
	_fill_pastilles(team)
	_fill_board(team)
	_fill_drawer(team)
	var cost := PlayerData.hunt_cost(dungeon_id)
	_go_label.text = "Partir · %d énergie" % cost
	_go.disabled = team.is_empty() or not PlayerData.can_start_hunt(dungeon_id)
	if PlayerData.energy() < cost:
		_go_label.text = "Énergie : %d / %d" % [PlayerData.energy(), cost]
	_go_label.modulate = Color(0.7, 0.68, 0.64) if _go.disabled else Color.WHITE


## Pastilles allumées quand l'équipe atteint un palier de synergie (survol : le détail).
func _fill_pastilles(team: Array) -> void:
	var table := GameData.synergies()
	for i in _pastilles.size():
		var p: Array = PASTILLES[i]
		var n := 0
		for id: String in team:
			if String(GameData.hero(id).get(p[1], "")) == p[2]:
				n += 1
		var info: Dictionary = table.get(p[1], {}).get(p[2], {})
		var on := false
		for level: Array in info.get("levels", []):
			if n >= int(level[0]):
				on = true
		_pastilles[i].texture = FinPack.tex("preparation_chasse/synergies/%s_%s.png" % [p[0], "allume" if on else "eteint"])
		_pastilles[i].tooltip_text = "%s · %d héros" % [info.get("name", p[2]), n]


## La formation : un tapis par place (occupé / vide), le héros animé dessus, échange en touchant deux places.
func _fill_board(team: Array) -> void:
	for c in _board.get_children():
		c.queue_free()
	var spots := {}
	for f: Dictionary in FinPack.data(PC).get("formation", []):
		spots[String(f.id)] = f
	for i in SPOT_IDS.size():
		var f: Dictionary = spots.get(SPOT_IDS[i], {})
		if f.is_empty():
			continue
		var r := FinPack.rect(f.rect)
		var feet := Vector2(f.hero_feet[0], f.hero_feet[1])
		var spot := Control.new()
		spot.position = r.position
		spot.size = r.size
		spot.mouse_filter = Control.MOUSE_FILTER_STOP
		spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		spot.tooltip_text = LINE_TIPS[0 if i < 2 else (1 if i < 5 else 2)]
		_board.add_child(spot)
		var mat := FinPack.image(spot, "preparation_chasse/formation_%s.png" % ("occupee" if i < team.size() else "vide"),
			Rect2(Vector2.ZERO, r.size))
		if i == _picked:
			mat.modulate = Color(1.5, 1.35, 0.8)
		if i < team.size():
			var id: String = team[i]
			var p := ClipPlayer.new()
			p.bundle = "res://assets/anim/heroes/"
			p.idle_clip = id + "_idle"
			p.position = feet - r.position
			p.scale = Vector2.ONE * 0.36
			spot.add_child(p)
			p.play(id + "_idle")
			p.speed = 0.0  # pose fixe
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


## Le tiroir : les héros possédés, 11 par page (flèches aux bords s'il y en a plus).
func _fill_drawer(team: Array) -> void:
	for c in _drawer.get_children():
		c.queue_free()
	var P: Dictionary = FinPack.data(PC).get("positions", {})
	var rects: Array = P.get("portraits", [])
	var owned := PlayerData.owned_heroes()
	var pages := maxi(1, ceili(float(owned.size()) / rects.size()))
	_page = clampi(_page, 0, pages - 1)
	for k in rects.size():
		var idx := _page * rects.size() + k
		if idx >= owned.size():
			break
		var id: String = owned[idx]
		var r := FinPack.rect(rects[k])
		var in_team := id in team
		var b := Control.new()
		b.position = r.position
		b.size = r.size
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.tooltip_text = "%s · niveau %d · Force %d" % [GameData.hero(id).name, PlayerData.hero_level(id), PlayerData.hero_power(id)]
		_drawer.add_child(b)
		var full := team.size() >= 7 and not in_team
		var port := RoundPortrait.new().setup(GameData.hero(id), r.size.x - 20, 0.0)
		port.position = Vector2(10, 10)
		b.add_child(port)
		if full:
			port.set_grey(true)
		FinPack.image(b, "preparation_chasse/portrait_%s.png" % ("choisi" if in_team else ("grise" if full else "normal")),
			Rect2(Vector2.ZERO, r.size))
		ScreenPack.shadow(ScreenPack.text(b, str(PlayerData.hero_level(id)), Rect2(r.size.x - 34, r.size.y - 28, 30, 24), 16,
			UiKit.WHITE, HORIZONTAL_ALIGNMENT_RIGHT), 2)
		var hid := id
		b.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				if PlayerData.toggle_team(hid):
					_picked = -1
					ui_sound.emit("ui_toggle"))
	var tr := FinPack.rect(P.tiroir)
	ScreenPack.shadow(ScreenPack.text(_drawer, "Choisis tes chasseurs · %d / 7" % team.size(),
		Rect2(tr.position + Vector2(0, -40), Vector2(tr.size.x, 34)), 24, Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 3)
	ScreenPack.shadow(ScreenPack.text(_drawer, "Touche deux héros de la formation pour échanger leurs places",
		Rect2(tr.position + Vector2(0, tr.size.y - 48), Vector2(tr.size.x, 28)), 18, Color("cbbfae"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	if pages > 1:
		for dir: int in [-1, 1]:
			var a := TextureButton.new()
			var side := "precedente" if dir < 0 else "suivante"
			a.texture_normal = MageRoom.tex("jardin/fleche_salle_%s_normal.png" % side)
			a.texture_hover = MageRoom.tex("jardin/fleche_salle_%s_survol.png" % side)
			a.ignore_texture_size = true
			a.stretch_mode = TextureButton.STRETCH_SCALE
			a.size = Vector2(80, 60)
			a.position = Vector2(tr.position.x + tr.size.x - 190 + (0 if dir < 0 else 92), tr.end.y - 64)
			a.disabled = (_page == 0 and dir < 0) or (_page == pages - 1 and dir > 0)
			a.modulate.a = 0.35 if a.disabled else 1.0
			a.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			a.pressed.connect(func() -> void:
				ui_sound.emit("ui_click")
				_page += dir
				refresh())
			_drawer.add_child(a)


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
