class_name DruidRoom
extends Control
## Sanctuaire du Druide (invocation d'Esprits), pack « Invocateurs » (assets/ui/invocateurs/druide/,
## positions dans invocateurs.json). Repère 1920 × 1080. Au repos : le druide respire, des lucioles
## flottent. `ceremony(élément)` : il plante son bâton, une onde de nature court vers l'autel,
## l'alcôve de l'élément s'éveille, une bulle d'énergie éclot sur l'autel ; `show_esprits()`
## montre ce qui en sort.

const DRUID_SCALE := 1.6
## Alcôves du décor (clés de invocateurs.json) selon l'élément du jeu.
const CORNERS := {"feu": "feu", "eau": "eau", "nature": "nature", "lumiere": "lumiere", "ombre": "ombre"}

var altar := Vector2(960, 800)
var spirit_feet := Vector2(960, 740)
var _druid: MageRoom.Sheet
var _wave: MageRoom.Sheet
var _wave_from := Vector2(535, 800)
var _wave_to := Vector2(960, 675)
var _corners: Dictionary = {}  # élément -> Sheet
var _hatch: MageRoom.Sheet
var _add: CanvasItemMaterial
var _ambiance: RoomAmbiance
var _flies: Array = []  # [ColorRect, phase, centre]
var _t := 0.0
var _shown: Array[Control] = []


static func available() -> bool:
	return ResourceLoader.exists(MageRoom.DIR + "druide/salle_druide.png")


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var room: Dictionary = MageRoom.data().get("salles", {}).get("druide", {})
	altar = MageRoom._vec(room.get("centre_autel", [960, 800]))
	spirit_feet = MageRoom._vec(room.get("sol_esprit", [960, 740]))
	var path: Dictionary = room.get("onde_nature_path", {})
	_wave_from = MageRoom._vec(path.get("depart", [535, 800]))
	_wave_to = MageRoom._vec(path.get("arrivee", [960, 675]))
	var bg := TextureRect.new()
	bg.texture = MageRoom.tex("druide/salle_druide.png")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_ambiance = RoomAmbiance.make("druide")
	add_child(_ambiance)
	for elem: String in CORNERS:
		var c: Dictionary = room.get("coins_elements", {}).get(CORNERS[elem], {})
		if c.is_empty():
			continue
		var s := _sheet(String(c.animation))
		s.position = MageRoom._vec(c.position)
		s.scale = Vector2(1.4, 1.4)
		s.material = _add
		s.visible = false
		_corners[elem] = [s, String(c.animation)]
	_druid = _sheet("druide_repos")
	_druid.position = MageRoom._vec(room.get("sol_personnage", [460, 890]))
	_druid.scale = Vector2.ONE * DRUID_SCALE
	_druid.play("druide_repos")
	_wave = _sheet("onde_nature")
	_wave.material = _add
	_wave.scale = Vector2(1.5, 1.5)
	_wave.visible = false
	_hatch = _sheet("eclosion_esprit")
	_hatch.position = altar
	_hatch.scale = Vector2(1.3, 1.3)
	_hatch.material = _add
	_hatch.visible = false
	for i in 26:
		var f := ColorRect.new()
		f.size = Vector2(3, 3)
		f.color = [Color("d8ff8a"), Color("ffe08a"), Color("9fe8ff")][i % 3]
		f.material = _add
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(f)
		_flies.append([f, randf() * TAU, Vector2(randf_range(150, 1770), randf_range(250, 900))])


func _process(delta: float) -> void:
	_t += delta
	for fl: Array in _flies:
		var f: ColorRect = fl[0]
		var ph: float = fl[1]
		f.position = fl[2] + Vector2(cos(_t * 0.5 + ph) * 40.0, sin(_t * 0.8 + ph * 1.7) * 26.0)
		f.modulate.a = 0.35 + 0.65 * maxf(0.0, sin(_t * 2.0 + ph))


func reset() -> void:
	if _ambiance:
		_ambiance.dim(false)
	for c in _shown:
		c.queue_free()
	_shown.clear()
	for c: Array in _corners.values():
		(c[0] as MageRoom.Sheet).visible = false
	_hatch.visible = false
	_wave.visible = false
	_druid.play("druide_repos")


## L'appel (~2,4 s) ; `elements` : les éléments des Esprits obtenus (leurs alcôves s'éveillent).
func ceremony(elements: Array) -> void:
	_ambiance.dim(true)
	reset()
	_druid.play("druide_appel", "druide_repos")
	await get_tree().create_timer(0.6).timeout
	_wave.position = _wave_from
	_wave.visible = true
	_wave.play("onde_nature")
	create_tween().tween_property(_wave, "position", _wave_to, 0.72)
	var seen := {}
	for e: String in elements:
		if seen.has(e) or not _corners.has(e):
			continue
		seen[e] = true
		var c: Array = _corners[e]
		var s: MageRoom.Sheet = c[0]
		s.visible = true
		s.play(String(c[1]))
	await get_tree().create_timer(0.72).timeout
	_wave.visible = false
	_hatch.visible = true
	_hatch.play("eclosion_esprit")
	_hatch.finished.connect(func() -> void: _hatch.visible = false, CONNECT_ONE_SHOT)
	await get_tree().create_timer(1.0).timeout


## Les Esprits obtenus, en éventail au-dessus de l'autel : icône 128, cadre de stade, quantité, nom.
func show_esprits(got: Dictionary) -> void:
	var ids := got.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return Progression.ESPRIT_STAGES.find(a.get_slice("_", 1)) > Progression.ESPRIT_STAGES.find(b.get_slice("_", 1)))
	var w := 150.0
	var per_row := mini(ids.size(), 7)
	for i in ids.size():
		var id: String = ids[i]
		var row := i / per_row
		var col := i % per_row
		var n_row := mini(per_row, ids.size() - row * per_row)
		var box := Control.new()
		box.position = Vector2(altar.x - n_row * w / 2.0 + col * w, 300 + row * 200)
		box.size = Vector2(w, 190)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_shown.append(box)
		var frame := TextureRect.new()
		frame.texture = ChestReveal.esprit_frame(id)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.position = Vector2(w / 2.0 - 56, 0)
		frame.size = Vector2(112, 112)
		box.add_child(frame)
		var ic := TextureRect.new()
		ic.texture = ChestReveal.esprit_icon(id, 128)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.position = Vector2(w / 2.0 - 48, 8)
		ic.size = Vector2(96, 96)
		box.add_child(ic)
		ScreenPack.shadow(ScreenPack.text(box, "×%d" % int(got[id]), Rect2(0, 112, w, 36), 28, Color("ffd27a"),
			HORIZONTAL_ALIGNMENT_CENTER), 3)
		ScreenPack.shadow(ScreenPack.text(box, HeroesScreen.esprit_name(id, int(got[id]) > 1), Rect2(-10, 146, w + 20, 30), 17,
			UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
		UiKit.pop_in(box, 0.06 * i)


func _sheet(anim: String) -> MageRoom.Sheet:
	var s := MageRoom.Sheet.new()
	s.anims = MageRoom.data().get("animations", {})
	s.load_anim(anim)
	add_child(s)
	return s
