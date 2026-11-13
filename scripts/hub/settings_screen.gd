class_name SettingsScreen
extends Control
## Paramètres en plein écran : la boîte à musique ouverte (pack « Paramètres »,
## assets/ui/finitions/parametres/). Trois curseurs en laiton (Général, Musique, Effets) qu'on fait
## glisser ou qu'on touche, et un interrupteur par canal (coupe / rétablit le son).

signal closed
signal ui_sound(sfx_name: String)

const SCREEN := "parametres"
const BUSES := {"general": "Master", "musique": GameSettings.BUS_MUSIC, "effets": GameSettings.BUS_SFX}
const ROW_TOP := 588.0  # centre de la première rangée (velours de la boîte)
const ROW_GAP := 74.0
const RAIL_X := 760.0
const RAIL_W := 470.0
var _row_dy: Dictionary = {}  # id -> décalage vertical de la rangée
const NAMES := {"general": "Général", "musique": "Musique", "effets": "Effets"}

var _sliders: Dictionary = {}  # id -> [Gauge, knob TextureRect, x0, x1, y]
var _switches: Dictionary = {}  # id -> TextureButton
var _saved: Dictionary = {}  # volume avant la coupure d'un canal
var _drag := ""


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color("17141c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := ScreenPack.frame(self)
	var D := FinPack.data(SCREEN)
	var P: Dictionary = D.get("positions", {})
	FinPack.image(root, String(D.get("background", "parametres/boite_musique.png")), Rect2(0, 0, 1920, 1080))
	var tr := FinPack.rect(P.get("titre", [610, 24, 700, 90]))
	FinPack.nine(root, "parametres/commun/bandeau_titre.png", tr, [130, 24, 130, 28])
	ScreenPack.shadow(ScreenPack.text(root, "PARAMÈTRES", Rect2(tr.position + Vector2(0, 24), Vector2(tr.size.x, 36)), 30,
		Color("f3d9a0"), HORIZONTAL_ALIGNMENT_CENTER), 2)
	var back := FinPack.button(root, "parametres/commun/retour", FinPack.rect(P.get("retour", [40, 30, 220, 80])), "Port", 26)
	back.get_node("Label").position.x = 30
	back.pressed.connect(_close)
	var fb: Dictionary = D.get("buttons", {}).get("fermer", {})
	var close := FinPack.button(root, "parametres/fermer", FinPack.rect(fb.get("rect", [1360, 200, 48, 48])))
	close.pressed.connect(_close)
	close.visible = false  # « Port » suffit : pas de deuxième façon de fermer
	# Les rangées du pack étaient trop serrées (le nom touchait le rail du dessus) : on les écarte de ROW_GAP,
	# autour de celle du milieu, et chaque nom est posé juste au-dessus de son rail.
	var sliders: Array = D.get("sliders", [])
	for i in sliders.size():
		var s: Dictionary = sliders[i]
		var id := String(s.id)
		# Rangée i centrée dans le velours de la boîte ; le nom à gauche du rail, sur la même ligne.
		var cy := ROW_TOP + i * ROW_GAP
		var rail := Rect2(RAIL_X, cy - 22, RAIL_W, 44)
		_row_dy[id] = Vector2(0, cy - FinPack.rect(s.rail_rect).get_center().y)
		var dy: Vector2 = _row_dy[id]
		var nl := ScreenPack.shadow(ScreenPack.text(root, NAMES.get(id, id), Rect2(RAIL_X - 150, cy - 17, 140, 34), 23,
			Color("f3d9a0"), HORIZONTAL_ALIGNMENT_RIGHT), 2)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var fill := Rect2(rail.position.x + 26, cy - 7, rail.size.x - 52, 14)
		var g := FinPack.Gauge.new().setup("parametres/curseur_rail.png", rail, [36, 14, 36, 14],
			"parametres/curseur_remplissage.png", fill.grow_individual(-10, -3, -6, -3))
		root.add_child(g)
		var hit := Control.new()  # zone de saisie : toute la largeur du rail
		hit.position = g.position + Vector2(0, -10)
		hit.size = g.size + Vector2(0, 20)
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.gui_input.connect(_slider_input.bind(id))
		root.add_child(hit)
		var ks: Array = s.get("knob_size", [60, 60])
		var knob := FinPack.image(root, "parametres/curseur_bouton.png", Rect2(Vector2.ZERO, Vector2(ks[0], ks[1])))
		var rng: Array = s.knob_center_range
		_sliders[id] = [g, knob, fill.position.x, fill.end.x, cy]
	for w: Dictionary in D.get("switches", []):
		var id := String(w.id).trim_suffix("_active")
		var b := TextureButton.new()
		b.toggle_mode = true
		b.texture_normal = FinPack.tex("parametres/interrupteur_off.png")
		b.texture_pressed = FinPack.tex("parametres/interrupteur_on.png")
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		var r := FinPack.rect(w.rect)
		r.position += _row_dy.get(id, Vector2.ZERO)
		b.position = r.position
		b.size = r.size
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.toggled.connect(_switch.bind(id))
		root.add_child(b)
		_switches[id] = b
		var st := ScreenPack.shadow(ScreenPack.text(root, "", Rect2(r.end.x + 10, r.position.y, 110, r.size.y), 19, UiKit.WHITE), 2)
		b.set_meta("state_label", st)


func open() -> void:
	visible = true
	_refresh()


func _close() -> void:
	ui_sound.emit("ui_click")
	visible = false
	closed.emit()


func _refresh() -> void:
	for id: String in _sliders:
		var v := GameSettings.get_volume(BUSES[id])
		var s: Array = _sliders[id]
		(s[0] as FinPack.Gauge).set_ratio(v)
		var knob: TextureRect = s[1]
		knob.position = Vector2(lerpf(s[2], s[3], v), s[4]) - knob.size / 2.0
	for id: String in _switches:
		var on := not GameSettings.muted if id == "general" else GameSettings.get_volume(BUSES[id]) > 0.0
		(_switches[id] as TextureButton).set_pressed_no_signal(on)
		var st: Label = (_switches[id] as TextureButton).get_meta("state_label")
		st.text = "Activé" if on else "Coupé"
		st.add_theme_color_override("font_color", Color("63c8be") if on else Color("c9a0a0"))


func _slider_input(e: InputEvent, id: String) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_drag = id if mb.pressed else ""
		if not mb.pressed and id != "musique":
			ui_sound.emit("ui_click")  # entendre le volume choisi
	if _drag == id and (mb or e is InputEventMouseMotion):
		var s: Array = _sliders[id]
		var root_x: float = (e as InputEventMouse).position.x + (s[0] as Control).position.x
		GameSettings.set_volume(BUSES[id], inverse_lerp(s[2], s[3], root_x))
		_refresh()


func _switch(on: bool, id: String) -> void:
	ui_sound.emit("ui_toggle")
	if id == "general":
		GameSettings.set_muted(not on)
	elif on:
		GameSettings.set_volume(BUSES[id], float(_saved.get(id, 0.5)))
	else:
		_saved[id] = GameSettings.get_volume(BUSES[id])
		GameSettings.set_volume(BUSES[id], 0.0)
	_refresh()
