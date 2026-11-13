class_name MechanicRoom
extends Control
## Atelier du Mécanicien ancien (pièces de construction des défenses), pack « Invocateurs »
## (assets/ui/invocateurs/mecanicien/, positions dans invocateurs.json). Repère 1920 × 1080.
## Au repos : le mécanicien bricole, les pièces flottent et tournent au-dessus de l'établi dans
## des particules de magie ancienne. `ceremony()` : il travaille, les pièces convergent au-dessus
## de l'établi, s'assemblent dans un éclair, étincelles et apparition ; `show_pieces()` montre ce
## qui est sorti.

const DIR := "res://assets/ui/invocateurs/"
const WORKER_SCALE := 1.0  # mécanicien peint : échelle dans invocateurs.json

var appear := Vector2(985, 555)
var _worker: MageRoom.Sheet
var _floaters: Array = []  # [TextureRect, position de repos, phase, vitesse de rotation]
var _particles: MageRoom.Sheet
var _fx: Dictionary = {}
var _t := 0.0
var _gather := 0.0  # 0 : au repos, 1 : toutes les pièces au point d'assemblage
var _add: CanvasItemMaterial
var _ambiance: RoomAmbiance
var _shown: Array[Control] = []


static func available() -> bool:
	return ResourceLoader.exists(DIR + "mecanicien/salle_mecanicien.png")


func _ready() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var room: Dictionary = MageRoom.data().get("salles", {}).get("mecanicien", {})
	appear = MageRoom._vec(room.get("centre_apparition", [985, 555]))
	_image(MageRoom.tex("mecanicien/salle_mecanicien.png"), Rect2(0, 0, 1920, 1080))
	_ambiance = RoomAmbiance.make("mecanicien")
	add_child(_ambiance)
	_particles = _sheet("particules_magie_ancienne")
	_particles.position = appear + Vector2(0, 20)
	_particles.scale = Vector2(2.2, 1.4)
	_particles.material = _add
	_particles.modulate.a = 0.7
	_particles.play("particules_magie_ancienne")
	_worker = _sheet("mecanicien_repos")
	_worker.position = MageRoom._vec(room.get("sol_personnage", [570, 765]))
	_worker.scale = Vector2.ONE * WORKER_SCALE
	_worker.position.x -= 60  # agrandi : un peu reculé pour ne pas mordre sur l'établi
	_worker.play("mecanicien_repos")
	for f: Dictionary in room.get("flottants", []):
		var t := MageRoom.tex(String(f.asset))
		if t == null:
			continue
		var at := MageRoom._vec(f.position)
		var s := t.get_size() * 1.5
		var r := _image(t, Rect2(at - s / 2.0, s))
		r.pivot_offset = s / 2.0
		_floaters.append([r, at, randf() * TAU, randf_range(-1.2, 1.2)])
	for n: String in ["assemblage", "etincelles", "apparition_objet"]:
		var fx := _sheet(n)
		fx.position = appear
		fx.scale = Vector2(1.3, 1.3)
		fx.material = _add
		fx.visible = false
		_fx[n] = fx


func _process(delta: float) -> void:
	_t += delta
	for f: Array in _floaters:
		var r: TextureRect = f[0]
		var rest: Vector2 = f[1] + Vector2(cos(_t * 0.7 + f[2]) * 14.0, sin(_t * 1.1 + f[2]) * 18.0 - 60.0)
		var c: Vector2 = rest.lerp(appear, _gather)
		r.position = c - r.size / 2.0
		r.rotation += delta * float(f[3]) * (1.0 + _gather * 6.0)
		r.modulate.a = (1.0 - maxf(0.0, _gather - 0.7) / 0.3) * (0.35 if not _shown.is_empty() else 1.0)


func reset() -> void:
	if _ambiance:
		_ambiance.dim(false)
	_gather = 0.0
	for fx: MageRoom.Sheet in _fx.values():
		fx.visible = false
	for c in _shown:
		c.queue_free()
	_shown.clear()
	_worker.play("mecanicien_repos")


## L'assemblage (~2,3 s), à attendre avec `await`.
func ceremony() -> void:
	_ambiance.dim(true)
	reset()
	_worker.play("mecanicien_travail", "mecanicien_repos")
	_play_fx("etincelles")
	await get_tree().create_timer(0.5).timeout
	create_tween().tween_property(self, "_gather", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.6).timeout
	_play_fx("assemblage")
	await get_tree().create_timer(0.9).timeout
	_play_fx("etincelles")
	_play_fx("apparition_objet")
	await get_tree().create_timer(0.35).timeout
	create_tween().tween_property(self, "_gather", 0.0, 0.6)


## Les pièces obtenues, en cercle au-dessus de l'établi : icône, quantité, nom.
func show_pieces(got: Dictionary, specs: Dictionary) -> void:
	var ids := got.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(specs.get(a, {}).get("weight", 0)) < int(specs.get(b, {}).get("weight", 0)))
	var w := 170.0
	var x0 := appear.x - ids.size() * w / 2.0
	for i in ids.size():
		var id: String = ids[i]
		var box := Control.new()
		box.position = Vector2(x0 + i * w, appear.y - 330)
		box.size = Vector2(w, 190)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		_shown.append(box)
		var back := Panel.new()
		back.add_theme_stylebox_override("panel", Palette.stylebox(Color(0.08, 0.06, 0.1, 0.8), Color("c6a66c"), 56, 3))
		back.position = Vector2(w / 2.0 - 56, -8)
		back.size = Vector2(112, 112)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(back)
		var ic := TextureRect.new()
		ic.texture = MageRoom.tex(String(specs.get(id, {}).get("icon", "")))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(w / 2.0 - 40, 8)
		ic.size = Vector2(80, 80)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ic)
		ScreenPack.shadow(ScreenPack.text(box, "×%d" % int(got[id]), Rect2(0, 106, w, 40), 32, Color("ffd27a"),
			HORIZONTAL_ALIGNMENT_CENTER), 3)
		ScreenPack.shadow(ScreenPack.text(box, String(specs.get(id, {}).get("name", id)), Rect2(-10, 144, w + 20, 30), 19,
			UiKit.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 2)
		UiKit.pop_in(box, 0.08 * i)


func _play_fx(name: String) -> void:
	var fx: MageRoom.Sheet = _fx.get(name)
	if fx:
		fx.visible = true
		fx.play(name)
		fx.finished.connect(func() -> void: fx.visible = false, CONNECT_ONE_SHOT)


func _sheet(anim: String) -> MageRoom.Sheet:
	var s := MageRoom.Sheet.new()
	s.anims = MageRoom.data().get("animations", {})
	s.load_anim(anim)
	add_child(s)
	return s


func _image(t: Texture2D, r: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr
